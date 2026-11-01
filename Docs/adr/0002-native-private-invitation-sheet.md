# Deliver private invitations with Apple's share sheet

Date: 2026-10-25. Status: implemented. This replaces the saved-share People manager used earlier on the same date.

Count.kcal collects mutual scope choices and, on first use, the sender's own profile name. Send invitation opens `UIActivityViewController` with a CloudKit `NSItemProvider`. Apple handles recipient selection and delivery. The app does not collect a recipient name or email, and the normal workflow does not require returning to Sharing, reopening a saved share, or copying a link.

Register a new share with `registerCKShare(container:allowedSharingOptions:preparationHandler:)`. Create and save the empty setup share and its private directory inside the preparation handler. Retain and coalesce preparation so repeated callbacks save one stable invitation. Cancelling before preparation creates no cloud draft and leaves scopes editable. Cancelling after a save retains the draft for Continue invitation. Recovery registers the existing share with the corresponding saved-share overload. Do not register a plain URL or text representation alongside the CloudKit provider.

Fix the allowed access to specified recipients and setup permission to read-write. Disable participant invitations and access requests on supported systems. Keep `publicPermission` at `.none`. The owner validates exactly one non-owner private participant, pins the participant identifier, and applies read-write setup permission with a server-version-checked save before creating the calorie proposal. Multiple participants cancel the metadata share before any calorie proposal is created. Names come from each person's app profile.

Apple's native Add Access UI can initially save read-only setup permission despite the fixed read-write setting. Import accepts either read-only or read-write permission only for the validated setup record, matching the authenticated participant's actual permission. Read-only import can wait for the inviter. It cannot create a calorie proposal before the owner normalizes setup permission. Control and calorie shares retain their separate strict read-only checks.

After Apple's handoff, open the imported invitation's consent screen directly. Show invitation progress if its proposal has not arrived yet. The recipient reviews and accepts the mutual scopes. Both accounts must finish reciprocal setup before calorie publication. No calorie values appear in invitation previews or setup records.

The sharing model, publisher ownership, reductions, revocations and retention stay unchanged. No backend, public share or extra entitlement is introduced. The email helper remains DEBUG-only for historical diagnostics.

Verification and delivery limits are recorded in `Docs/calorie-card-sharing-verification.md`, under Direct invitation delivery. Simulator delivery substitutes must not be described as Messages or Mail verification.

Apple references: [CloudKit registration](https://developer.apple.com/documentation/foundation/nsitemprovider/registerckshare(container:allowedsharingoptions:preparationhandler:)), [collaboration share sheets](https://developer.apple.com/documentation/uikit/collaborating-and-sharing-copies-of-your-data), and [existing shares](https://developer.apple.com/documentation/foundation/nsitemprovider/registerckshare(_:container:allowedsharingoptions:)).
