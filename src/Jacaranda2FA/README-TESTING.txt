Jacaranda2FA 00.00.28 TESTING
===============================

Purpose
-------
00.00.28 is a UI-only login-form alignment/accessibility cleanup based on the confirmed-working 00.00.27 security-hardening release.

Upgrade test
------------
- Install 00.00.28 over 00.00.27 without uninstalling 00.00.27.
- EXPECTED: no new SQL migration is required.
- EXPECTED: Jacaranda2FA remains enabled and existing authenticator, recovery-code and trusted-browser data remain intact.

Login-page visual tests
-----------------------
1. Initial Jacaranda2FA login screen:
   - “Keep me signed in” checkbox is visible.
   - Checkbox sits immediately to the left of the label text.
   - Label text is vertically aligned with the checkbox.
   - Explanatory text sits below the checkbox/label line.

2. 2FA verification screen:
   - “Remember this browser for 2FA” checkbox is visible.
   - Checkbox sits immediately to the left of the label text.
   - Label text is vertically aligned with the checkbox.
   - Explanatory text sits below the checkbox/label line.

3. Repeat the visual checks at desktop and narrow/mobile widths.

Functional regression
---------------------
- Normal password + authenticator login succeeds.
- Email fallback succeeds.
- Recovery-code login succeeds.
- “Keep me signed in” still controls DNN persistent sign-in.
- “Remember this browser for 2FA” still creates a trusted-browser record only after successful 2FA and only over HTTPS.
- Existing trusted-browser revocation continues to work.
- Jacaranda2FA still works with DNN Normal authentication disabled.

Rollback
--------
00.00.27 is the confirmed-working rollback baseline if an unexpected DNN/theme rendering problem appears.
