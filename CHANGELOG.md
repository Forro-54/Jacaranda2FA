# Changelog

## 00.00.31

- UI-only correction for the DNN 10.3.2 popup/mobile login form.
- Identified DNN's `min-width:100% !important` rule as the reason 00.00.30 maximum widths had no visible effect.
- Explicitly resets `min-width:0 !important` on Jacaranda2FA credential, OTP/TOTP and recovery-code inputs.
- Adds exact overrides for `dnnFormPopupMobileView`.
- Retains all checkbox normalisation/alignment fixes.
- No authentication, security-model, cryptographic, policy, or database-schema changes.
- No new SQL migration.

## 00.00.30

- UI-only width-hardening release for the stock DNN 10.3.2 full-width skin.
- Username/password controls now have a forced responsive maximum width of 460px.
- Authenticator/email-code controls now have a forced maximum width of 14rem.
- Recovery-code entry now has a forced maximum width of 18rem.
- Added inline `!important` field constraints plus stronger stock-DNN CSS fallback selectors.
- Retains the 00.00.29 duplicate-checkbox normalisation and 00.00.28 checkbox alignment.
- No authentication, security-model, cryptographic, policy, or database-schema changes.
- No new SQL migration.

## 00.00.29

- UI-only/default-skin housekeeping release based on the confirmed-working 00.00.28 baseline.
- Constrained username and password fields to a responsive 460px maximum width for DNN skins with full-width content panes.
- Fixed duplicate visual checkboxes caused by DNN's `dnnCheckbox()` JavaScript wrapping the same native checkbox that 00.00.28 deliberately made visible.
- Marked the native inputs as `normalCheckBox` so DNN leaves them as ordinary accessible checkboxes.
- Retained the 00.00.28 flex alignment, label association and help-text positioning.
- Added a defensive CSS fallback for an already-injected DNN checkbox wrapper.
- No authentication, security-model, cryptographic, database-schema or policy changes.
- No new SQL migration.

## 00.00.28

- UI-only login-form alignment and accessibility cleanup based on the confirmed-working 00.00.27 security-hardened baseline.
- Reworked “Keep me signed in” so its checkbox sits visibly and directly beside its label.
- Reworked “Remember this browser for 2FA” the same way on the verification screen.
- Added explicit 20px checkbox dimensions, flex alignment and theme/DNN float/width overrides.
- Associated both text labels with their checkbox controls to improve click/tap targeting.
- Moved explanatory help text beneath each checkbox/label pair with consistent indentation.
- Added narrow-screen handling.
- No authentication, security-model, cryptographic, database-schema or policy changes.
- No new SQL migration.

## 00.00.27

- Security-hardening release based on the 00.00.26 source audit.
- Added persistent cross-challenge second-factor throttling: ten failed TOTP/email/recovery verifications within 15 minutes trigger a 15-minute cooldown.
- Prevented email fallback/resend from extending an expired password-valid challenge or resetting the verification-attempt counter.
- Added recent current-password confirmation for authenticator setup/replacement/removal and recovery-code replacement in Account Security.
- Protected temporary TOTP enrolment secrets in Session with ASP.NET MachineKey protection.
- Added explicit no-store/no-cache handling for TOTP enrolment material and newly displayed recovery codes.
- Added transactional recovery-code set replacement.
- Trusted-browser tokens are now created only over HTTPS and all trusted-browser cookies are Secure.
- Prevented policy-covered users from removing their final usable second-factor method.
- Generalised the enforcement warning to all alternate DNN authentication providers.
- Added `00.00.27.SqlDataProvider` and matching uninstall cleanup.
- No changes to DNN password validation, TOTP algorithm, stored TOTP secret protection, trusted-token entropy/hashing, role-policy evaluation, or final DNN login hand-off.

## 00.00.26

- Fixed invalid TOTP attempts dropping back to the initial login screen.
- Added verification-stage flash messages that survive DNN's authentication-provider rebuild.
- Applied the same retry-safe behaviour to email OTP, recovery-code, and resend messages.
- No database or cryptographic changes.

## 00.00.25

- Fixed the installer manifest reference to the TOTP SQL migration.
- The package now correctly references `00.00.23.SqlDataProvider`, where TOTP database support was introduced.
- Retains the authenticator-to-email fallback state-transition fix from the rejected 00.00.24 package.
- No database schema or security-model changes.

## 00.00.24

- Fixed the authenticator-to-email fallback returning to the initial login screen.
- Added a clean verification-stage redirect after fallback email delivery.
- Corrected the post-redirect message when an email code is active.
- Clears stale authenticator textbox content when switching methods.
- No security-model or database changes.

## 00.00.23

- Added TOTP authenticator-app enrolment and login verification.
- Added locally generated QR enrolment and manual Base32 setup key.
- Added protected TOTP secret storage using ASP.NET MachineKey protection.
- Added atomic TOTP replay protection with last-accepted time-step tracking.
- Added authenticator-first login with email fallback.
- Added authenticator enable/replace/remove controls to Account Security.
- Retained email OTP, recovery codes, trusted browsers, audit logging and policy enforcement.

## 00.00.22

- Fixed the DNN module manifest that caused the 00.00.21 installer to be rejected.
- Added the required `<moduleDefinitions>` container.
- Removed the invalid `definitionName` element.
- Added standard empty `businessControllerClass` and `supportedFeatures` elements.
- Aligned module-control metadata and element order with DNN 10.3.2 module manifests.
- Changed the combined manifest format to 6.0.
- No runtime authentication/security changes.

## 00.00.21

- Added the Jacaranda2FA Account Security DNN module.
- Added user self-service recovery-code generation/replacement.
- Added user self-service trusted-browser count and revoke-all action.
- Added user-facing 2FA policy and masked-email status.
- Added an Authenticator App placeholder section for the next TOTP development stage.
- No changes to the working password/email OTP/recovery/trusted-browser login flow.

## 00.00.20

- Kept the proven single-column card layout for security and audit settings.
- Increased timeout/range/help text to 18px with 1.55 line height and full contrast for improved accessibility.
- Increased numeric security-setting values to 18px while retaining compact 85px inputs.
- No authentication or security behaviour changes.

## 00.00.19

- Reworked Security and audit settings into a responsive two-column layout on wider screens.
- Reduced numeric timeout/count fields to a compact 85px width.
- Added automatic single-column fallback below 900px.
- Retained 10px settings-panel padding and CSS cache-busting.
- No authentication, OTP, recovery-code, trusted-browser, database or policy logic changes.

## 00.00.18

- Fixed Jacaranda2FA settings-panel spacing shown in the DNN Site Settings popup.
- Applied 10px horizontal padding directly to the settings wrapper so the fix does not depend on an updated external stylesheet being loaded.
- Added a version query to the Login.css reference to force browsers/DNN to fetch updated CSS after future UI releases.
- No authentication or security logic changes.

## 00.00.17

- Added 10px left padding to the Jacaranda2FA settings panel.
- Improved settings-page readability without changing authentication or security logic.

## 00.00.16

- Added structured Jacaranda2FA security audit logging to DNN Event Viewer.
- Added optional detailed diagnostic logging, disabled by default.
- Added configurable OTP lifetime, verification attempts, resend count and resend delay.
- Added configurable trusted-browser lifetime and per-user trusted-browser limit.
- Added configurable recovery-code set size.
- Added safe numeric ranges and server-side clamping.
- Updated trusted-browser SQL procedure to honour the configured active-token limit.
- Preserved 00.00.15 authentication defaults and security boundary.

## 00.00.15

- Added genuine trusted-browser support for 2FA.
- Separated DNN persistent sign-in from Jacaranda2FA trusted-browser behaviour.
- Added trusted-browser revocation.

## 00.00.14

- Added role-based second-factor policy.
- Added one-time recovery codes.

## 00.00.13

- Completed the clean Jacaranda2FA package/provider identity rename.
