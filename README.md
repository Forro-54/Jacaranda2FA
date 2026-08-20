# Jacaranda2FA

Jacaranda2FA is a two-factor authentication provider for **DNN Platform 10.3.2**.

Current development version: **00.00.15**. Confirmed-working baseline before these changes: **00.00.14**.

## 00.00.15 features

- DNN performs the normal username/password validation.
- Policy can require the second factor for **All users**, **Administrators/SuperUsers**, or **Selected roles**.
- Email OTP remains six digits, five-minute lifetime, five attempts, three resends, 30-second resend delay.
- Eight one-time recovery codes can be generated for the signed-in administrator's own account.
- **Remember this browser for 2FA** creates a 30-day trusted-browser token after a successful email OTP or recovery-code verification.
- A trusted browser still requires the correct DNN password; it only skips the Jacaranda2FA email/recovery-code step.
- Trusted-browser tokens are random 256-bit values. Only SHA-256 hashes are stored in the database.
- Trusted-browser cookies are HttpOnly, SameSite=Lax, and Secure when the request uses HTTPS.
- The signed-in account can revoke all of its trusted-browser tokens from Jacaranda2FA settings.

## Sign-in persistence vs trusted browser

The login page now uses two deliberately separate concepts:

- **Keep me signed in** — DNN's own persistent authentication cookie. Explicit logout clears this DNN login.
- **Remember this browser for 2FA** — Jacaranda2FA trusted-browser token. It survives normal logout and can skip the second-factor step for 30 days after DNN validates the password.

## Enforcement model

Jacaranda2FA can act as the only DNN login provider. Accounts covered by the selected policy receive second-factor verification; accounts outside the policy pass through after successful DNN password validation.

**Important:** while DNN's Normal login provider remains enabled, users can choose it and bypass Jacaranda2FA. Keep Normal login enabled during testing. Only disable it after email OTP, recovery codes, trusted-browser behaviour and SuperUser access are all proven on the test site.

## Repository layout

- `src/Jacaranda2FA/` — provider source, manifest and SQL scripts.
- `build/Build-Install.ps1` — creates the DNN install ZIP.
- `dist/` — generated installers; ignored by Git except for `.gitkeep`.

## Build installer

```powershell
.\build\Build-Install.ps1
```

Output:

```text
dist/Jacaranda2FA_00.00.15_Install.zip
```

## Security notes

Jacaranda2FA never stores the user's DNN password and does not create the `.DOTNETNUKE` authentication cookie itself. DNN owns password validation and final authenticated login. Email OTP secrets are session-scoped salted hashes; recovery codes are high-entropy one-time values stored only as salted hashes; trusted-browser raw tokens exist only in the browser and are stored server-side only as SHA-256 hashes.

Do not commit a DNN website, database, live `web.config`, SMTP credentials, machine keys or other secrets to this repository.
