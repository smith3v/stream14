# App and test-runner icons

Created 2026-11-05 using the built-in image generation tool. Final project assets:

- `Stream14/Assets.xcassets/AppIcon.appiconset/AppIcon.png`: opaque 1024×1024 teal camera/14 icon, compiled by Xcode's app-icon asset catalog.
- `Tools/TestRunnerIcon/Icon.png`: opaque 1024×1024 purple flask/UI icon. The shared scheme's build post-action creates native 120/180-pixel icons, sets the separate UI runner's icon metadata/display name (`s14 UI Tests`), and signs the modified built wrapper using the configured normal development identity. Provisioning and entitlements are preserved. No Xcode installation files are modified.

Unit tests are hosted in Stream14.app, so there is no second unit-test application. Every future separately installed test app needs a distinct generated icon before installation. `test-without-building` must use an already branded/signed runner. The branding script is test-only; the production app uses the standard asset catalog.

Generated sources were square/opaque and normalized mechanically to required native icon sizes using macOS `sips`. Visual design/editing used the built-in image tool, not a CLI/API fallback. No outer corner mask is baked in; iOS applies its normal mask.

## Prompt set

Main icon:

> Create a single simple iPhone app icon for stream14, a local camera recording app with a web scoreboard overlay. Square 1024x1024, full bleed opaque deep teal background, centered bold white minimal camera outline, a small coral-red record dot and a crisp small '14' integrated inside the camera body. Flat vector-like graphic, strong silhouette readable at tiny home-screen size, balanced generous padding. No gradients, no shadows, no photographic elements, no rounded outer mask or border, no mockup. Only text is 14. Production app icon asset.

Test icon generation:

> Generate one simple iPhone TEST RUNNER app icon, visually distinct from a teal camera app. Square 1024x1024 full bleed opaque vivid purple background. Centered bold white laboratory flask outline, small bright yellow bubble, and large crisp white text UI beneath or inside the flask. Flat minimal vector-like graphic, instantly readable at small iPhone home-screen size, generous spacing, no gradients, no shadows, no outer rounded mask, no border, no photographic detail. Only text is UI. This is a unique test application icon, not the main camera app.

Final test-icon edit:

> Edit this purple test-app icon. Preserve the purple full-bleed opaque square background, white flask outline, yellow bubbles, and flat simple style. Replace the words TEST RUNNER with only the two large white letters UI centered beneath the flask, readable at tiny home-screen size. No other text. Keep a generous safe margin, no outer rounded corners or border.
