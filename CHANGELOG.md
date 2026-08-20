# Changelog

## 00.00.15

- Added a genuine 30-day **Remember this browser for 2FA** feature.
- Trusted browsers still require successful DNN password validation before bypassing the email/recovery-code second factor.
- Added cryptographically random 256-bit trusted-browser tokens; only SHA-256 token hashes are stored in the database.
- Added HttpOnly, SameSite=Lax trusted-browser cookies, marked Secure on HTTPS.
- Added trusted-browser database storage, validation, expiry, counting and revocation procedures.
- Added a settings action to revoke all trusted browsers for the signed-in account.
- Renamed the existing DNN persistence checkbox from **Remember me** to **Keep me signed in** so its purpose is distinct from 2FA browser trust.
- Preserved 00.00.14 role policy, recovery-code and email OTP behaviour.

## 00.00.14

- Added second-factor policy for all users, administrators/SuperUsers, or selected DNN roles.
- Added one-time recovery-code generation and verification.
- Added DNN SQL install/uninstall scripts for recovery-code storage.
- Added safe pass-through after DNN password validation for users outside the selected policy.
- Preserved 00.00.13 behaviour by defaulting policy to All users.
- Added explicit warning that Normal DNN login bypasses Jacaranda2FA enforcement while it remains enabled.

## 00.00.13

- Confirmed working on DNN Platform 10.3.2 test site.
- Completed full internal and visible rename to Jacaranda2FA.
- Authentication type: `Jacaranda2FA`.
- Package identity: `ForrestITServices.Jacaranda2FA`.
- Install directory: `DesktopModules/AuthenticationServices/Jacaranda2FA/`.
- Portal setting: `Jacaranda2FA_Enabled`.
- Preserves the working password -> email OTP -> verification -> DNN login flow.
