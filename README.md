# Jacaranda2FA

**Jacaranda2FA 01.00.00 — First Public Test Release**

Jacaranda2FA is a community two-factor authentication extension for **DNN Platform**.
It keeps DNN responsible for normal username/password validation and final
authentication, while adding a second verification stage when policy requires it.

## Tested compatibility

01.00.00 has been tested successfully on:

- **DNN Platform 10.3.2**
- **DNN Platform 10.3.3**
- the stock/default DNN skin
- a production-style Bootstrap 5 custom skin
- Microsoft Authenticator
- Google Authenticator

## Features

- TOTP authenticator-app verification
- email one-time verification codes
- one-time recovery codes
- trusted/remembered browsers
- role-based enforcement policies
- persistent cross-challenge second-factor throttling
- TOTP replay protection
- security audit logging
- configurable OTP, resend, trusted-browser and recovery-code controls
- Account Security module for authenticator, recovery-code and trusted-browser management
- responsive login and verification controls

## Authentication boundary

Jacaranda2FA does **not** replace DNN's password system and does not create the
DNN authentication cookie directly.

1. DNN validates the username and password.
2. Jacaranda2FA determines whether a second factor is required.
3. Jacaranda2FA verifies the configured second factor.
4. Jacaranda2FA hands successful authentication back to DNN.
5. DNN completes the normal login.

A trusted-browser token is considered only **after DNN has accepted the password**.

## Important enforcement note

Jacaranda2FA can enforce 2FA only for authentication paths that pass through
Jacaranda2FA.

If **DNN Normal Login** or another independent authentication provider remains
enabled, that provider may offer a separate login route that does not invoke
Jacaranda2FA.

Before disabling alternative authentication providers, confirm that a SuperUser
can successfully authenticate through Jacaranda2FA and has a usable authenticator,
email fallback or unused recovery code. Keep a logged-in SuperUser session open
during initial enforcement testing.

## Email fallback

Email OTP is provided as a practical fallback. An authenticator app plus securely
stored recovery codes is recommended for higher-assurance accounts.

## Installation

Install `Jacaranda2FA_01.00.00_Install.zip` through DNN Extensions.

For a fresh installation, enable Jacaranda2FA while leaving DNN Normal Login
enabled for the first test. Verify Jacaranda2FA with a normal user and a SuperUser
before deciding whether to disable other authentication providers.

See `INSTALLATION.md` and `PUBLIC-TESTING.md`.

## Upgrade from development versions

01.00.00 is promoted directly from the confirmed-working **00.00.31** development
baseline. Install 01.00.00 as an upgrade; do not uninstall the working extension first.

There is **no new database migration in 01.00.00**.

## Security

The 00.00.27 hardening cycle added persistent second-factor throttling, stricter
challenge expiry, recent password confirmation for sensitive Account Security
changes, protected temporary TOTP enrolment state, no-store handling for one-time
secrets, transactional recovery-code replacement and HTTPS-only trusted-browser issuance.

For suspected vulnerabilities, see `SECURITY.md`.

## Repository layout

- `src/Jacaranda2FA/` — DNN provider and Account Security module source/package files
- `INSTALLATION.md` — installation, upgrade and enforcement guidance
- `PUBLIC-TESTING.md` — recommended public-test matrix
- `SECURITY.md` — private security-reporting guidance
- `CHANGELOG.md` — release history

## Status

01.00.00 is a **public test release**. Validate it in test/staging before production
deployment and retain normal DNN backup and recovery procedures.

## Licence

MIT License.

Copyright (c) 2026 Forrest IT Services
