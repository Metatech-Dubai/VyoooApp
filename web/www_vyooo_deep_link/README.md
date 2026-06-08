# Vyooo profile / reel deep links (Universal Links + App Links)

Goal: sharing a profile produces one clean, Instagram-style HTTPS link
(`https://www.vyooo.com/u/<username>`) that:

1. opens the **app directly** when installed (verified Universal Link / App Link), or
2. opens this **web bridge** which launches the app via `vyooo://` or sends the
   user to the store.

The Flutter app already builds these links (`lib/core/config/deep_link_config.dart`)
and parses inbound ones (`lib/core/services/deep_link_service.dart`). The only
remaining work is **hosting these files on `www.vyooo.com` (and `vyooo.com`)**.

> ⚠️ `www.vyooo.com` is currently a Vercel marketing SPA that returns
> `index.html` for unknown paths. As verified on 2026‑06, it serves the SPA HTML
> for `/.well-known/apple-app-site-association` (breaking iOS) and for `/open`.
> The files below must be deployed so they take precedence over the SPA
> catch‑all.

## Files

| File | Deploy to | Notes |
|---|---|---|
| `.well-known/apple-app-site-association` | `https://www.vyooo.com/.well-known/...` and `https://vyooo.com/.well-known/...` | Must be served as **`application/json`**, status **200**, **no redirect**, scoped to `/u/*`, `/r/*`, `/open*`. |
| `.well-known/assetlinks.json` | both hosts | `sha256_cert_fingerprints` **must include the Play App Signing SHA‑256** (Play Console → Test and release → App integrity → App signing). Verify the two values here against it; remove any that don't belong. |
| `open/index.html` | served for `/u/:username`, `/r/:id`, and `/open` | The redirect bridge. |
| `vercel.json` | Vercel project root | Sets JSON content-type for `.well-known/*` and rewrites `/u/:username` + `/r/:id` to the bridge. Merge into the marketing site's existing config. |

## iOS checklist

- `ios/Runner/Runner.entitlements` already declares
  `applinks:www.vyooo.com` and `applinks:vyooo.com`. ✅
- Confirm the Associated Domains capability is enabled on the App ID in the
  Apple Developer portal for the provisioning profile.
- `appIDs` in the AASA is `BTBWJXR552.com.vyooo` (Team ID + bundle id). Confirm the
  Team ID matches the team that owns `com.vyooo`.
- Validate: https://branch.io/resources/aasa-validator or
  `curl -I https://www.vyooo.com/.well-known/apple-app-site-association`
  → expect `200` + `content-type: application/json`.

## Android checklist

- `android/app/src/main/AndroidManifest.xml` has a single `autoVerify="true"`
  HTTPS intent-filter scoped to `/u/`, `/r/`, `/open` on both hosts. ✅
- Verify: `https://developers.google.com/digital-asset-links/tools/generator`
  or after install: `adb shell pm get-app-links com.vyooo` → state `verified`.

## Verify the end-to-end flow

1. Deploy the files above.
2. iOS: paste `https://www.vyooo.com/u/<username>` into Notes, long-press → it
   should offer "Open in Vyooo".
3. Android: tap the link from any app → app opens to the profile.
4. App not installed: link opens `open/index.html`, which falls back to the store.
