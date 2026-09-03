Jacaranda2FA 01.00.04 TESTING
===============================

Purpose
-------
Restore the trusted-browser behaviour that worked in 01.00.00 while retaining
the 01.00.01 Other Login Options layout.

Upgrade
-------
Install 01.00.04 directly over 01.00.03. No new SQL migration is included.

Required tests
--------------

A. Authenticator app
1. Sign in with valid DNN username/password.
2. Tick Remember this browser for 2FA.
3. Enter a valid authenticator code.
4. Log out.
5. Sign in again with the correct password.
6. EXPECTED: no second-factor prompt.

B. Email OTP
1. Start a new challenge.
2. Tick Remember this browser for 2FA.
3. Choose Email me a code instead.
4. Verify the email code.
5. Log out.
6. Sign in again with the correct password.
7. EXPECTED: no second-factor prompt.

C. Recovery code
1. Start a new challenge.
2. Tick Remember this browser for 2FA.
3. Expand Other Login Options.
4. Use a valid unused recovery code.
5. Log out.
6. Sign in again with the correct password.
7. EXPECTED: no second-factor prompt.

Negative test
-------------
Repeat each path without selecting Remember this browser for 2FA.
EXPECTED: the next password-valid login still requires a second factor.

Regression
----------
- Trusted-browser revoke/delete works.
- Other Login Options remains collapsed initially for authenticator users.
- Email workflow reopens Other Login Options correctly.
- Microsoft Authenticator works.
- Google Authenticator works.
- DNN Normal Login can remain disabled with Jacaranda2FA as sole provider.

Test on DNN 10.3.2 and DNN 10.3.3 where available.
