# Resolve native Copy Link failure on signed-in simulators

## What to build

Restore native invitation copying and verify a fresh metadata invitation through ordinary link delivery, receiver tap, explicit Today proposal acceptance, reciprocal readiness and calorie-card exchange. Do not count SDK URL extraction or developer URL-opening commands as invitation delivery.

## Blocked by

No earlier local ticket. The cause is not isolated between the installed system sharing implementation, its interaction with these accounts and shares, and remaining app integration factors.

## Status

needs-triage. Unresolved on 25 October 2026. No app fix is claimed.

## Evidence

Xcode 27.0 build 27A266a, iOS 27.0 simulator build 24A434. Native Copy Link displays "Couldn't Add People" and "A link couldn't be created for you to share." System logs report CKErrorDomain Code 1, "No optionsGroups provided to addToCloudKitSharing".

The isolated native XCUITest reproduces the exact alert and empty clipboard. Permission-choice expansion, omission of the title metadata callback, an alternate activity-controller initializer, and a public saved-share UICloudSharingController comparison all failed. All experiments were reverted. Original-source retest failed again. Existing accepted connections were preserved; only disposable metadata invitations were canceled through the app.

Artifacts and the executable reproduction command are in `output/sharing-qa/copy-link-fix-20261025/README.md`, with structured findings in `diagnosis.json` and system logs in `system-copy-errors.log`.

Apple documents private and shared CloudKit database access on signed-in simulators in Development. No documentation establishing support or a prohibition for this exact native Copy Link path was found.

The subsequent physical comparison used ordinary user controls. After the phone control tool repeatedly rejected taps, the user manually completed Sharing → Invite → Today → Send invitation → Copy Link on iPhone von Berken, iOS 27.0.1, Count.kcal 1.6.0 build 2. A supported read of the phone's system clipboard confirmed a change from the captured empty clipboard to a new CloudKit invitation URL. This verifies the native copy step on the installed phone app. It does not isolate OS, simulator, account or build differences, validate link acceptance, or establish a simulator-wide prohibition. No developer URL delivery occurred. Evidence: `phone-copy-result.json` in the diagnostic artifact folder; the raw copied link stays local.

The user then reported that pasting this URL into simulator Safari opened only the iCloud website. Apple's TN3155 documents that address-bar navigation does not open an associated app. To test a hyperlink tap, the actual phone-copied URL was entered through ordinary keyboard input into one disposable simulator Reminders note. Tapping the detected link reached Apple's native CloudKit prompt. It displayed "Item Unavailable", saying the main test account lacked permission or the owner stopped sharing. This establishes that the tap reached system invitation handling, not that the share was accessible or Count.kcal received its metadata. No invitation or calorie proposal was accepted. The disposable reminder was reversibly completed and retained in Completed; accepted relationships were unchanged. Artifact prefix: `Normal Invitation Link Tap-20_46_56_575`. Source: https://developer.apple.com/documentation/technotes/tn3155-debugging-universal-links .

## Acceptance criteria

- Identify a supported correction with an exact failing-then-passing native reproduction.
- Preserve private access, one-recipient validation, explicit calorie consent and read-only calorie shares.
- Copy a new invitation successfully with native Copy Link on each signed-in simulator.
- Paste the actual copied link into an ordinary delivery app and tap it on the receiving device, without developer URL delivery.
- Accept a fresh Today proposal through the app and observe reciprocal calorie cards.
- Preserve unrelated accepted connections, account sign-ins and app data; restore any deliberately interrupted test pair.
