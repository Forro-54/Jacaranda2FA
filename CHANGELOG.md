# Changelog

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
