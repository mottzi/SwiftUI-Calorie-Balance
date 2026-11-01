# Bind email invitations after CloudKit acceptance

Date: 2026-10-24. Status: implemented and live-tested in Development.

CloudKit can return a legitimate email participant without exposing its account record ID. The normal Invite flow must support this state. Display names and writable discovery records cannot establish identity or consent.

Create a metadata-only private CKShare for the returned participant. Atomically save its setup, share and encrypted private directory. The directory retains the original scope choices, expiry, proposal and mutation IDs, and exact participant ID. A retry uses the same invitation ID.

After metadata acceptance, only the inviter's own private CKShare can establish the recipient's account ID. Require the exact original private participant, accepted status, expected permissions and no extra participant. Then create the original owner-controlled consent proposal idempotently. The recipient separately accepts calorie sharing, and both scope hierarchies must become ready before publication. An incoming metadata invitation may wait for the inviter to finish this step.

The CloudKit adapter owns this handshake behind `prepareInvitation`, `cancelPendingInvitation` and pending-invitation presentation values. The calorie consent domain continues to contain verified account identities only. No placeholder account, public share, deprecated identity discovery or email-to-account claim in the writable mailbox authorizes calories.

Existing directories decode without a draft. Cancellation is idempotent. Refresh completes metadata cleanup when a previous cancellation already removed its share. Scope permissions are removed before a late bootstrap cancellation discards their grants.

Evidence: `output/sharing-qa/completion/cloud/solo/email-v13/`, `email-v14/`, and the current verification document. API sources are linked in `Docs/research/calorie-card-sharing-cloudkit.md`.
