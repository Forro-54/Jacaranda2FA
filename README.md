# Jacaranda2FA

Jacaranda2FA is a two-factor authentication provider for **DNN Platform 10.3.2**. DNN remains responsible for normal username/password validation and final authentication. Where policy requires a second factor, Jacaranda2FA verifies a TOTP authenticator code, email OTP or one-time recovery code, with optional trusted-browser support.

## Current development version

**00.00.31**

### 00.00.31 DNN popup/mobile field-width correction

- Fixes the stock DNN 10.3.2 `dnnFormPopupMobileView` rule that forced login fields to `min-width:100% !important`.
- Explicitly resets Jacaranda2FA login/2FA field `min-width` to zero so the intended responsive maximum widths can take effect.
- Retains 460px username/password, 14rem OTP/TOTP and 18rem recovery-code maximum widths.
- Retains the duplicate-checkbox and alignment fixes.
- No authentication, security-model, cryptographic, policy or database-schema changes.
## Authentication boundary

Jacaranda2FA does **not** create DNN authentication cookies itself. DNN validates the normal username/password first. When the account requires a second factor, Jacaranda2FA completes verification before raising DNN's normal successful authentication event.

A valid trusted-browser token is evaluated only **after** DNN has accepted the normal password.

## Repository layout

- `src/Jacaranda2FA/` — DNN authentication-provider and Account Security module source/package files.
- `src/Jacaranda2FA/README-TESTING.txt` — release-specific regression and security test plan.

## Install package

The release install package is:

`Jacaranda2FA_00.00.31_Install.zip`

Install 00.00.30 as an upgrade over 00.00.29. Do not uninstall the working package first.

## Testing

Use a **DNN 10.3.2 test site first** and keep a separate logged-in SuperUser session open during the initial upgrade test. Version 00.00.28 is the confirmed-working rollback baseline while 00.00.29 completes default-skin UI regression testing.
