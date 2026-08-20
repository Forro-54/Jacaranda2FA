Jacaranda2FA 00.00.20 TESTING

1. Install 00.00.20 as an upgrade over the confirmed-working 00.00.16 package on the DNN 10.3.2 test site.
2. Open Jacaranda2FA settings and confirm there is approximately 10px of space between the left settings border and the Jacaranda2FA text/controls.
3. Confirm the settings page still fits correctly at desktop and narrow/mobile widths.
4. Save settings once and confirm the existing 00.00.16 security settings remain unchanged.
5. Perform one email-OTP login and one trusted-browser login to confirm authentication behaviour is unchanged.

Rollback note:
00.00.20 is a CSS/layout maintenance release only. It makes no database changes and retains the 00.00.16 SQL baseline for fresh installs.

00.00.20 UI: Security/audit settings use a two-column responsive grid on wider screens with compact 85px numeric fields. No authentication logic changed.
