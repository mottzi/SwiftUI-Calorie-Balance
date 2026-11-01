# iPhone Lock Screen widgets based on watch complications

Research date: 2026-10-31.

## Recommendation

Proceed with one circular Lock Screen widget. The open two-ring shape, lightning symbol, and calorie value in the supplied watch image are feasible in WidgetKit. Apple explicitly supports sharing SwiftUI views between iPhone accessory widgets and watch complications. The main visual change is compulsory monochrome rendering on the iPhone Lock Screen. The blue expenditure ring and orange intake ring cannot keep their separate brand colors there. [Apple accessory widget guide](https://developer.apple.com/documentation/widgetkit/creating-accessory-widgets-and-watch-complications), [Apple rendering guide](https://developer.apple.com/documentation/widgetkit/preparing-widgets-for-additional-contexts-and-appearances).

The drawing is a modest addition to this project. Reliable health data while the phone is locked is the larger engineering concern. This is a feasibility review, with no implementation or device verification.

The reference inspected was [watch-complication-01.png](../../Marketing/archive/legacy-app-store/watch/exports/watch-complication-01.png). The bottom circular complications offer a more direct starting point than the large central composition.

## What Apple allows

These are the three accessory families for the ordinary iPhone Lock Screen. They have been available since iOS 16. Apple controls their placement and allocated size. [Apple circular family](https://developer.apple.com/documentation/widgetkit/widgetfamily/accessorycircular), [Apple rectangular family](https://developer.apple.com/documentation/widgetkit/widgetfamily/accessoryrectangular), [Apple inline family](https://developer.apple.com/documentation/widgetkit/widgetfamily/accessoryinline).

| Family | Placement on the conventional portrait Lock Screen | Suitable Count.kcal content |
| --- | --- | --- |
| `accessoryCircular` | Compact circular slot below the clock | The watch-style rings, one primary calorie value, and a small symbol |
| `accessoryRectangular` | Wider slot in the widget area below the clock | Rings beside expenditure, intake, and balance values |
| `accessoryInline` | A single text row above the clock, beside the system date | A symbol and short balance text, such as `750 kcal` |

Apple documents these positions in its [widget design guidelines](https://developer.apple.com/design/human-interface-guidelines/widgets). Inline content consists of text and an optional image, with layout and character capacity dependent on context. It is unsuitable for the custom ring drawing. [Apple inline family](https://developer.apple.com/documentation/widgetkit/widgetfamily/accessoryinline), [Apple widget view guide](https://developer.apple.com/documentation/widgetkit/creating-views-for-widgets-live-activities-and-watch-complications).

`accessoryCorner` is a watch complication family, unavailable on iPhone. The curved labels and bezel space provided by some watch faces do not carry over to iPhone. [Apple widget design guidelines](https://developer.apple.com/design/human-interface-guidelines/widgets), [WWDC22 watch-specific behavior](https://developer.apple.com/videos/play/wwdc2022/10051/).

The usual portrait layout is commonly described as four circular positions, two rectangular positions, or two circles plus one rectangle, alongside the separate inline slot. Treat that as a layout planning assumption to verify on target devices, rather than an API guarantee. The primary sources reviewed establish the families and their placement but do not specify a universal slot-count contract. The user chooses widgets and placement through Apple's editor. [Apple Lock Screen customization guide](https://support.apple.com/guide/iphone/create-a-custom-lock-screen-iph4d0e6c351/ios).

Avoid fixing the drawing to one pixel size. Apple's specification examples include circular allocations of 68, 72, and 76 points and rectangular allocations of roughly 153 to 172 points wide. These are design guidance, not a complete list of future device sizes. [Apple widget design specifications](https://developer.apple.com/design/human-interface-guidelines/widgets#Specifications).

## What is fixed, and what we can draw

The family defines the available shape and space. Apple does not require us to use a particular ring or gauge template. WidgetKit uses SwiftUI views in place of ClockKit's old complication templates. Standard `Gauge` and `ProgressView` styles are useful options; custom paths and shapes can supply the Count.kcal geometry. [WWDC22 WidgetKit and ClockKit migration](https://developer.apple.com/videos/play/wwdc2022/10051/), [Apple additional widget sizes guide](https://developer.apple.com/documentation/widgetkit/supporting-additional-widget-sizes).

| System constraint | Consequence for this design |
| --- | --- |
| The system chooses the rendering mode for the context. On iPhone Lock Screen it is `vibrant`, which desaturates content and applies a material treatment that adapts to the wallpaper and selected tint. | Preserve ring position, arc length, gaps, symbol, and number. Do not rely on orange versus blue to explain intake versus expenditure. |
| Current documentation still maps the Lock Screen to `vibrant`, even while Home Screen widgets support clear and tinted appearances. | Liquid Glass and Home Screen color options do not provide a way to force this accessory widget into full color. |
| Background treatment depends on context. `AccessoryWidgetBackground` provides the adaptive accessory background, while `containerBackground(for: .widget)` identifies removable background content. | Start with the open rings. Add the accessory background only if wallpaper contrast requires it. Do not copy the watch screenshot's black rectangular image background. |
| Modern WidgetKit uses content margins. A configuration can disable them and apply its own padding. | A carefully fitted ring can use the available bounds, but disabling margins does not enlarge the system slot. |

Sources: [Apple rendering guide](https://developer.apple.com/documentation/widgetkit/preparing-widgets-for-additional-contexts-and-appearances), [Apple background guide](https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background), [Apple content margins API](https://developer.apple.com/documentation/swiftui/widgetconfiguration/contentmarginsdisabled()).

Design inference: distinguish the two rings through inner/outer position and deliberate grayscale contrast. Keep the balance number readable without interpreting either ring. A direct grayscale conversion of the screenshot needs review because the two colored rings may end up too similar. Test light, dark, and busy wallpapers, user tint, and Always On. Apple provides `isLuminanceReduced` for adapting to Always On. [Apple rendering guide](https://developer.apple.com/documentation/widgetkit/preparing-widgets-for-additional-contexts-and-appearances).

## Fit with the existing project

The following observations come from the current repository, reviewed alongside this research:

- [CountWidgetBundle.swift](../../Count.kcal.widgets/CountWidgetBundle.swift) already registers the iPhone circle, bar, nutrition, and weight widgets. Their current supported families are system widget sizes, without iPhone accessory support. [BalanceWidgetCircle.swift](../../Count.kcal.widgets/Widgets/BalanceWidgetCircle.swift) is the existing circle entry point.
- The watch already has WidgetKit circular complication implementations in [BalanceCircleGraph.swift](../../Count.kcal.complications/BalanceComplications/Circle/Graph/BalanceCircleGraph.swift). The watch graph wrapper in [CircleBalanceGraphWatch.swift](../../Count.kcal.watch/Tab.Calories/Views/CircleBalanceGraphWatch.swift) uses the shared [CalorieCircleGraph.swift](../../Count.kcal/Views/CalorieGraph/Circle/CalorieCircleGraph.swift), which is compiled into the relevant app and extension targets. Reusing this drawing is more direct than recreating it from the archived marketing PNG.
- [The Xcode project](../../Count.kcal.xcodeproj/project.pbxproj) currently targets iOS 17 or later. Lock Screen accessory availability therefore does not require raising the iPhone deployment target.
- [HealthDataTimelineProvider.swift](../../Count.kcal/Abstract/System/HealthDataTimelineProvider.swift) currently requests a new timeline after the earlier of 15 minutes or midnight and supplies one entry. Its iPhone now/midnight selection comes from a shared setting. A new circle should expose its meaning explicitly, either as a dedicated variant or per-widget configuration.

Apple supports extending an existing widget extension with accessory families. Declare the family and supply a view adapted to it; a new app target is unnecessary. A dedicated widget configuration within the current extension would make the first Lock Screen design easier to name and configure independently. That configuration choice is a recommendation, not an Apple requirement. [Apple accessory widget guide](https://developer.apple.com/documentation/widgetkit/creating-accessory-widgets-and-watch-complications), [Apple additional sizes guide](https://developer.apple.com/documentation/widgetkit/supporting-additional-widget-sizes).

## Health data, freshness, and privacy

HealthKit protects its store while the device is locked, and reads can fail with `errorDatabaseInaccessible`. Do not assume the Lock Screen widget can query fresh calorie statistics whenever its provider runs. [Apple HealthKit error documentation](https://developer.apple.com/documentation/healthkit/hkerror/errordatabaseinaccessible), [Apple HealthKit privacy guide](https://developer.apple.com/documentation/healthkit/protecting-user-privacy).

The current provider calls [HealthRepository.swift](../../Count.kcal/Abstract/System/HealthRepository.swift), which uses direct queries through [HealthKitDataSource.swift](../../Count.kcal/Abstract/System/HealthKitDataSource.swift). A thrown query error currently produces unavailable data. No last-good persisted daily snapshot fallback was found in this path. The existing multiline health-unavailable presentation also needs a compact accessory-specific alternative. These are repository findings, not platform restrictions.

Implementation recommendation: save a small last-successful daily snapshot after successful reads, with its day and timestamp. Let the widget use that snapshot when HealthKit is unavailable. Define when to show cached data, stale data, or no data, particularly after midnight. Select file protection deliberately so the cache is available in the intended locked state; caching health-derived values is a privacy decision, not merely a performance optimization. A rendered widget may already remain visible between reloads, but that does not make its next HealthKit query succeed.

WidgetKit schedules refreshes within a dynamic budget. Apple's typical example for frequently viewed widgets is 40 to 70 reloads per day, with variable intervals. An `.after` policy requests another timeline; it does not promise a fresh sample every 15 minutes. The containing app can request timeline reloads after data changes. The calorie value should be treated as a recent snapshot, not a continuously running measurement. [Apple widget refresh guide](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date).

Mark calorie values and related graphics with `privacySensitive` so the system can redact them according to the user's Lock Screen settings. An extension's Data Protection capability can impose stronger restrictions and replace its content with a placeholder until authentication. Plan a recognizable compact placeholder. [Apple widget extension privacy guidance](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension#Hide-sensitive-content).

## Taps and other Lock Screen features

For the first version, tapping the circle should open the relevant calorie screen through `widgetURL`. Circular and rectangular iPhone accessory widgets can also contain App Intent buttons and toggles, but actions on a locked device require authentication. A tiny information widget needs no additional action for its first release. [Apple interactivity guide](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities).

Do not confuse these families with the following features:

- Controls can replace system Lock Screen actions and appear in Control Center or on the Action button. They use system-rendered button or toggle presentations for actions, rather than offering a general custom circular data widget. [Apple control guide](https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system).
- Live Activities use ActivityKit for an ongoing event or task, with Lock Screen and Dynamic Island presentations. They are a different feature from a user-installed daily calorie accessory. [Apple WidgetKit overview](https://developer.apple.com/documentation/widgetkit).
- StandBy uses scaled `systemSmall` widgets. Supporting the circular accessory does not by itself define a StandBy design. [Apple additional contexts guide](https://developer.apple.com/documentation/widgetkit/preparing-widgets-for-additional-contexts-and-appearances).

## Suggested first scope

This is a proposed implementation sequence inferred from the platform and repository findings:

1. Add one iPhone `accessoryCircular` configuration to the existing widget extension, reusing the shared circle geometry. Start with the watch reference's ring-plus-number version, with one explicit balance meaning.
2. Adapt its monochrome appearance and fit. Use the ring positions and primary number to communicate meaning without separate blue and orange colors.
3. Add the cached-snapshot fallback, date handling, and compact privacy/unavailable states. Confirm behavior while locked and after midnight before considering the feature complete.
4. Deep-link the circle to the calorie screen. Defer action buttons and additional families until the information widget is legible and trustworthy.

Before shipping, verify on Sharing Cloud B through the repository's prescribed visible serve-sim workflow, then check privacy and locked HealthKit behavior on a physical iPhone. Simulator visual evidence alone cannot establish real locked-device data access. No simulator or physical-device tests were performed for this research.
