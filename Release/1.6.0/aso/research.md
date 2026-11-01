# Count.kcal 1.6.0 App Store refresh

Checked 20 October 2026 against Apple's published documentation, the live marketing website and this repository. This refresh covers iPhone media and en-US, de-DE, fr-FR and es-ES metadata. The copy is in [metadata.json](metadata.json).

## Positioning and title

Recommend `Count.kcal: Calorie Deficit` for en-US, with `Intake, burn & weight trends` as the subtitle. The title has 27 characters and the subtitle has 28. This restores the app's identity while keeping a direct description of what people can track. The current `Calorie Deficit Tracker -/+` name is generic, and the plus/minus suffix adds little meaning at search-result size.

Use native phrasing in the other locales:

| Locale | Name | Subtitle |
| --- | --- | --- |
| de-DE | Count.kcal: Kalorienbilanz | Aufnahme, Verbrauch & Gewicht |
| fr-FR | Count.kcal: Bilan calorique | Apports, dépense et poids |
| es-ES | Count.kcal: Balance calórico | Ingesta, gasto y peso |

These are editorial recommendations, not measured keyword-volume or conversion claims. Apple recommends a memorable, distinctive name, a subtitle that explains the app's use, relevant keywords without duplicates or competing names, and a description whose first sentence states the main value. Promotional text does not improve search ranking. [Apple product-page guidance](https://developer.apple.com/app-store/product-page/)

The opening message is intake compared with burn using Apple Health data. Food logging belongs to another app. Do not imply that Count.kcal has meal entry, a barcode scanner, a food database, AI food recognition or a diet plan. The first screen should make the intake/burn comparison visible before it introduces customization.

## Metadata limits and validation

Apple permits 30 characters for the name and subtitle. [Apple product-page guidance](https://developer.apple.com/app-store/product-page/)

Promotional text allows 170 characters. Descriptions allow 4,000 characters and plain text with line breaks. Keywords allow 100 bytes. Apple's reference says each keyword must be longer than two characters and excludes app/company names already searchable elsewhere. Its marketing guide describes the keyword limit as 100 characters; this release uses the stricter UTF-8 byte limit. [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)

The JSON contains validated character counts and UTF-8 keyword byte counts. The copy deliberately leaves some keyword capacity unused. No keyword needs padding simply to reach 100 bytes.

| Locale | Name | Subtitle | Promo | Description | Keywords, UTF-8 bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| en-US | 27 | 28 | 139 | 1653 | 84 |
| de-DE | 26 | 29 | 150 | 1905 | 94 |
| fr-FR | 27 | 25 | 151 | 1957 | 89 |
| es-ES | 28 | 21 | 139 | 1758 | 89 |

The four release notes retain the specific 1.6.0 changes already documented in `Release/1.6.0/whats-new.*.txt`. Significant changes need specific What's New text rather than a generic improvements line. [App Review Guideline 2.3.12](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata)

## Screenshot delivery

Apple's current screenshot page names device families rather than relying only on diagonal display measurements. Its required-size summary explicitly names iPhone with Dynamic Island, medium display. Accepted portrait dimensions are 1179 × 2556 and 1206 × 2622. Prepare 1206 × 2622 for the current iPhone 18 Pro material.

The large Dynamic Island family accepts 1260 × 2736, 1290 × 2796 and 1320 × 2868. Face ID large accepts 1284 × 2778 and 1242 × 2688. The page describes automatic scaling between relevant families. Keep large exports available if the current App Store Connect media wells still require them.

Each device size accepts 1 to 10 JPEG, JPG or PNG screenshots. Images must have no alpha channel or transparency. iPad requires its own media only if the app supports iPadOS. This refresh creates iPhone media only. [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)

Screenshots must show the app in use. Explanatory text and image overlays are allowed. Use fictional sample health records. Keep visible app content large enough to read; avoid giving all six cards the same dashboard composition. [App Review Guidelines 2.3.3 and 2.3.9](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata)

The six copy concepts in the JSON cover the calorie comparison, Midnight estimate, Progress, macros, weight charts and customization. They are suggested scene copy, not a requirement to produce six images if the available scenes do not support six distinct stories. Show themes 1, 2 and 4 in dark mode as requested. Repeating a theme with an alternate caption must still show the feature named in that caption.

## App Preview delivery

Use this export target for modern portrait iPhone footage:

| Property | Delivery requirement |
| --- | --- |
| Accepted portrait resolution | 886 × 1920 pixels |
| Duration | 15 to 30 seconds |
| File size | At most 500 MB |
| H.264 container | .mp4, .mov or .m4v |
| H.264 encoding | Progressive, up to High Profile Level 4.0 |
| H.264 target rate | 10 to 12 Mbps |
| Frame rate | At most 30 fps |
| Alternate codec | ProRes 422 HQ in .mov |
| If audio is present | Stereo AAC, 256 kbps, 44.1 or 48 kHz |
| Audio track layout | One two-channel L/R track or two one-channel L/R tracks, all enabled |
| Default poster | 5 seconds |

Use the accepted preview resolution, which differs from screenshot resolution. A preview with a different aspect ratio from the screenshots can move to A Closer Look. [App Preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/)

A preview precedes screenshots in the product-page gallery even if reordered in the app record. Up to three previews per device size and language are permitted. Processing may take 24 hours, so upload well before the intended review time. [Upload previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/)

Use actual app screen recordings. Narration and explanatory text overlays are allowed; a rendered phone montage is unsuitable for this preview. [App Review Guideline 2.3.4](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata)

The first seconds should show the app's calorie comparison. Keep it understandable with sound muted. Use readable text, straightforward cuts or dissolves, and avoid seasonal claims and pricing. Apple recommends native UI capture rather than zoomed views and disallows filmed fingers or people handling devices. The poster must be selected from the footage and appears when autoplay is disabled. Changing an approved preview's poster requires another preview submission. [Apple App Preview guidance](https://developer.apple.com/app-store/app-previews/)

For this release, keep a settled dashboard on screen at five seconds so the default poster is useful even before manual selection. Ensure the selected poster has no half-animated labels or transition frame. This is an editing recommendation, not an Apple requirement.

## Product-page header

Header art uses a different placement from an App Preview. A still header accepts 3840 × 1646 at 21:9 as JPEG/JPG/PNG, or 5244 × 2950 at 16:9 as PNG. Neither may include alpha or transparency. The header's video option accepts 3840 × 1646 at 30 or 60 fps, 5 to 30 seconds, in MOV/M4V/MP4. Those video limits must not be used for the iPhone App Preview. [Creative assets specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications)

## Localization

Localize the visible metadata and on-image copy as a set. App Store language selection depends on the customer's language, storefront support and available localizations, not just the device's country. A newly added localization inherits screenshots and most properties from the primary language, but description and keywords need their own entries. App Store localizations and the binary's supported languages are separate settings. [Localize app information](https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information/)

If a localized preview is missing, Apple can display the next available language. Four localized exports avoid relying on that fallback. [Upload previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/)

## Product facts checked

The website describes Apple Health imports, separate active and resting burn, a Midnight estimate, macronutrients, weight and custom colors. It explicitly says intake can come from a third-party food logger that writes to Apple Health. The metadata uses those product facts without repeating its simplified weight-loss claims. [Count.kcal website](https://count.mottzi.codes/)

Repository evidence supports the other claims:

- [README](../../../README.md) documents calorie graphs, macros, body weight, custom energy values, widgets, local health data and dark/light appearance.
- [ProgressSummary.swift](../../../Count.kcal/Progress/ProgressSummary.swift), [ProgressDetails.swift](../../../Count.kcal/Progress/ProgressDetails.swift) and [release review notes](../review-notes.en-US.txt) document completed-day averages, exclusions and weight-period comparisons.
- [Settings.swift](../../../Count.kcal/Abstract/System/Settings.swift) defines the ordered color themes. Themes 1, 2 and 4 refer to the first, second and fourth displayed choices.
- [Current release notes](../whats-new.en-US.txt) document the new large widget, reorderable dashboard, Progress placement and optional steps.

Free use without paid upgrades is part of the release brief. The copy states no subscriptions or in-app purchases in the description, and avoids putting a price claim in the name, subtitle, screenshot text or preview. No sign-in is required according to the release review notes. Privacy wording describes Count.kcal not uploading health data, without making a claim about Apple Health's own optional iCloud synchronization.

## URL checks and remaining work

Anonymous HTTP checks on 20 October 2026 found:

| URL | Result | Use |
| --- | --- | --- |
| https://count.mottzi.codes | HTTP 200 | Verified marketing URL |
| https://count.mottzi.codes/help | HTTP 404 | Do not enter as support URL |
| https://count.mottzi.codes/privacy | HTTP 404 | Do not enter as privacy URL |
| https://count.mottzi.de/help | DNS lookup failed | Existing support link is unavailable |
| https://sites.google.com/view/count-kcal-privacy/ | Redirects to Google sign-in | Existing privacy page could not be verified as public |
| https://github.com/mottzi/SwiftUI-Calorie-Balance/issues | HTTP 200, public issue list and New issue action | Useful issue-report destination |

A public issue list works for filing feedback, but Apple's Support URL reference requires actual contact information, such as an email address, legal address or telephone number. The verified issue-list page does not establish that requirement by itself. Add a public support page with an existing authorized contact method, or verify a different current contact page before changing the field. [Support URL requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)

The JSON sets the verified marketing URL only. Support and privacy URLs remain unresolved rather than pointing to fabricated routes. No App Store Connect fields were changed by this research task. Final publishing still needs App Store Connect save/readback, media processing checks and a working public privacy page.
