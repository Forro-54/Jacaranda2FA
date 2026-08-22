Jacaranda2FA 01.00.00 — PUBLIC TESTING GUIDE
================================================

Status
------
01.00.00 is the first public test release of Jacaranda2FA.

Supported/tested DNN versions
-----------------------------
- DNN Platform 10.3.2
- DNN Platform 10.3.3

Before installation
-------------------
1. Use a test or staging site first.
2. Confirm DNN email/SMTP delivery works before depending on email OTP.
3. Keep an existing logged-in SuperUser session open during initial setup.
4. Back up the site and database using your normal DNN maintenance procedure.

Fresh installation
------------------
1. Install Jacaranda2FA_01.00.00_Install.zip through DNN Extensions.
2. Enable the Jacaranda2FA authentication provider.
3. Initially leave DNN Normal Login enabled.
4. Log out in a separate/private browser and test Jacaranda2FA.
5. Test a normal registered user.
6. Test a SuperUser.
7. Enrol an authenticator app and confirm a current code.
8. Generate recovery codes and store them securely.
9. Test email fallback.
10. Test trusted-browser creation and revocation.
11. Review DNN Event Viewer for hidden exceptions.

Mandatory 2FA enforcement
-------------------------
Jacaranda2FA only controls logins that pass through its authentication provider.
DNN Normal Login or another enabled authentication provider may provide an
independent route that bypasses Jacaranda2FA.

Before disabling alternative providers:
- confirm SuperUser login works through Jacaranda2FA;
- confirm a usable second factor exists;
- retain unused recovery codes;
- keep a logged-in SuperUser session open until testing is complete.

Recommended public-test checks
------------------------------
- Correct and incorrect passwords.
- Microsoft Authenticator.
- Google Authenticator.
- Incorrect authenticator code followed by a correct retry.
- Email OTP and resend.
- Incorrect email OTP followed by a correct retry.
- Recovery code works once only.
- Recovery-code replacement.
- Trusted-browser creation, use and revoke-all.
- 2FA policy for all users, privileged users and selected roles.
- Account Security authenticator setup/replacement/removal.
- DNN Normal Login disabled: registered-user and SuperUser login.
- Default DNN skin and any production skin.
- Desktop and mobile/narrow widths.
- DNN Event Viewer after each major scenario.

Security reporting
------------------
Please do not publish exploitable security details in a public issue before the
maintainer has had a reasonable opportunity to investigate.

Report suspected security vulnerabilities privately to:
webmaster@forrestitservices.org

Include the Jacaranda2FA version, DNN version, reproduction steps and relevant
sanitised Event Viewer information. Do not send passwords, authenticator secrets,
recovery codes, trusted-browser tokens, machine keys or database credentials.

Licence
-------
MIT License. See license.txt.
