Jacaranda2FA 00.00.15 TESTING

1. Install as an upgrade over 00.00.14 or as a fresh install on a DNN 10.3.2 test site.
2. Keep DNN Normal login enabled during initial testing.
3. Confirm ordinary email OTP login still works with "Remember this browser for 2FA" left unchecked.
4. Start another Jacaranda2FA login, enter the email OTP, tick "Remember this browser for 2FA", and complete login.
5. Log out normally. The trusted-browser cookie is intentionally not the DNN authentication cookie and should survive logout.
6. Sign in again through Jacaranda2FA with the same user on the same browser. After the correct DNN password, the email/recovery-code step should be skipped.
7. Test a different browser/private window. It should still require the second factor.
8. Wait is not required for expiry testing; use Jacaranda2FA settings while signed in and choose "Revoke all my trusted browsers". After logout, the next Jacaranda2FA login should require the second factor again.
9. Confirm "Keep me signed in" remains independent. It controls DNN's persistent authentication cookie; explicit logout clears DNN's login cookie but does not revoke a Jacaranda2FA trusted browser.
10. Confirm recovery-code login still works and that ticking "Remember this browser for 2FA" after a recovery-code login also establishes trust.
11. Test Administrator/SuperUser and ordinary/Registered User accounts under the policies already confirmed in 00.00.14.
12. Only after all tests pass should you consider disabling DNN Normal login to make Jacaranda2FA policy enforcement non-bypassable.

Security note:
A trusted-browser token never replaces the DNN password. Jacaranda2FA checks it only after DNN has successfully validated the user's password. The raw trusted token is not stored in the database.
