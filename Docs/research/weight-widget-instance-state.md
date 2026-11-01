# Independent weight widget periods

Research date: 2026-10-23.

The earlier recommendation needs a qualification. WidgetKit supports different
saved configuration values for different widgets. Changing to
`AppIntentConfiguration` alone does not establish that the existing in-widget
buttons can change one physical placement's period independently of every
identically configured placement. The public APIs examined provide configuration
values and widget family, without a documented durable placement identifier
passed to the timeline provider or button intent. Sources and limits follow.

## Current behavior in this repository

[`WeightWidget.swift`](/Users/berken/Development/Swift/Count.kcal/Count.kcal.widgets/Widgets/WeightWidget.swift:7)
uses `StaticConfiguration` with kind `WeightProgressWidget`, supports small and
medium families, and uses a `TimelineProvider`. Every timeline reads the same
`WeightWidgetMode.isMonthly` value at line 40. Both action intents write the
single `weightWidgetMonthlyMode` key in the shared app group at lines 79-90 and
105-129. No family, selected configuration, or placement identity scopes this
state. Consequently, all instances use the same period when their timelines
reload. This is a code observation; it does not promise simultaneous visual
updates of every placement.

## What Apple supports

An `AppIntentConfiguration` defines user-editable widget options through a
`WidgetConfigurationIntent`. `AppIntentTimelineProvider` receives those selected
values in its snapshot and timeline callbacks. Apple's example lets a person
choose a different game character for each widget. A `period` option can use the
same mechanism, so one small widget can be configured as weekly and one medium
widget as monthly. These APIs are available from iOS 17. Sources:
[Making a configurable widget](https://developer.apple.com/documentation/widgetkit/making-a-configurable-widget),
[AppIntentTimelineProvider](https://developer.apple.com/documentation/widgetkit/appintenttimelineprovider),
and [WidgetConfigurationIntent](https://developer.apple.com/documentation/appintents/widgetconfigurationintent).

Interactive buttons are a separate mechanism. Their App Intent performs an
action against app data. After `perform()` returns, WidgetKit reloads the
timeline. Apple tells developers to finish persisting required data before
returning, and says that only `@Parameter` values are preserved for the action.
This supports passing a stable model identifier into the period action. It
does not document replacing a particular placement's saved configuration by
mutating a configuration intent value in that action. Sources:
[Adding interactivity](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)
and [Bring widgets to life, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10028/).

## Identity limits in the current public SDK

The installed iOS 27 public interface was examined alongside Apple's docs. The
relevant declarations are in
[WidgetKit.swiftinterface](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.0.sdk/System/Library/Frameworks/WidgetKit.framework/Modules/WidgetKit.swiftmodule/arm64e-apple-ios.swiftinterface:92).

- `WidgetInfo`, lines 92-119, exposes kind, family, the configuration intent, and
  `Identifiable` conformance. Its `id` has type `WidgetInfo`; the inspected
  interface declares a getter without exposing its implementation.
  It is inaccurate to say this type has no `id`. Its declaration and documentation
  do not establish an independently serializable placement token delivered to
  the provider or action.
- `TimelineProviderContext`, lines 1667-1681, exposes family, preview status,
  display size, and environment variants. None is a placement identifier.
- `AppIntentTimelineProvider`, lines 1498-1505, receives configuration and context.
- `WidgetCenter`, lines 574-589, offers configuration inspection and reloads by
  kind or all timelines. These declarations provide no method to replace one
  placement's saved configuration, or reload by a placement token.

Apple documents the same members in
[WidgetInfo](https://developer.apple.com/documentation/widgetkit/widgetinfo),
[TimelineProviderContext](https://developer.apple.com/documentation/widgetkit/timelineprovidercontext),
and [WidgetCenter](https://developer.apple.com/documentation/widgetkit/widgetcenter).
This is a bounded conclusion about the inspected public APIs, not proof about
private implementation details. A Swift `hashValue` or debug description is not
a documented substitute for durable placement identity.

`WidgetConfigurationIntent` also inherits `PersistentlyIdentifiable`, but that
protocol identifies the intent **type** through a static `persistentIdentifier`.
It does not assign each added widget a unique record. Source:
[PersistentlyIdentifiable](https://developer.apple.com/documentation/appintents/persistentlyidentifiable).

## Designs and their guarantees

The following are architectural deductions from the APIs above, rather than
additional platform promises.

| Design | Independence | Existing period buttons |
| --- | --- | --- |
| Separate stored period per family | Small and medium independent; two small widgets still linked | Can remain; provider and action must use the same family key |
| Period in Edit Widget configuration | Any placement can be configured weekly or monthly, including two of the same size | A button cannot simply overwrite that saved configuration through the APIs examined |
| Configured app-owned view record | Each distinct record has independent persistent period state | Can remain; buttons pass the selected record ID and update that record |

For the record approach, the app would create durable records such as "Weight
view 1" and "Weight view 2". The configuration selects an `AppEntity` representing
one record; the provider resolves its ID and reads the record's period; each
button receives that same ID. Apple's entity documentation defines `id` as
stable identity, and `EntityQuery.entities(for:)` resolves saved identifiers.
Apple demonstrates reusing an entity as a widget configuration option in
WWDC24. Sources:
[AppEntity.id](https://developer.apple.com/documentation/appintents/appentity/id),
[EntityQuery](https://developer.apple.com/documentation/appintents/entityquery),
and [Bring your app's core features to users with App Intents](https://developer.apple.com/videos/play/wwdc2024/10210/).

This gives independence per configured record. Two placements selecting the
same record would intentionally share its period. To promise one record per
physical placement, the setup experience must make the user select different
records, or a separately validated allocation mechanism must guarantee it.
Merely renaming the record "widget instance" does not solve that distinction.

The mode and record identifier can live in persistent app storage. The current
app group defaults are sufficient for small nonsensitive period values; Apple
documents persistent defaults and app group sharing. Persistence still requires
the same stable key on every read, including refreshes and after restart.
Sources: [UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults)
and [init(suiteName:)](https://developer.apple.com/documentation/foundation/userdefaults/init(suitename:)).

## Why a hidden random UUID is not yet a recommendation

A UUID parameter could distinguish configurations **if** WidgetKit saves a
different UUID for every placement and preserves it thereafter. This research
found no first-party guarantee that generating a UUID in an intent initializer,
provider callback, or default-options query runs exactly once per physical
placement. Apple defines `defaultResult()` as supplying a default parameter
value when the user supplies none; it does not define it as a widget-creation
callback. Source:
[DynamicOptionsProvider.defaultResult()](https://developer.apple.com/documentation/appintents/dynamicoptionsprovider/defaultresult()).

Omitting a parameter from `parameterSummary` controls its presentation, not its
uniqueness or allocation lifecycle. Source:
[WidgetConfigurationIntent](https://developer.apple.com/documentation/appintents/widgetconfigurationintent).

Inference: a UUID created in a timeline entry would lack a documented way to
attach itself to the persisted configuration for subsequent callbacks.
Generating IDs in defaults or initializers also leaves unanswered whether
previews allocate records, whether configuration copying preserves an ID, and
whether editing or reconstruction regenerates one. These are unanswered
lifecycle questions, not claims that any particular OS always fails. Do not
ship this as transparent complete independence based on a successful first tap.

## Recommendation and implementation gates

For the requested weekly-small/monthly-medium combination while retaining the
existing buttons, separate family state is the smallest predictable change.
For arbitrary combinations of the same size, use the native period setting in
Edit Widget if changing there is acceptable. If buttons must remain and same-size
placements must differ, use distinct app-owned records with explicit selection.
The latter adds setup and should not be presented as an invisible migration.

Before choosing a configurable replacement, verify upgrades from the existing
static widget. An Apple Frameworks Engineer said in October 2020 that changing
static to intent configuration had no supported migration then. That historical
answer does not establish iOS 27 behavior, but it makes an upgrade check necessary
instead of assuming that keeping the kind string preserves existing widgets.
Source: [Apple's migration reply](https://developer.apple.com/forums/thread/661247).

Any implementation that claims complete independence should exercise two
different-size widgets and two identical-size, identically configured widgets.
Verify separate and shared record selections, repeated button taps, ordinary
timeline refresh, extension termination, device reboot, widget editing,
duplication, resizing, removal and re-addition, and upgrade from this static
widget. If both a saved period and a button-updated period exist, define which
one wins after editing and refresh so the configuration UI cannot silently
disagree with the displayed graph. Include the minimum supported iOS release and
a physical device. If automatic UUID allocation is proposed, add gallery
previews, configuration copies, and backup restoration to establish its limits.
These are proposed acceptance checks; no such prototype, build, install, or
device experiment was performed for this note.

Research changed documentation only. The app's current shared setting is intact.
