# Jacaranda2FA 01.00.00 Public Testing

Thank you for testing Jacaranda2FA.

This is the first public test release. Reports from different DNN installations,
skins, SMTP environments and authentication policies are especially useful.

## Environment information to include with feedback

- DNN Platform version
- Windows Server / IIS version if relevant
- SQL Server version if relevant
- DNN skin/theme
- fresh install or upgrade
- authentication providers enabled
- mail provider/SMTP type (without credentials)
- browser and device
- affected account type

## Core login tests

- correct username/password + Microsoft Authenticator
- correct username/password + Google Authenticator
- wrong authenticator code followed by correct code
- email OTP
- wrong email OTP followed by correct code
- resend email code
- one-time recovery code
- reused recovery code rejected
- trusted browser remembered
- trusted browser revoked
- logout and login again

## Policy tests

- all users
- Administrators and SuperUsers
- selected roles
- account outside selected policy passes through correctly

## Enforcement test

With a known-good logged-in SuperUser session retained:

1. disable DNN Normal Login;
2. confirm a normal registered user can sign in through Jacaranda2FA;
3. confirm a SuperUser can sign in through Jacaranda2FA;
4. confirm no unintended alternate login route remains.

## Account Security tests

- enrol authenticator
- confirm enrolment with current authenticator code
- replace authenticator
- remove authenticator when another usable method remains
- generate new recovery codes
- old recovery codes stop working
- revoke trusted browsers
- sensitive changes require recent password confirmation

## UI tests

- stock/default DNN skin
- custom skin
- desktop
- narrow/mobile
- username/password fields remain contained
- authenticator/email/recovery fields remain contained
- “Keep me signed in” displays one checkbox
- “Remember this browser for 2FA” displays one checkbox
- checkbox label alignment and click/tap behaviour

## Failure tests

- incorrect password
- expired verification challenge
- repeated incorrect second-factor codes
- persistent second-factor cooldown
- SMTP failure
- Event Viewer contains useful information without secrets

## Security reports

Please report exploitable security problems privately rather than publishing full
details in a public issue. See `SECURITY.md`.
