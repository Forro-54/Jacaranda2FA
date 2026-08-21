Jacaranda2FA 00.00.26 TESTING

PRIMARY FIX
1. Use an account with Google Authenticator (or another TOTP app) enrolled.
2. Start a Jacaranda2FA login and enter the correct DNN username/password.
3. Enter an intentionally incorrect six-digit authenticator code.
4. EXPECTED: the page returns to the Jacaranda2FA verification stage, not the initial login screen.
5. EXPECTED: the authenticator input is still available.
6. EXPECTED: an error says the code is not valid and shows the remaining attempt count.
7. Enter the current correct authenticator code.
8. EXPECTED: login completes normally.

REGRESSION TESTS
- Switch to "Email me a code instead"; confirm the email panel remains active.
- Enter one intentionally wrong email OTP; confirm Jacaranda2FA remains on the email verification stage.
- Enter the correct email OTP and confirm login.
- Enter one intentionally invalid recovery code; confirm Jacaranda2FA remains on the verification stage.
- Test email resend before the delay has elapsed; confirm the warning remains on the verification stage.
- Confirm normal authenticator, recovery-code, and trusted-browser success paths still work.

LOCKOUT
After the configured maximum failed attempts, Jacaranda2FA intentionally clears the challenge
and requires the user to sign in again with the normal DNN password.
