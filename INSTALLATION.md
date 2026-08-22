# Installing Jacaranda2FA 01.00.00

## Before you begin

Jacaranda2FA 01.00.00 is the first public test release. Test it on a staging or
non-production DNN site before relying on it for production authentication.

It has been tested on DNN Platform 10.3.2 and 10.3.3.

Before installation:

1. Back up the DNN site and database using your normal process.
2. Confirm the site's configured SMTP/email service can send mail.
3. Keep a logged-in SuperUser browser session available during first-time setup.

## Fresh installation

1. Open **Settings > Extensions** in DNN.
2. Install `Jacaranda2FA_01.00.00_Install.zip`.
3. Confirm installation completes without manifest or SQL errors.
4. Open the authentication-provider settings.
5. Enable **Jacaranda2FA**.
6. Leave **DNN Normal Login** enabled for the initial test.
7. Open a private/incognito browser window.
8. Test a normal registered account.
9. Test a SuperUser account.
10. Configure and test an authenticator app.
11. Generate and securely store recovery codes.
12. Test email fallback.
13. Test trusted-browser creation and revocation.
14. Review DNN Event Viewer.

## Making Jacaranda2FA the enforced login route

Jacaranda2FA cannot impose 2FA on a login that goes through another independent
authentication provider.

If DNN Normal Login or another provider remains enabled, users may be able to
choose that provider and authenticate without Jacaranda2FA.

Before disabling alternative providers:

- keep an existing SuperUser session open;
- prove SuperUser login works through Jacaranda2FA in another browser;
- confirm the SuperUser has a usable second factor;
- retain unused recovery codes.

Only then disable the alternative provider and test again.

## Account Security module

The installer also registers **Jacaranda2FA Account Security** as a DNN module.
Place it on an appropriate authenticated-user page if users should manage:

- authenticator-app enrolment;
- recovery codes;
- trusted-browser revocation;
- current 2FA status.

Use normal DNN page/module permissions.

## Upgrade from 00.00.31

Install 01.00.00 directly over 00.00.31. Do not uninstall 00.00.31 first.

01.00.00 contains no new SQL migration relative to 00.00.31.

## DNN 10.3.3

The confirmed 00.00.31 baseline was tested successfully after upgrading a virgin
DNN site from 10.3.2 to 10.3.3. Version 01.00.00 uses the same runtime security
logic and retains a minimum DNN CoreVersion dependency of 10.03.02.

## Rollback

Keep the previously working package and a normal DNN backup until public testing
is complete. A security extension should never be the site's only recovery plan.
