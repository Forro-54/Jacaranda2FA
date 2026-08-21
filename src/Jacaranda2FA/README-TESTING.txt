Jacaranda2FA 00.00.31 TESTING
===============================

Purpose
-------
Correct the stock DNN 10.3.2 popup/mobile min-width rule that defeated the
00.00.30 max-width limits.

Upgrade
-------
Install 00.00.31 directly over 00.00.30. No new SQL migration is included.

Visual checks on virgin/default DNN 10.3.2
------------------------------------------
1. Username/password:
   - should no longer span the page;
   - maximum width about 460px on wide layouts.

2. Authenticator/email verification:
   - code field should be compact, maximum 14rem.

3. Recovery code:
   - maximum 18rem.

4. Checkboxes:
   - one visible checkbox only for each option;
   - label alignment retained.

Functional regression
---------------------
- Microsoft Authenticator login succeeds.
- Google Authenticator login succeeds.
- Email fallback succeeds.
- Recovery-code login succeeds.
- Trusted-browser behaviour remains unchanged.
- Jacaranda2FA still works with DNN Normal authentication disabled.

Rollback
--------
00.00.28 remains the last fully confirmed working master until this UI correction
is confirmed in runtime testing.
