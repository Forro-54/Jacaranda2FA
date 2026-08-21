Jacaranda2FA 00.00.27 TESTING

IMPORTANT
- Test on a non-production DNN 10.3.2 site first.
- Keep a separate logged-in SuperUser session open while testing the upgrade.
- 00.00.26 is the confirmed-working rollback baseline.

1. UPGRADE / DATABASE
- Install 00.00.27 over 00.00.26 without uninstalling 00.00.26.
- EXPECTED: DNN installs 00.00.27.SqlDataProvider successfully.
- EXPECTED: existing authenticator, recovery-code and trusted-browser data remains intact.

2. NORMAL AUTHENTICATOR LOGIN
- Sign in with a user that has a TOTP authenticator enrolled.
- Enter the correct DNN password and current authenticator code.
- EXPECTED: login succeeds normally.

3. EMAIL FALLBACK / EXPIRY
- Start a TOTP login and choose email fallback.
- EXPECTED: email code is sent and the verification stage remains active.
- Resend within the configured delay; EXPECTED: delay warning.
- Confirm the original password-valid challenge is not extended by fallback/resend.
- After the challenge expires, try email fallback/resend.
- EXPECTED: Jacaranda2FA requires a fresh password login instead of issuing a renewed challenge.

4. PERSISTENT CROSS-CHALLENGE THROTTLE
- Use a test account and enter valid-format but incorrect second-factor codes.
- The existing per-challenge limit should still end each challenge as configured.
- Continue with fresh password-valid challenges until ten total failed second-factor verifications occur within 15 minutes.
- EXPECTED: Jacaranda2FA blocks further second-factor challenges for approximately 15 minutes.
- EXPECTED: the block remains when a new browser session/login challenge is started.
- After a successful second factor (before reaching the block), EXPECTED: the persistent failure record is cleared.

5. ACCOUNT SECURITY REAUTHENTICATION
- Open the Jacaranda2FA Account Security module as a normal registered user and as a SuperUser.
- Without confirming the current password, try to:
  * set up/replace an authenticator,
  * remove an authenticator,
  * generate/replace recovery codes.
- EXPECTED: each sensitive action is refused and asks for security confirmation.
- Enter the current DNN password in Security confirmation.
- EXPECTED: sensitive changes are unlocked for 10 minutes.
- EXPECTED: the password field is cleared and the password is not displayed/stored by the module.

6. AUTHENTICATOR ENROLMENT
- After security confirmation, start authenticator setup.
- EXPECTED: QR/manual key appears and setup works as before.
- Confirm with the current six-digit app code.
- EXPECTED: authenticator is saved and login works.

7. LAST-FACTOR PROTECTION
- On a policy-covered test account, arrange for the authenticator to be the only usable second-factor method.
- Try to remove it.
- EXPECTED: removal is refused until a usable registered email or recovery code exists.

8. RECOVERY-CODE REPLACEMENT
- Confirm security, then generate a new recovery-code set.
- EXPECTED: the new set is shown once and replaces the old set atomically.
- Confirm an old code no longer works and a new code works once.
- Also test recovery-code generation from the authentication-provider Settings page; EXPECTED: current DNN password is required.

9. TRUSTED BROWSERS / HTTPS
- On HTTPS, complete a second factor and choose Remember this browser for 2FA.
- EXPECTED: trusted-browser login continues to work.
- EXPECTED: cookie is HttpOnly, SameSite=Lax and Secure.
- On plain HTTP (test only), EXPECTED: login can complete but a trusted-browser token is not issued.
- Revoke trusted browsers and confirm the browser must perform 2FA again.

10. REGRESSION
- SuperUser authenticator login.
- Registered-user authenticator login.
- Email OTP success and retry handling.
- Recovery-code success and one-time consumption.
- Trusted-browser creation, use and revocation.
- Role/administrator/all-user policy behaviour.
- Jacaranda2FA as sole authentication provider with DNN Normal disabled.
- Invalid TOTP/email/recovery code remains on verification stage until limits are reached.
