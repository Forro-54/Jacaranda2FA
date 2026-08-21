<%@ Control Language="C#" AutoEventWireup="false" Inherits="DotNetNuke.Services.Authentication.AuthenticationSettingsBase" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Collections.Generic" %>
<%@ Import Namespace="System.Globalization" %>
<%@ Import Namespace="System.Security.Cryptography" %>
<%@ Import Namespace="System.Text" %>
<%@ Import Namespace="System.Web" %>
<%@ Import Namespace="DotNetNuke.Common.Utilities" %>
<%@ Import Namespace="DotNetNuke.Data" %>
<%@ Import Namespace="DotNetNuke.Entities.Portals" %>
<%@ Import Namespace="DotNetNuke.Entities.Users" %>
<%@ Import Namespace="DotNetNuke.Security.Roles" %>
<%@ Import Namespace="DotNetNuke.Security.Membership" %>
<%@ Import Namespace="DotNetNuke.Services.Exceptions" %>
<%@ Import Namespace="DotNetNuke.Services.Log.EventLog" %>

<script runat="server">
    private const string Version = "00.00.27";
    private const string SettingEnabled = "Jacaranda2FA_Enabled";
    private const string SettingPolicy = "Jacaranda2FA_Policy";
    private const string SettingRoleIds = "Jacaranda2FA_RoleIds";
    private const string SettingAuditEnabled = "Jacaranda2FA_AuditEnabled";
    private const string SettingDiagnosticLogging = "Jacaranda2FA_DiagnosticLogging";
    private const string SettingCodeLifetimeMinutes = "Jacaranda2FA_CodeLifetimeMinutes";
    private const string SettingMaxCodeAttempts = "Jacaranda2FA_MaxCodeAttempts";
    private const string SettingMaxResends = "Jacaranda2FA_MaxResends";
    private const string SettingResendWaitSeconds = "Jacaranda2FA_ResendWaitSeconds";
    private const string SettingTrustedBrowserDays = "Jacaranda2FA_TrustedBrowserDays";
    private const string SettingMaxTrustedBrowsers = "Jacaranda2FA_MaxTrustedBrowsers";
    private const string SettingRecoveryCodeCount = "Jacaranda2FA_RecoveryCodeCount";
    private const int DefaultCodeLifetimeMinutes = 5;
    private const int DefaultMaxCodeAttempts = 5;
    private const int DefaultMaxResends = 3;
    private const int DefaultResendWaitSeconds = 30;
    private const int DefaultTrustedBrowserDays = 30;
    private const int DefaultMaxTrustedBrowsers = 10;
    private const int DefaultRecoveryCodeCount = 8;
    private const int RecoveryCodeLength = 12;
    private const string RecoveryAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

    protected override void OnInit(EventArgs e)
    {
        base.OnInit(e);
        // Recreate role list items early on every request so ASP.NET can restore ViewState
        // and posted checkbox selections correctly.
        this.PopulateRoles();
    }

    protected override void OnLoad(EventArgs e)
    {
        base.OnLoad(e);
        this.cmdGenerateRecovery.Click += this.GenerateRecoveryCodes_Click;
        this.cmdRevokeTrustedBrowsers.Click += this.RevokeTrustedBrowsers_Click;
        this.txtRecoveryPassword.Attributes["autocomplete"] = "current-password";

        if (!this.IsPostBack)
        {
            this.LoadSettings();
            this.ApplySavedRoleSelections();
            this.RefreshRecoveryStatus();
            this.RefreshTrustedBrowserStatus();
        }
    }

    private void LoadSettings()
    {
#pragma warning disable CS0618
        this.chkEnabled.Checked = PortalController.GetPortalSettingAsBoolean(SettingEnabled, this.PortalId, false);
        this.chkAuditEnabled.Checked = PortalController.GetPortalSettingAsBoolean(SettingAuditEnabled, this.PortalId, true);
        this.chkDiagnosticLogging.Checked = PortalController.GetPortalSettingAsBoolean(SettingDiagnosticLogging, this.PortalId, false);
        string policy = PortalController.GetPortalSetting(SettingPolicy, this.PortalId, "All");
#pragma warning restore CS0618

        this.txtCodeLifetimeMinutes.Text = this.GetIntPortalSetting(SettingCodeLifetimeMinutes, DefaultCodeLifetimeMinutes, 2, 15).ToString(CultureInfo.InvariantCulture);
        this.txtMaxCodeAttempts.Text = this.GetIntPortalSetting(SettingMaxCodeAttempts, DefaultMaxCodeAttempts, 3, 10).ToString(CultureInfo.InvariantCulture);
        this.txtMaxResends.Text = this.GetIntPortalSetting(SettingMaxResends, DefaultMaxResends, 0, 5).ToString(CultureInfo.InvariantCulture);
        this.txtResendWaitSeconds.Text = this.GetIntPortalSetting(SettingResendWaitSeconds, DefaultResendWaitSeconds, 15, 300).ToString(CultureInfo.InvariantCulture);
        this.txtTrustedBrowserDays.Text = this.GetIntPortalSetting(SettingTrustedBrowserDays, DefaultTrustedBrowserDays, 1, 90).ToString(CultureInfo.InvariantCulture);
        this.txtMaxTrustedBrowsers.Text = this.GetIntPortalSetting(SettingMaxTrustedBrowsers, DefaultMaxTrustedBrowsers, 1, 20).ToString(CultureInfo.InvariantCulture);
        this.txtRecoveryCodeCount.Text = this.GetIntPortalSetting(SettingRecoveryCodeCount, DefaultRecoveryCodeCount, 4, 20).ToString(CultureInfo.InvariantCulture);

        if (this.ddlPolicy.Items.FindByValue(policy) != null)
        {
            this.ddlPolicy.SelectedValue = policy;
        }
        else
        {
            this.ddlPolicy.SelectedValue = "All";
        }

    }

    private void PopulateRoles()
    {
        this.cblRoles.Items.Clear();
        foreach (RoleInfo role in RoleController.Instance.GetRoles(this.PortalId))
        {
            if (role == null || role.RoleID < 0 || string.IsNullOrWhiteSpace(role.RoleName))
            {
                continue;
            }

            this.cblRoles.Items.Add(new System.Web.UI.WebControls.ListItem(role.RoleName, role.RoleID.ToString(CultureInfo.InvariantCulture)));
        }
    }

    private void ApplySavedRoleSelections()
    {
#pragma warning disable CS0618
        string saved = PortalController.GetPortalSetting(SettingRoleIds, this.PortalId, string.Empty);
#pragma warning restore CS0618
        HashSet<string> selected = new HashSet<string>((saved ?? string.Empty).Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries), StringComparer.OrdinalIgnoreCase);
        foreach (System.Web.UI.WebControls.ListItem item in this.cblRoles.Items)
        {
            item.Selected = selected.Contains(item.Value);
        }
    }

    public override void UpdateSettings()
    {
        int codeLifetime = this.ParseBoundedInt(this.txtCodeLifetimeMinutes.Text, DefaultCodeLifetimeMinutes, 2, 15);
        int maxAttempts = this.ParseBoundedInt(this.txtMaxCodeAttempts.Text, DefaultMaxCodeAttempts, 3, 10);
        int maxResends = this.ParseBoundedInt(this.txtMaxResends.Text, DefaultMaxResends, 0, 5);
        int resendWait = this.ParseBoundedInt(this.txtResendWaitSeconds.Text, DefaultResendWaitSeconds, 15, 300);
        int trustedDays = this.ParseBoundedInt(this.txtTrustedBrowserDays.Text, DefaultTrustedBrowserDays, 1, 90);
        int maxTrusted = this.ParseBoundedInt(this.txtMaxTrustedBrowsers.Text, DefaultMaxTrustedBrowsers, 1, 20);
        int recoveryCount = this.ParseBoundedInt(this.txtRecoveryCodeCount.Text, DefaultRecoveryCodeCount, 4, 20);

        PortalController.UpdatePortalSetting(this.PortalId, SettingEnabled, this.chkEnabled.Checked.ToString());
        PortalController.UpdatePortalSetting(this.PortalId, SettingPolicy, this.ddlPolicy.SelectedValue);
        PortalController.UpdatePortalSetting(this.PortalId, SettingAuditEnabled, this.chkAuditEnabled.Checked.ToString());
        PortalController.UpdatePortalSetting(this.PortalId, SettingDiagnosticLogging, this.chkDiagnosticLogging.Checked.ToString());
        PortalController.UpdatePortalSetting(this.PortalId, SettingCodeLifetimeMinutes, codeLifetime.ToString(CultureInfo.InvariantCulture));
        PortalController.UpdatePortalSetting(this.PortalId, SettingMaxCodeAttempts, maxAttempts.ToString(CultureInfo.InvariantCulture));
        PortalController.UpdatePortalSetting(this.PortalId, SettingMaxResends, maxResends.ToString(CultureInfo.InvariantCulture));
        PortalController.UpdatePortalSetting(this.PortalId, SettingResendWaitSeconds, resendWait.ToString(CultureInfo.InvariantCulture));
        PortalController.UpdatePortalSetting(this.PortalId, SettingTrustedBrowserDays, trustedDays.ToString(CultureInfo.InvariantCulture));
        PortalController.UpdatePortalSetting(this.PortalId, SettingMaxTrustedBrowsers, maxTrusted.ToString(CultureInfo.InvariantCulture));
        PortalController.UpdatePortalSetting(this.PortalId, SettingRecoveryCodeCount, recoveryCount.ToString(CultureInfo.InvariantCulture));

        List<string> selected = new List<string>();
        foreach (System.Web.UI.WebControls.ListItem item in this.cblRoles.Items)
        {
            if (item.Selected)
            {
                selected.Add(item.Value);
            }
        }
        PortalController.UpdatePortalSetting(this.PortalId, SettingRoleIds, string.Join(",", selected.ToArray()));

        // Echo clamped values back to the controls so an out-of-range entry is visibly corrected.
        this.txtCodeLifetimeMinutes.Text = codeLifetime.ToString(CultureInfo.InvariantCulture);
        this.txtMaxCodeAttempts.Text = maxAttempts.ToString(CultureInfo.InvariantCulture);
        this.txtMaxResends.Text = maxResends.ToString(CultureInfo.InvariantCulture);
        this.txtResendWaitSeconds.Text = resendWait.ToString(CultureInfo.InvariantCulture);
        this.txtTrustedBrowserDays.Text = trustedDays.ToString(CultureInfo.InvariantCulture);
        this.txtMaxTrustedBrowsers.Text = maxTrusted.ToString(CultureInfo.InvariantCulture);
        this.txtRecoveryCodeCount.Text = recoveryCount.ToString(CultureInfo.InvariantCulture);

        if (this.chkAuditEnabled.Checked)
        {
            UserInfo currentUser = UserController.Instance.GetCurrentUserInfo();
            this.LogSecurityEvent(
                "SettingsUpdated",
                currentUser,
                "Success",
                "Jacaranda2FA policy/security settings were saved.");
        }
    }

    private int GetIntPortalSetting(string settingName, int defaultValue, int minimum, int maximum)
    {
#pragma warning disable CS0618
        string raw = PortalController.GetPortalSetting(settingName, this.PortalId, defaultValue.ToString(CultureInfo.InvariantCulture));
#pragma warning restore CS0618
        return this.ParseBoundedInt(raw, defaultValue, minimum, maximum);
    }

    private int ParseBoundedInt(string raw, int defaultValue, int minimum, int maximum)
    {
        int value;
        if (!int.TryParse(raw, NumberStyles.Integer, CultureInfo.InvariantCulture, out value))
        {
            value = defaultValue;
        }

        if (value < minimum)
        {
            return minimum;
        }
        if (value > maximum)
        {
            return maximum;
        }
        return value;
    }

    private void GenerateRecoveryCodes_Click(object sender, EventArgs e)
    {
        this.recoveryMessage.Visible = false;
        this.litRecoveryCodes.Text = string.Empty;

        UserInfo currentUser = UserController.Instance.GetCurrentUserInfo();
        if (currentUser == null || currentUser.UserID <= 0)
        {
            this.ShowRecoveryMessage("Recovery codes can only be generated for a signed-in DNN account.", true);
            return;
        }

        if (!this.ValidateCurrentPassword(currentUser, this.txtRecoveryPassword.Text))
        {
            this.txtRecoveryPassword.Text = string.Empty;
            this.ShowRecoveryMessage("Enter your current DNN password before generating or replacing recovery codes.", true);
            this.LogSecurityEvent("SecurityReauthentication", currentUser, "Failed", "Recovery-code replacement password confirmation failed in provider settings.");
            return;
        }
        this.txtRecoveryPassword.Text = string.Empty;

        List<string> plainCodes = new List<string>();
        List<string> hashes = new List<string>();
        List<string> salts = new List<string>();

        int recoveryCodeCount = this.GetIntPortalSetting(SettingRecoveryCodeCount, DefaultRecoveryCodeCount, 4, 20);
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
        }
        catch (Exception ex)
        {
            Exceptions.LogException(ex);
            this.ShowRecoveryMessage("Jacaranda2FA could not save the new recovery codes. Check DNN Event Viewer.", true);
            return;
        }

        this.SetSensitiveResponseNoStore();
        StringBuilder html = new StringBuilder();
        html.Append("<div class=\"dnnFormMessage dnnFormSuccess\"><strong>Save these codes now.</strong> They are shown only on this response. Generating another set immediately invalidates this set.</div><pre class=\"jacaranda2fa-recovery-list\">");
        for (int i = 0; i < plainCodes.Count; i++)
        {
            html.Append(HttpUtility.HtmlEncode(plainCodes[i]));
            html.Append("\n");
        }
        html.Append("</pre>");
        this.litRecoveryCodes.Text = html.ToString();
        this.RefreshRecoveryStatus();
        this.LogSecurityEvent("RecoveryCodesGenerated", currentUser, "Success", recoveryCodeCount.ToString(CultureInfo.InvariantCulture) + " new one-time recovery codes generated; previous set invalidated.");
    }

    private void RefreshRecoveryStatus()
    {
        UserInfo currentUser = UserController.Instance.GetCurrentUserInfo();
        if (currentUser == null || currentUser.UserID <= 0)
        {
            this.litRecoveryStatus.Text = "Sign in to manage recovery codes for your own account.";
            this.cmdGenerateRecovery.Enabled = false;
            return;
        }

        try
        {
            int count = DataProvider.Instance().ExecuteScalar<int>("Jacaranda2FA_CountRecoveryCodes", this.PortalId, currentUser.UserID);
            this.litRecoveryStatus.Text = count > 0
                ? count.ToString(CultureInfo.InvariantCulture) + " unused recovery code(s) currently exist for your account."
                : "No unused recovery codes currently exist for your account.";
            this.cmdGenerateRecovery.Enabled = true;
        }
        catch (Exception ex)
        {
            Exceptions.LogException(ex);
            this.litRecoveryStatus.Text = "Recovery-code storage is unavailable. Check that the Jacaranda2FA database scripts installed successfully.";
            this.cmdGenerateRecovery.Enabled = false;
        }
    }

    private void RefreshTrustedBrowserStatus()
    {
        UserInfo currentUser = UserController.Instance.GetCurrentUserInfo();
        if (currentUser == null || currentUser.UserID <= 0)
        {
            this.litTrustedBrowserStatus.Text = "Sign in to manage trusted browsers for your own account.";
            this.cmdRevokeTrustedBrowsers.Enabled = false;
            return;
        }

        try
        {
            int count = DataProvider.Instance().ExecuteScalar<int>("Jacaranda2FA_CountTrustedBrowsers", this.PortalId, currentUser.UserID);
            this.litTrustedBrowserStatus.Text = count > 0
                ? count.ToString(CultureInfo.InvariantCulture) + " trusted browser token(s) currently exist for your account."
                : "No trusted browser tokens currently exist for your account.";
            this.cmdRevokeTrustedBrowsers.Enabled = count > 0;
        }
        catch (Exception ex)
        {
            Exceptions.LogException(ex);
            this.litTrustedBrowserStatus.Text = "Trusted-browser storage is unavailable. Check that the Jacaranda2FA database scripts installed successfully.";
            this.cmdRevokeTrustedBrowsers.Enabled = false;
        }
    }

    private void RevokeTrustedBrowsers_Click(object sender, EventArgs e)
    {
        this.trustedBrowserMessage.Visible = false;

        UserInfo currentUser = UserController.Instance.GetCurrentUserInfo();
        if (currentUser == null || currentUser.UserID <= 0)
        {
            this.ShowTrustedBrowserMessage("Trusted browsers can only be revoked for a signed-in DNN account.", true);
            return;
        }

        try
        {
            DataProvider.Instance().ExecuteNonQuery("Jacaranda2FA_RevokeTrustedBrowsers", this.PortalId, currentUser.UserID);
            this.ExpireCurrentTrustedBrowserCookie(currentUser.UserID);
            this.ShowTrustedBrowserMessage("All trusted-browser tokens for your account have been revoked.", false);
            this.RefreshTrustedBrowserStatus();
            this.LogSecurityEvent("TrustedBrowsersRevoked", currentUser, "Success", "All trusted-browser tokens for this account were revoked.");
        }
        catch (Exception ex)
        {
            Exceptions.LogException(ex);
            this.ShowTrustedBrowserMessage("Jacaranda2FA could not revoke trusted browsers. Check DNN Event Viewer.", true);
        }
    }

    private void ExpireCurrentTrustedBrowserCookie(int userId)
    {
        if (this.Response == null)
        {
            return;
        }

        string cookieName = "Jacaranda2FA.Trusted." +
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

    private void LogSecurityEvent(string eventName, UserInfo user, string result, string reason)
    {
#pragma warning disable CS0618
        bool auditEnabled = PortalController.GetPortalSettingAsBoolean(SettingAuditEnabled, this.PortalId, true);
#pragma warning restore CS0618
        if (!auditEnabled)
        {
            return;
        }

        // Security audit events intentionally exclude passwords, OTP values, recovery codes,
        // trusted-browser tokens, token hashes, email addresses and session identifiers.
        try
        {
            LogInfo log = new LogInfo();
            log.LogTypeKey = "ADMIN_ALERT";
            log.LogPortalID = this.PortalId;
            log.LogUserID = user != null && user.UserID > 0 ? user.UserID : Null.NullInteger;
            log.LogProperties.Add(new LogDetailInfo("Source", "Jacaranda2FA " + Version));
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
            // Audit logging must never interrupt settings or authentication.
        }
    }

    private void ShowTrustedBrowserMessage(string message, bool error)
    {
        this.trustedBrowserMessage.Visible = true;
        this.trustedBrowserMessage.Attributes["class"] = error ? "dnnFormMessage dnnFormError" : "dnnFormMessage dnnFormSuccess";
        this.litTrustedBrowserMessage.Text = HttpUtility.HtmlEncode(message);
    }

    private void ShowRecoveryMessage(string message, bool error)
    {
        this.recoveryMessage.Visible = true;
        this.recoveryMessage.Attributes["class"] = error ? "dnnFormMessage dnnFormError" : "dnnFormMessage dnnFormInfo";
        this.litRecoveryMessage.Text = HttpUtility.HtmlEncode(message);
    }

    private bool ValidateCurrentPassword(UserInfo currentUser, string password)
    {
        if (currentUser == null || currentUser.UserID <= 0 || string.IsNullOrEmpty(password)) return false;
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
        return validated != null && validated.UserID == currentUser.UserID && (status == UserLoginStatus.LOGIN_SUCCESS || status == UserLoginStatus.LOGIN_SUPERUSER);
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

    private string GenerateRecoveryCode()
    {
        StringBuilder builder = new StringBuilder(RecoveryCodeLength);
        byte[] bytes = new byte[RecoveryCodeLength];
        using (RandomNumberGenerator rng = RandomNumberGenerator.Create())
        {
            rng.GetBytes(bytes);
        }

        // RecoveryAlphabet contains exactly 32 characters, so masking five random bits is unbiased.
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
</script>

<link rel="stylesheet" type="text/css" href="<%= ResolveUrl("~/DesktopModules/AuthenticationServices/Jacaranda2FA/Login.css?v=00.00.27") %>" />

<div class="dnnForm jacaranda2fa-settings" style="padding-left:10px; padding-right:10px; box-sizing:border-box;">
    <div class="dnnFormMessage dnnFormInfo">
        <strong>Jacaranda2FA 00.00.27</strong><br />
        DNN validates the normal password first. Jacaranda2FA then applies the policy below and, where required, verifies a TOTP authenticator code, emailed one-time code, unused recovery code, or valid trusted-browser token before reporting successful authentication to DNN.
    </div>

    <div class="dnnFormItem">
        <asp:Label ID="lblEnabled" runat="server" AssociatedControlID="chkEnabled" CssClass="dnnFormLabel" Text="Enable for this site" />
        <asp:CheckBox ID="chkEnabled" runat="server" />
    </div>

    <div class="dnnFormItem">
        <asp:Label ID="lblPolicy" runat="server" AssociatedControlID="ddlPolicy" CssClass="dnnFormLabel" Text="Require second factor for" />
        <asp:DropDownList ID="ddlPolicy" runat="server">
            <asp:ListItem Value="All" Text="All users" />
            <asp:ListItem Value="Administrators" Text="Administrators and SuperUsers" />
            <asp:ListItem Value="Roles" Text="Selected roles (SuperUsers are always included)" />
        </asp:DropDownList>
    </div>

    <div class="dnnFormItem">
        <asp:Label ID="lblRoles" runat="server" AssociatedControlID="cblRoles" CssClass="dnnFormLabel" Text="Selected roles" />
        <asp:CheckBoxList ID="cblRoles" runat="server" RepeatLayout="Flow" CssClass="jacaranda2fa-role-list" />
    </div>

    <div class="dnnFormMessage dnnFormWarning">
        <strong>Enforcement warning:</strong> any independently enabled authentication provider that completes a DNN login without passing through Jacaranda2FA can bypass Jacaranda2FA enforcement. During testing you may keep DNN Normal login available as a recovery path; for enforced production use, disable Normal and any other alternate login providers after Jacaranda2FA, recovery methods and SuperUser access have been tested successfully.
    </div>

    <fieldset class="jacaranda2fa-security-fieldset">
        <legend>Security and audit settings</legend>
        <div class="dnnFormMessage dnnFormInfo">
            These values are portal-specific. Jacaranda2FA clamps saved values to the safe ranges shown below.
        </div>

        <div class="jacaranda2fa-settings-grid">
            <div class="jacaranda2fa-setting-cell">
                <asp:Label ID="lblAuditEnabled" runat="server" AssociatedControlID="chkAuditEnabled" CssClass="jacaranda2fa-setting-label" Text="Security audit logging" />
                <div class="jacaranda2fa-setting-control">
                    <asp:CheckBox ID="chkAuditEnabled" runat="server" />
                    <span class="jacaranda2fa-help">Record Jacaranda2FA security events in DNN Event Viewer. Enabled by default.</span>
                </div>
            </div>

            <div class="jacaranda2fa-setting-cell">
                <asp:Label ID="lblDiagnosticLogging" runat="server" AssociatedControlID="chkDiagnosticLogging" CssClass="jacaranda2fa-setting-label" Text="Detailed diagnostics" />
                <div class="jacaranda2fa-setting-control">
                    <asp:CheckBox ID="chkDiagnosticLogging" runat="server" />
                    <span class="jacaranda2fa-help">Troubleshooting only. Adds low-level provider lifecycle messages to Event Viewer. Disabled by default.</span>
                </div>
            </div>

            <div class="jacaranda2fa-setting-cell">
                <asp:Label ID="lblCodeLifetimeMinutes" runat="server" AssociatedControlID="txtCodeLifetimeMinutes" CssClass="jacaranda2fa-setting-label" Text="OTP lifetime (minutes)" />
                <div class="jacaranda2fa-setting-control">
                    <asp:TextBox ID="txtCodeLifetimeMinutes" runat="server" CssClass="jacaranda2fa-number" MaxLength="3" />
                    <span class="jacaranda2fa-help">2–15 minutes. Default: 5.</span>
                </div>
            </div>

            <div class="jacaranda2fa-setting-cell">
                <asp:Label ID="lblMaxCodeAttempts" runat="server" AssociatedControlID="txtMaxCodeAttempts" CssClass="jacaranda2fa-setting-label" Text="Maximum verification attempts" />
                <div class="jacaranda2fa-setting-control">
                    <asp:TextBox ID="txtMaxCodeAttempts" runat="server" CssClass="jacaranda2fa-number" MaxLength="3" />
                    <span class="jacaranda2fa-help">3–10 combined OTP/recovery attempts. Default: 5.</span>
                </div>
            </div>

            <div class="jacaranda2fa-setting-cell">
                <asp:Label ID="lblMaxResends" runat="server" AssociatedControlID="txtMaxResends" CssClass="jacaranda2fa-setting-label" Text="Maximum OTP resends" />
                <div class="jacaranda2fa-setting-control">
                    <asp:TextBox ID="txtMaxResends" runat="server" CssClass="jacaranda2fa-number" MaxLength="3" />
                    <span class="jacaranda2fa-help">0–5 resends per challenge. Default: 3.</span>
                </div>
            </div>

            <div class="jacaranda2fa-setting-cell">
                <asp:Label ID="lblResendWaitSeconds" runat="server" AssociatedControlID="txtResendWaitSeconds" CssClass="jacaranda2fa-setting-label" Text="Resend delay (seconds)" />
                <div class="jacaranda2fa-setting-control">
                    <asp:TextBox ID="txtResendWaitSeconds" runat="server" CssClass="jacaranda2fa-number" MaxLength="3" />
                    <span class="jacaranda2fa-help">15–300 seconds. Default: 30.</span>
                </div>
            </div>

            <div class="jacaranda2fa-setting-cell">
                <asp:Label ID="lblTrustedBrowserDays" runat="server" AssociatedControlID="txtTrustedBrowserDays" CssClass="jacaranda2fa-setting-label" Text="Trusted-browser lifetime (days)" />
                <div class="jacaranda2fa-setting-control">
                    <asp:TextBox ID="txtTrustedBrowserDays" runat="server" CssClass="jacaranda2fa-number" MaxLength="3" />
                    <span class="jacaranda2fa-help">1–90 days. Default: 30.</span>
                </div>
            </div>

            <div class="jacaranda2fa-setting-cell">
                <asp:Label ID="lblMaxTrustedBrowsers" runat="server" AssociatedControlID="txtMaxTrustedBrowsers" CssClass="jacaranda2fa-setting-label" Text="Maximum trusted browsers" />
                <div class="jacaranda2fa-setting-control">
                    <asp:TextBox ID="txtMaxTrustedBrowsers" runat="server" CssClass="jacaranda2fa-number" MaxLength="3" />
                    <span class="jacaranda2fa-help">1–20 active tokens per user. Default: 10.</span>
                </div>
            </div>

            <div class="jacaranda2fa-setting-cell">
                <asp:Label ID="lblRecoveryCodeCount" runat="server" AssociatedControlID="txtRecoveryCodeCount" CssClass="jacaranda2fa-setting-label" Text="Recovery codes generated" />
                <div class="jacaranda2fa-setting-control">
                    <asp:TextBox ID="txtRecoveryCodeCount" runat="server" CssClass="jacaranda2fa-number" MaxLength="3" />
                    <span class="jacaranda2fa-help">4–20 codes per generated set. Default: 8.</span>
                </div>
            </div>
        </div>
    </fieldset>

    <fieldset>
        <legend>Recovery codes for your account</legend>
        <div class="dnnFormItem">
            <span class="dnnFormLabel">Current status</span>
            <asp:Literal ID="litRecoveryStatus" runat="server" />
        </div>
        <div class="dnnFormItem">
            <asp:Label ID="lblRecoveryPassword" runat="server" AssociatedControlID="txtRecoveryPassword" CssClass="dnnFormLabel" Text="Current password" />
            <asp:TextBox ID="txtRecoveryPassword" runat="server" TextMode="Password" />
            <span class="jacaranda2fa-help">Required before a new recovery-code set can replace the existing set.</span>
        </div>
        <div class="dnnFormItem">
            <span class="dnnFormLabel">Generate codes</span>
            <asp:Button ID="cmdGenerateRecovery" runat="server" CssClass="dnnSecondaryAction" Text="Generate / replace my recovery codes" CausesValidation="false" UseSubmitBehavior="true" OnClientClick="return confirm('Generate a new recovery-code set? Any existing unused recovery codes for your account will immediately stop working.');" />
        </div>
        <div id="recoveryMessage" runat="server" visible="false" class="dnnFormMessage">
            <asp:Literal ID="litRecoveryMessage" runat="server" />
        </div>
        <asp:Literal ID="litRecoveryCodes" runat="server" EnableViewState="false" />
    </fieldset>

    <fieldset>
        <legend>Trusted browsers for your account</legend>
        <div class="dnnFormMessage dnnFormInfo">
            After a successful email or recovery-code verification, you may choose <strong>Remember this browser for 2FA</strong>. The browser then skips the second-factor step for the configured trusted-browser lifetime, but the normal DNN password is still required.
        </div>
        <div class="dnnFormItem">
            <span class="dnnFormLabel">Current status</span>
            <asp:Literal ID="litTrustedBrowserStatus" runat="server" />
        </div>
        <div class="dnnFormItem">
            <span class="dnnFormLabel">Revoke access</span>
            <asp:Button ID="cmdRevokeTrustedBrowsers" runat="server" CssClass="dnnSecondaryAction" Text="Revoke all my trusted browsers" CausesValidation="false" UseSubmitBehavior="true" OnClientClick="return confirm('Revoke all trusted-browser tokens for your account? You will need a second factor again on those browsers.');" />
        </div>
        <div id="trustedBrowserMessage" runat="server" visible="false" class="dnnFormMessage">
            <asp:Literal ID="litTrustedBrowserMessage" runat="server" />
        </div>
    </fieldset>

</div>
