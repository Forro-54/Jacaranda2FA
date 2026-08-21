# Jacaranda2FA

Jacaranda2FA is a two-factor authentication provider for **DNN Platform 10.3.2**. DNN remains responsible for normal username/password validation and final authentication. Where policy requires a second factor, Jacaranda2FA verifies a TOTP authenticator code, email OTP or one-time recovery code, with optional trusted-browser support.

## Current development version

**00.00.27**

### 00.00.27 security hardening

- Adds persistent cross-challenge second-factor throttling: 10 failed second-factor verifications within 15 minutes trigger a 15-minute cooldown.
- Prevents email fallback/resend from renewing an expired password-valid challenge or resetting failed-attempt counts.
- Requires recent current-password confirmation before sensitive Account Security changes.
- Protects temporary TOTP enrolment secrets in Session with ASP.NET MachineKey.
- Adds explicit no-store handling while TOTP enrolment secrets or fresh recovery codes are displayed.
- Replaces recovery-code sets transactionally.
- Requires HTTPS before creating trusted-browser tokens and forces Secure cookies.
- Prevents removal of the last usable second factor for a policy-covered account.
- Generalises the warning about alternate authentication providers bypassing Jacaranda2FA enforcement.
- Adds `00.00.27.SqlDataProvider` for the new throttle and transactional recovery replacement.

## Authentication boundary

Jacaranda2FA does **not** create DNN authentication cookies itself. DNN validates the normal username/password first. When the account requires a second factor, Jacaranda2FA completes verification before raising DNN's normal successful authentication event.

A valid trusted-browser token is evaluated only **after** DNN has accepted the normal password.

## Repository layout

- `src/Jacaranda2FA/` — DNN authentication-provider and Account Security module source/package files.
- `src/Jacaranda2FA/README-TESTING.txt` — release-specific regression and security test plan.

## Install package

The release install package is:

`Jacaranda2FA_00.00.27_Install.zip`

Install 00.00.27 as an upgrade over 00.00.26. Do not uninstall the working 00.00.26 package first.

## Testing

Use a **DNN 10.3.2 test site first** and keep a separate logged-in SuperUser session open during the initial upgrade test. Version 00.00.26 remains the confirmed-working rollback baseline until 00.00.27 completes regression testing.
