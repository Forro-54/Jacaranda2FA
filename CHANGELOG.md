# Changelog

## 00.00.20

- Kept the proven single-column card layout for security and audit settings.
- Increased timeout/range/help text to 18px with 1.55 line height and full contrast for improved accessibility.
- Increased numeric security-setting values to 18px while retaining compact 85px inputs.
- No authentication or security behaviour changes.

## 00.00.19

- Reworked Security and audit settings into a responsive two-column layout on wider screens.
- Reduced numeric timeout/count fields to a compact 85px width.
- Added automatic single-column fallback below 900px.
- Retained 10px settings-panel padding and CSS cache-busting.
- No authentication, OTP, recovery-code, trusted-browser, database or policy logic changes.

## 00.00.18

- Fixed Jacaranda2FA settings-panel spacing shown in the DNN Site Settings popup.
- Applied 10px horizontal padding directly to the settings wrapper so the fix does not depend on an updated external stylesheet being loaded.
- Added a version query to the Login.css reference to force browsers/DNN to fetch updated CSS after future UI releases.
- No authentication or security logic changes.

## 00.00.17

- Added 10px left padding to the Jacaranda2FA settings panel.
- Improved settings-page readability without changing authentication or security logic.

## 00.00.16

- Added structured Jacaranda2FA security audit logging to DNN Event Viewer.
- Added optional detailed diagnostic logging, disabled by default.
- Added configurable OTP lifetime, verification attempts, resend count and resend delay.
- Added configurable trusted-browser lifetime and per-user trusted-browser limit.
- Added configurable recovery-code set size.
- Added safe numeric ranges and server-side clamping.
- Updated trusted-browser SQL procedure to honour the configured active-token limit.
- Preserved 00.00.15 authentication defaults and security boundary.

## 00.00.15

- Added genuine trusted-browser support for 2FA.
- Separated DNN persistent sign-in from Jacaranda2FA trusted-browser behaviour.
- Added trusted-browser revocation.

## 00.00.14

- Added role-based second-factor policy.
- Added one-time recovery codes.

## 00.00.13

- Completed the clean Jacaranda2FA package/provider identity rename.
