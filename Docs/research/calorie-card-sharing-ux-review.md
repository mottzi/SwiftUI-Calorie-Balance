# Calorie card sharing UX review

Reviewed 24 October 2026. Proposals only. No app, account, simulator, or source changes were made.

## Executive finding

Sharing already has the right underlying structure: an overview, a person's calorie card, permission controls, and explicit consent. The full shared card looks like Count.kcal because it uses the same presentation as the dashboard. The surrounding screens make the feature feel unfinished. Setup occupies the best space on every visit, invitations read like protocol paperwork, and important status changes compete with repeated headings and explanatory text.

I recommend a focused refinement of the existing screens. Put people first, move the user's profile into a trailing toolbar sheet, reuse the existing calorie arcs in people rows, and make invitation and permission screens explain the decision currently being made. Keep the consent and revocation machinery. Most of the improvement comes from layout, copy, and presenting existing state accurately.

The profile-sheet direction is a good fit for this app. Automatically selecting the first publishing iPhone is also worthwhile, but only after the app can authoritatively distinguish an unclaimed account from an account already using another iPhone. The current `nil` lease result cannot make that distinction.

## Evidence and limits

I visually inspected all 36 numbered PNGs in [the capture folder](</Users/berken/Library/Mobile Documents/com~apple~CloudDocs/Downloads/Count.kcal-Sharing-UX-2026-10-24-220557>), and read its README, manifest, capture report, capture context, and matching accessibility hierarchies. The images are native 1206 × 2622 captures of the iPhone 18 Pro on iOS 27. Screens 01 and 02 show the normal app. The populated states use in-memory synthetic fixtures and production child views.

The sample overview is a navigation root. Its missing dashboard Back button and its `Sample sharing` label are fixture artifacts, not production defects. No actual CloudKit invitation or acceptance sheet appears in this set. Screenshot 34 proves only the fixture result. Some manifest descriptions are inaccurate: 06 visibly shows a historical 105 kcal deficit, 26 shows the overview after acceptance, and 11 has only Sharing settings and Remove connection. The images and hierarchies take precedence over those descriptions.

The current [specification](/Users/berken/Development/Swift/Count.kcal/Docs/calorie-card-sharing-spec.md) supplies the product rules. The [verification report](/Users/berken/Development/Swift/Count.kcal/Docs/calorie-card-sharing-verification.md) records real two-account and physical-device work as well as subsequent local changes. Its latest style-pass result is 73 tests passed and one snapshot-policy test failed with an unconfigured database dependency issue. This review did not investigate that failure or run tests. Historical cloud success is not proof of every screen or of the latest binary's real-service behavior. VoiceOver speech and gestures remain explicitly unverified.

### Current Apple Fitness reference

The live iPhone guide currently selects iOS 27. It documents Sharing → sharing action → Invite a Friend, a first-use Get Started action, pending invitations, person detail with seven-day activity, and per-person More actions. This supports a compact overview followed by detail and contextual management. [Apple's current iPhone guide](https://support.apple.com/en-nz/guide/iphone/iph0b826155d/ios)

I opened the illustration linked by that current guide and inspected it visually. It shows a centered Sharing title, a trailing person-plus action, Highlights, and compact named Activity Rings cards with values and a small graphic on the trailing side. It does not show a profile button. [Current Apple illustration](https://ipcdn-web.apple.com/assets/v2/web/6501ccc0-21fa-4dec-ba93-2dd053506998)

The versioned iOS 26 guide has the same broad workflow but different first-use wording. Prefer the current guide over the older reference supplied for this review. [Apple's iOS 26 guide](https://support.apple.com/en-euro/guide/iphone/iph0b826155d/26/ios/26)

These sources establish a pattern, not a complete recording of the current app. I did not verify Apple's current invitation-acceptance screen, profile placement elsewhere, animations, or every detail state. The proposed profile sheet and date menu below are Count.kcal design choices. Fitness's messaging, Highlights, competitions, and activity rings do not belong in this implementation. Apple's Activity Sharing privacy notice describes a different payload and protection scheme; its promises should not be copied into Count.kcal. [Apple Activity Sharing & Privacy](https://www.apple.com/legal/privacy/data/en/activity-sharing/)

## Prioritized recommendations

### 1. Put people and requests above setup

Priority: first. Observed in 02, 03, 15, 16, 22, 23, 26, 27, and 30.

The profile form consumes most of the first screen before the person arrives. On 03, Bob's row starts at roughly 560 points in an 874-point screen. On 23, the invitation appears below the same saved profile, followed by a second pending Bob row. Normal first use in 02 offers two disabled Invite controls while the most prominent enabled action is `Publish from this iPhone`. A person must work out the setup dependency themselves.

Move `SharingAccountSection` into a `Sharing profile` sheet opened by a trailing initials or person-circle button. Keep Invite beside it as a distinct person-plus toolbar action. Incoming requests appear first when present, then People, then outgoing invitations that have not become connections. An existing person's outgoing scope request belongs with that person's row and detail. Do not add another top-level tab or an inbox subsystem.

The empty state becomes `Share calorie cards` followed by `See each other's calorie cards. Choose Today, Previous 7 Days, or both.` Its enabled primary action is `Invite someone`. If a name is missing, that action opens a short `Your name` step with `Continue`, then resumes the invitation. A request can always be opened and declined; collect the user's missing name only before they accept. Once configured, profile editing uses a draft and `Save`, not an always-present `Confirm display name` button.

Keep the current dashboard Sharing button below Progress. Screen 01 shows a usable native control, and that placement is settled in the specification. A small request count on that same button is a reasonable refinement only if the existing inbox state can supply it without a new notification system. It is not needed for this first pass.

Source: [overview composition and disabled empty action](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingOverviewView.swift:40), [toolbar](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingOverviewView.swift:102), [profile form](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingOverviewView.swift:188), [disabled request review](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingOverviewView.swift:295), [name confirmation](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingRuntime.swift:167).

Preserve account binding and name validation. Moving the form does not make a display name verified identity. Account errors that block an action must still appear beside that action, even though routine account information moves into the profile sheet.

### 2. Make publishing-device selection contextual and safe

Priority: first, alongside profile work. Observed in 02 and 03; ownership constraints confirmed in source.

`Publish from this iPhone` makes normal sharing sound like a manual export and puts a rare replacement-device action into the first-use path. Remove it from the overview. During the first authorized invite or acceptance, select this iPhone automatically only when an authoritative server check establishes that no other publisher exists. Reuse confirmed ownership on later visits. Merely opening Sharing must not take over another phone.

In the profile sheet, use `Updates from` with value `This iPhone`. Supporting copy can say `Your cards update when Count.kcal receives new data. Updates may be delayed.` If another iPhone owns publication, show `Updates come from another iPhone` with `Use this iPhone`. That action requires an explicit contextual confirmation: `Use this iPhone for updates?` and `Your other iPhone will stop sending calorie-card updates for this Apple Account.` The confirmation action is `Use this iPhone`.

This is a narrow ownership improvement, not a synchronization redesign. `publisherLease` currently returns `nil` both for no record and for another device's lease. Do not call `takeOverPublisher()` automatically whenever `isPublisher` is false. The transport must distinguish unclaimed, owned here, owned elsewhere, and unverifiable ownership; claiming an unowned account must retain the existing server concurrency checks and handle another phone claiming it first. If ownership cannot be verified, show `Couldn't check the iPhone used for updates` and `Try again`. Do not invent a device name the model does not store.

Source: [current publisher action](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingOverviewView.swift:200), [lease ambiguity](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/CloudKitSharingTransport.swift:483), [claim operation](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/CloudKitSharingTransport.swift:495), [takeover and generation update](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingCoordinator.swift:214).

Preserve one publisher per account, explicit replacement, generation fencing, and best-effort background behavior. Do not promise live or continuous updates.

### 3. Use one calorie graphic and a tighter people row

Priority: first. Observed in 03 through 06, 16, 26, and 30.

The overview draws complete concentric circles while the full card uses open calorie arcs. They look like different products. The four-line row also separates `50 kcal` from `Deficit`, which makes a simple result unnecessarily tall.

Keep initials, name, summary, capture age, and trailing graphic. Combine the summary into `50 kcal deficit`. Use the existing `CalorieCircleGraph` at a small fitted size with its bottom opening and the sender's palette. Do not place a tiny number inside it. Keep the number in readable text and retain the row's combined accessibility description. At large text sizes, the name and summary may wrap, and the decorative graph may move or disappear rather than compress text.

Sample active row:

```text
[B] Bob                                  [calorie arcs] >
    50 kcal deficit
    Today · Updated 5 min ago
```

For History-only, replace Today with the sender's actual localized date. For paused or unavailable sharing, replace the numeric summary with the state and omit the graphic. Keep alphabetical sorting. No rankings, percentage completion, or new goal indicator.

Source: [current row](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingOverviewView.swift:330), [separate full-circle implementation](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingOverviewView.swift:393), [existing arc renderer](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Views/CalorieGraph/Circle/CalorieCircleGraph.swift:11), [fitted configuration with 90-degree opening](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Views/CalorieGraph/Circle/CalorieCircleConfiguration.swift:6), [shared full-card adapter](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharedCalorieCard.swift:16).

Preserve sender-rendered energy components, units, colors, and capture time. Feed the stored `snapshot.now.energy` to the miniature renderer; do not fetch local health data or read the recipient's calorie settings. Keep the full shared card's existing `CalorieCardContent` reuse intact.

### 4. Make invitation and consent about the actual choice

Priority: first. Observed in 07 through 10, 24, 25, 28, 29, and 31 through 34.

The invitation is a long form with five disclosure paragraphs, an agreement switch, and a separate creation action below the fold. The recipient sees almost the same essay. `CloudKit binds the invitation to their account` explains implementation rather than what the person must enter. The first screen has a fixed checkmark for Today and a switch for Previous 7 Days. Source confirms Today is hardwired on in both the invitation view and runtime. This is an existing flow limitation against the product's independently configurable scopes, not merely a visual preference.

Use a concise invitation form with persistently labeled `Apple Account email` and `Name` fields. Keep Name required for this bounded pass because the current invitation model uses it. Put email first and explain `Use the email address they use for iCloud. Check it with them before sending.` Do not add Contacts access or an account search feature.

Show two equivalent switches under `Share with each other`: Today on by default, Previous 7 Days off. Allow History-only, and require at least one scope for a new invitation. When History is on, place `Includes the seven completed days before today, even dates before you connected.` directly below that choice.

Replace the agreement switch with one explicit primary action after the concise disclosure: `Agree and continue`. This records the inviter's intentional agreement to the displayed person and exact scopes, prepares the invitation, and proceeds to the native sending step. Explain beneath it: `Next, choose how to send the invitation. It expires in 7 days.` If native presentation cannot follow preparation reliably, use a compact `Invitation ready` step with `Send invitation`. Never claim it was sent merely because a URL exists or the share sheet closed.

For an incoming initial request, use `Share with Bob?`, a scope summary, the same concise disclosure, and `Accept and share` / `Decline`. For an expansion, use `Add Previous 7 Days?`, `You and Bob already share Today`, and `Accept addition` / `Decline`. State that declining keeps Today. Do not repeat an initial-connection form for an addition.

Suggested first-layer disclosure, adjusted to the selected scopes:

> You and Bob will share calorie cards with each other through iCloud. Cards include burned and eaten energy, their components, deficit or surplus, and any goal result you show. Today includes the Midnight estimate. Meals, weight, steps, and raw Health samples are not shared.
>
> Either person can reduce or stop sharing. Changes take effect on this iPhone first; removing iCloud access may take longer. Saved copies cannot be erased. Old cards may remain accessible in iCloud until cleanup runs.

Keep `How sharing works` immediately available before agreement. It opens the complete explanation of sender dates, units/colors, delayed updates, storage, protection limits, rolling display/cache window, eventual cloud cleanup, and downloaded copies. Split that explanation into readable sections. The first layer must still state reciprocity, the selected scope, pre-connection history when applicable, and the material access-removal/retention limits. This is layered informed consent, not removal of consent or a claim that a particular legal checkbox is required.

Source: [invitation fields, fixed Today, disclosure and switch](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingInvitationView.swift:35), [creation and native ShareLink handoff](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingInvitationView.swift:65), [full disclosure](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingInvitationView.swift:119), [generic consent sheet](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingInvitationView.swift:160), [runtime hardwires Today](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingRuntime.swift:189).

Preserve intended-account binding, zero calorie disclosure during metadata acceptance, exact proposal identity, seven-day request expiry, and reciprocal readiness. The real system screens remain a verification gap for this proposal.

### 5. Separate current sharing from requested changes

Priority: first. Observed in 12 through 19 and 23 through 30.

Today-only sharing survives cancellation and decline correctly in the captured flows. The copy does not make that easy to understand. An expansion request lists `Today and Previous 7 Days` without saying which part is new. A resumption request becomes `Invitation pending` above `Sharing paused`. Settings show the same `Apply changes` action for a reduction, expansion, pause, or unchanged draft.

Keep one permission sheet with two independent draft switches. Title it `Sharing with Bob`. At the top state `Currently sharing Today`. Below the switches, describe the consequence of the draft in one sentence. Use a primary action that matches it:

| Draft | Explanation | Action |
| --- | --- | --- |
| Remove History, keep Today | `Stop sharing Previous 7 Days. Today stays on.` | `Save changes` |
| Add History | `Ask Bob to add Previous 7 Days. Today stays on while you wait.` | `Send request` |
| Both off | `Pause calorie-card sharing for both of you.` | `Pause sharing` |
| Resume selected scopes | `Sharing stays paused until Bob accepts.` | `Request to resume` |
| Remove Today and add History | `Stop Today now and ask Bob to share Previous 7 Days.` | `Save and send request` |
| No change | No consequence message needed | Disabled `Save changes` |

Keep the history explanation beside History. Keep a short access-removal caveat beside reductions and pause. Longer general information belongs in `How sharing works`.

Incoming requests get a compact actionable row at the top of Sharing: `Bob wants to add Previous 7 Days`, `Today stays shared`, and `Review`. Put Decline in the review sheet to keep the overview quiet. Outgoing changes appear as `Previous 7 Days requested · Waiting for Bob` on the existing person's row and in detail, with `Cancel request` in the request detail. Avoid a second large card that repeats the whole relationship. An initial invitation with no active relationship appears only under Invitations until accepted.

For a paused person, show `Sharing paused` once with `Request to resume`. After requesting, show `Waiting for Bob` and `Sharing remains paused until Bob accepts`, with a cancellation action. Derive wording from confirmed connection and proposal context. The current proposal has no explicit request-kind field, so do not guess a past relationship from a display name or `scopes.isEmpty`. Neutral `Sharing request` wording is acceptable where initial invitation versus resumption is not established.

Source: [request cards](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingOverviewView.swift:240), [generic status selection](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingOverviewView.swift:449), [permission draft and action](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingPersonDetail.swift:205), [waiting guidance](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingPersonDetail.swift:167), [remove-first transition](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingCoordinator.swift:184), [proposal model](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingModels.swift:72).

Preserve immediate local reductions after commitment, reduced scope while cloud revocation is pending, separate acceptance for additions/resumption, and invalidation of stale requests. A switch in an uncommitted draft is not an active permission. Keep it visually distinct from the current-sharing summary.

### 6. Let the person's card lead, with compact date navigation

Priority: next. Observed in 04 through 06, 11, 14, and 35.

The detail repeats Bob in the navigation bar and body, uses raw `2026-10-24` strings, and places a long date list beneath the card. With both scopes enabled, settings sit below that list. With Today only, the same list contains a single selected date and adds no useful choice. The large calorie card is already the strongest part of the screen.

Keep Bob as the navigation title. Replace the repeated body name and raw date heading with one date control: `Today, 24 Oct` with a menu containing only permitted dates. Use `Yesterday, 23 Oct` and localized weekday/date labels for older entries. Hide the menu affordance when only one date is available. This is a proposed Count.kcal layout, not a verified copy of Apple's date picker.

Keep `Updated 5 min ago` near the card. Show an exact timestamp in accessible detail and show the sender's time zone when it differs, using a readable label rather than an unexplained identifier. Preserve Now / Midnight directly above today's card, with `Estimate for midnight` as short supporting text when Midnight is selected. Historical dates have no mode picker. A compact `Sharing Today and Previous 7 Days` row below the card opens the permission sheet; More remains the place for pause and removal.

Source: [repeated name, date and mode](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingPersonDetail.swift:49), [full date list](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingPersonDetail.swift:83), [scope summary and settings](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingPersonDetail.swift:103).

Format the stored sender calendar day in its recorded time zone. Do not parse midnight in the recipient's zone and accidentally move the date. Relative Today/Yesterday labels must use the sender's day. Maintain date-window filtering and reset an invalidated selection. Never replace a missing Today card with yesterday under a Today label. If authorized History exists while Today is waiting, the date control must still let the person open those actual dates.

### 7. Give pending work one visible explanation and one relevant action

Priority: first for revocation; next for general loading polish. Observed in 18 through 22 and 35 through 36; further failure behavior confirmed in source.

Screens 35 and 36 place the access-removal message below the calorie card and date list, followed by a generic error and a separate `Try again`. The unchanged card visually dominates a privacy-relevant incomplete operation. After removal, 21 leaves a dead detail screen with a disabled More button. In source, consent and permission sheets dismiss after `runtime.perform` even when it catches a failure. That can make a failed action resemble success.

Use a compact status block above the affected card when revocation is pending. Example for the captured History reduction:

> Previous 7 Days is off on this iPhone. iCloud access removal is still pending. Bob may still be able to access earlier cloud copies.
>
> Retry removal

Use the existing pending work to show completion only after confirmation. If the retry fails, keep the same status, retain Today, and show `Couldn't finish removing iCloud access. Try again when connected.` Avoid a second generic error elsewhere on the screen. The overview should retain an actionable pending-removal item even after the person disappears from People.

After successful local removal, return to Sharing. Show `Sharing stopped on this iPhone` while cloud removal is pending, then remove that pending item when confirmed. Reserve `Sharing ended with Bob` for confirmed completion. Confirmation before removal should name Bob, state that it affects both people, and explain that reconnecting needs a new invitation. Keep the destructive action distinct from Pause.

For other states, use the shortest truthful explanation:

| State | Proposed presentation |
| --- | --- |
| First load, no known result | `Loading sharing…` with progress, not a final empty state |
| Refresh with cached permitted cards | Keep cards and original update times; show refresh progress without replacing them |
| No first Today snapshot | `Waiting for today's update` with `Updates arrive when Bob's iPhone sends them` |
| Invitation metadata accepted, inviter unfinished | `Finishing invitation` and `Calorie sharing hasn't started. Waiting for the other iPhone.` |
| Consent accepted, reciprocal setup unfinished | `Connecting with Bob` and `Cards appear when setup finishes`, with Retry on an actionable failure |
| Expired/canceled request | `This request is no longer available` with a clear return to Sharing |
| Account temporarily unverifiable | `Couldn't check iCloud` and Retry; retain only the cache allowed by existing policy |

Do not describe another person's missing data as a diagnosed Health permission problem. Do not reset a capture timestamp after fetching the same data or promise that pull-to-refresh can wake the sender's phone. For failed form actions, keep the sheet open with its draft and inline error unless the local change was durably committed. If the local reduction succeeded and only remote work failed, return to detail with the pending status instead of restoring the old scope.

Source: [pending overview block](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingOverviewView.swift:43), [detail status/error placement](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingPersonDetail.swift:103), [removal and confirmation](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingPersonDetail.swift:143), [consent dismissal](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingInvitationView.swift:176), [permissions dismissal](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingPersonDetail.swift:229), [runtime catches action errors](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingRuntime.swift:245).

Preserve durable retries, immediate local hiding, surviving removal work, permitted offline cache, and the difference between local success and server confirmation. Do not add time-based success assumptions or an Undo that silently restores revoked sharing.

### 8. Make the revised controls easier to operate without undoing accessibility work

Priority: part of each changed screen. Evidence from 04, 15, 23, 27, 35, and 36 plus their hierarchies.

The captured detail settings and retry buttons have accessibility frames only about 20 points high; date buttons are about 36 points high. Request Review and Decline frames are about 34 points high. These measurements justify checking and enlarging the actual hit regions. They do not prove that every system toolbar control is too small, because a system control's reported visual frame may differ from its touch behavior.

Use normal native rows or bordered actions with at least a 44-point interaction region for the custom content controls. Keep visible action styling rather than making Retry resemble body text. Preserve semantic text colors and the previous contrast corrections. Do not restore forced black calorie-label backgrounds; the app already has a separate optional setting for those.

Retain the combined name/value/freshness label on each person row, hide decorative initials and arcs from VoiceOver, and give every toolbar icon a clear label such as `Sharing profile`, `Invite someone`, and `More`. Use native selected-state semantics for date choices. Test the new compact layouts with long names, accessibility text sizes, VoiceOver, and Reduce Motion. Density should come from removing repetition, not reducing type size.

Source: [combined person row](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingOverviewView.swift:364), [request buttons](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingOverviewView.swift:295), [detail buttons](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Sharing/SharingPersonDetail.swift:86), [existing accessible full-card layout](/Users/berken/Development/Swift/Count.kcal/Count.kcal/Dashboard/CaloriesCard/CaloriesCard.swift:90).

## Proposed screen hierarchy

Use the existing dashboard navigation stack. The overview remains a list; person detail remains a card screen. Profile, invitation, request review, permissions, and About are native sheets. No custom navigation framework is needed.

```text
Dashboard
  Sharing
    Incoming requests, when present -> request review sheet
    People -> person detail
      Date menu -> permitted date
      Now / Midnight -> local viewing choice
      Sharing summary -> permissions sheet
      More -> permissions, pause, remove
    Outgoing invitations -> send / cancel
    Toolbar Invite -> name step if needed -> invitation sheet
    Toolbar Profile -> profile sheet -> How sharing works
```

These wireframes show hierarchy, not fixed dimensions. Native spacing, SF text styles, semantic backgrounds, and the existing sender palette should supply the appearance.

```text
OVERVIEW
< Back              Sharing          [Invite] [Profile]

Requests
  [B] Bob wants to add Previous 7 Days               >
      Today stays shared · Review

People
  [B] Bob                              [calorie arcs] >
      50 kcal deficit
      Today · Updated 5 min ago

Invitations
  [C] Charlie                                      >
      Invitation ready · Expires 31 Oct

PROFILE SHEET
Cancel             Sharing profile                 Save

Name                  Alice
Shown to people you share with.

Updates from          This iPhone
Cards update when Count.kcal receives new data.
Updates may be delayed.

Request notifications                                 >
How sharing works                                     >

INVITATION SHEET
Cancel             Invite someone

Apple Account email   bob@example.com
Name                  Bob
Use the email address they use for iCloud.

Share with each other
Today                                             [on]
Previous 7 Days                                   [off]

[Concise card-content and access disclosure]
How sharing works                                     >

[Agree and continue]
Next, choose how to send the invitation.
It expires in 7 days.

PERSON DETAIL
< Sharing                 Bob                       [More]

[Pending status only when needed]
Today, 24 Oct                                         v
Updated 5 min ago
              [ Now | Midnight ]
[Existing full Count.kcal calorie card]
Sharing Today and Previous 7 Days                      >

PERMISSIONS SHEET, EXAMPLE EXPANSION
Cancel                Sharing with Bob

Currently sharing Today
Today                                             [on]
Previous 7 Days                                    [on]
Includes dates before you connected.

Ask Bob to add Previous 7 Days.
Today stays on while you wait.
[Send request]
```

The profile's Save action only commits name edits. Request-notification controls use actual authorization state and are optional. Do not repeatedly prompt after denial. Normal request access remains available without notifications.

## Critical flow contracts

| Flow | Exact proposed sequence and result |
| --- | --- |
| First use | Open Sharing → see a clear empty state → Invite someone → enter own name if missing → Continue → invitation form. Verify account and publisher ownership in context. Automatic first-device selection is allowed only for authoritatively unclaimed ownership; otherwise offer explicit takeover or a recoverable account state. |
| Create invitation | Enter recipient email and name → choose Today and/or Previous 7 Days → review reciprocal scope, history and concise disclosure → Agree and continue → prepare one metadata invitation → native send interface. Canceling the system interface leaves an invitation that can still be sent or canceled. No calorie data is exposed at this stage. |
| Receive invitation | Open system invitation → perform metadata acceptance → return to a truthful preparation state if necessary → review the authoritative in-app proposal. Opening the link does not replace consent. The normal Sharing screen also exposes the request. |
| Accept | Review named person and exact scopes → supply own name if missing → Accept and share → durably record acceptance → Connecting while both directions become ready → display only authorized snapshots. An action failure stays visible; no premature success screen. |
| Decline | Review → Decline → remove that proposal. For a new relationship, no cards appear. For an addition, retain the current agreed scopes and show the person normally. No reason or message is required. |
| Reduce one scope | Person → permissions → turn one scope off → Save changes → persist reduction and hide/stop that scope locally immediately → show pending cloud access removal until both directions confirm. Retained scope remains usable. |
| Expand scope | Person → permissions → turn an additional scope on → Send request → retain the old scope → show the requested addition and named recipient → recipient reviews and accepts → provision the new scope before showing it. |
| Mixed remove/add | Review the draft consequence → Save and send request → apply removal first → send the addition against the reduced state. Failure of the addition never restores the removed scope. |
| Pause | More → Pause sharing → short explanation that both people's cards stop and resumption needs agreement → Pause sharing. Alternatively, both permission switches off yield the same action. Hide all pair cards locally immediately and retain cloud-removal status until confirmed. |
| Resume | Paused detail → Request to resume → choose scopes → Request to resume → remain paused while awaiting the other person → explicit acceptance → reciprocal readiness → cards. Cancel/decline/expiry leaves the connection paused. |
| Cancel outgoing request | Open its status → Cancel request → remove the proposal; existing scopes remain. Canceling an initial metadata invitation removes that invitation and associated setup through the existing lifecycle. |
| Remove person | More → Remove Bob → confirm that sharing ends for both and reconnecting needs a new invitation → remove locally and return to overview → keep any pending access-removal item with Retry → clear it on server confirmation. |
| Retry or reconnect | Retry only the relevant pending operation through existing coordinator/runtime paths. Keep reduced permissions and original snapshot times. Never convert a retry into renewed consent, automatic takeover, or a new invitation. |

## Minimum implementation scope

1. Rearrange `SharingOverviewView`, extract the existing profile controls into one sheet, and make Invite/Review route through missing-name setup rather than silently disabling them. Keep native List, Form, NavigationStack, Button, Menu, and sheet behavior.
2. Replace `SharingMiniGraphic` with a small configured use of the existing arc renderer. Keep `SharedCalorieCard` and `CalorieCardContent` as the full-card path. No new chart system or style library.
3. Revise the existing invitation/consent views, move long text into the existing About view, and pass an explicit scope set through `SharingRuntime.invite` so the initial form supports History-only. Keep Today-only as the default.
4. Derive request additions by comparing proposed and currently accepted scopes. Reuse the same review sheet with contextual titles and actions. Do not introduce a second consent model or infer authority in the view.
5. Replace the date list with a native date menu over the already filtered snapshot list. Add small sender-date formatting helpers only where needed.
6. Make action completion distinguish a locally committed change from a failure before dismissing. Preserve durable pending work and use it for status. Avoid a generic operation framework, new scheduler, or broad error-handling rewrite.
7. Add only the publisher ownership distinction needed to make unclaimed first-device setup safe. Retain the current authority record, claim mechanics, and generation fences. Explicit takeover remains a separate user action.

New UI strings should use the existing localization resources. UI-only composition and small concrete helpers are enough. Any future implementation should update the specification where this proposal intentionally changes first-use placement, consent presentation, or initial scope selection; it should not silently reinterpret the settled sharing guarantees.

## Coverage and verification after implementation

| Captures inspected | Review coverage |
| --- | --- |
| 01–02 | Dashboard discoverability, first-use hierarchy, disabled actions, publisher setup |
| 03–06 | People rows, complete rings versus arcs, Now/Midnight, historical date behavior |
| 07–10 | Invitation defaults, independent-scope limitation, consent density, About |
| 11–14 | More, permissions, reduction, remaining Today card |
| 15–19 | Outgoing addition, cancellation, pause and resumption wording |
| 20–22 | Destructive confirmation, dead detail after removal, empty state |
| 23–26 | Incoming initial request, consent, successful acceptance result |
| 27–30 | Incoming addition, repeated initial consent, decline preserving Today |
| 31–34 | Empty-fixture invitation, agreement gating, fixture-only completion |
| 35–36 | Local reduction with failed cloud revocation, retained status after retry |

The screenshots do not cover a multi-person list, long names, History-only first use, light appearance, accessibility sizes, keyboard entry, expired requests, slow invitation creation, first-load progress, account recovery, or current real system sheets. Treat recommendations for those states as source/spec-based proposals, not observed failures.

Verify the changed screens with a bounded fixture matrix: empty and populated overview, initial invite and History-only invite, initial acceptance, addition decline, reduction, mixed change, pause/resume, removal, slow/failing action, and pending revocation. Check that the user can still reach every action at maximum text size and on a compact iPhone. Exercise VoiceOver speech and gestures rather than treating the static hierarchy as a substitute. Check contrast, long names, translations, keyboard focus, selected date announcements, and Reduce Motion.

Retain existing sender/recipient raster parity checks for the full card. Check the new miniature against the same snapshot values and colors. Run targeted behavior tests only for changed scope submission, action-result handling, and automatic ownership claim safety. Do not repeat the entire historical CloudKit program for cosmetic changes. The revised invitation handoff and publisher setup do require focused real-account verification because their timing and system screens are outside these captures.

After any eventual iOS implementation, follow AGENTS.md: install and launch the latest build on the existing iPhone 18 Pro simulator, preserve its data and Apple Account, leave the affected screen open, and close owned debugger/log sessions. This proposals-only review leaves that simulator untouched.

No additional product features are needed to proceed. The main decisions are the concrete recommendations above: people-first overview, profile sheet, safe contextual publisher setup, layered consent, and contextual request/permission states. Preserve the safety model while making those decisions easier to see.
