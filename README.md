# Jacaranda2FA

Jacaranda2FA is a two-factor authentication provider for **DNN Platform 10.3.2**. DNN remains responsible for normal username/password validation and final authentication. Where policy requires a second factor, Jacaranda2FA verifies a TOTP authenticator code, email OTP or one-time recovery code, with optional trusted-browser support.

## Current development version

**00.00.28**

### 00.00.28 login-form alignment cleanup

- Aligns the “Keep me signed in” checkbox directly with its label.
- Aligns the “Remember this browser for 2FA” checkbox directly with its label.
- Adds explicit checkbox dimensions and flex-row layout so DNN/theme input rules cannot make these controls difficult to see or separate them from their text.
- Associates each label with its checkbox for a larger click/tap target and better accessibility.
- Places explanatory help text cleanly beneath each checkbox row.
- Includes narrow-screen/mobile handling.
- Contains no authentication, cryptographic, policy, trusted-browser, database-schema or security-model changes from 00.00.27.

## Authentication boundary

Jacaranda2FA does **not** create DNN authentication cookies itself. DNN validates the normal username/password first. When the account requires a second factor, Jacaranda2FA completes verification before raising DNN's normal successful authentication event.

A valid trusted-browser token is evaluated only **after** DNN has accepted the normal password.

## Repository layout

- `src/Jacaranda2FA/` — DNN authentication-provider and Account Security module source/package files.
- `src/Jacaranda2FA/README-TESTING.txt` — release-specific regression and security test plan.

## Install package

The release install package is:

`Jacaranda2FA_00.00.28_Install.zip`

Install 00.00.28 as an upgrade over 00.00.27. Do not uninstall the working 00.00.27 package first.

## Testing

Use a **DNN 10.3.2 test site first** and keep a separate logged-in SuperUser session open during the initial upgrade test. Version 00.00.27 is the confirmed-working rollback baseline while 00.00.28 completes UI regression testing.
