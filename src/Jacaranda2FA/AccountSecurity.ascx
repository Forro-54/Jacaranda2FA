<%@ Control Language="C#" AutoEventWireup="false" Inherits="DotNetNuke.Entities.Modules.PortalModuleBase" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Collections.Generic" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Globalization" %>
<%@ Import Namespace="System.Security.Cryptography" %>
<%@ Import Namespace="System.Text" %>
<%@ Import Namespace="System.Web" %>
<%@ Import Namespace="System.Web.Security" %>
<%@ Import Namespace="DotNetNuke.Common.Utilities" %>
<%@ Import Namespace="DotNetNuke.Data" %>
<%@ Import Namespace="DotNetNuke.Entities.Portals" %>
<%@ Import Namespace="DotNetNuke.Entities.Users" %>
<%@ Import Namespace="DotNetNuke.Security.Roles" %>
<%@ Import Namespace="DotNetNuke.Security.Membership" %>
<%@ Import Namespace="DotNetNuke.Services.Mail" %>
<%@ Import Namespace="DotNetNuke.Services.Exceptions" %>
<%@ Import Namespace="DotNetNuke.Services.Log.EventLog" %>

<script runat="server">
    private const string Version = "00.00.31";
    private const string SettingEnabled = "Jacaranda2FA_Enabled";
    private const string SettingPolicy = "Jacaranda2FA_Policy";
    private const string SettingRoleIds = "Jacaranda2FA_RoleIds";
    private const string SettingAuditEnabled = "Jacaranda2FA_AuditEnabled";
    private const string SettingRecoveryCodeCount = "Jacaranda2FA_RecoveryCodeCount";
    private const int DefaultRecoveryCodeCount = 8;
    private const int RecoveryCodeLength = 12;
    private const string RecoveryAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private const int TotpSecretBytes = 20;
    private const int TotpDigits = 6;
    private const int TotpPeriodSeconds = 30;
    private const int TotpWindowSteps = 1;
    private const int EnrollmentMinutes = 10;
    private const string TotpPurpose = "Jacaranda2FA.TOTP";
    private const string TotpEnrollmentPurpose = "Jacaranda2FA.TOTP.Enrollment";
    private const int SecurityConfirmationMinutes = 10;

    private string EnrollmentPrefix
    {
        get
        {
            return "Jacaranda2FA:TOTPEnroll:" +
                this.PortalId.ToString(CultureInfo.InvariantCulture) + ":" +
                this.ModuleId.ToString(CultureInfo.InvariantCulture) + ":";
        }
    }

    private string EnrollmentKey(string name)
    {
        return this.EnrollmentPrefix + name;
    }

    protected override void OnLoad(EventArgs e)
    {
        base.OnLoad(e);

        this.cmdGenerateRecovery.Click += this.GenerateRecoveryCodes_Click;
        this.cmdRevokeTrustedBrowsers.Click += this.RevokeTrustedBrowsers_Click;
        this.cmdBeginAuthenticator.Click += this.BeginAuthenticator_Click;
        this.cmdConfirmAuthenticator.Click += this.ConfirmAuthenticator_Click;
        this.cmdCancelAuthenticator.Click += this.CancelAuthenticator_Click;
        this.cmdDisableAuthenticator.Click += this.DisableAuthenticator_Click;
        this.cmdConfirmSecurity.Click += this.ConfirmSecurity_Click;

        this.txtSecurityPassword.Attributes["autocomplete"] = "current-password";
        this.txtAuthenticatorConfirm.Attributes["autocomplete"] = "one-time-code";
        this.txtAuthenticatorConfirm.Attributes["inputmode"] = "numeric";
        this.txtAuthenticatorConfirm.Attributes["pattern"] = "[0-9]*";
        this.txtAuthenticatorConfirm.Attributes["maxlength"] = TotpDigits.ToString(CultureInfo.InvariantCulture);

        if (!this.IsPostBack)
        {
            this.BindAccountSecurity();
        }
    }

    protected override void OnPreRender(EventArgs e)
    {
        base.OnPreRender(e);

        UserInfo currentUser = UserController.Instance.GetCurrentUserInfo();
        if (currentUser != null && currentUser.UserID > 0 && this.HasActiveEnrollment(currentUser.UserID))
        {
            string secret = this.RestoreEnrollmentSecret(currentUser.UserID);
            if (!string.IsNullOrWhiteSpace(secret))
            {
                this.ShowAuthenticatorEnrollment(currentUser, secret);
            }
        }
    }

    private void BindAccountSecurity()
    {
        this.HideMessages();

        UserInfo currentUser = UserController.Instance.GetCurrentUserInfo();
        bool signedIn = currentUser != null && currentUser.UserID > 0;

        this.pnlSignedOut.Visible = !signedIn;
        this.pnlSecurity.Visible = signedIn;

        if (!signedIn)
        {
            return;
        }

#pragma warning disable CS0618
        bool providerEnabled = PortalController.GetPortalSettingAsBoolean(SettingEnabled, this.PortalId, false);
#pragma warning restore CS0618

        bool required = providerEnabled && this.ShouldRequireTwoFactor(currentUser);

        this.litAccountName.Text = HttpUtility.HtmlEncode(
            string.IsNullOrWhiteSpace(currentUser.DisplayName) ? currentUser.Username : currentUser.DisplayName);
        this.litUsername.Text = HttpUtility.HtmlEncode(currentUser.Username ?? string.Empty);
        this.litEmail.Text = HttpUtility.HtmlEncode(this.MaskEmail(currentUser.Email));

        if (!providerEnabled)
        {
            this.litTwoFactorStatus.Text = "<span class=\"jacaranda2fa-status-badge status-off\">Disabled for this site</span>";
            this.litPolicyStatus.Text = "Jacaranda2FA is currently disabled by the site administrator.";
        }
        else if (required)
        {
            this.litTwoFactorStatus.Text = "<span class=\"jacaranda2fa-status-badge status-on\">Required</span>";
            this.litPolicyStatus.Text = "Your account is covered by the site's Jacaranda2FA policy.";
        }
        else
        {
            this.litTwoFactorStatus.Text = "<span class=\"jacaranda2fa-status-badge status-optional\">Available</span>";
            this.litPolicyStatus.Text = "Jacaranda2FA is available, but the current site policy does not require it for your account.";
        }

        this.litEmailMethod.Text = string.IsNullOrWhiteSpace(currentUser.Email)
            ? "<span class=\"jacaranda2fa-method-state state-warning\">Unavailable</span><span>No registered email address is available for email verification.</span>"
            : "<span class=\"jacaranda2fa-method-state state-ready\">Available</span><span>Verification codes can be sent to " + HttpUtility.HtmlEncode(this.MaskEmail(currentUser.Email)) + ".</span>";

        this.RefreshSecurityConfirmationStatus(currentUser);
        this.RefreshAuthenticatorStatus(currentUser);
        this.RefreshRecoveryStatus();
        this.RefreshTrustedBrowserStatus();
    }

    private bool ShouldRequireTwoFactor(UserInfo user)
    {
#pragma warning disable CS0618
        string policy = PortalController.GetPortalSetting(SettingPolicy, this.PortalId, "All");
#pragma warning restore CS0618

        if (string.Equals(policy, "Administrators", StringComparison.OrdinalIgnoreCase))
        {
            return user.IsSuperUser || user.IsInRole(this.PortalSettings.AdministratorRoleName);
        }

        if (string.Equals(policy, "Roles", StringComparison.OrdinalIgnoreCase))
        {
            if (user.IsSuperUser)
            {
                return true;
            }

#pragma warning disable CS0618
            string selected = PortalController.GetPortalSetting(SettingRoleIds, this.PortalId, string.Empty);
#pragma warning restore CS0618
            string[] values = (selected ?? string.Empty).Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
            for (int i = 0; i < values.Length; i++)
            {
                int roleId;
                if (!int.TryParse(values[i], NumberStyles.Integer, CultureInfo.InvariantCulture, out roleId))
                {
                    continue;
                }

                RoleInfo role = RoleController.Instance.GetRoleById(this.PortalId, roleId);
                if (role != null && user.IsInRole(role.RoleName))
                {
                    return true;
                }
            }

            return false;
        }

        return true;
    }

    private string SecurityConfirmationKey(int userId)
    {
        return "Jacaranda2FA:SecurityConfirmed:" + this.PortalId.ToString(CultureInfo.InvariantCulture) + ":" + userId.ToString(CultureInfo.InvariantCulture);
    }

    private void ConfirmSecurity_Click(object sender, EventArgs e)
    {
        this.HideMessages();
        UserInfo currentUser = UserController.Instance.GetCurrentUserInfo();
        if (currentUser == null || currentUser.UserID <= 0)
        {
            this.ShowMessage("You must be signed in to confirm your security settings.", true);
            return;
        }

        string password = this.txtSecurityPassword.Text ?? string.Empty;
        this.txtSecurityPassword.Text = string.Empty;
        if (password.Length == 0)
        {
            this.ShowMessage("Enter your current DNN password to confirm sensitive security changes.", true);
            return;
        }

        UserLoginStatus status = UserLoginStatus.LOGIN_FAILURE;
        UserInfo validated = null;
        try
        {
            validated = UserController.ValidateUser(this.PortalId, currentUser.Username, password, "DNN", string.Empty, this.PortalSettings.PortalName, this.Request != null ? this.Request.UserHostAddress : string.Empty, ref status);
        }
        finally
        {
            password = string.Empty;
        }

        if (validated == null || validated.UserID != currentUser.UserID || (status != UserLoginStatus.LOGIN_SUCCESS && status != UserLoginStatus.LOGIN_SUPERUSER))
        {
            this.Session.Remove(this.SecurityConfirmationKey(currentUser.UserID));
            this.ShowMessage("The current password was not accepted. Security changes remain locked.", true);
            this.LogSecurityEvent("SecurityReauthentication", currentUser, "Failed", "Current password confirmation failed.");
            this.RefreshSecurityConfirmationStatus(currentUser);
            return;
        }

        this.Session[this.SecurityConfirmationKey(currentUser.UserID)] = DateTime.UtcNow.AddMinutes(SecurityConfirmationMinutes).Ticks;
        this.ShowMessage("Security changes are unlocked for the next " + SecurityConfirmationMinutes.ToString(CultureInfo.InvariantCulture) + " minutes.", false);
        this.LogSecurityEvent("SecurityReauthentication", currentUser, "Success", "Current password confirmed for sensitive Account Security changes.");
        this.RefreshSecurityConfirmationStatus(currentUser);
    }

    private bool IsSecurityConfirmed(int userId)
    {
        if (userId <= 0) return false;
        object value = this.Session[this.SecurityConfirmationKey(userId)];
        if (value == null) return false;
        long ticks;
        if (!long.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), NumberStyles.Integer, CultureInfo.InvariantCulture, out ticks) || ticks <= 0)
        {
            this.Session.Remove(this.SecurityConfirmationKey(userId));
            return false;
        }
        if (DateTime.UtcNow > new DateTime(ticks, DateTimeKind.Utc))
        {
            this.Session.Remove(this.SecurityConfirmationKey(userId));
            return false;
        }
        return true;
    }

    private bool RequireRecentSecurityConfirmation(UserInfo currentUser, string action)
    {
        if (currentUser != null && this.IsSecurityConfirmed(currentUser.UserID)) return true;
        this.ShowMessage("Confirm your current DNN password in the Security confirmation section before you " + action + ".", true);
        if (currentUser != null) this.RefreshSecurityConfirmationStatus(currentUser);
        return false;
    }

    private void RefreshSecurityConfirmationStatus(UserInfo currentUser)
    {
        if (currentUser == null || currentUser.UserID <= 0)
        {
            this.litSecurityConfirmationStatus.Text = string.Empty;
            return;
        }
        this.litSecurityConfirmationStatus.Text = this.IsSecurityConfirmed(currentUser.UserID)
            ? "<span class=\"jacaranda2fa-method-state state-ready\">Confirmed</span><span>Sensitive security changes are temporarily unlocked.</span>"
            : "<span class=\"jacaranda2fa-method-state state-warning\">Locked</span><span>Confirm your current password before changing authentication methods or recovery codes.</span>";
    }

    private bool HasAlternateSecondFactor(UserInfo currentUser)
    {
        if (currentUser == null || currentUser.UserID <= 0) return false;
        if (!string.IsNullOrWhiteSpace(currentUser.Email) && Mail.IsValidEmailAddress(currentUser.Email, this.PortalId)) return true;
        try
        {
            return DataProvider.Instance().ExecuteScalar<int>("Jacaranda2FA_CountRecoveryCodes", this.PortalId, currentUser.UserID) > 0;
        }
        catch (Exception ex)
        {
            Exceptions.LogException(ex);
            return false;
        }
    }

    private string ProtectEnrollmentSecret(byte[] secret, int userId)
    {
        byte[] protectedSecret = MachineKey.Protect(secret, TotpEnrollmentPurpose, this.PortalId.ToString(CultureInfo.InvariantCulture), userId.ToString(CultureInfo.InvariantCulture), this.ModuleId.ToString(CultureInfo.InvariantCulture));
        if (protectedSecret == null || protectedSecret.Length == 0) throw new InvalidOperationException("MachineKey.Protect returned no protected enrollment secret.");
        return Convert.ToBase64String(protectedSecret);
    }

    private string RestoreEnrollmentSecret(int userId)
    {
        string protectedText = Convert.ToString(this.Session[this.EnrollmentKey("ProtectedSecret")], CultureInfo.InvariantCulture);
        if (string.IsNullOrWhiteSpace(protectedText)) return string.Empty;
        try
        {
            byte[] secret = MachineKey.Unprotect(Convert.FromBase64String(protectedText), TotpEnrollmentPurpose, this.PortalId.ToString(CultureInfo.InvariantCulture), userId.ToString(CultureInfo.InvariantCulture), this.ModuleId.ToString(CultureInfo.InvariantCulture));
            return secret == null || secret.Length == 0 ? string.Empty : this.Base32Encode(secret);
        }
        catch (Exception ex)
        {
            Exceptions.LogException(ex);
            return string.Empty;
        }
    }

    private void SetSensitiveResponseNoStore()
    {
        if (this.Response == null) return;
        this.Response.Cache.SetCacheability(HttpCacheability.NoCache);
        this.Response.Cache.SetNoStore();
        this.Response.Cache.SetExpires(DateTime.UtcNow.AddYears(-1));
        this.Response.Cache.AppendCacheExtension("must-revalidate, proxy-revalidate");
    }

    private string BuildRecoveryCodesXml(IList<string> hashes, IList<string> salts)
    {
        if (hashes == null || salts == null || hashes.Count == 0 || hashes.Count != salts.Count) throw new InvalidOperationException("Recovery-code replacement requires matching hash and salt values.");
        StringBuilder xml = new StringBuilder();
        xml.Append("<codes>");
        for (int i = 0; i < hashes.Count; i++)
        {
            xml.Append("<c h=\""); xml.Append(HttpUtility.HtmlAttributeEncode(hashes[i])); xml.Append("\" s=\""); xml.Append(HttpUtility.HtmlAttributeEncode(salts[i])); xml.Append("\" />");
        }
        xml.Append("</codes>");
        return xml.ToString();
    }

    private void RefreshAuthenticatorStatus(UserInfo currentUser)
    {
        try
        {
            DateTime? enrolledUtc;
            bool enabled = this.TryGetAuthenticatorStatus(currentUser.UserID, out enrolledUtc);
            if (enabled)
            {
                string dateText = enrolledUtc.HasValue
                    ? enrolledUtc.Value.ToLocalTime().ToString("d MMM yyyy", CultureInfo.CurrentCulture)
                    : "configured";

                this.litAuthenticatorStatus.Text =
                    "<span class=\"jacaranda2fa-method-state state-ready\">Enabled</span>" +
                    "<span>Authenticator app enrolled " + HttpUtility.HtmlEncode(dateText) + ".</span>";
                this.cmdBeginAuthenticator.Text = "Replace authenticator app";
                this.cmdDisableAuthenticator.Visible = true;
            }
            else
            {
                this.litAuthenticatorStatus.Text =
                    "<span class=\"jacaranda2fa-method-state state-coming\">Not configured</span>" +
                    "<span>No authenticator app is currently enrolled.</span>";
                this.cmdBeginAuthenticator.Text = "Set up authenticator app";
                this.cmdDisableAuthenticator.Visible = false;
            }
        }
        catch (Exception ex)
        {
            Exceptions.LogException(ex);
            this.litAuthenticatorStatus.Text =
                "<span class=\"jacaranda2fa-method-state state-warning\">Unavailable</span>" +
                "<span>Authenticator storage could not be read.</span>";
            this.cmdBeginAuthenticator.Enabled = false;
            this.cmdDisableAuthenticator.Visible = false;
        }
    }

    private bool TryGetAuthenticatorStatus(int userId, out DateTime? enrolledUtc)
    {
        enrolledUtc = null;
        using (IDataReader reader = DataProvider.Instance().ExecuteReader(
            "Jacaranda2FA_GetTotpAuthenticator",
            this.PortalId,
            userId))
        {
            if (!reader.Read())
            {
                return false;
            }

            string protectedSecret = Convert.ToString(reader["ProtectedSecret"], CultureInfo.InvariantCulture);
            if (string.IsNullOrWhiteSpace(protectedSecret))
            {
                return false;
            }

            if (reader["EnrolledOnDate"] != DBNull.Value)
            {
                enrolledUtc = Convert.ToDateTime(reader["EnrolledOnDate"], CultureInfo.InvariantCulture);
                if (enrolledUtc.Value.Kind == DateTimeKind.Unspecified)
                {
                    enrolledUtc = DateTime.SpecifyKind(enrolledUtc.Value, DateTimeKind.Utc);
                }
            }

            return true;
        }
    }

    private void BeginAuthenticator_Click(object sender, EventArgs e)
    {
        this.HideMessages();

        UserInfo currentUser = UserController.Instance.GetCurrentUserInfo();
        if (currentUser == null || currentUser.UserID <= 0)
        {
            this.ShowMessage("You must be signed in to set up an authenticator app.", true);
            return;
        }

        if (!this.RequireRecentSecurityConfirmation(currentUser, "set up or replace an authenticator app"))
        {
            return;
        }

        byte[] secretBytes = new byte[TotpSecretBytes];
        using (RandomNumberGenerator rng = RandomNumberGenerator.Create())
        {
            rng.GetBytes(secretBytes);
        }

        string secret = this.Base32Encode(secretBytes);
        this.Session[this.EnrollmentKey("UserId")] = currentUser.UserID;
        this.Session[this.EnrollmentKey("ProtectedSecret")] = this.ProtectEnrollmentSecret(secretBytes, currentUser.UserID);
        this.Session[this.EnrollmentKey("StartedUtcTicks")] = DateTime.UtcNow.Ticks;

        this.ShowAuthenticatorEnrollment(currentUser, secret);
        this.ShowMessage("Scan the QR code with your authenticator app, then enter the six-digit code it shows to confirm setup.", false);
        this.LogSecurityEvent("TotpEnrollmentStarted", currentUser, "Started", "Authenticator-app enrolment started.");
    }

    private void ConfirmAuthenticator_Click(object sender, EventArgs e)
    {
        this.HideMessages();

        UserInfo currentUser = UserController.Instance.GetCurrentUserInfo();
        if (currentUser == null || currentUser.UserID <= 0 || !this.HasActiveEnrollment(currentUser.UserID))
        {
            this.ClearEnrollment();
            this.ShowMessage("Your authenticator setup session has ended. Start the setup again.", true);
            this.BindAccountSecurity();
            return;
        }

        if (!this.RequireRecentSecurityConfirmation(currentUser, "confirm an authenticator app"))
        {
            this.ClearEnrollment();
            return;
        }

        string secretText = this.RestoreEnrollmentSecret(currentUser.UserID);
        if (string.IsNullOrWhiteSpace(secretText))
        {
            this.ClearEnrollment();
            this.ShowMessage("The authenticator setup secret could not be restored. Start the setup again.", true);
            return;
        }
        string code = (this.txtAuthenticatorConfirm.Text ?? string.Empty).Trim();
        if (!this.IsSixDigitCode(code))
        {
            this.ShowMessage("Enter the six-digit code currently shown in your authenticator app.", true);
            this.ShowAuthenticatorEnrollment(currentUser, secretText);
            return;
        }

        byte[] secret;
        try
        {
            secret = this.Base32Decode(secretText);
        }
        catch
        {
            this.ClearEnrollment();
            this.ShowMessage("The authenticator setup secret could not be restored. Start the setup again.", true);
            return;
        }

        long acceptedStep;
        if (!this.TryMatchTotp(secret, code, out acceptedStep))
        {
            this.txtAuthenticatorConfirm.Text = string.Empty;
            this.ShowMessage("That authenticator code is not correct. Check that your device time is automatic and try the current code.", true);
            this.ShowAuthenticatorEnrollment(currentUser, secretText);
            this.LogSecurityEvent("TotpEnrollmentConfirmation", currentUser, "Failed", "Authenticator enrolment confirmation code did not validate.");
            return;
        }

        try
        {
            byte[] protectedSecret = MachineKey.Protect(
                secret,
                TotpPurpose,
                this.PortalId.ToString(CultureInfo.InvariantCulture),
                currentUser.UserID.ToString(CultureInfo.InvariantCulture));

            if (protectedSecret == null || protectedSecret.Length == 0)
            {
                throw new InvalidOperationException("MachineKey.Protect returned no protected data.");
            }

            DataProvider.Instance().ExecuteNonQuery(
                "Jacaranda2FA_SaveTotpAuthenticator",
                this.PortalId,
                currentUser.UserID,
                Convert.ToBase64String(protectedSecret),
                acceptedStep);

            this.ClearEnrollment();
            this.pnlAuthenticatorSetup.Visible = false;
            this.ShowMessage("Authenticator app setup completed successfully.", false);
            this.LogSecurityEvent("TotpEnrollmentCompleted", currentUser, "Success", "Authenticator app enrolled and confirmed.");
            this.RefreshAuthenticatorStatus(currentUser);
        }
        catch (Exception ex)
        {
            Exceptions.LogException(ex);
            this.ShowMessage("Jacaranda2FA could not save the authenticator setup. Check DNN Event Viewer.", true);
            this.ShowAuthenticatorEnrollment(currentUser, secretText);
        }
    }

    private void CancelAuthenticator_Click(object sender, EventArgs e)
    {
        UserInfo currentUser = UserController.Instance.GetCurrentUserInfo();
        this.ClearEnrollment();
        this.pnlAuthenticatorSetup.Visible = false;
        this.txtAuthenticatorConfirm.Text = string.Empty;
        this.ShowMessage("Authenticator setup was cancelled. Your existing security methods were not changed.", false);
        if (currentUser != null && currentUser.UserID > 0)
        {
            this.LogSecurityEvent("TotpEnrollmentCancelled", currentUser, "Cancelled", "Authenticator-app enrolment was cancelled.");
            this.RefreshAuthenticatorStatus(currentUser);
        }
    }

    private void DisableAuthenticator_Click(object sender, EventArgs e)
    {
        this.HideMessages();

        UserInfo currentUser = UserController.Instance.GetCurrentUserInfo();
        if (currentUser == null || currentUser.UserID <= 0)
        {
            this.ShowMessage("You must be signed in to remove an authenticator app.", true);
            return;
        }

        if (!this.RequireRecentSecurityConfirmation(currentUser, "remove an authenticator app"))
        {
            return;
        }

        if (this.ShouldRequireTwoFactor(currentUser) && !this.HasAlternateSecondFactor(currentUser))
        {
            this.ShowMessage("This authenticator app is currently your last usable second-factor method. Create recovery codes or add a usable registered email address before removing it.", true);
            return;
        }

        try
        {
            DataProvider.Instance().ExecuteNonQuery(
                "Jacaranda2FA_DeleteTotpAuthenticator",
                this.PortalId,
                currentUser.UserID);

            this.ClearEnrollment();
            this.ShowMessage("Authenticator app has been removed from your account.", false);
            this.LogSecurityEvent("TotpDisabled", currentUser, "Success", "Authenticator app removed from Account Security.");
            this.RefreshAuthenticatorStatus(currentUser);
        }
        catch (Exception ex)
        {
            Exceptions.LogException(ex);
            this.ShowMessage("Jacaranda2FA could not remove the authenticator app. Check DNN Event Viewer.", true);
        }
    }

    private void ShowAuthenticatorEnrollment(UserInfo currentUser, string secret)
    {
        this.SetSensitiveResponseNoStore();
        if (currentUser == null || string.IsNullOrWhiteSpace(secret))
        {
            return;
        }

        this.pnlAuthenticatorSetup.Visible = true;
        this.litManualKey.Text = HttpUtility.HtmlEncode(this.FormatBase32Secret(secret));

        string issuer = string.IsNullOrWhiteSpace(this.PortalSettings.PortalName)
            ? "DNN"
            : this.PortalSettings.PortalName.Trim();
        string account = string.IsNullOrWhiteSpace(currentUser.Username)
            ? currentUser.UserID.ToString(CultureInfo.InvariantCulture)
            : currentUser.Username;

        string label = issuer + ":" + account;
        string uri =
            "otpauth://totp/" + Uri.EscapeDataString(label) +
            "?secret=" + Uri.EscapeDataString(secret) +
            "&issuer=" + Uri.EscapeDataString(issuer) +
            "&algorithm=SHA1&digits=6&period=30";

        string elementId = this.qrContainer.ClientID;
        string script =
            "if(window.Jacaranda2FAQRCode){Jacaranda2FAQRCode.render('" +
            HttpUtility.JavaScriptStringEncode(elementId) + "','" +
            HttpUtility.JavaScriptStringEncode(uri) + "',280);}";

        this.Page.ClientScript.RegisterStartupScript(
            this.GetType(),
            "Jacaranda2FA_TOTP_QR_" + this.ModuleId.ToString(CultureInfo.InvariantCulture),
            script,
            true);
    }

    private bool HasActiveEnrollment(int userId)
    {
        if (userId <= 0)
        {
            return false;
        }

        object storedUser = this.Session[this.EnrollmentKey("UserId")];
        object secret = this.Session[this.EnrollmentKey("ProtectedSecret")];
        object started = this.Session[this.EnrollmentKey("StartedUtcTicks")];
        if (storedUser == null || secret == null || started == null)
        {
            return false;
        }

        int storedUserId = Convert.ToInt32(storedUser, CultureInfo.InvariantCulture);
        long startedTicks = Convert.ToInt64(started, CultureInfo.InvariantCulture);
        if (storedUserId != userId || startedTicks <= 0)
        {
            return false;
        }

        DateTime startedUtc = new DateTime(startedTicks, DateTimeKind.Utc);
        if (DateTime.UtcNow > startedUtc.AddMinutes(EnrollmentMinutes))
        {
            this.ClearEnrollment();
            return false;
        }

        return true;
    }

    private void ClearEnrollment()
    {
        this.Session.Remove(this.EnrollmentKey("UserId"));
        this.Session.Remove(this.EnrollmentKey("Secret")); // pre-00.00.27 cleanup
        this.Session.Remove(this.EnrollmentKey("ProtectedSecret"));
        this.Session.Remove(this.EnrollmentKey("StartedUtcTicks"));
    }

    private bool TryMatchTotp(byte[] secret, string code, out long acceptedStep)
    {
        acceptedStep = -1L;
        long currentStep = this.GetCurrentTotpStep();
        for (int offset = -TotpWindowSteps; offset <= TotpWindowSteps; offset++)
        {
            long step = currentStep + offset;
            if (step < 0)
            {
                continue;
            }

            string candidate = this.ComputeTotp(secret, step);
            if (this.FixedTimeEquals(
                Encoding.ASCII.GetBytes(candidate),
                Encoding.ASCII.GetBytes(code ?? string.Empty)))
            {
                acceptedStep = step;
                return true;
            }
        }

        return false;
    }

    private long GetCurrentTotpStep()
    {
        long unixSeconds = (long)(DateTime.UtcNow - new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc)).TotalSeconds;
        return unixSeconds / TotpPeriodSeconds;
    }

    private string ComputeTotp(byte[] secret, long step)
    {
        byte[] counter = new byte[8];
        ulong value = unchecked((ulong)step);
        for (int i = 7; i >= 0; i--)
        {
            counter[i] = (byte)(value & 0xff);
            value >>= 8;
        }

        byte[] hash;
        using (HMACSHA1 hmac = new HMACSHA1(secret))
        {
            hash = hmac.ComputeHash(counter);
        }

        int offset = hash[hash.Length - 1] & 0x0f;
        int binary =
            ((hash[offset] & 0x7f) << 24) |
            ((hash[offset + 1] & 0xff) << 16) |
            ((hash[offset + 2] & 0xff) << 8) |
            (hash[offset + 3] & 0xff);

        int otp = binary % 1000000;
        return otp.ToString("D6", CultureInfo.InvariantCulture);
    }

    private bool FixedTimeEquals(byte[] left, byte[] right)
    {
        if (left == null || right == null || left.Length != right.Length)
        {
            return false;
        }

        int difference = 0;
        for (int i = 0; i < left.Length; i++)
        {
            difference |= left[i] ^ right[i];
        }

        return difference == 0;
    }

    private bool IsSixDigitCode(string value)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length != 6)
        {
            return false;
        }

        for (int i = 0; i < value.Length; i++)
        {
            if (value[i] < '0' || value[i] > '9')
            {
                return false;
            }
        }

        return true;
    }

    private string Base32Encode(byte[] data)
    {
        if (data == null || data.Length == 0)
        {
            return string.Empty;
        }

        const string alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
        StringBuilder result = new StringBuilder((data.Length * 8 + 4) / 5);
        int buffer = data[0];
        int next = 1;
        int bitsLeft = 8;

        while (bitsLeft > 0 || next < data.Length)
        {
            if (bitsLeft < 5)
            {
                if (next < data.Length)
                {
                    buffer <<= 8;
                    buffer |= data[next++] & 0xff;
                    bitsLeft += 8;
                }
                else
                {
                    int pad = 5 - bitsLeft;
                    buffer <<= pad;
                    bitsLeft += pad;
                }
            }

            int index = (buffer >> (bitsLeft - 5)) & 0x1f;
            bitsLeft -= 5;
            result.Append(alphabet[index]);
        }

        return result.ToString();
    }

    private byte[] Base32Decode(string text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return new byte[0];
        }

        string clean = text.Trim().Replace(" ", string.Empty).Replace("-", string.Empty).ToUpperInvariant();
        List<byte> bytes = new List<byte>();
        int buffer = 0;
        int bitsLeft = 0;

        for (int i = 0; i < clean.Length; i++)
        {
            char c = clean[i];
            int value;
            if (c >= 'A' && c <= 'Z')
            {
                value = c - 'A';
            }
            else if (c >= '2' && c <= '7')
            {
                value = 26 + (c - '2');
            }
            else
            {
                throw new FormatException("Invalid Base32 character.");
            }

            buffer = (buffer << 5) | value;
            bitsLeft += 5;

            if (bitsLeft >= 8)
            {
                bytes.Add((byte)((buffer >> (bitsLeft - 8)) & 0xff));
                bitsLeft -= 8;
            }
        }

        return bytes.ToArray();
    }

    private string FormatBase32Secret(string secret)
    {
        if (string.IsNullOrWhiteSpace(secret))
        {
            return string.Empty;
        }

        StringBuilder output = new StringBuilder(secret.Length + secret.Length / 4);
        for (int i = 0; i < secret.Length; i++)
        {
            if (i > 0 && i % 4 == 0)
            {
                output.Append(' ');
            }
            output.Append(secret[i]);
        }
        return output.ToString();
    }

    private void RefreshRecoveryStatus()
    {
        UserInfo currentUser = UserController.Instance.GetCurrentUserInfo();
        if (currentUser == null || currentUser.UserID <= 0)
        {
            return;
        }

        try
        {
            int count = DataProvider.Instance().ExecuteScalar<int>(
                "Jacaranda2FA_CountRecoveryCodes",
                this.PortalId,
                currentUser.UserID);

            this.litRecoveryStatus.Text = count > 0
                ? "<strong>" + count.ToString(CultureInfo.InvariantCulture) + "</strong> unused recovery code(s) remain."
                : "No unused recovery codes currently exist.";

            this.cmdGenerateRecovery.Enabled = true;
        }
        catch (Exception ex)
        {
            Exceptions.LogException(ex);
            this.litRecoveryStatus.Text = "Recovery-code storage is temporarily unavailable.";
            this.cmdGenerateRecovery.Enabled = false;
        }
    }

    private void RefreshTrustedBrowserStatus()
    {
        UserInfo currentUser = UserController.Instance.GetCurrentUserInfo();
        if (currentUser == null || currentUser.UserID <= 0)
        {
            return;
        }

        try
        {
            int count = DataProvider.Instance().ExecuteScalar<int>(
                "Jacaranda2FA_CountTrustedBrowsers",
                this.PortalId,
                currentUser.UserID);

            this.litTrustedBrowserStatus.Text = count > 0
                ? "<strong>" + count.ToString(CultureInfo.InvariantCulture) + "</strong> trusted browser(s) are currently remembered."
                : "No trusted browsers are currently remembered.";

            this.cmdRevokeTrustedBrowsers.Enabled = count > 0;
        }
        catch (Exception ex)
        {
            Exceptions.LogException(ex);
            this.litTrustedBrowserStatus.Text = "Trusted-browser storage is temporarily unavailable.";
            this.cmdRevokeTrustedBrowsers.Enabled = false;
        }
    }

    private void GenerateRecoveryCodes_Click(object sender, EventArgs e)
    {
        this.HideMessages();

        UserInfo currentUser = UserController.Instance.GetCurrentUserInfo();
        if (currentUser == null || currentUser.UserID <= 0)
        {
            this.ShowMessage("You must be signed in to generate recovery codes.", true);
            return;
        }

        if (!this.RequireRecentSecurityConfirmation(currentUser, "generate or replace recovery codes"))
        {
            return;
        }

        int recoveryCodeCount = this.GetRecoveryCodeCount();
        List<string> plainCodes = new List<string>();
        List<string> hashes = new List<string>();
        List<string> salts = new List<string>();

        for (int i = 0; i < recoveryCodeCount; i++)
        {
            string raw = this.GenerateRecoveryCode();
            byte[] salt = new byte[16];
            using (RandomNumberGenerator rng = RandomNumberGenerator.Create())
            {
                rng.GetBytes(salt);
            }

            byte[] hash = this.HashCode(raw, salt);
            plainCodes.Add(this.FormatRecoveryCode(raw));
            hashes.Add(Convert.ToBase64String(hash));
            salts.Add(Convert.ToBase64String(salt));
        }

        try
        {
            DataProvider.Instance().ExecuteNonQuery(
                "Jacaranda2FA_ReplaceRecoveryCodes",
                this.PortalId,
                currentUser.UserID,
                this.BuildRecoveryCodesXml(hashes, salts));

            this.SetSensitiveResponseNoStore();
            StringBuilder output = new StringBuilder();
            output.Append("<div class=\"jacaranda2fa-important\"><strong>Save these codes now.</strong> They are shown only this time. Generating another set invalidates this set.</div>");
            output.Append("<pre class=\"jacaranda2fa-recovery-list\">");
            foreach (string code in plainCodes)
            {
                output.Append(HttpUtility.HtmlEncode(code));
                output.Append("\n");
            }
            output.Append("</pre>");

            this.litRecoveryCodes.Text = output.ToString();
            this.pnlRecoveryCodes.Visible = true;
            this.ShowMessage("New recovery codes were generated successfully.", false);
            this.RefreshRecoveryStatus();
            this.LogSecurityEvent("RecoveryCodesGenerated", currentUser, "Success",
                recoveryCodeCount.ToString(CultureInfo.InvariantCulture) + " recovery codes generated from Account Security.");
        }
        catch (Exception ex)
        {
            Exceptions.LogException(ex);
            this.ShowMessage("Jacaranda2FA could not save the new recovery codes. Check DNN Event Viewer.", true);
        }
    }

    private void RevokeTrustedBrowsers_Click(object sender, EventArgs e)
    {
        this.HideMessages();

        UserInfo currentUser = UserController.Instance.GetCurrentUserInfo();
        if (currentUser == null || currentUser.UserID <= 0)
        {
            this.ShowMessage("You must be signed in to revoke trusted browsers.", true);
            return;
        }

        try
        {
            DataProvider.Instance().ExecuteNonQuery(
                "Jacaranda2FA_RevokeTrustedBrowsers",
                this.PortalId,
                currentUser.UserID);

            this.ExpireCurrentTrustedBrowserCookie(currentUser.UserID);
            this.ShowMessage("All trusted browsers for your account have been revoked.", false);
            this.RefreshTrustedBrowserStatus();
            this.LogSecurityEvent("TrustedBrowsersRevoked", currentUser, "Success",
                "All trusted-browser tokens were revoked from Account Security.");
        }
        catch (Exception ex)
        {
            Exceptions.LogException(ex);
            this.ShowMessage("Jacaranda2FA could not revoke trusted browsers. Check DNN Event Viewer.", true);
        }
    }

    private int GetRecoveryCodeCount()
    {
#pragma warning disable CS0618
        string raw = PortalController.GetPortalSetting(
            SettingRecoveryCodeCount,
            this.PortalId,
            DefaultRecoveryCodeCount.ToString(CultureInfo.InvariantCulture));
#pragma warning restore CS0618

        int value;
        if (!int.TryParse(raw, NumberStyles.Integer, CultureInfo.InvariantCulture, out value))
        {
            value = DefaultRecoveryCodeCount;
        }

        if (value < 4) return 4;
        if (value > 20) return 20;
        return value;
    }

    private string GenerateRecoveryCode()
    {
        StringBuilder builder = new StringBuilder(RecoveryCodeLength);
        byte[] bytes = new byte[RecoveryCodeLength];

        using (RandomNumberGenerator rng = RandomNumberGenerator.Create())
        {
            rng.GetBytes(bytes);
        }

        for (int i = 0; i < bytes.Length; i++)
        {
            builder.Append(RecoveryAlphabet[bytes[i] & 31]);
        }

        return builder.ToString();
    }

    private string FormatRecoveryCode(string raw)
    {
        return raw.Substring(0, 4) + "-" + raw.Substring(4, 4) + "-" + raw.Substring(8, 4);
    }

    private byte[] HashCode(string code, byte[] salt)
    {
        byte[] codeBytes = Encoding.UTF8.GetBytes(code);
        byte[] input = new byte[salt.Length + codeBytes.Length];
        Buffer.BlockCopy(salt, 0, input, 0, salt.Length);
        Buffer.BlockCopy(codeBytes, 0, input, salt.Length, codeBytes.Length);

        using (SHA256 sha = SHA256.Create())
        {
            return sha.ComputeHash(input);
        }
    }

    private void ExpireCurrentTrustedBrowserCookie(int userId)
    {
        if (this.Response == null)
        {
            return;
        }

        string cookieName =
            "Jacaranda2FA.Trusted." +
            this.PortalId.ToString(CultureInfo.InvariantCulture) + "." +
            userId.ToString(CultureInfo.InvariantCulture);

        HttpCookie cookie = new HttpCookie(cookieName, string.Empty);
        cookie.HttpOnly = true;
        cookie.Secure = true;
        cookie.Path = string.IsNullOrEmpty(DotNetNuke.Common.Globals.ApplicationPath)
            ? "/"
            : DotNetNuke.Common.Globals.ApplicationPath;
        cookie.Expires = DateTime.Now.AddDays(-1);
        cookie.SameSite = SameSiteMode.Lax;
        this.Response.Cookies.Set(cookie);
    }

    private string MaskEmail(string email)
    {
        if (string.IsNullOrWhiteSpace(email) || !email.Contains("@"))
        {
            return "No registered email";
        }

        string[] parts = email.Split(new[] { '@' }, 2);
        string local = parts[0];
        string domain = parts[1];

        string maskedLocal;
        if (local.Length <= 1)
        {
            maskedLocal = "*";
        }
        else if (local.Length == 2)
        {
            maskedLocal = local.Substring(0, 1) + "*";
        }
        else
        {
            maskedLocal = local.Substring(0, 1) + new string('*', Math.Min(6, local.Length - 2)) + local.Substring(local.Length - 1);
        }

        return maskedLocal + "@" + domain;
    }

    private void HideMessages()
    {
        this.pnlMessage.Visible = false;
        this.litMessage.Text = string.Empty;
        this.pnlRecoveryCodes.Visible = false;
        this.litRecoveryCodes.Text = string.Empty;
    }

    private void ShowMessage(string message, bool isError)
    {
        this.pnlMessage.Visible = true;
        this.pnlMessage.CssClass = isError
            ? "dnnFormMessage dnnFormValidationSummary"
            : "dnnFormMessage dnnFormSuccess";
        this.litMessage.Text = HttpUtility.HtmlEncode(message ?? string.Empty);
    }

    private void LogSecurityEvent(string eventName, UserInfo user, string result, string reason)
    {
#pragma warning disable CS0618
        bool auditEnabled = PortalController.GetPortalSettingAsBoolean(SettingAuditEnabled, this.PortalId, true);
#pragma warning restore CS0618
        if (!auditEnabled)
        {
            return;
        }

        try
        {
            LogInfo log = new LogInfo();
            log.LogTypeKey = "ADMIN_ALERT";
            log.LogPortalID = this.PortalId;
            log.LogUserID = user != null && user.UserID > 0 ? user.UserID : Null.NullInteger;
            log.LogProperties.Add(new LogDetailInfo("Source", "Jacaranda2FA Account Security " + Version));
            log.LogProperties.Add(new LogDetailInfo("Event", eventName ?? string.Empty));
            log.LogProperties.Add(new LogDetailInfo("Result", result ?? string.Empty));
            log.LogProperties.Add(new LogDetailInfo("UserID", user != null && user.UserID > 0 ? user.UserID.ToString(CultureInfo.InvariantCulture) : string.Empty));
            log.LogProperties.Add(new LogDetailInfo("Username", user != null ? user.Username ?? string.Empty : string.Empty));
            log.LogProperties.Add(new LogDetailInfo("PortalID", this.PortalId.ToString(CultureInfo.InvariantCulture)));
            log.LogProperties.Add(new LogDetailInfo("UTC", DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture)));
            log.LogProperties.Add(new LogDetailInfo("Reason", reason ?? string.Empty));
            LogController.Instance.AddLog(log);
        }
        catch
        {
            // Audit logging must never interrupt account-security actions.
        }
    }
</script>

<link rel="stylesheet" type="text/css" href="<%= ResolveUrl("~/DesktopModules/Jacaranda2FA/AccountSecurity.css?v=00.00.31") %>" />
<script type="text/javascript" src="<%= ResolveUrl("~/DesktopModules/Jacaranda2FA/qrcode-local.js?v=00.00.31") %>"></script>

<div class="jacaranda2fa-account-security">
    <asp:Panel ID="pnlSignedOut" runat="server" Visible="false" CssClass="dnnFormMessage dnnFormInfo">
        You must be signed in to manage your Jacaranda2FA security settings.
    </asp:Panel>

    <asp:Panel ID="pnlSecurity" runat="server">
        <header class="jacaranda2fa-security-header">
            <div>
                <h2>Two-Factor Authentication</h2>
                <p>Manage the additional security methods attached to your DNN account.</p>
            </div>
            <div class="jacaranda2fa-version">Jacaranda2FA 00.00.31</div>
        </header>

        <asp:Panel ID="pnlMessage" runat="server" Visible="false">
            <asp:Literal ID="litMessage" runat="server" />
        </asp:Panel>

        <section class="jacaranda2fa-security-card jacaranda2fa-security-confirmation">
            <h3>Security confirmation</h3>
            <div class="jacaranda2fa-method-row"><asp:Literal ID="litSecurityConfirmationStatus" runat="server" /></div>
            <p class="jacaranda2fa-help-large">For your protection, confirm your current DNN password before replacing or removing an authenticator app or generating a new recovery-code set. Confirmation remains valid for 10 minutes and the password is not stored.</p>
            <div class="jacaranda2fa-confirm-row">
                <asp:Label ID="lblSecurityPassword" runat="server" AssociatedControlID="txtSecurityPassword" Text="Current password" />
                <asp:TextBox ID="txtSecurityPassword" runat="server" TextMode="Password" CssClass="jacaranda2fa-security-password" />
            </div>
            <div class="jacaranda2fa-button-row"><asp:Button ID="cmdConfirmSecurity" runat="server" Text="Confirm security changes" CssClass="dnnSecondaryAction" /></div>
        </section>

        <section class="jacaranda2fa-security-card">
            <h3>Your account</h3>
            <dl class="jacaranda2fa-account-summary">
                <div><dt>Name</dt><dd><asp:Literal ID="litAccountName" runat="server" /></dd></div>
                <div><dt>Username</dt><dd><asp:Literal ID="litUsername" runat="server" /></dd></div>
                <div><dt>Registered email</dt><dd><asp:Literal ID="litEmail" runat="server" /></dd></div>
                <div><dt>2FA policy</dt><dd><asp:Literal ID="litTwoFactorStatus" runat="server" /></dd></div>
            </dl>
            <p class="jacaranda2fa-help-large"><asp:Literal ID="litPolicyStatus" runat="server" /></p>
        </section>

        <div class="jacaranda2fa-security-grid">
            <section class="jacaranda2fa-security-card">
                <h3>Authenticator app</h3>
                <div class="jacaranda2fa-method-row">
                    <asp:Literal ID="litAuthenticatorStatus" runat="server" />
                </div>
                <p class="jacaranda2fa-help-large">
                    Use a standard TOTP authenticator such as Microsoft Authenticator, Google Authenticator, 1Password or another compatible app. Codes are six digits and change every 30 seconds.
                </p>

                <div class="jacaranda2fa-button-row">
                    <asp:Button ID="cmdBeginAuthenticator" runat="server"
                        Text="Set up authenticator app"
                        CssClass="dnnPrimaryAction" />
                    <asp:Button ID="cmdDisableAuthenticator" runat="server"
                        Text="Remove authenticator app"
                        CssClass="dnnSecondaryAction"
                        Visible="false"
                        OnClientClick="return confirm('Remove the authenticator app from this account? Email verification and recovery codes will remain available if configured.');" />
                </div>

                <asp:Panel ID="pnlAuthenticatorSetup" runat="server" Visible="false" CssClass="jacaranda2fa-authenticator-setup">
                    <h4>Set up your authenticator app</h4>
                    <ol class="jacaranda2fa-setup-steps">
                        <li>Open your authenticator app and choose to add or scan a new account.</li>
                        <li>Scan the QR code below. The QR code is generated locally in your browser; the secret is not sent to an external QR service.</li>
                        <li>If scanning is not available, enter the manual setup key instead.</li>
                        <li>Enter the current six-digit code from the app below to confirm the setup.</li>
                    </ol>

                    <div id="qrContainer" runat="server" class="jacaranda2fa-qr" aria-live="polite"></div>

                    <div class="jacaranda2fa-manual-key">
                        <strong>Manual setup key</strong><br />
                        <code><asp:Literal ID="litManualKey" runat="server" /></code>
                    </div>

                    <div class="jacaranda2fa-confirm-row">
                        <asp:Label ID="lblAuthenticatorConfirm" runat="server"
                            AssociatedControlID="txtAuthenticatorConfirm"
                            Text="Current six-digit code" />
                        <asp:TextBox ID="txtAuthenticatorConfirm" runat="server"
                            CssClass="jacaranda2fa-totp-input" />
                    </div>

                    <div class="jacaranda2fa-button-row">
                        <asp:Button ID="cmdConfirmAuthenticator" runat="server"
                            Text="Confirm authenticator"
                            CssClass="dnnPrimaryAction" />
                        <asp:Button ID="cmdCancelAuthenticator" runat="server"
                            Text="Cancel setup"
                            CssClass="dnnSecondaryAction" />
                    </div>
                </asp:Panel>
            </section>

            <section class="jacaranda2fa-security-card">
                <h3>Email verification</h3>
                <div class="jacaranda2fa-method-row">
                    <asp:Literal ID="litEmailMethod" runat="server" />
                </div>
                <p class="jacaranda2fa-help-large">
                    Email verification remains available as a fallback. Your normal DNN password is always required first.
                </p>
            </section>

            <section class="jacaranda2fa-security-card">
                <h3>Recovery codes</h3>
                <p><asp:Literal ID="litRecoveryStatus" runat="server" /></p>
                <p class="jacaranda2fa-help-large">
                    Recovery codes replace the second verification method in an emergency. They never replace your DNN password and each code can be used only once.
                </p>
                <asp:Button ID="cmdGenerateRecovery" runat="server"
                    Text="Generate / replace recovery codes"
                    CssClass="dnnSecondaryAction" />
                <asp:Panel ID="pnlRecoveryCodes" runat="server" Visible="false" CssClass="jacaranda2fa-generated-codes">
                    <asp:Literal ID="litRecoveryCodes" runat="server" />
                </asp:Panel>
            </section>

            <section class="jacaranda2fa-security-card">
                <h3>Trusted browsers</h3>
                <p><asp:Literal ID="litTrustedBrowserStatus" runat="server" /></p>
                <p class="jacaranda2fa-help-large">
                    A trusted browser may skip the second-factor challenge for the configured trust period, but your normal DNN username and password are still required.
                </p>
                <asp:Button ID="cmdRevokeTrustedBrowsers" runat="server"
                    Text="Revoke all trusted browsers"
                    CssClass="dnnSecondaryAction" />
            </section>
        </div>
    </asp:Panel>
</div>
