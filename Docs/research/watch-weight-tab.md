# Watch weight tab

Research date: 2026-10-04. Scope: a small weekly and monthly weight page that preserves the iPhone app's calculations.

## Current redesign recommendation

The user now wants weekly and monthly averages and charts stacked in one scrollable watch tab. This supersedes the original period toggle and the fitted single-screen layout described below. Use one ordinary `ScrollView` with a `VStack` containing Weekly, then Monthly. Keep it as the last page of the existing vertical tab view. Apple's watchOS guide explicitly supports longer scrolling pages and recommends placing them after fixed-height pages. The native tab indicator expands to represent scrolling within a longer page. [Creating an intuitive and effective UI in watchOS 10](https://developer.apple.com/documentation/watchos-apps/creating-an-intuitive-and-effective-ui-in-watchos-10)

Use plain sections rather than bordered cards or a boxed period control. Each section has an average label, a large left-aligned average with its unit, then a wide chart. Show the latest measurement and its date in a compact footer after both sections, without the visible Last Sample label. Separate the sections with whitespace. These choices implement the user's request; Apple does not require this exact composition. See [the visual comparison](watch-weight-visual-references.md) for the later refinement against Apple and popular watch apps.

Give the average the strongest text emphasis using a system title style with semibold or bold weight, with the unit smaller. Keep the period label at a readable supporting size. Apple's typography guidance says "In general, avoid light font weights" and "Consider using the built-in text styles." It specifies 16 pt as the watch default and 12 pt as the minimum. Support Dynamic Type by letting content grow vertically rather than shrinking the numbers or capping text size. [Typography HIG](https://developer.apple.com/design/human-interface-guidelines/typography), [official typography content read for this research](https://developer.apple.com/tutorials/data/design/human-interface-guidelines/typography.json)

Apply `.scenePadding(.horizontal)` to text blocks, not the whole ScrollView. Leave each chart the available safe-area width. Apple says to "maximize the width of the plot area" in compact environments. Use a visible line, recorded-value dots, and a restrained dashed mean. Retain two or three short trailing Y labels so the scale remains interpretable. Put the unit beside the average instead of repeating it on ticks. Omit per-point numbers and heavy vertical grid lines. Weekly weekday labels and a few monthly dates are enough. Keep accessibility dates and weights on data marks. [Charts HIG](https://developer.apple.com/design/human-interface-guidelines/charts), [official charts content read for this research](https://developer.apple.com/tutorials/data/design/human-interface-guidelines/charts.json)

Keep the system clock and existing toolbar. Use a standard `.navigationTitle("Weight")` if a title is needed, with no duplicate body title. Let native navigation and scrolling safe areas place the first metric below the status region. Text should follow the system's leading and trailing margins, while charts use the wider region. `.scenePadding(.top)` does nothing on watchOS. Avoid hard-coded clock-height offsets and `.ignoresSafeArea(.all)` on content. If native placement fails in this container, verify the actual title and toolbar arrangement before choosing a bounded local adjustment. [Supporting multiple watch sizes](https://developer.apple.com/documentation/watchos-apps/supporting-multiple-watch-sizes), [scenePadding](https://developer.apple.com/documentation/swiftui/view/scenepadding(_:edges:)), [watchOS navigation guidance](https://developer.apple.com/documentation/watchos-apps/creating-an-intuitive-and-effective-ui-in-watchos-10)

I fetched Apple's official HIG JSON and read the primary content, rather than relying on the JavaScript placeholder pages. The current layout content dated September 9, 2026 emphasizes alignment, whitespace grouping, safe areas, and adaptable text. Older cached HIG pages still contain a watch-specific edge-to-edge sentence that is absent from the current JSON. Full-width charts here follow the current Charts width guidance and the user's request, not a quotation invented from the current Layout page. [Layout HIG](https://developer.apple.com/design/human-interface-guidelines/layout), [official layout content read for this research](https://developer.apple.com/tutorials/data/design/human-interface-guidelines/layout.json)

Verify Weekly on first arrival, Monthly after a Crown scroll, returning to the macro page, both chart edges, German labels, smaller watch sizes, and larger text. Re-run the unchanged shared semantic tests. This redesign changes presentation rather than calculation or transfer policy.

## Original recommendation, superseded for layout

Add one weight page to the existing `.verticalPage` `TabView`. Apple recommends focused, glanceable pages and native Digital Crown navigation. Keep period selection within that page, with a simple Weekly/Monthly control. Let the existing tab view own Crown navigation. This control choice is an implementation recommendation, not a specific Apple requirement. [Designing for watchOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos), [Creating an intuitive and effective UI in watchOS 10](https://developer.apple.com/documentation/watchos-apps/creating-an-intuitive-and-effective-ui-in-watchos-10)

Use native Swift Charts. Apple's watch sample introduces Charts on watchOS 9 and demonstrates a chart as a peer page in a tab view. This project targets watchOS 10.5, so no fallback chart renderer is needed. [Build a productivity app for Apple Watch](https://developer.apple.com/videos/play/wwdc2022/10133/?time=372), [project target settings](../../Count.kcal.xcodeproj/project.pbxproj)

Use a line for change over time, points for recorded daily values, and a dashed horizontal mean. Keep the chart wide with sparse labels. Avoid scrubbing and interactive zoom. Apple explicitly advises simple chart interactions on watchOS and supports pairing point marks with a line. Preserve visible units and date context. Swift Charts provides accessible marks and audio graphs; supply useful date and weight labels, and hide decorative duplicate marks from accessibility. [Charts HIG](https://developer.apple.com/design/human-interface-guidelines/charts), [LineMark](https://developer.apple.com/documentation/charts/linemark), [Swift Charts](https://developer.apple.com/documentation/charts)

## Existing iPhone semantics

The existing calculations already live in shared [`WeightHistory`](../../Count.kcal/Abstract/WeightHistory.swift) and [`HealthRepository`](../../Count.kcal/Abstract/System/HealthRepository.swift). Reuse them, and adapt only chart layout for the wrist. These details matter for parity:

- The weekly chart uses the final seven calendar-day entries, including missing days. It is a rolling period, not the current calendar week.
- The monthly plotted series uses the existing `lastMonday` helper applied to thirty days before today. It can contain more than thirty entries. Its average uses only the final thirty entries. Preserve this existing distinction rather than silently reducing the plot to thirty days.
- HealthKit returns a discrete daily average. The repository rounds each daily value to one decimal in the selected kg or lbs unit. The period average is the mean of those rounded daily values, excluding missing days, rounded again to one decimal. Days have equal weight even if one day contains more measurements.
- Missing days stay `nil`, rather than becoming zero. The iPhone connects the valid points across these gaps.
- The latest measurement and its timestamp come from a separate latest-sample query. They can differ from the latest charted daily average, and the latest sample can fall outside the plotted period.
- Trend color compares the newest valid daily average with the selected period average. It does not compare first and last samples, and it does not change with the weight goal.
- Weekly and monthly use their existing shared Y-range calculations. The iPhone weekly X domain ends tomorrow. Its monthly X domain ends on the Sunday boundary after today.

The visual source is [`WeeklyChart`](../../Count.kcal/WeightCard/WeeklyChart.swift), [`MonthlyChart`](../../Count.kcal/WeightCard/MonthlyChart.swift), and [`WeightTopBar`](../../Count.kcal/WeightCard/WeightTopBar.swift). Large per-point labels and the iPhone's thick lines need not be copied to the smaller display. Their meanings do.

## Device data parity

Apple documents separate HealthKit stores on iPhone and Apple Watch, automatic synchronization, and periodic purging of old watch samples. `earliestPermittedSampleDate()` exposes the platform retention boundary. Therefore, matching query code alone cannot guarantee that a watch retains the same complete monthly history as the phone. [About the HealthKit framework](https://developer.apple.com/documentation/healthkit/about-the-healthkit-framework), [earliestPermittedSampleDate](https://developer.apple.com/documentation/healthkit/hkhealthstore/earliestpermittedsampledate())

For literal phone mirroring, send the small phone weight snapshot through the existing Watch Connectivity application context. Retain the latest received snapshot on watch, with its unit and sample timestamp. Reuse `WeightHistory` for calculations over those same daily inputs. This avoids adding a second history database or treating the watch's shorter local history as a full phone month.

Application context fits latest state: it replaces a pending older context and supports delivery while the counterpart is unreachable. Delivery is opportunistic, so the watch mirrors the latest received phone snapshot, not a guaranteed instantaneous phone state. Combine settings and weight in every outgoing context because a separate context update would replace the other payload. [updateApplicationContext](https://developer.apple.com/documentation/watchconnectivity/wcsession/updateapplicationcontext(_:)), [Transferring data with Watch Connectivity](https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity)

## Verification

Test identical deterministic daily inputs on both platforms for seven-day and thirty-day means, missing days, multiple measurements per day, kg/lbs, latest sample versus latest daily mean, flat trend, and Monday-aligned monthly chart bounds. Include an older point that affects the monthly chart but falls outside the thirty-day mean. Check the empty series without drawing a false zero-weight reference line.

Verify both periods are readable on the smaller watch simulator and that scrolling leaves normal tab navigation intact. Simulator fixtures establish layout and calculation parity. Apple asks for physical paired devices when testing its Watch Connectivity sample, so distinguish a local snapshot round trip from verified physical delivery. [Transferring data with Watch Connectivity](https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity)

## Navigation title and top layout

Prefer `.navigationTitle("Weight")` on the weight page and remove its duplicate body title. Apple recommends a large title on a watch NavigationStack root. The system moves the title and clock to accommodate toolbar items. Standard text navigation titles also support Dynamic Type and marquee behavior. Verify the existing leading ring toolbar still leaves useful title space. [Creating an intuitive and effective UI in watchOS 10](https://developer.apple.com/documentation/watchos-apps/creating-an-intuitive-and-effective-ui-in-watchos-10), [watchOS 11 release notes](https://developer.apple.com/documentation/watchos-release-notes/watchos-11-release-notes)

`.scenePadding(.top)` cannot reserve space for the clock. Apple explicitly documents that scene padding ignores top and bottom on watchOS. Keep `.scenePadding(.horizontal)` for standard text margins. Scrolling content normally settles within safe areas, so use the native navigation title and safe-area behavior before adding a fixed offset. [scenePadding](https://developer.apple.com/documentation/swiftui/view/scenepadding(_:edges:)), [Supporting multiple watch sizes](https://developer.apple.com/documentation/watchos-apps/supporting-multiple-watch-sizes)

## Previous implementation and verification, before redesign

The regular watch layout uses a fitted VStack and leaves the Crown with the vertical tab view. Accessibility text sizes use a ScrollView. The chart uses the same daily points, selected-period mean, trend calculation, date bounds, and Y range as the phone. Weight snapshots travel in the existing combined settings application context and restore from its cached received context after watch relaunch.

Debug and Release simulator builds passed without compiler warnings. `zsh Tests/run-weight-semantics.sh` passed against the production WeightHistory and date helpers with fixture query dependencies. It checks missing days, the monthly lead-in, means, units, latest measurement versus daily average, empty and short histories, trends, property-list round trips, and rejection of pending results after reset or a unit change.

On the 208×248 Apple Watch simulator, phone/watch values matched: weekly 79.8 kg, monthly 80.1 kg, latest 79.8 kg; weekly 175.9 lbs, monthly 176.5 lbs, latest 176.0 lbs. Actual simulator application-context delivery, unit replacement, cached snapshot restoration, German labels, period switching, and Crown navigation passed. The final header and full chart axes were visible on first arrival. The phone unit was restored to kg.

Physical paired-device delivery, smaller watch sizes, and accessibility text sizes remain unverified. All-nil and short histories were checked by model tests rather than simulator fixtures.

## First scrollable redesign and verification

Both periods now remain in a single native ScrollView. Text headers retain system scene margins; charts have only 4 pt horizontal padding and inset scale labels. A large latest weight and its short date replace the Last Sample row. Plain period headings and prominent averages replace the control. Charts use a visible line, subtle area tint, sparse date labels, two readable weight-scale labels, and the existing dashed mean. The monthly chart omits only the empty future tail of the iPhone plot; all daily values, averages, units, trend calculations, and Y ranges stay shared.

The normal watch simulator shows weekly 79.8 kg and monthly 80.1 kg. Crown and touch scrolling expose both sections, return to the latest weight, and return to the macro tab. Both upper and lower inset scale labels fit without clipping after explicit label anchoring. The shared semantic runner passed, and Debug and Release builds passed without compiler warnings. Only VoiceOver labels changed after the final visual capture. Smaller watch layouts and accessibility text sizes remain unverified with the installed simulator inventory.
