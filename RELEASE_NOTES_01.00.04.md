# Jacaranda2FA 01.00.04 — Trusted Browser Regression Correction

01.00.04 fixes the trusted-browser regression introduced by the 01.00.01
verification-screen state refactor.

The original 01.00.00 release successfully determined trusted-browser intent
directly from the visible checkbox and its raw posted form field. Later UI-state
work replaced that proven path with Session-based state.

01.00.04 restores direct checkbox-post detection as the primary source of truth
for all successful second-factor paths:

- authenticator app
- email OTP
- recovery code

The hidden preference field remains only to carry a selected trust preference
through the clean authenticator-to-email redirect.

No trusted-browser cryptography, cookie security, database schema, TOTP, email
OTP, recovery-code, throttling or policy logic has changed.
