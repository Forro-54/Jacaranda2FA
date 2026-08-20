Jacaranda2FA 00.00.16 TESTING

1. Install 00.00.16 as an upgrade over the confirmed-working 00.00.15 package on the DNN 10.3.2 test site.
2. Keep DNN Normal login enabled until the upgrade and all Jacaranda2FA paths have been retested.
3. Open Jacaranda2FA settings. Confirm these defaults are shown:
   - Security audit logging: enabled.
   - Detailed diagnostics: disabled.
   - OTP lifetime: 5 minutes.
   - Maximum verification attempts: 5.
   - Maximum OTP resends: 3.
   - Resend delay: 30 seconds.
   - Trusted-browser lifetime: 30 days.
   - Maximum trusted browsers: 10.
   - Recovery codes generated: 8.
4. Save settings once and confirm a Jacaranda2FA SettingsUpdated entry appears in DNN Event Viewer.
5. Perform an ordinary successful email-OTP login. Confirm Event Viewer contains safe Jacaranda2FA audit entries for password validation, OTP sending and OTP verification.
6. Enter a wrong OTP once and confirm an OtpVerification failed event is recorded without the OTP value.
7. Test the resend button and confirm the resend success/block behaviour and audit entries.
8. Generate a new recovery-code set. Confirm the number of codes matches the configured Recovery codes generated value. Use one code and confirm the success audit event.
9. Tick Remember this browser for 2FA after successful verification. Log out and sign in again. Confirm the trusted browser still skips the second-factor step after the correct DNN password and that creation/acceptance audit events are visible.
10. Revoke all trusted browsers in Jacaranda2FA settings and confirm the revocation event is recorded.
11. Change one security value at a time (for example OTP lifetime to 6 minutes or trusted-browser lifetime to 7 days), save, and confirm the login UI/behaviour reflects the saved value.
12. Test a value outside the documented range (for example OTP lifetime 999). Save and reopen settings; it should be clamped to the maximum allowed value rather than accepted as entered.
13. Enable Detailed diagnostics only for troubleshooting and verify additional Diagnostic events appear. Turn it back off after the test.
14. Re-test the previously confirmed policy cases: ordinary user, Registered Users, Administrators and SuperUsers.
15. Confirm no Event Viewer Jacaranda2FA entry contains passwords, OTP values, recovery codes, full email addresses, trusted-browser token values/hashes, or session identifiers.

Rollback note:
00.00.16 does not alter the recovery-code or trusted-browser table schemas. It recreates the trusted-browser add procedure with a configurable token-limit parameter. Keep the 00.00.15 installer/source as the known prior baseline until 00.00.16 is fully accepted.
