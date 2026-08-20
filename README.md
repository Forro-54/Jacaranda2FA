# Jacaranda2FA

Jacaranda2FA is an email-based two-factor authentication provider for DNN Platform 10.3.2. It keeps DNN responsible for password validation and final authentication, then adds policy-controlled email OTP verification, recovery codes and trusted-browser support.

## Current development version

**00.00.20**

### 00.00.20 changes

- Reworks Security and audit settings into a responsive two-column layout on wider screens.
- Uses compact 85px numeric fields for timeout/count values.
- Collapses to a single column below 900px for smaller screens.
- Retains 10px settings-panel padding and versioned CSS cache-busting.
- No authentication or security logic changes.

- Applies 10px horizontal padding directly to the Jacaranda2FA settings wrapper so fieldset headings, wrapped help text and controls no longer sit against the DNN panel border.
- Adds a versioned stylesheet URL (`Login.css?v=00.00.20`) to prevent stale browser/DNN CSS caching after UI upgrades.
- No authentication, OTP, recovery-code, trusted-browser or security-policy logic has changed.

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

`dist\Jacaranda2FA_00.00.20_Install.zip`

## Testing

See `src/Jacaranda2FA/README-TESTING.txt`.

Use a DNN 10.3.2 test site first and keep the standard DNN login provider available until Jacaranda2FA has been verified end-to-end.
