# Jacaranda2FA 01.00.00 — First Public Test Release

Jacaranda2FA 01.00.00 is the first public testing release of the Jacaranda2FA
two-factor authentication provider for DNN Platform.

## Tested

- DNN Platform 10.3.2
- DNN Platform 10.3.3
- Microsoft Authenticator
- Google Authenticator
- email OTP fallback
- one-time recovery codes
- trusted browsers
- stock DNN skin
- custom Bootstrap 5 skin
- normal registered users
- SuperUsers
- Jacaranda2FA as the sole enabled login provider

## Highlights

- TOTP authenticator-app support
- email verification fallback
- one-time recovery codes
- trusted-browser support
- role-based enforcement
- persistent second-factor throttling
- TOTP replay protection
- security audit logging
- Account Security self-service module
- responsive DNN 10.3.x login UI

## Important public-test note

Test it in staging before production use and keep a logged-in SuperUser session
available during first-time authentication-provider configuration.

Jacaranda2FA can enforce 2FA only for logins that pass through Jacaranda2FA.
DNN Normal Login or another independently enabled provider may offer a separate
route that does not invoke Jacaranda2FA.

## Upgrade

01.00.00 is promoted from the confirmed-working 00.00.31 baseline. Install it as
an upgrade; do not uninstall the working package first.

There is no new database migration in 01.00.00.

## Feedback and security

General testing feedback is welcome.

Report suspected exploitable security issues privately to
webmaster@forrestitservices.org rather than posting full exploit details publicly.

## Licence

MIT
