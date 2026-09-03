# Security Policy

## Public test release

Jacaranda2FA 01.00.00 is the first public test release.

Security reports are welcome and should be handled privately until the issue can
be investigated and, where necessary, corrected.

## Reporting a vulnerability

Please email:

**webmaster@forrestitservices.org**

Include:

- Jacaranda2FA version
- DNN Platform version
- concise description
- reproduction steps
- expected and actual behaviour
- sanitised Event Viewer information where useful

Please do **not** send passwords, TOTP secrets, recovery codes, trusted-browser
tokens, machine keys, database connection strings, SMTP credentials, or unrelated
private user data.

Please do not publish working exploit details before the maintainer has had a
reasonable opportunity to investigate.

## Security boundary

Jacaranda2FA controls only authentication routes that pass through its provider.
An independently enabled authentication provider may bypass Jacaranda2FA's second
factor. Administrators should review all enabled DNN authentication providers
before treating Jacaranda2FA as mandatory 2FA.

## Supported public-test release

Current public-test release: **01.00.04**

Tested on DNN Platform 10.3.2 and 10.3.3.
