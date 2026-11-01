Count.kcal 1.6.0 product-page header
Created 20 October 2026

Delivery
count-kcal-product-page-header-3840x1646.png
3840 x 1646 pixels, RGB PNG, no alpha channel or transparency.
review-1920.jpg is a smaller review image, not the upload asset.

Composition
One large Midnight calorie card in theme 1 occupies the center. Themes 2
and 4 sit behind it, cropped at the outside edges and dimmed uniformly.
The main card keeps its original colors and complete UI. The background
matches the screenshot collection's near-black #080A0F. No marketing text,
price, website, icon or device frame has been added.

Sources
The central card is the current theme-1 transparent Midnight still from
Marketing/2026-10-calorie-card/stills. Side cards are direct rectangular
crops of current theme-2 and theme-4 dashboard screenshots from
Marketing/2026-10-today/captures. They contain fictional sample data.
No UI was synthesized, redrawn or selectively recolored. Layout operations
are crop, proportional resize, uniform side-card dimming, shadow and
alpha composition onto an opaque canvas.

manifest.json records exact source paths, crop and placement coordinates,
brightness and SHA-256 source hashes. Original source assets are unchanged.
The image has no added locale text; existing app UI is English.

Validation
The full-size output was opened with view_image and inspected for readable
main values, intact circle and bar graphs, a clear central focus, clean
card edges and an opaque background. Pillow confirms RGB, 3840 x 1646.
App Store Connect crop/placement preview still needs inspection after upload.

Apple specifications
https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications
Apple accepts 3840 x 1646 for the 21:9 product-page header, in PNG/JPG/JPEG,
without an alpha channel or transparency.

Apple design guidance
https://developer.apple.com/app-store/asset-best-practices/
The composition uses current UI and one central focus, consistent with
Apple's image and product-page header guidance.

Rebuild
/Users/berken/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 Marketing/2026-10-app-store-1.6.0/header/source/build_header.py
