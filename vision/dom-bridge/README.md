# DOM Bridge (Playwright persistent context)

Local service that turns **DOM selectors** into **stable bounding boxes** (viewport-relative) and text for the Vision layer. It uses **Playwright locators** with auto-wait and a **persistent browser context** so you stay logged into GitHub/private dashboards.

- Locators reference: prefer `getByRole`, `getByTestId`, etc.¹
- `locator.boundingBox()` returns `null` if not visible; the bridge auto-scrolls once.²
- Persistent auth via `launchPersistentContext(userDataDir)` keeps cookies across runs.³

## Install

```bash
cd vision/dom-bridge
cp .env.example .env
./scripts/bootstrap_dom_bridge.sh
```

### Log in once (headful)

```bash
npm run login
# Log into github.com and any other sites, then Ctrl+C to quit.
```

### Start the bridge

```bash
./scripts/start_dom_bridge.sh
npm run health
```

## API (localhost only)

### `POST /dom/locate`

Body example:

```json
{
  "app": "com.apple.Safari",
  "url_contains": "github.com",
  "seed_url": "https://github.com",
  "wait_until": "domcontentloaded",
  "timeout_ms": 8000,
  "selector": {
    "testid": "overall-checks-summary"
  }
}
```

Response:

```json
{
  "ok": true,
  "url": "https://github.com/foo/bar/pull/123/checks",
  "viewport": { "width": 1440, "height": 900 },
  "bbox": { "x": 1088.5, "y": 92.0, "width": 252.0, "height": 40.0 },
  "inner_text": "All checks have passed",
  "meta": { "app_bundle": "com.apple.Safari", "headless": true, "browser": "chromium" }
}
```

Bounding boxes are viewport-relative (Playwright semantics); `visiond` maps them to crop pixels using ScreenCaptureKit frame attachments.

### `POST /dom/text`

Same body, returns `{ "ok": true, "text": "…", "url": "…" }`.

### `GET /healthz`

Basic status plus current page URL.

## Mapping note (Vision layer)

The Swift daemon reads `SCStreamFrameInfoContentRect`, `SCStreamFrameInfoScaleFactor`, and `SCStreamFrameInfoContentScale` each frame, then transforms the viewport bbox into window pixels for deterministic cropping (mirrors Chromium’s approach).⁴

## Tips

- Prefer role/test-id locators before raw CSS/text for resilience.¹
- If `bbox` is `null`, the element isn’t visible; refine the locator or adjust scroll.
- Keep the same `USER_DATA_DIR` between headless/headful runs so authentication persists. (Playwright 1.49 introduced the new headless mode.)⁵

---
¹ [Playwright locator docs](https://playwright.dev/docs/locators)

² [Playwright API – `locator.boundingBox()`](https://playwright.dev/docs/api/class-locator#locator-bounding-box)

³ [Playwright persistent context usage](https://playwright.dev/docs/auth#persistent-context)

⁴ [Chromium ScreenCaptureKit mapping](https://chromium.googlesource.com/chromium/src.git/+/refs/heads/main/content/browser/media/capture/screen_capture_kit_device_mac.mm)

⁵ [Playwright 1.49 release notes](https://github.com/microsoft/playwright/releases/tag/v1.49.0)
