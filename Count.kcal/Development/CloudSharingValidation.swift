#if DEBUG
import CloudKit
import CryptoKit
import Foundation
#if os(iOS)
import UIKit
#endif

@MainActor
/// Debug runner for explicit sharing validation launches with sample health data.
enum CloudSharingValidation {

    /// Records whether the runner body has started.
    private static var started = false

    /// Holds the runner task and prevents a second launch.
    private static var runner: Task<Void, Never>?

    /// Starts the Debug runner for an explicit sample data validation launch.
    static func startIfRequested() {

        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--cloud-sharing-validation"), arguments.contains("--health-data-sample"),
              !arguments.contains("--sharing-qa"), runner == nil else { return }
        runner = Task { await runIfRequested() }
    }

    /// Reads requests from the app container and dispatches one bounded session.
    private static func runIfRequested() async {

        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--cloud-sharing-validation"),
              arguments.contains("--health-data-sample"),
              !arguments.contains("--sharing-qa"), !started else { return }
        started = true
        #if os(iOS)
        let previousIdleTimer = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = previousIdleTimer }
        #endif
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SharingValidation", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: folder.appendingPathComponent("request.json"))
            try Data("compiled-v8".utf8).write(to: folder.appendingPathComponent("ready.txt"), options: .atomic)
            let executable = Bundle.main.executableURL!
            let dylib = Bundle.main.bundleURL.appendingPathComponent("Count.kcal.debug.dylib")
            let ready: [String: Any] = [
                "runner": "compiled-v8", "arguments": arguments,
                "bundlePath": Bundle.main.bundlePath,
                "executableSHA256": SHA256.hash(
                    data: try Data(contentsOf: executable)
                ).map { String(format: "%02x", $0) }.joined(),
                "debugDylibSHA256": SHA256.hash(
                    data: try Data(contentsOf: dylib)
                ).map { String(format: "%02x", $0) }.joined()
            ]
            try JSONSerialization.data(
                withJSONObject: ready,
                options: [.sortedKeys]
            ).write(
                to: folder.appendingPathComponent("ready.json"),
                options: .atomic
            )
            let deadline = Date().addingTimeInterval(30 * 60)
            var processedRequests = Set<UUID>()
            var ticks = 0
            while !Task.isCancelled && Date() < deadline {
                let stop = folder.appendingPathComponent("stop")
                if FileManager.default.fileExists(atPath: stop.path) { try FileManager.default.removeItem(at: stop); break }
                let inbox = folder.appendingPathComponent("request.json")
                ticks += 1
                if ticks % 25 == 0 {
                    try Data(Date().description.utf8).write(
                        to: folder.appendingPathComponent("heartbeat.txt"),
                        options: .atomic
                    )
                }
                if let data = try? Data(contentsOf: inbox),
                   let request = try? JSONDecoder().decode(Request.self, from: data),
                   processedRequests.insert(request.id).inserted {
                    let output = folder.appendingPathComponent(request.id.uuidString + ".json")
                    try Data("received".utf8).write(to: output.appendingPathExtension("phase"), options: .atomic)
                    switch request.probe {
                    case "core": await core(request.payload, output: output)
                    case "pair": await pair(request.payload, output: output)
                    case "publisher": await publisher(request.payload, output: output)
                    case "retention": await retention(request.payload, output: output)
                    case "cleanup": await cleanup(request.payload, output: output)
                    case "metadata": await metadata(request.payload, output: output)
                    default: throw CocoaError(.validationMissingMandatoryProperty)
                    }
                    try Data("completed".utf8).write(to: output.appendingPathExtension("phase"), options: .atomic)
                }
                try await Task.sleep(for: .milliseconds(200))
            }
            try? FileManager.default.removeItem(at: folder.appendingPathComponent("ready.txt"))
            try? FileManager.default.removeItem(at: folder.appendingPathComponent("ready.json"))
        } catch {
            try? Data(String(describing: error).utf8).write(
                to: folder.appendingPathComponent("runner-error.txt"),
                options: .atomic
            )
        }
    }

}

extension CloudSharingValidation {

    /// Writes CloudKit metadata for a supplied invitation URL to the result file.
    private static func metadata(_ payload: Data, output: URL) async {

        var result: [String: Any] = ["success": false]
        do {
            let input = try JSONSerialization.jsonObject(with: payload) as! [String: Any]
            let container = CKContainer(identifier: CloudKitSharingTransport.containerIdentifier)
            let account = try await container.userRecordID().recordName
            let metadata = try await container.shareMetadata(for: URL(string: input["url"] as! String)!)
            result["accountID"] = account
            result["ownerID"] = metadata.ownerIdentity.userRecordID?.recordName ?? "nil"
            result["shareOwnerID"] = metadata.share.owner.userIdentity.userRecordID?.recordName ?? "nil"
            result["currentParticipantID"] = metadata.share.currentUserParticipant?
                .userIdentity.userRecordID?.recordName ?? "nil"
            result["role"] = metadata.participantRole.rawValue
            result["permission"] = metadata.participantPermission.rawValue
            result["status"] = metadata.participantStatus.rawValue
            result["participants"] = metadata.share.participants.map {
                [
                    "id": $0.userIdentity.userRecordID?.recordName ?? "nil",
                    "permission": $0.permission.rawValue,
                    "role": $0.role.rawValue,
                    "status": $0.acceptanceStatus.rawValue
                ] as [String: Any]
            }
            result["success"] = true
        } catch { result["error"] = String(describing: error); result["cloudKitDetails"] = cloudDetails(error) }
        try? JSONSerialization.data(
            withJSONObject: result,
            options: [.prettyPrinted, .sortedKeys]
        ).write(to: output, options: .atomic)
    }

    /// Deletes exact synthetic records after a caller-confirmed clean preflight.
    private static func cleanup(_ payload: Data, output: URL) async {

        var result: [String: Any] = ["success": false]
        do {
            guard let input = try JSONSerialization.jsonObject(with: payload) as? [String: Any],
                  let expectedAccount = input["expectedAccountID"] as? String,
                  let connections = input["connectionIDs"] as? [String], !connections.isEmpty,
                  connections.allSatisfy({ UUID(uuidString: $0) != nil }),
                  let devices = input["publisherDeviceIDs"] as? [String],
                  input["cleanPreflightConfirmed"] as? Bool == true else { throw SharingError.invalidConnection }
            let transport = CloudKitSharingTransport(displayName: "Synthetic cleanup QA")
            guard case .available(let account) = try await transport.accountStatus(),
                  account.id == expectedAccount
            else { throw SharingError.wrongAccount }
            let database = CKContainer(identifier: CloudKitSharingTransport.containerIdentifier).privateCloudDatabase
            let zone = CKRecordZone.ID(zoneName: "CalorieSharing", ownerName: CKCurrentUserDefaultName)
            func records() async throws -> [CKRecord] {

                var token: CKServerChangeToken?
                var current: [CKRecord.ID: CKRecord] = [:]
                repeat {
                    let page = try await database.recordZoneChanges(inZoneWith: zone, since: token)
                    for (id, value) in page.modificationResultsByID { current[id] = try value.get().record }
                    for deletion in page.deletions { current[deletion.recordID] = nil }
                    token = page.changeToken
                    if !page.moreComing { return Array(current.values) }
                } while true
            }
            let all = try await records()
            let connectionIDs = Set(connections)
            var approved = Set<CKRecord.ID>()
            var shares = Set<CKRecord.ID>()
            for record in all where !(record is CKShare) {
                let belongs: Bool
                if record.recordType == "CountSharingPublisher" {
                    guard let text = record.encryptedValues["payload"] as? String
                    else { throw SharingError.invalidConnection }
                    let lease = try JSONDecoder().decode(SharingPublisherLease.self, from: Data(text.utf8))
                    belongs = lease.accountID == account.id && devices.contains(lease.deviceID.uuidString)
                } else if record.recordType == "CountSharingCard" {
                    guard let text = record.encryptedValues["payload"] as? String
                    else { throw SharingError.invalidConnection }
                    let card = try JSONDecoder().decode(SharedSnapshotEnvelope.self, from: Data(text.utf8))
                    belongs = connectionIDs.contains(card.connectionID.uuidString) && card.senderID == account.id
                } else if record.recordType == "CountSharingDirectory" {
                    guard let text = record.encryptedValues["payload"] as? String,
                          let document = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
                          let id = document["connectionID"] as? String else { throw SharingError.invalidConnection }
                    belongs = connectionIDs.contains(id)
                } else {
                    belongs = ["CountSharingSetup", "CountSharingScope", "CountSharingControl"].contains(record.recordType)
                        && (record["connectionID"] as? String).map(connectionIDs.contains) == true
                }
                guard belongs else { throw SharingError.invalidConnection }
                approved.insert(record.recordID)
                if let share = record.share?.recordID { shares.insert(share) }
            }
            for record in all where record is CKShare {
                guard shares.contains(record.recordID) else { throw SharingError.invalidConnection }
                approved.insert(record.recordID)
            }
            guard all.count == approved.count, approved.count <= 100 else { throw SharingError.invalidConnection }
            result["ownedRecordNames"] = approved.map(\.recordName).sorted()
            try JSONSerialization.data(
                withJSONObject: result,
                options: [.prettyPrinted, .sortedKeys]
            ).write(
                to: output.appendingPathExtension("progress"),
                options: .atomic
            )
            if !approved.isEmpty {
                let childIDs = all.filter { $0.parent != nil }.map(\.recordID)
                if !childIDs.isEmpty {
                    let deleted = try await database.modifyRecords(
                        saving: [],
                        deleting: childIDs,
                        savePolicy: .ifServerRecordUnchanged,
                        atomically: true
                    )
                    for id in childIDs { try deleted.deleteResults[id]!.get() }
                }
                let roots = approved.subtracting(childIDs)
                if !roots.isEmpty {
                    let deleted = try await database.modifyRecords(
                        saving: [],
                        deleting: Array(roots),
                        savePolicy: .ifServerRecordUnchanged,
                        atomically: true
                    )
                    for id in roots { try deleted.deleteResults[id]!.get() }
                }
            }
            guard try await records().isEmpty else { throw SharingError.invalidConnection }
            result["success"] = true
            result["zoneRetainedEmpty"] = true
        } catch { result["error"] = String(describing: error); result["cloudKitDetails"] = cloudDetails(error) }
        try? JSONSerialization.data(
            withJSONObject: result,
            options: [.prettyPrinted, .sortedKeys]
        ).write(to: output, options: .atomic)
    }

    /// Runs account and sharing probes against the configured CloudKit container.
    private static func core(_ payload: Data, output: URL) async {

        guard let input = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any],
              input["operation"] is String
        else {
            try? Data("{\"success\":false,\"error\":\"invalid validation payload\"}".utf8).write(
                to: output,
                options: .atomic
            )
            return
        }
        var result: [String: Any] = ["operation": input["operation"]!, "success": false]
        result["timeZoneIdentifier"] = TimeZone.current.identifier
        func decode<T: Decodable>(_ key: String, _: T.Type) throws -> T {
            guard let value = input[key] else { throw SharingError.invalidConnection }
            return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: value))
        }
        func json<T: Encodable>(_ value: T) throws -> Any {
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(value), options: [.fragmentsAllowed])
        }
        do {
            let transport = CloudKitSharingTransport(displayName: input["name"] as! String)
            try Data("account-status-started".utf8).write(to: output.appendingPathExtension("phase"), options: .atomic)
            let status = try await transport.accountStatus()
            try Data("account-status-finished".utf8).write(to: output.appendingPathExtension("phase"), options: .atomic)
            switch status {
            case .signedOut: result["accountStatus"] = "signedOut"
            case .uncertain: result["accountStatus"] = "uncertain"
            case .available(let identity):
                result["accountStatus"] = "available"
                result["identity"] = try json(identity)
            }
            let operation = input["operation"] as! String
            if operation == "account" {
                let sdkStatus = try await CKContainer(
                    identifier: CloudKitSharingTransport.containerIdentifier
                ).accountStatus()
                result["sdkAccountStatusRawValue"] = sdkStatus.rawValue
                result["sdkAccountStatus"] = String(describing: sdkStatus)

            }
            if operation != "account" {
                guard case .available(let account) = status else { throw SharingError.accountUnavailable }
                let container = CKContainer(identifier: CloudKitSharingTransport.containerIdentifier)
                if operation == "preflight" {
                    let zones = try await container.privateCloudDatabase.allRecordZones()
                    let sharingZone = zones.first { $0.zoneID.zoneName == "CalorieSharing" }
                    var metadata: [CKRecord.ID: String] = [:]
                    if let sharingZone {
                        var token: CKServerChangeToken?
                        repeat {
                            let page = try await container.privateCloudDatabase.recordZoneChanges(
                                inZoneWith: sharingZone.zoneID,
                                since: token,
                                desiredKeys: []
                            )
                            for (id, change) in page.modificationResultsByID {
                                metadata[id] = try change.get().record.recordType
                            }
                            for deletion in page.deletions { metadata[deletion.recordID] = nil }
                            token = page.changeToken
                            if !page.moreComing { break }
                        } while true
                    }
                    result["cleanTestAccount"] = metadata.isEmpty
                    result["sharingZoneExists"] = sharingZone != nil
                    result["existingRecordMetadata"] = metadata.map {
                        [
                            "recordName": $0.key.recordName,
                            "recordType": $0.value
                        ]
                    }
                    result["zoneNames"] = zones.map { $0.zoneID.zoneName }.sorted()
                } else if operation == "prepare-email" {
                    guard let rawID = input["connectionID"] as? String, let id = UUID(uuidString: rawID),
                          let email = input["peerEmail"] as? String, let name = input["peerName"] as? String,
                          let rawScopes = input["scopes"] as? [String] else { throw SharingError.invalidConnection }
                    result["url"] = try await transport.prepareInvitation(
                        id: id,
                        email: email,
                        name: name,
                        scopes: Set(rawScopes.compactMap(SharingScope.init(rawValue:)))
                    ).absoluteString
                } else if operation == "cancel-email" {
                    guard let rawID = input["connectionID"] as? String,
                          let id = UUID(uuidString: rawID)
                    else { throw SharingError.invalidConnection }
                    _ = try await transport.fetchConnections(for: account)
                    try await transport.cancelPendingInvitation(id: id)
                } else if operation == "invitation-participants" {
                    guard let rawID = input["connectionID"] as? String,
                          let id = UUID(uuidString: rawID)
                    else { throw SharingError.invalidConnection }
                    let db = container.privateCloudDatabase
                    let root = try await db.record(
                        for: CKRecord.ID(
                            recordName: "setup-\(id)",
                            zoneID: CKRecordZone.ID(
                                zoneName: "CalorieSharing",
                                ownerName: CKCurrentUserDefaultName
                            )
                        )
                    )
                    guard let shareID = root.share?.recordID,
                          let share = try await db.record(for: shareID) as? CKShare
                    else { throw SharingError.invalidConnection }
                    result["url"] = share.url?.absoluteString
                    result["participants"] = share.participants.map {
                        [
                            "participantID": $0.participantID,
                            "accountID": $0.userIdentity.userRecordID?.recordName ?? "nil",
                            "role": $0.role.rawValue,
                            "permission": $0.permission.rawValue,
                            "status": $0.acceptanceStatus.rawValue
                        ] as [String: Any]
                    }
                } else if operation == "known-fetch" || operation == "readonly-write" {
                    let id = CKRecord.ID(
                        recordName: input["recordName"] as! String,
                        zoneID: CKRecordZone.ID(
                            zoneName: "CalorieSharing",
                            ownerName: input["ownerID"] as! String
                        )
                    )
                    do {
                        let record = try await container.sharedCloudDatabase.record(for: id)
                        result["accessible"] = true
                        if operation == "readonly-write" {
                            guard let payload = record.encryptedValues["payload"] as? String
                            else { throw SharingError.invalidConnection }
                            // change trailing JSON whitespace in the existing encrypted field
                            // without adding a schema field or changing decoded card data
                            record.encryptedValues["payload"] = payload + "\n"
                            _ = try await container.sharedCloudDatabase.save(record)
                            result["writeDenied"] = false
                        }
                    } catch let error as CKError {
                        result["cloudKitCode"] = error.code.rawValue
                        result["cloudKitError"] = String(describing: error.code)
                        if operation == "readonly-write" {
                            result["writeDenied"] = error.code == .permissionFailure
                        } else {
                            result["accessible"] = false
                            result["accessRevoked"] = [
                                .permissionFailure,
                                .unknownItem,
                                .zoneNotFound,
                                .userDeletedZone
                            ].contains(error.code)
                        }
                    }
                } else if operation == "import" {
                    try await transport.importInvitation(url: URL(string: input["url"] as! String)!)
                    let connections = try await transport.fetchConnections(for: account)
                    result["connections"] = try json(connections)
                } else {
                    let existing = try await transport.fetchConnections(for: account)
                    let id = UUID(uuidString: input["connectionID"] as! String)!
                    var connection = existing.first { $0.id == id }
                    if operation == "create" {
                        guard connection == nil else { throw SharingError.invalidConnection }
                        let peer = try decode("peer", SharingIdentity.self)
                        let seed = SharingConnection(
                            id: id,
                            containerIdentifier: CloudKitSharingTransport.containerIdentifier,
                            inviter: account,
                            invitee: peer
                        )
                        let now = Date()
                        let proposal = SharingProposal(
                            id: UUID(uuidString: input["proposalID"] as! String)!,
                            proposerID: account.id,
                            recipientID: peer.id,
                            baseRevision: 0,
                            scopes: [.today, .history],
                            createdAt: now,
                            expiresAt: now.addingTimeInterval(SharingConsent.requestLifetime)
                        )
                        connection = try await transport.commit(
                            SharingConsentMutation(
                                id: UUID(),
                                connection: seed,
                                actorID: account.id,
                                expectedRevision: 0,
                                action: .propose(proposal),
                                createdAt: now
                            ),
                            as: account
                        )
                        result["url"] = try await transport.invitationURL(for: id).absoluteString
                    } else {
                        guard let current = connection else { throw SharingError.invalidConnection }
                        switch operation {
                        case "fetch": break
                        case "accept":
                            guard let proposal = current.proposal else { throw SharingError.invalidProposal }
                            connection = try await transport.commit(
                                SharingConsentMutation(
                                    id: UUID(),
                                    connection: current,
                                    actorID: account.id,
                                    expectedRevision: current.revision,
                                    action: .accept(proposalID: proposal.id),
                                    createdAt: Date()
                                ),
                                as: account
                            )
                        case "provision":
                            var provisioned: [String] = []
                            var pending: [String] = []
                            for grant in current.grants {
                                do {
                                    _ = try await transport.provision(
                                        SharingProvisionRequest(
                                            connection: current,
                                            accountID: account.id,
                                            scope: grant.scope,
                                            generation: grant.generation
                                        )
                                    )
                                    provisioned.append(grant.scope.rawValue)
                                } catch SharingError.unavailable { pending.append(grant.scope.rawValue) }
                            }
                            result["provisioned"] = provisioned
                            result["pending"] = pending
                        case "publish":
                            let lease = try await transport.claimPublisher(
                                account: account,
                                deviceID: UUID(uuidString: input["deviceID"] as! String)!
                            )
                            let snapshots = try decode("snapshots", [CalorieCardSnapshot].self)
                            var recordNames: [String: String] = [:]
                            for snapshot in snapshots {
                                let scope: SharingScope = snapshot.midnight == nil ? .history : .today
                                guard let grant = current.grants.first(where: { $0.scope == scope })
                                else { throw SharingError.staleGeneration }
                                let envelope = SharedSnapshotEnvelope(
                                    connectionID: id,
                                    senderID: account.id,
                                    scope: scope,
                                    consentGeneration: grant.generation,
                                    publisherGeneration: lease.generation,
                                    snapshot: snapshot
                                )
                                try await transport.publish(envelope)
                                recordNames[scope.rawValue] =
                                    "card-\(id)-\(scope.rawValue)-\(grant.generation)-\(snapshot.senderLocalDate)"
                            }
                            result["recordNames"] = recordNames
                        case "snapshots":
                            result["snapshots"] = try json(
                                try await transport.fetchSnapshots(
                                    connection: current,
                                    as: account
                                ).snapshots
                            )
                        case "reduce":
                            let scopes = Set((input["scopes"] as! [String]).compactMap(SharingScope.init(rawValue:)))
                            connection = try await transport.commit(
                                SharingConsentMutation(
                                    id: UUID(),
                                    connection: current,
                                    actorID: account.id,
                                    expectedRevision: current.revision,
                                    action: .reduce(to: scopes),
                                    createdAt: Date()
                                ),
                                as: account
                            )
                            let peer = current.peer(of: account.id)!
                            for grant in current.grants where !scopes.contains(grant.scope) {
                                for direction in SharingDirection.allCases {
                                    try await transport.revoke(
                                        SharingRevocation(
                                            id: UUID(),
                                            connectionID: id,
                                            accountID: account.id,
                                            peerID: peer.id,
                                            scope: grant.scope,
                                            generation: grant.generation,
                                            direction: direction
                                        )
                                    )
                                }
                            }
                        default: throw SharingError.invalidConnection
                        }
                    }
                    if let connection { result["connection"] = try json(connection) }
                }
            }
            result["pendingInvitationCount"] = transport.pendingInvitations.count
            result["success"] = true
        } catch {
            result["error"] = String(describing: error); result["cloudKitDetails"] = cloudDetails(error)
            let ns = error as NSError
            result["errorDomain"] = ns.domain
            result["errorCode"] = ns.code
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: output, options: .atomic)
        } catch { print("CLOUD_QA_OUTPUT_ERROR \(error)") }
    }

    /// Runs one operation for the signed-in account on an existing connection.
    private static func pair(_ payload: Data, output: URL) async {

        guard let input = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any],
              input["operation"] is String
        else {
            try? Data("{\"success\":false,\"error\":\"invalid validation payload\"}".utf8).write(
                to: output,
                options: .atomic
            )
            return
        }
        var result: [String: Any] = ["success": false, "operation": input["operation"]!]
        func decode<T: Decodable>(_ key: String, _: T.Type) throws -> T {
            guard let value = input[key] else { throw SharingError.invalidConnection }
            return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: value))
        }
        func json<T: Encodable>(_ value: T) throws -> Any {
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(value), options: [.fragmentsAllowed])
        }
        do {
            let policyNow = (input["policyNow"] as? Double).map(Date.init(timeIntervalSinceReferenceDate:))
            let transport = CloudKitSharingTransport(displayName: "Synthetic extended QA", clock: { policyNow ?? Date() })
            guard case .available(let account) = try await transport.accountStatus()
            else { throw SharingError.accountUnavailable }
            guard account.id == input["expectedAccountID"] as? String else { throw SharingError.wrongAccount }
            result["accountID"] = account.id
            result["policyClockInjected"] = policyNow != nil
            let operation = input["operation"] as! String
            let id = UUID(uuidString: input["connectionID"] as! String)!
            let existing = try await transport.fetchConnections(for: account)
            guard let current = existing.first(where: { $0.id == id }) else { throw SharingError.invalidConnection }
            result["before"] = try json(current)
            switch operation {
            case "fetch": break
            case "mutation":
                let mutation = try decode("mutation", SharingConsentMutation.self)
                guard mutation.connection.id == id else { throw SharingError.invalidConnection }
                result["connection"] = try json(try await transport.commit(mutation, as: account))
            case "provision":
                let scope = SharingScope(rawValue: input["scope"] as! String)!
                let generation = UUID(uuidString: input["generation"] as! String)!
                result["receipt"] = try json(try await transport.provision(SharingProvisionRequest(
                    connection: current,
                    accountID: account.id,
                    scope: scope,
                    generation: generation
                )))
            case "claim":
                let device = UUID(uuidString: input["deviceID"] as! String)!
                result["lease"] = try json(try await transport.claimPublisher(account: account, deviceID: device))
            case "publish":
                let envelope = try decode("envelope", SharedSnapshotEnvelope.self)
                guard envelope.connectionID == id else { throw SharingError.invalidConnection }
                try await transport.publish(envelope)
                result["recordName"] = """
                card-\(id)-\(envelope.scope.rawValue)-\
                \(envelope.consentGeneration)-\(envelope.snapshot.senderLocalDate)
                """
            case "snapshots":
                let base: SharingConnection = input["base"] == nil ? current : try decode("base", SharingConnection.self)
                guard base.id == id else { throw SharingError.invalidConnection }
                result["snapshots"] = try json(try await transport.fetchSnapshots(connection: base, as: account).snapshots)
            case "revoke":
                let revocation = try decode("revocation", SharingRevocation.self)
                guard revocation.connectionID == id else { throw SharingError.invalidConnection }
                try await transport.revoke(revocation)
            case "own-root":
                let scope = input["scope"] as! String
                let generation = input["generation"] as! String
                let recordID = CKRecord.ID(
                    recordName: "scope-\(id)-\(scope)-\(generation)",
                    zoneID: CKRecordZone.ID(
                        zoneName: "CalorieSharing",
                        ownerName: CKCurrentUserDefaultName
                    )
                )
                let root = try await CKContainer(
                    identifier: CloudKitSharingTransport.containerIdentifier
                ).privateCloudDatabase.record(for: recordID)
                guard root["connectionID"] as? String == id.uuidString,
                      root["senderID"] as? String == account.id,
                      root["scope"] as? String == scope,
                      root["generation"] as? String == generation
                else { throw SharingError.invalidConnection }
                result["recordName"] = root.recordID.recordName
                result["shareRecordName"] = root.share?.recordID.recordName
            case "control-readonly":
                let peer = current.peer(of: account.id)!
                let recordID = CKRecord.ID(
                    recordName: "control-\(id)",
                    zoneID: CKRecordZone.ID(
                        zoneName: "CalorieSharing",
                        ownerName: peer.id
                    )
                )
                let db = CKContainer(identifier: CloudKitSharingTransport.containerIdentifier).sharedCloudDatabase
                let record = try await db.record(for: recordID)
                guard record.recordType == "CountSharingControl",
                      record["connectionID"] as? String == id.uuidString,
                      record["ownerID"] as? String == peer.id,
                      let payload = record.encryptedValues["payload"] as? String
                else { throw SharingError.invalidConnection }
                result["ordinaryPayloadAbsent"] = record["payload"] == nil
                result["encryptedPayloadDecodes"] = (try? JSONSerialization.jsonObject(with: Data(payload.utf8))) != nil
                record.encryptedValues["payload"] = payload + "\n"
                do { _ = try await db.save(record); result["writeDenied"] = false }
                catch let error as CKError {
                    result["writeDenied"] = error.code == .permissionFailure
                    result["cloudKitCode"] = error.code.rawValue
                    if error.code != .permissionFailure { throw error }
                }
            case "own-invitation":
                let url = try await transport.invitationURL(for: id)
                result["url"] = url.absoluteString
                try await transport.importInvitation(url: url)
            default: throw SharingError.invalidConnection
            }
            if result["connection"] == nil { result["connection"] = try json(current) }
            result["success"] = true
        } catch {
            result["error"] = String(describing: error); result["cloudKitDetails"] = cloudDetails(error)
            if let error = error as? SharingError { result["sharingError"] = String(describing: error) }
            let ns = error as NSError
            result["errorDomain"] = ns.domain; result["errorCode"] = ns.code
            if let cloud = error as? CKError {
                result["cloudKitCode"] = cloud.code.rawValue
                result["cloudKitError"] = String(describing: cloud.code)
            }
        }
        do {
            try JSONSerialization.data(
                withJSONObject: result,
                options: [.prettyPrinted, .sortedKeys]
            ).write(to: output, options: .atomic)
        }
        catch { print("EXTENDED_PAIR_OUTPUT_ERROR \(error)") }
    }

    /// Verifies publisher takeover, stale-batch rejection, and exact cleanup.
    private static func publisher(_ payload: Data, output: URL) async {

        guard let input = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any],
              input["operation"] is String
        else {
            try? Data("{\"success\":false,\"error\":\"invalid validation payload\"}".utf8).write(
                to: output,
                options: .atomic
            )
            return
        }
        var result: [String: Any] = [
            "operation": input["operation"]!,
            "success": false,
            "checks": [String](),
            "environment": "Development"
        ]
        func check(_ value: Bool, _ description: String) throws {

            guard value else {
                throw NSError(
                    domain: "CountSharingExtendedQA",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: description]
                )
            }
            var checks = result["checks"] as! [String]; checks.append(description); result["checks"] = checks
        }
        func json<T: Encodable>(_ value: T) throws -> Any {
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(value), options: [.fragmentsAllowed])
        }
        func journal(_ phase: String) throws {
            result["phase"] = phase
            let bytes = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            try bytes.write(to: output.appendingPathExtension("progress"), options: .atomic)
        }
        func codes(_ error: Error) -> [Int] {
            guard let cloud = error as? CKError else { return [] }
            return [cloud.code.rawValue] + (cloud.partialErrorsByItemID?.values.flatMap { codes($0) } ?? [])
        }
        func records(_ db: CKDatabase, _ zone: CKRecordZone.ID) async throws -> [CKRecord] {

            var token: CKServerChangeToken?
            var current: [CKRecord.ID: CKRecord] = [:]
            repeat {
                let page = try await db.recordZoneChanges(inZoneWith: zone, since: token)
                for (id, change) in page.modificationResultsByID { current[id] = try change.get().record }
                for deletion in page.deletions { current[deletion.recordID] = nil }
                token = page.changeToken
                if !page.moreComing { return Array(current.values) }
            } while true
        }
        func publisherCopy(_ record: CKRecord) throws -> CKRecord {

            let archive = NSKeyedArchiver(requiringSecureCoding: true)
            record.encodeSystemFields(with: archive)
            archive.finishEncoding()
            let decoder = try NSKeyedUnarchiver(forReadingFrom: archive.encodedData)
            decoder.requiresSecureCoding = true
            guard let copy = CKRecord(coder: decoder) else { throw SharingError.invalidConnection }
            decoder.finishDecoding()
            copy.encryptedValues["payload"] = record.encryptedValues["payload"]
            copy["senderTimeZone"] = record["senderTimeZone"]
            copy["lastClaim"] = record["lastClaim"]
            return copy
        }
        func rejectedBatch(_ db: CKDatabase, saving: [CKRecord], deleting: [CKRecord.ID]) async throws -> [Int] {

            var errors: [Int] = []
            var successful = 0
            do {
                let changed = try await db.modifyRecords(
                    saving: saving,
                    deleting: deleting,
                    savePolicy: .ifServerRecordUnchanged,
                    atomically: true
                )
                for record in saving {
                    guard let saved = changed.saveResults[record.recordID] else { throw SharingError.unavailable }
                    switch saved { case .success: successful += 1; case .failure(let error): errors += codes(error) }
                }
                for id in deleting {
                    guard let deleted = changed.deleteResults[id] else { throw SharingError.unavailable }
                    switch deleted { case .success: successful += 1; case .failure(let error): errors += codes(error) }
                }
            } catch { errors += codes(error); if errors.isEmpty { throw error } }
            try check(successful == 0, "Atomic stale batch reports no successful save or deletion")
            try check(
                errors.contains(CKError.Code.serverRecordChanged.rawValue),
                "CloudKit reports serverRecordChanged for stale publisher authority"
            )
            return errors
        }
        do {
            let operation = input["operation"] as! String
            try check(
                operation == "publisher-authority" || operation == "cleanup-publisher-authority",
                """
                Only the bounded publisher scenario or its \
                scoped cleanup is selected
                """
            )
            let transport = CloudKitSharingTransport(displayName: "Synthetic Extended QA B")
            guard case .available(let account) = try await transport.accountStatus()
            else { throw SharingError.accountUnavailable }
            try check(account.id == input["expectedAccountID"] as! String, "SDK authenticated the expected B account")
            result["accountID"] = account.id
            let oldDevice = UUID(uuidString: input["oldDeviceID"] as! String)!
            let newDevice = UUID(uuidString: input["newDeviceID"] as! String)!
            let connectionID = UUID(uuidString: input["connectionID"] as! String)!
            let generation = UUID(uuidString: input["generation"] as! String)!
            let zone = CKRecordZone.ID(zoneName: "CalorieSharing", ownerName: CKCurrentUserDefaultName)
            let publisherID = CKRecord.ID(recordName: "publisher", zoneID: zone)
            let sentinelID = CKRecord.ID(recordName: "scope-\(connectionID)-today-\(generation)", zoneID: zone)
            result["ownedRecordNames"] = [publisherID.recordName, sentinelID.recordName]
            result["connectionID"] = connectionID.uuidString
            result["generation"] = generation.uuidString
            let container = CKContainer(identifier: CloudKitSharingTransport.containerIdentifier)
            let db = container.privateCloudDatabase

            if operation == "publisher-authority" {
                let zones = try await db.allRecordZones()
                try check(
                    !zones.contains(where: { $0.zoneID.zoneName == zone.zoneName }),
                    "CalorieSharing zone was absent before this test created any data"
                )
                result["zoneCreatedByRun"] = true
                try journal("claim-old-publisher")
                let oldLease = try await transport.claimPublisher(account: account, deviceID: oldDevice)
                result["oldLease"] = try json(oldLease)
                let restarted = CloudKitSharingTransport(displayName: "Synthetic Extended QA B restart")
                let recovered = try await restarted.publisherLease(account: account, deviceID: oldDevice)
                try check(recovered == oldLease, "A fresh production adapter recovers the server publisher lease")
                let repeated = try await restarted.claimPublisher(account: account, deviceID: oldDevice)
                try check(repeated == oldLease, "Repeating a claim for the same logical device preserves its generation")
                let stalePublisher = try await db.record(for: publisherID)
                result["capturedChangeTag"] = stalePublisher.recordChangeTag
                let staleDeletePublisher = try publisherCopy(stalePublisher)
                let sentinel = CKRecord(recordType: "CountSharingScope", recordID: sentinelID)
                sentinel["connectionID"] = connectionID.uuidString
                sentinel["scope"] = SharingScope.today.rawValue
                sentinel["generation"] = generation.uuidString
                sentinel["senderID"] = account.id
                let savedSentinel = try await db.save(sentinel)
                result["sentinelCreatedByRun"] = true
                try journal("takeover")
                let current = try await restarted.claimPublisher(account: account, deviceID: newDevice)
                result["currentLease"] = try json(current)
                try check(
                    current.generation != oldLease.generation,
                    "A different logical device receives a new publishing generation"
                )
                let obsolete = try await transport.publisherLease(account: account, deviceID: oldDevice)
                try check(obsolete == nil, "The old logical device cannot recover current publisher authority")
                do {
                    try await transport.cleanup(account: account, lease: oldLease, now: Date())
                    try check(false, "Production cleanup must reject the old publisher lease")
                } catch let error as SharingError {
                    try check(
                        error == .publisherNotOwned,
                        "Production cleanup rejects obsolete authority before retention work"
                    )
                }
                // exercise the same-zone compare-and-swap used by publication and cleanup
                // this direct SDK batch is not queued in transport.publish and grants no calorie access
                stalePublisher["lastPublication"] = Date()
                savedSentinel["scope"] = SharingScope.history.rawValue
                result["staleSaveCloudKitCodes"] = try await rejectedBatch(
                    db,
                    saving: [stalePublisher, savedSentinel],
                    deleting: []
                )
                let unchanged = try await db.record(for: sentinelID)
                try check(
                    unchanged["scope"] as? String == SharingScope.today.rawValue,
                    """
                    Rejected stale save leaves the independent sentinel unchanged \
                    on the server
                    """
                )
                let authority = try await restarted.publisherLease(account: account, deviceID: newDevice)
                try check(
                    authority == current,
                    "Rejected stale save leaves the current production publisher lease unchanged"
                )
                try journal("stale-delete")
                result["staleDeleteCloudKitCodes"] = try await rejectedBatch(
                    db,
                    saving: [staleDeletePublisher],
                    deleting: [sentinelID]
                )
                let stillPresent = try await db.record(for: sentinelID)
                try check(
                    stillPresent["connectionID"] as? String == connectionID.uuidString,
                    "Rejected stale deletion preserves the known synthetic record"
                )
                let stillCurrent = try await restarted.publisherLease(account: account, deviceID: newDevice)
                try check(stillCurrent == current, "Rejected stale deletion preserves the new publisher generation")
                result["scenarioPassed"] = true
                try journal("scoped-cleanup")
            } else {
                try check(
                    input["zoneCreatedByRun"] as? Bool == true,
                    "Cleanup manifest records a zone created by this test"
                )
                result["zoneCreatedByRun"] = true
                try journal("explicit-scoped-cleanup")
            }

            // preserve the zone and reject records outside the recorded synthetic set
            let currentRecords = try await records(db, zone)
            let owned = Set([publisherID.recordName, sentinelID.recordName])
            try check(
                currentRecords.allSatisfy { owned.contains($0.recordID.recordName) },
                "Zone enumeration contains only the two recorded synthetic IDs before cleanup"
            )
            for record in currentRecords {
                if record.recordID == publisherID {
                    guard record.recordType == "CountSharingPublisher",
                          let payload = record.encryptedValues["payload"] as? String
                    else { throw SharingError.invalidConnection }
                    let lease = try JSONDecoder().decode(SharingPublisherLease.self, from: Data(payload.utf8))
                    try check(
                        lease.accountID == account.id && [oldDevice, newDevice].contains(lease.deviceID),
                        "Publisher cleanup verifies the account and one of this run's logical device IDs"
                    )
                } else {
                    try check(
                        record.recordType == "CountSharingScope"
                            && record["connectionID"] as? String == connectionID.uuidString
                            && record["generation"] as? String == generation.uuidString
                            && record["senderID"] as? String == account.id
                            && record.share == nil,
                        "Sentinel cleanup verifies exact synthetic ownership and absence of a share"
                    )
                }
            }
            let ids = currentRecords.map(\.recordID)
            if !ids.isEmpty {
                let deletion = try await db.modifyRecords(saving: [], deleting: ids, atomically: true)
                for id in ids {
                    guard let outcome = deletion.deleteResults[id] else { throw SharingError.unavailable }
                    try outcome.get()
                }
            }
            result["deletedRecordNames"] = ids.map(\.recordName)
            let after = try await records(db, zone)
            try check(after.isEmpty, "After exact-ID cleanup the server CalorieSharing zone is empty")
            result["zoneDeleted"] = false
            result["cleanupComplete"] = true
            result["success"] = true
        } catch {
            result["error"] = String(describing: error); result["cloudKitDetails"] = cloudDetails(error)
            result["cloudKitCodes"] = codes(error)
            let ns = error as NSError
            result["errorDomain"] = ns.domain
            result["errorCode"] = ns.code
            result["cleanupRequired"] = result["zoneCreatedByRun"] as? Bool == true
        }
        do {
            try JSONSerialization.data(
                withJSONObject: result,
                options: [.prettyPrinted, .sortedKeys]
            ).write(to: output, options: .atomic)
        } catch { print("EXTENDED_QA_OUTPUT_ERROR \(error)") }
    }

    /// Runs production retention cleanup against exact synthetic card records.
    private static func retention(_ payload: Data, output: URL) async {

        guard let input = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any],
              input["operation"] is String
        else {
            try? Data("{\"success\":false,\"error\":\"invalid validation payload\"}".utf8).write(
                to: output,
                options: .atomic
            )
            return
        }
        var result: [String: Any] = [
            "success": false,
            "checks": [String](),
            "scope": """
            Production cleanup performs real server deletes using \
            sender-calendar policy; private synthetic seed only
            """
        ]
        func check(_ ok: Bool, _ message: String) throws {

            guard ok else {
                throw NSError(
                    domain: "ExtendedRetention",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: message]
                )
            }
            var checks = result["checks"] as! [String]; checks.append(message); result["checks"] = checks
        }
        func journal(_ phase: String) throws {
            result["phase"] = phase
            try JSONSerialization.data(
                withJSONObject: result,
                options: [.prettyPrinted, .sortedKeys]
            ).write(
                to: output.appendingPathExtension("progress"),
                options: .atomic
            )
        }
        func records(_ db: CKDatabase, _ zone: CKRecordZone.ID) async throws -> [CKRecord] {

            var token: CKServerChangeToken?; var current: [CKRecord.ID: CKRecord] = [:]
            repeat {
                let page = try await db.recordZoneChanges(inZoneWith: zone, since: token)
                for (id, change) in page.modificationResultsByID { current[id] = try change.get().record }
                for deleted in page.deletions { current[deleted.recordID] = nil }
                token = page.changeToken
                if !page.moreComing { return Array(current.values) }
            } while true
        }
        do {
            let transport = CloudKitSharingTransport(displayName: "Synthetic retention QA")
            guard case .available(let account) = try await transport.accountStatus(),
                  account.id == input["expectedAccountID"] as? String
            else { throw SharingError.wrongAccount }
            let connection = UUID(uuidString: input["connectionID"] as! String)!
            let device = UUID(uuidString: input["deviceID"] as! String)!
            guard let lease = try await transport.publisherLease(
                account: account,
                deviceID: device
            ), lease.generation.uuidString == input["publisherGeneration"] as? String
            else { throw SharingError.publisherNotOwned }
            let db = CKContainer(identifier: CloudKitSharingTransport.containerIdentifier).privateCloudDatabase
            let zone = CKRecordZone.ID(zoneName: "CalorieSharing", ownerName: CKCurrentUserDefaultName)
            let before = try await records(db, zone)
            let approved = Set(input["approvedExistingCardNames"] as! [String])
            let existingCards = before.filter { $0.recordType == "CountSharingCard" }
            try check(
                Set(existingCards.map { $0.recordID.recordName }) == approved,
                "Every preexisting calorie record matches the supplied core ownership ledger exactly"
            )
            for record in existingCards {
                guard let raw = record.encryptedValues["payload"] as? String else { throw SharingError.invalidConnection }
                let envelope = try JSONDecoder().decode(SharedSnapshotEnvelope.self, from: Data(raw.utf8))
                try check(
                    envelope.connectionID == connection && envelope.senderID == account.id,
                    "Existing calorie payload belongs to this run's exact synthetic connection and current owner"
                )
            }
            let generation = UUID(uuidString: input["generation"] as! String)!
            let rootName = "scope-\(connection)-history-\(generation)"
            let rootID = CKRecord.ID(recordName: rootName, zoneID: zone)
            let root = CKRecord(recordType: "CountSharingScope", recordID: rootID)
            root["connectionID"] = connection.uuidString
            root["scope"] = "history"
            root["generation"] = generation.uuidString
            root["senderID"] = account.id
            let fixtures = try JSONDecoder().decode(
                [SharedSnapshotEnvelope].self,
                from: JSONSerialization.data(withJSONObject: input["fixtures"]!)
            )
            try check(
                fixtures.count == 4 && fixtures.allSatisfy {
                    $0.connectionID == connection
                        && $0.senderID == account.id
                        && $0.consentGeneration == generation
                        && $0.publisherGeneration == lease.generation
                },
                "All four seed envelopes have exact recorded synthetic ownership"
            )
            let names = input["fixtureNames"] as! [String]
            let owned = Set([rootName] + names)
            try check(
                owned.count == 5 && names.count == 4
                    && before.allSatisfy { !owned.contains($0.recordID.recordName) },
                "All five private seed IDs are fresh and distinct from existing records"
            )
            result["ownedRecordNames"] = Array(owned).sorted(); result["generation"] = generation.uuidString
            try await journal("before-seed")
            var seed = [root]
            for (index, envelope) in fixtures.enumerated() {
                let record = CKRecord(
                    recordType: "CountSharingCard",
                    recordID: CKRecord.ID(recordName: names[index], zoneID: zone)
                )
                record.parent = CKRecord.Reference(recordID: rootID, action: .none)
                record.encryptedValues["payload"] = String(decoding: try JSONEncoder().encode(envelope), as: UTF8.self)
                seed.append(record)
            }
            let saved = try await db.modifyRecords(
                saving: seed,
                deleting: [],
                savePolicy: .ifServerRecordUnchanged,
                atomically: true
            )
            for record in seed { _ = try saved.saveResults[record.recordID]!.get() }
            try await journal("seeded")
            // use current time and the publisher's sender time zone from CloudKit
            // no injected clock, device clock change, or assumed server TTL
            try await transport.cleanup(account: account, lease: lease, now: Date())
            let after = try await records(db, zone)
            let remaining = Set(after.map { $0.recordID.recordName })
            let expectedSurvivors = Set([names[0], names[2]])
            try check(
                remaining.intersection(Set(names)) == expectedSurvivors,
                """
                Production cleanup retains current Today and seventh completed date, \
                deleting prior Today and eighth completed date on CloudKit
                """
            )
            try check(
                approved.isSubset(of: remaining),
                "Production retention leaves all recorded current core calorie records untouched"
            )
            for record in after where expectedSurvivors.contains(record.recordID.recordName) {
                try check(
                    record["payload"] == nil && record.encryptedValues["payload"] != nil,
                    "Retained SDK roundtrip uses encrypted payload rather than an ordinary calorie field"
                )
            }
            result["retentionPassed"] = true
            try await journal("before-exact-cleanup")
            let survivors = after.filter { owned.contains($0.recordID.recordName) }
            for record in survivors {
                if record.recordID == rootID {
                    try check(
                        record.share == nil
                            && record["connectionID"] as? String == connection.uuidString
                            && record["generation"] as? String == generation.uuidString,
                        "Scoped cleanup revalidates private unshared root ownership"
                    )
                } else {
                    try check(
                        record.parent?.recordID == rootID,
                        "Scoped cleanup revalidates each survivor's private parent"
                    )
                }
            }
            let childIDs = survivors.filter { $0.recordID != rootID }.map(\.recordID)
            if !childIDs.isEmpty {
                let deleted = try await db.modifyRecords(
                    saving: [],
                    deleting: childIDs,
                    savePolicy: .ifServerRecordUnchanged,
                    atomically: true
                )
                for id in childIDs { try deleted.deleteResults[id]!.get() }
            }
            if survivors.contains(where: { $0.recordID == rootID }) { _ = try await db.deleteRecord(withID: rootID) }
            let final = try await records(db, zone)
            try check(
                final.allSatisfy { !owned.contains($0.recordID.recordName) },
                "All exact retention fixture IDs are removed, without deleting the zone or publisher"
            )
            try check(
                Set(final.filter { $0.recordType == "CountSharingCard" }.map { $0.recordID.recordName }) == approved,
                "Final calorie IDs exactly match the original core ledger"
            )
            result["cleanupComplete"] = true; result["success"] = true
        } catch {
            result["error"] = String(describing: error); result["cloudKitDetails"] = cloudDetails(error)
            let ns = error as NSError; result["errorDomain"] = ns.domain; result["errorCode"] = ns.code
        }
        do {
            try JSONSerialization.data(
                withJSONObject: result,
                options: [.prettyPrinted, .sortedKeys]
            ).write(to: output, options: .atomic)
        }
        catch { print("RETENTION_OUTPUT_ERROR \(error)") }
    }

    /// Collects nested CloudKit partial failures in JSON-ready form.
    private static func cloudDetails(_ error: Error) -> [[String: Any]] {
        guard let cloud = error as? CKError else { return [] }
        return (cloud.partialErrorsByItemID ?? [:]).map { item, nested in
            [
                "item": String(describing: item),
                "code": (nested as NSError).code,
                "error": String(describing: nested),
                "children": cloudDetails(nested)
            ]
        }
    }

    /// One file request with a unique identifier and encoded operation payload.
    private struct Request: Decodable {

        /// Request identifier used to prevent repeated processing.
        var id: UUID

        /// Operation name that selects a validation handler.
        var probe: String

        /// JSON payload decoded by the selected handler.
        var payload: Data

    }

}
#endif
