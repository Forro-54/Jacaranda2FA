<%@ Control Language="C#" AutoEventWireup="false" Inherits="DotNetNuke.Services.Authentication.AuthenticationSettingsBase" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Collections.Generic" %>
<%@ Import Namespace="System.Globalization" %>
<%@ Import Namespace="System.Security.Cryptography" %>
<%@ Import Namespace="System.Text" %>
<%@ Import Namespace="System.Web" %>
<%@ Import Namespace="DotNetNuke.Data" %>
<%@ Import Namespace="DotNetNuke.Entities.Portals" %>
<%@ Import Namespace="DotNetNuke.Entities.Users" %>
<%@ Import Namespace="DotNetNuke.Security.Roles" %>
<%@ Import Namespace="DotNetNuke.Services.Exceptions" %>

<script runat="server">
    private const string Version = "00.00.15";
    private const string SettingEnabled = "Jacaranda2FA_Enabled";
    private const string SettingPolicy = "Jacaranda2FA_Policy";
    private const string SettingRoleIds = "Jacaranda2FA_RoleIds";
    private const int RecoveryCodeCount = 8;
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
        string policy = PortalController.GetPortalSetting(SettingPolicy, this.PortalId, "All");
#pragma warning restore CS0618

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
        PortalController.UpdatePortalSetting(this.PortalId, SettingEnabled, this.chkEnabled.Checked.ToString());
        PortalController.UpdatePortalSetting(this.PortalId, SettingPolicy, this.ddlPolicy.SelectedValue);

        List<string> selected = new List<string>();
        foreach (System.Web.UI.WebControls.ListItem item in this.cblRoles.Items)
        {
            if (item.Selected)
            {
                selected.Add(item.Value);
            }
        }
        PortalController.UpdatePortalSetting(this.PortalId, SettingRoleIds, string.Join(",", selected.ToArray()));
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

        List<string> plainCodes = new List<string>();
        List<string> hashes = new List<string>();
        List<string> salts = new List<string>();

        for (int i = 0; i < RecoveryCodeCount; i++)
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
            DataProvider.Instance().ExecuteNonQuery("Jacaranda2FA_DeleteRecoveryCodes", this.PortalId, currentUser.UserID);
            for (int i = 0; i < plainCodes.Count; i++)
            {
                DataProvider.Instance().ExecuteNonQuery("Jacaranda2FA_AddRecoveryCode", this.PortalId, currentUser.UserID, hashes[i], salts[i]);
            }
        }
        catch (Exception ex)
        {
            Exceptions.LogException(ex);
            this.ShowRecoveryMessage("Jacaranda2FA could not save the new recovery codes. Check DNN Event Viewer.", true);
            return;
        }

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
            this.litRecoveryStatus.Text = "Recovery-code storage is unavailable. Check that the 00.00.15 database script installed successfully.";
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
            this.litTrustedBrowserStatus.Text = "Trusted-browser storage is unavailable. Check that the 00.00.15 database script installed successfully.";
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
        cookie.Secure = this.Request != null && this.Request.IsSecureConnection;
        cookie.Path = string.IsNullOrEmpty(DotNetNuke.Common.Globals.ApplicationPath)
            ? "/"
            : DotNetNuke.Common.Globals.ApplicationPath;
        cookie.Expires = DateTime.Now.AddDays(-1);
        cookie.SameSite = SameSiteMode.Lax;
        this.Response.Cookies.Set(cookie);
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

<link rel="stylesheet" type="text/css" href="<%= ResolveUrl("~/DesktopModules/AuthenticationServices/Jacaranda2FA/Login.css") %>" />

<div class="dnnForm jacaranda2fa-settings">
    <div class="dnnFormMessage dnnFormInfo">
        <strong>Jacaranda2FA 00.00.15</strong><br />
        DNN validates the normal password first. Jacaranda2FA then applies the policy below and, where required, verifies an emailed one-time code, an unused recovery code, or a valid trusted-browser token before reporting successful authentication to DNN.
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
        <strong>Enforcement warning:</strong> while DNN's Normal login provider remains enabled, a user can choose Normal login and bypass Jacaranda2FA. Keep Normal login enabled during testing. Only disable it after Jacaranda2FA login, email delivery, recovery codes and SuperUser access have all been tested successfully.
    </div>

    <fieldset>
        <legend>Recovery codes for your account</legend>
        <div class="dnnFormItem">
            <span class="dnnFormLabel">Current status</span>
            <asp:Literal ID="litRecoveryStatus" runat="server" />
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
            After a successful email or recovery-code verification, you may choose <strong>Remember this browser for 2FA</strong>. The browser then skips the second-factor step for 30 days, but the normal DNN password is still required.
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

    <div class="dnnFormItem">
        <span class="dnnFormLabel">Email-code limits</span>
        <div>6-digit code; 5-minute expiry; 5 combined verification attempts; up to 3 resends; minimum 30 seconds between resends.</div>
    </div>
</div>
