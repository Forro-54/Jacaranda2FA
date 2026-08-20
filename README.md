# Jacaranda2FA

Jacaranda2FA is an email-based two-factor authentication provider for DNN Platform 10.3.2. It keeps DNN responsible for password validation and final authentication, then adds policy-controlled email OTP verification, recovery codes and trusted-browser support.

## Current development version

**00.00.16**

### 00.00.16 features

- Security audit events in DNN Event Viewer.
- Optional detailed diagnostic logging for troubleshooting.
- Portal-specific OTP lifetime, verification-attempt, resend and resend-delay settings.
- Configurable trusted-browser lifetime and per-user active token limit.
- Configurable recovery-code set size.
- All numeric security values are constrained to documented safe ranges.
- Existing 00.00.15 defaults and authentication behaviour are preserved unless settings are changed.
- Audit entries never store authentication secrets.

## Authentication boundary

Jacaranda2FA does not create DNN authentication cookies itself. DNN validates the normal username/password first. When the account requires a second factor, Jacaranda2FA completes OTP/recovery/trusted-browser checks before raising DNN's normal successful authentication event.

## Repository layout

- `src/Jacaranda2FA/` — DNN authentication provider source/package files.
- `build/Build-Install.ps1` — builds the DNN install ZIP.
- `dist/` — generated install packages (ignored by Git).

## Build

From PowerShell in the repository root:

```powershell
.\build\Build-Install.ps1
```

The generated package is written to:

`dist\Jacaranda2FA_00.00.16_Install.zip`

## Testing

See `src/Jacaranda2FA/README-TESTING.txt`.

Use a DNN 10.3.2 test site first and keep the standard DNN login provider available until Jacaranda2FA has been verified end-to-end.
