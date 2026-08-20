<%@ Control Language="C#" AutoEventWireup="false" Inherits="DotNetNuke.Services.Authentication.AuthenticationLoginBase" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Collections.Generic" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Globalization" %>
<%@ Import Namespace="System.Security.Cryptography" %>
<%@ Import Namespace="System.Text" %>
<%@ Import Namespace="System.Web" %>
<%@ Import Namespace="DotNetNuke.Common.Utilities" %>
<%@ Import Namespace="DotNetNuke.Data" %>
<%@ Import Namespace="DotNetNuke.Entities.Host" %>
<%@ Import Namespace="DotNetNuke.Entities.Portals" %>
<%@ Import Namespace="DotNetNuke.Entities.Users" %>
<%@ Import Namespace="DotNetNuke.Security" %>
<%@ Import Namespace="DotNetNuke.Security.Membership" %>
<%@ Import Namespace="DotNetNuke.Security.Roles" %>
<%@ Import Namespace="DotNetNuke.Services.Authentication" %>
<%@ Import Namespace="DotNetNuke.Services.Exceptions" %>
<%@ Import Namespace="DotNetNuke.Services.Mail" %>
<%@ Import Namespace="DotNetNuke.Services.Log.EventLog" %>

<script runat="server">
    private const int CodeDigits = 6;
    private const int CodeLifetimeMinutes = 5;
    private const int MaxCodeAttempts = 5;
    private const int MaxResends = 3;
    private const int ResendWaitSeconds = 30;
    private const int TrustedBrowserDays = 30;
    private const string TrustedCookiePrefix = "Jacaranda2FA.Trusted.";
    private const string Version = "00.00.15";
    private const string SettingEnabled = "Jacaranda2FA_Enabled";
    private const string SettingPolicy = "Jacaranda2FA_Policy";
    private const string SettingRoleIds = "Jacaranda2FA_RoleIds";
    private const string StageQueryKey = "jacaranda2fa_stage";
    private bool actionHandled;

    public override bool Enabled
    {
        get
        {
#pragma warning disable CS0618
            return PortalController.GetPortalSettingAsBoolean(SettingEnabled, this.PortalId, false);
#pragma warning restore CS0618
        }
    }

    private string SessionPrefix
    {
        get
        {
            return "Jacaranda2FA:" + this.PortalId.ToString(CultureInfo.InvariantCulture) + ":";
        }
    }

    private string Key(string name)
    {
        return this.SessionPrefix + name;
    }

    protected override void OnLoad(EventArgs e)
    {
        base.OnLoad(e);

        // DNN dynamically loads third-party authentication providers during the parent login
        // control's OnLoad. Keep the normal ASP.NET Click path, but also register a guarded
        // LoadComplete fallback for hosts where the dynamically loaded submit button is present
        // in Request.Form but ASP.NET does not raise its Click event.
        this.cmdLogin.Click += this.Login_Click;
        this.cmdVerify.Click += this.Verify_Click;
        this.cmdResend.Click += this.Resend_Click;
        this.cmdRecovery.Click += this.Recovery_Click;
        this.cmdCancelVerification.Click += this.CancelVerification_Click;

        if (this.Page != null)
        {
            this.Page.LoadComplete += this.Page_LoadComplete;

            // Some DNN/skin JavaScript can submit the surrounding form without preserving the
            // clicked submit button's name/value. Record only a fixed action name in a hidden
            // field so the server can identify which Jacaranda2FA action was requested. The marker is
            // not an authorization decision and contains no account or authentication data.
            string actionClientId = HttpUtility.JavaScriptStringEncode(this.actionField.ClientID);
            this.cmdLogin.OnClientClick = "document.getElementById('" + actionClientId + "').value='login';";
            this.cmdVerify.OnClientClick = "document.getElementById('" + actionClientId + "').value='verify';";
            this.cmdResend.OnClientClick = "document.getElementById('" + actionClientId + "').value='resend';";
            this.cmdRecovery.OnClientClick = "document.getElementById('" + actionClientId + "').value='recovery';";
            this.cmdCancelVerification.OnClientClick = "document.getElementById('" + actionClientId + "').value='cancel';";

            if (this.Page.IsPostBack)
            {
                this.LogDiagnostic("Authentication control loaded during postback.");
            }
        }

        this.txtUsername.Attributes["autocomplete"] = "username";
        this.txtPassword.Attributes["autocomplete"] = "current-password";
        this.txtCode.Attributes["autocomplete"] = "one-time-code";
        this.txtCode.Attributes["inputmode"] = "numeric";
        this.txtCode.Attributes["pattern"] = "[0-9]*";
        this.txtCode.Attributes["maxlength"] = CodeDigits.ToString(CultureInfo.InvariantCulture);
        this.txtRecoveryCode.Attributes["autocomplete"] = "off";
        this.txtRecoveryCode.Attributes["autocapitalize"] = "characters";
        this.txtRecoveryCode.Attributes["spellcheck"] = "false";
        this.txtRecoveryCode.Attributes["maxlength"] = "14";

        this.chkRemember.Visible = Host.RememberCheckbox;

        string returnUrl = DotNetNuke.Common.Globals.NavigateURL();
        string encodedReturnUrl = HttpUtility.UrlEncode(returnUrl);
        this.registerLink.NavigateUrl = DotNetNuke.Common.Globals.RegisterURL(encodedReturnUrl, Null.NullString);
        this.passwordLink.NavigateUrl = DotNetNuke.Common.Globals.NavigateURL("SendPassword", "returnurl=" + encodedReturnUrl);
        this.registerRow.Visible = this.PortalSettings.UserRegistration != (int)DotNetNuke.Common.Globals.PortalRegistrationType.NoRegistration;

        if (!string.IsNullOrEmpty(this.RedirectURL))
        {
            this.cancelLink.NavigateUrl = this.RedirectURL;
        }
        else
        {
            this.cancelLink.NavigateUrl = DotNetNuke.Common.Globals.NavigateURL(this.PortalSettings.HomeTabId);
        }

        if (!this.IsPostBack)
        {
            this.HideMessage();
        }

        // DNN rebuilds authentication provider controls on every request. Restore the
        // visible stage from the server-side challenge. 00.00.15 continues the clean
        // stage one with a clean GET so this decision happens during a normal page load
        // instead of relying on a late postback UI change.
        bool hasChallenge = this.HasChallenge();
        if (hasChallenge)
        {
            this.ShowVerificationPanel();
        }
        else
        {
            this.ShowLoginPanel();
        }

        if (!this.IsPostBack && string.Equals(this.Request.QueryString[StageQueryKey], "verify", StringComparison.OrdinalIgnoreCase))
        {
            if (hasChallenge)
            {
                this.LogDiagnostic("Active verification challenge restored after clean stage redirect.");
                this.ShowMessage("Enter the six-digit verification code sent to your registered email address.", false);
                this.RegisterAuthenticationTabPresentationScript(true);
            }
            else
            {
                this.LogDiagnostic("Verification-stage redirect completed but no active challenge was present.");
                this.ShowLoginPanel();
                this.ShowMessage("Your verification session could not be restored. Please sign in again.", true);
            }
        }
        else
        {
            // Keep the authentication choices readable on the ordinary login stage too.
            this.RegisterAuthenticationTabPresentationScript(false);
        }
    }

    private void RegisterAuthenticationTabPresentationScript(bool selectVerificationTab)
    {
        if (this.Page == null)
        {
            return;
        }

        // DNN themes can apply login-tab rules after an authentication provider's own CSS,
        // including !important rules and background images. 00.00.15 therefore paints only
        // DNN's authentication-choice tabs with inline !important properties after rendering.
        // This is presentation-only; it does not change DNN authentication state or permissions.
        string selectVerification = selectVerificationTab ? "true" : "false";
        string script = @"
(function () {
    var selectVerification = " + selectVerification + @";
    var tries = 0;
    var observerAttached = false;

    function getTabs(root) {
        var group = root.querySelector('.LoginTabGroup');
        if (group) {
            return group.querySelectorAll('.LoginTab, .LoginTabSelected, .LoginTabHover');
        }
        return root.querySelectorAll('.LoginTab, .LoginTabSelected, .LoginTabHover');
    }

    function paintTab(tab, selected) {
        var bg = selected ? '#343a40' : '#e9ecef';
        var fg = selected ? '#ffffff' : '#212529';
        var border = selected ? '#212529' : '#6c757d';

        tab.style.setProperty('background', bg, 'important');
        tab.style.setProperty('background-color', bg, 'important');
        tab.style.setProperty('background-image', 'none', 'important');
        tab.style.setProperty('color', fg, 'important');
        tab.style.setProperty('border', '2px solid ' + border, 'important');
        tab.style.setProperty('text-shadow', 'none', 'important');
        tab.style.setProperty('box-shadow', selected ? '0 0 0 1px rgba(255,255,255,.45) inset' : 'none', 'important');

        var children = tab.querySelectorAll('*');
        for (var j = 0; j < children.length; j++) {
            children[j].style.setProperty('color', fg, 'important');
            children[j].style.setProperty('background-color', 'transparent', 'important');
            children[j].style.setProperty('background-image', 'none', 'important');
            children[j].style.setProperty('text-shadow', 'none', 'important');
        }
    }

    function positionTabGroup(root) {
        var group = root.querySelector('.LoginTabGroup');
        if (!group) {
            return;
        }

        // Move DNN's authentication-provider choices clear of the Username label.
        // Use inline !important because some DNN skins position these controls aggressively.
        group.style.setProperty('position', 'relative', 'important');
        group.style.setProperty('top', '-18px', 'important');
        group.style.setProperty('margin-bottom', '1.5rem', 'important');
        group.style.setProperty('z-index', '2', 'important');
    }

    function repaint() {
        var root = document.querySelector('.dnnLogin') || document;
        positionTabGroup(root);
        var tabs = getTabs(root);
        for (var i = 0; i < tabs.length; i++) {
            var selected = (' ' + tabs[i].className + ' ').indexOf(' LoginTabSelected ') >= 0;
            paintTab(tabs[i], selected);
        }
    }

    function selectAndPaint() {
        tries++;
        var root = document.querySelector('.dnnLogin') || document;
        var tabs = getTabs(root);

        if (tabs.length === 0) {
            if (tries < 20) {
                window.setTimeout(selectAndPaint, 100);
            }
            return;
        }

        for (var i = 0; i < tabs.length; i++) {
            if (!tabs[i].getAttribute('data-jacaranda2fa-style-hook')) {
                tabs[i].setAttribute('data-jacaranda2fa-style-hook', '1');
                tabs[i].addEventListener('click', function () {
                    window.setTimeout(repaint, 0);
                    window.setTimeout(repaint, 75);
                    window.setTimeout(repaint, 200);
                });
            }
        }

        if (selectVerification) {
            for (var k = 0; k < tabs.length; k++) {
                var text = (tabs[k].textContent || tabs[k].innerText || '').replace(/\s+/g, ' ').trim().toLowerCase();
                if (text === 'jacaranda2fa') {
                    if ((' ' + tabs[k].className + ' ').indexOf(' LoginTabSelected ') < 0 && typeof tabs[k].click === 'function') {
                        tabs[k].click();
                    }
                    break;
                }
            }
        }

        repaint();
        window.setTimeout(repaint, 75);
        window.setTimeout(repaint, 200);

        if (!observerAttached && window.MutationObserver) {
            var group = root.querySelector('.LoginTabGroup');
            if (group) {
                observerAttached = true;
                var observer = new MutationObserver(function (mutations) {
                    for (var m = 0; m < mutations.length; m++) {
                        if (mutations[m].type === 'attributes' && mutations[m].attributeName === 'class') {
                            repaint();
                            break;
                        }
                    }
                });
                observer.observe(group, { subtree: true, attributes: true, attributeFilter: ['class'] });
            }
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', selectAndPaint);
    } else {
        window.setTimeout(selectAndPaint, 0);
    }
})();";

        this.Page.ClientScript.RegisterStartupScript(this.GetType(), "Jacaranda2FA_AuthenticationTabPresentation", script, true);
    }

    private void Page_LoadComplete(object sender, EventArgs e)
    {
        if (this.actionHandled || this.Page == null || !this.Page.IsPostBack)
        {
            return;
        }

        string action = this.GetSubmittedAction();
        if (string.IsNullOrEmpty(action))
        {
            return;
        }

        this.LogDiagnostic("Jacaranda2FA submit action was present but ASP.NET did not raise the normal Click event; using guarded fallback dispatch for " + action + ".");

        switch (action)
        {
            case "login":
                this.Login_Click(this.cmdLogin, EventArgs.Empty);
                break;
            case "verify":
                this.Verify_Click(this.cmdVerify, EventArgs.Empty);
                break;
            case "resend":
                this.Resend_Click(this.cmdResend, EventArgs.Empty);
                break;
            case "recovery":
                this.Recovery_Click(this.cmdRecovery, EventArgs.Empty);
                break;
            case "cancel":
                this.CancelVerification_Click(this.cmdCancelVerification, EventArgs.Empty);
                break;
        }
    }

    private string GetSubmittedAction()
    {
        string action = Convert.ToString(this.Request.Form[this.actionField.UniqueID], CultureInfo.InvariantCulture);
        if (action == "login" || action == "verify" || action == "resend" || action == "recovery" || action == "cancel")
        {
            return action;
        }

        if (this.Request.Form[this.cmdLogin.UniqueID] != null)
        {
            return "login";
        }
        if (this.Request.Form[this.cmdVerify.UniqueID] != null)
        {
            return "verify";
        }
        if (this.Request.Form[this.cmdResend.UniqueID] != null)
        {
            return "resend";
        }
        if (this.Request.Form[this.cmdRecovery.UniqueID] != null)
        {
            return "recovery";
        }
        if (this.Request.Form[this.cmdCancelVerification.UniqueID] != null)
        {
            return "cancel";
        }

        string eventTarget = Convert.ToString(this.Request.Form["__EVENTTARGET"], CultureInfo.InvariantCulture);
        if (string.Equals(eventTarget, this.cmdLogin.UniqueID, StringComparison.Ordinal))
        {
            return "login";
        }
        if (string.Equals(eventTarget, this.cmdVerify.UniqueID, StringComparison.Ordinal))
        {
            return "verify";
        }
        if (string.Equals(eventTarget, this.cmdResend.UniqueID, StringComparison.Ordinal))
        {
            return "resend";
        }
        if (string.Equals(eventTarget, this.cmdRecovery.UniqueID, StringComparison.Ordinal))
        {
            return "recovery";
        }
        if (string.Equals(eventTarget, this.cmdCancelVerification.UniqueID, StringComparison.Ordinal))
        {
            return "cancel";
        }

        return string.Empty;
    }

    private bool BeginAction(string diagnosticMessage)
    {
        if (this.actionHandled)
        {
            return false;
        }

        this.actionHandled = true;
        this.LogDiagnostic(diagnosticMessage);
        return true;
    }

    protected void Login_Click(object sender, EventArgs e)
    {
        if (!this.BeginAction("Sign-in action received."))
        {
            return;
        }
        this.HideMessage();

        string enteredUserName = this.txtUsername.Text ?? string.Empty;
        if (enteredUserName.Length == 0)
        {
            enteredUserName = Convert.ToString(this.Request.Form[this.txtUsername.UniqueID], CultureInfo.InvariantCulture) ?? string.Empty;
        }
        enteredUserName = enteredUserName.Trim();

        string password = this.txtPassword.Text ?? string.Empty;
        if (password.Length == 0)
        {
            password = Convert.ToString(this.Request.Form[this.txtPassword.UniqueID], CultureInfo.InvariantCulture) ?? string.Empty;
        }

        bool rememberMe = this.chkRemember.Checked || this.Request.Form[this.chkRemember.UniqueID] != null;

        if (enteredUserName.Length == 0 || password.Length == 0)
        {
            this.ShowMessage("Enter both your username and password.", true);
            return;
        }

#pragma warning disable CS0618
        string userName = PortalSecurity.Instance.InputFilter(
            enteredUserName,
            PortalSecurity.FilterFlag.NoScripting |
            PortalSecurity.FilterFlag.NoAngleBrackets |
            PortalSecurity.FilterFlag.NoMarkup |
            PortalSecurity.FilterFlag.NoControlCharacters);
#pragma warning restore CS0618

#pragma warning disable CS0618
        bool emailUsedAsUsername = PortalController.GetPortalSettingAsBoolean("Registration_UseEmailAsUserName", this.PortalId, false);
#pragma warning restore CS0618
        UserInfo userByEmail = null;
        if (emailUsedAsUsername)
        {
            userByEmail = UserController.GetUserByEmail(this.PortalId, userName);
            if (userByEmail != null)
            {
                userName = userByEmail.Username;
            }
        }

        UserLoginStatus loginStatus = UserLoginStatus.LOGIN_FAILURE;
        UserInfo user = null;
        if (!emailUsedAsUsername || userByEmail != null)
        {
            user = UserController.ValidateUser(
                this.PortalId,
                userName,
                password,
                "DNN",
                string.Empty,
                this.PortalSettings.PortalName,
                this.IPAddress,
                ref loginStatus);
        }

        // Never retain the password after DNN has validated this request.
        this.txtPassword.Text = string.Empty;

        if (loginStatus != UserLoginStatus.LOGIN_SUCCESS && loginStatus != UserLoginStatus.LOGIN_SUPERUSER)
        {
            this.LogDiagnostic("DNN password validation did not succeed. Status: " + loginStatus.ToString() + ".");
            bool authenticated = loginStatus != UserLoginStatus.LOGIN_FAILURE;
            string message = loginStatus == UserLoginStatus.LOGIN_USERNOTAPPROVED ? "UserNotAuthorized" : string.Empty;
            UserAuthenticatedEventArgs failedArgs = new UserAuthenticatedEventArgs(user, userName, loginStatus, "DNN");
            failedArgs.Authenticated = authenticated;
            failedArgs.Message = message;
            failedArgs.RememberMe = rememberMe;
            this.OnUserAuthenticated(failedArgs);
            return;
        }

        this.LogDiagnostic("DNN password validation succeeded; preparing email verification challenge.");

        if (user == null)
        {
            this.ShowMessage("The login could not be verified. Please try again.", true);
            return;
        }

        if (!this.ShouldRequireTwoFactor(user))
        {
            this.ClearChallenge();
            this.LogDiagnostic("DNN password validation succeeded and current policy does not require a second factor for this account; handing authenticated user back to DNN.");
            UserAuthenticatedEventArgs passThroughArgs = new UserAuthenticatedEventArgs(user, userName, loginStatus, "DNN");
            passThroughArgs.Authenticated = true;
            passThroughArgs.RememberMe = rememberMe;
            this.OnUserAuthenticated(passThroughArgs);
            return;
        }

        if (this.IsTrustedBrowser(user.UserID))
        {
            this.ClearChallenge();
            this.LogDiagnostic("DNN password validation succeeded and a valid trusted-browser token was accepted; skipping the email second-factor step.");
            UserAuthenticatedEventArgs trustedArgs = new UserAuthenticatedEventArgs(user, userName, loginStatus, "DNN");
            trustedArgs.Authenticated = true;
            trustedArgs.RememberMe = rememberMe;
            this.OnUserAuthenticated(trustedArgs);
            return;
        }

        if (string.IsNullOrWhiteSpace(user.Email) || !Mail.IsValidEmailAddress(user.Email, this.PortalId))
        {
            this.ShowMessage("This account does not have a usable registered email address. Email verification cannot continue.", true);
            return;
        }

        this.ClearChallenge();
        this.Session[this.Key("UserId")] = user.UserID;
        this.Session[this.Key("UserName")] = userName;
        this.Session[this.Key("LoginStatus")] = (int)loginStatus;
        this.Session[this.Key("RememberMe")] = rememberMe;
        this.Session[this.Key("ResendCount")] = 0;

        if (!this.IssueCode(user, false))
        {
            this.ClearChallenge();
            return;
        }

        this.LogDiagnostic("Verification challenge created and email accepted by DNN mail provider.");
        this.LogDiagnostic("Verification challenge saved; redirecting to verification stage.");
        this.RedirectToVerificationStage();
    }

    protected void Verify_Click(object sender, EventArgs e)
    {
        if (!this.BeginAction("Verify-code action received."))
        {
            return;
        }
        this.HideMessage();

        if (!this.HasChallenge())
        {
            this.ClearChallenge();
            this.ShowLoginPanel();
            this.ShowMessage("Your verification session has ended. Please sign in again.", true);
            return;
        }

        long expiresTicks = this.GetSessionLong("ExpiresUtcTicks");
        if (expiresTicks <= 0 || DateTime.UtcNow > new DateTime(expiresTicks, DateTimeKind.Utc))
        {
            this.ClearChallenge();
            this.ShowLoginPanel();
            this.ShowMessage("The verification code has expired. Please sign in again.", true);
            return;
        }

        string code = this.txtCode.Text ?? string.Empty;
        if (code.Length == 0)
        {
            code = Convert.ToString(this.Request.Form[this.txtCode.UniqueID], CultureInfo.InvariantCulture) ?? string.Empty;
        }
        code = code.Trim();
        if (!this.IsSixDigitCode(code))
        {
            this.ShowMessage("Enter the six-digit verification code.", true);
            return;
        }

        int attempts = this.GetSessionInt("Attempts");
        if (!this.CodeMatches(code))
        {
            attempts++;
            this.Session[this.Key("Attempts")] = attempts;
            this.txtCode.Text = string.Empty;

            if (attempts >= MaxCodeAttempts)
            {
                this.ClearChallenge();
                this.ShowLoginPanel();
                this.ShowMessage("Too many incorrect verification attempts. Please sign in again.", true);
            }
            else
            {
                int remaining = MaxCodeAttempts - attempts;
                this.ShowMessage("That verification code is not correct. " + remaining.ToString(CultureInfo.InvariantCulture) + " attempt(s) remain.", true);
            }

            return;
        }

        int userId = this.GetSessionInt("UserId");
        string userName = Convert.ToString(this.Session[this.Key("UserName")], CultureInfo.InvariantCulture);
        int statusValue = this.GetSessionInt("LoginStatus");
        bool rememberMe = this.GetSessionBool("RememberMe");

        UserInfo user = UserController.GetUserById(this.PortalId, userId);
        if (user == null || !string.Equals(user.Username, userName, StringComparison.OrdinalIgnoreCase))
        {
            this.ClearChallenge();
            this.ShowLoginPanel();
            this.ShowMessage("The account could not be reloaded. Please sign in again.", true);
            return;
        }

        UserLoginStatus loginStatus = (UserLoginStatus)statusValue;
        bool trustBrowser = this.chkTrustBrowser.Checked || this.Request.Form[this.chkTrustBrowser.UniqueID] != null;
        this.CompleteChallengeAuthentication(user, userName, loginStatus, rememberMe, trustBrowser, "Email verification succeeded");
    }

    protected void Recovery_Click(object sender, EventArgs e)
    {
        if (!this.BeginAction("Recovery-code action received."))
        {
            return;
        }
        this.HideMessage();

        if (!this.HasChallenge())
        {
            this.ClearChallenge();
            this.ShowLoginPanel();
            this.ShowMessage("Your verification session has ended. Please sign in again.", true);
            return;
        }

        long expiresTicks = this.GetSessionLong("ExpiresUtcTicks");
        if (expiresTicks <= 0 || DateTime.UtcNow > new DateTime(expiresTicks, DateTimeKind.Utc))
        {
            this.ClearChallenge();
            this.ShowLoginPanel();
            this.ShowMessage("The verification session has expired. Please sign in again.", true);
            return;
        }

        int userId = this.GetSessionInt("UserId");
        string recoveryCode = this.txtRecoveryCode.Text ?? string.Empty;
        if (recoveryCode.Length == 0)
        {
            recoveryCode = Convert.ToString(this.Request.Form[this.txtRecoveryCode.UniqueID], CultureInfo.InvariantCulture) ?? string.Empty;
        }
        recoveryCode = this.NormalizeRecoveryCode(recoveryCode);

        if (recoveryCode.Length != 12)
        {
            this.ShowMessage("Enter a valid Jacaranda2FA recovery code.", true);
            return;
        }

        if (!this.TryConsumeRecoveryCode(userId, recoveryCode))
        {
            int attempts = this.GetSessionInt("Attempts") + 1;
            this.Session[this.Key("Attempts")] = attempts;
            this.txtRecoveryCode.Text = string.Empty;

            if (attempts >= MaxCodeAttempts)
            {
                this.ClearChallenge();
                this.ShowLoginPanel();
                this.ShowMessage("Too many incorrect verification attempts. Please sign in again.", true);
            }
            else
            {
                int remaining = MaxCodeAttempts - attempts;
                this.ShowMessage("That recovery code is not valid or has already been used. " + remaining.ToString(CultureInfo.InvariantCulture) + " attempt(s) remain.", true);
            }
            return;
        }

        string userName = Convert.ToString(this.Session[this.Key("UserName")], CultureInfo.InvariantCulture);
        int statusValue = this.GetSessionInt("LoginStatus");
        bool rememberMe = this.GetSessionBool("RememberMe");
        UserInfo user = UserController.GetUserById(this.PortalId, userId);
        if (user == null || !string.Equals(user.Username, userName, StringComparison.OrdinalIgnoreCase))
        {
            this.ClearChallenge();
            this.ShowLoginPanel();
            this.ShowMessage("The account could not be reloaded. Please sign in again.", true);
            return;
        }

        bool trustBrowser = this.chkTrustBrowser.Checked || this.Request.Form[this.chkTrustBrowser.UniqueID] != null;
        this.CompleteChallengeAuthentication(user, userName, (UserLoginStatus)statusValue, rememberMe, trustBrowser, "Recovery code accepted");
    }

    private void CompleteChallengeAuthentication(UserInfo user, string userName, UserLoginStatus loginStatus, bool rememberMe, bool trustBrowser, string diagnostic)
    {
        // Only a successfully completed second factor may create a trusted-browser token.
        if (trustBrowser)
        {
            this.TryRememberTrustedBrowser(user.UserID);
        }

        // Single use: invalidate the active email challenge before handing control back to DNN.
        this.ClearChallenge();
        this.LogDiagnostic(diagnostic + "; handing authenticated user back to DNN.");
        UserAuthenticatedEventArgs successArgs = new UserAuthenticatedEventArgs(user, userName, loginStatus, "DNN");
        successArgs.Authenticated = true;
        successArgs.RememberMe = rememberMe;
        this.OnUserAuthenticated(successArgs);
    }

    protected void Resend_Click(object sender, EventArgs e)
    {
        if (!this.BeginAction("Resend-code action received."))
        {
            return;
        }
        this.HideMessage();

        if (!this.HasChallenge())
        {
            this.ClearChallenge();
            this.ShowLoginPanel();
            this.ShowMessage("Your verification session has ended. Please sign in again.", true);
            return;
        }

        int resendCount = this.GetSessionInt("ResendCount");
        if (resendCount >= MaxResends)
        {
            this.ShowMessage("The resend limit has been reached. Please sign in again to request a new code.", true);
            return;
        }

        long lastSentTicks = this.GetSessionLong("LastSentUtcTicks");
        if (lastSentTicks > 0)
        {
            DateTime lastSent = new DateTime(lastSentTicks, DateTimeKind.Utc);
            TimeSpan elapsed = DateTime.UtcNow - lastSent;
            if (elapsed.TotalSeconds < ResendWaitSeconds)
            {
                int seconds = Math.Max(1, ResendWaitSeconds - (int)elapsed.TotalSeconds);
                this.ShowMessage("Please wait " + seconds.ToString(CultureInfo.InvariantCulture) + " second(s) before requesting another code.", true);
                return;
            }
        }

        int userId = this.GetSessionInt("UserId");
        UserInfo user = UserController.GetUserById(this.PortalId, userId);
        if (user == null || string.IsNullOrWhiteSpace(user.Email))
        {
            this.ClearChallenge();
            this.ShowLoginPanel();
            this.ShowMessage("The account could not be reloaded. Please sign in again.", true);
            return;
        }

        if (!this.IssueCode(user, true))
        {
            return;
        }

        this.Session[this.Key("ResendCount")] = resendCount + 1;
        this.ShowVerificationPanel();
        this.ShowMessage("A new verification code has been sent to " + this.MaskEmail(user.Email) + ".", false);
    }

    protected void CancelVerification_Click(object sender, EventArgs e)
    {
        if (!this.BeginAction("Cancel-2FA action received."))
        {
            return;
        }
        this.ClearChallenge();
        this.txtCode.Text = string.Empty;
        this.LogDiagnostic("Verification challenge cleared; returning to login options with a clean request.");
        this.RedirectToLoginOptions();
    }

    private void RedirectToVerificationStage()
    {
        this.RedirectClean(this.BuildCurrentPageUrl("verify"));
    }

    private void RedirectToLoginOptions()
    {
        this.RedirectClean(this.BuildCurrentPageUrl(null));
    }

    private string BuildCurrentPageUrl(string stage)
    {
        string path = this.Request.Url != null ? this.Request.Url.AbsolutePath : DotNetNuke.Common.Globals.NavigateURL();
        string queryText = this.Request.Url != null ? this.Request.Url.Query : string.Empty;
        var query = HttpUtility.ParseQueryString(queryText);

        if (string.IsNullOrEmpty(stage))
        {
            query.Remove(StageQueryKey);
        }
        else
        {
            query[StageQueryKey] = stage;
        }

        string encodedQuery = query.ToString();
        return string.IsNullOrEmpty(encodedQuery) ? path : path + "?" + encodedQuery;
    }

    private void RedirectClean(string url)
    {
        this.Response.Redirect(url, false);
        if (this.Context != null && this.Context.ApplicationInstance != null)
        {
            this.Context.ApplicationInstance.CompleteRequest();
        }
    }

    private bool IssueCode(UserInfo user, bool resend)
    {
        string code = this.GenerateCode();
        byte[] salt = new byte[16];
        using (RandomNumberGenerator rng = RandomNumberGenerator.Create())
        {
            rng.GetBytes(salt);
        }

        byte[] hash = this.HashCode(code, salt);
        DateTime now = DateTime.UtcNow;

        string fromAddress = this.PortalSettings.Email;
        if (string.IsNullOrWhiteSpace(fromAddress))
        {
            this.ShowMessage("The site administrator email address is not configured, so the verification message cannot be sent.", true);
            return false;
        }

        // Use DNN's Host email as the SMTP Sender identity. DNN's CoreMailProvider
        // can then substitute the authenticated SMTP username when required by the
        // configured mail server, while preserving the portal address as the visible From.
        string senderAddress = Host.HostEmail;
        if (string.IsNullOrWhiteSpace(senderAddress))
        {
            senderAddress = fromAddress;
        }

        string subject = this.PortalSettings.PortalName + " login verification code";
        string body =
            "A sign-in attempt for your account requires email verification.\r\n\r\n" +
            "Verification code: " + code + "\r\n\r\n" +
            "This code expires in " + CodeLifetimeMinutes.ToString(CultureInfo.InvariantCulture) + " minutes and can be used once.\r\n\r\n" +
            "If you did not attempt to sign in, you can ignore this message.";

        try
        {
            string error = Mail.SendEmail(
                fromAddress,
                senderAddress,
                user.Email,
                subject,
                body,
                new List<MailAttachment>());

            if (!string.IsNullOrEmpty(error))
            {
                Exceptions.LogException(new Exception("Jacaranda2FA 00.00.15 email delivery error: " + error));
                this.ShowMessage("DNN reported a problem sending the verification email. Check the site's SMTP configuration and Event Viewer.", true);
                return false;
            }
        }
        catch (Exception ex)
        {
            Exceptions.LogException(ex);
            this.ShowMessage("The verification email could not be sent. Check the site's SMTP configuration and Event Viewer.", true);
            return false;
        }

        // Replace the active challenge only after DNN's mail provider accepts the send.
        this.Session[this.Key("CodeSalt")] = Convert.ToBase64String(salt);
        this.Session[this.Key("CodeHash")] = Convert.ToBase64String(hash);
        this.Session[this.Key("ExpiresUtcTicks")] = now.AddMinutes(CodeLifetimeMinutes).Ticks;
        this.Session[this.Key("LastSentUtcTicks")] = now.Ticks;
        this.Session[this.Key("Attempts")] = 0;

        return true;
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
            // SuperUsers are always protected whenever a selective enforcement policy is active.
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

        // "All" is the default and preserves 00.00.13 behaviour.
        return true;
    }

    private string TrustedCookieName(int userId)
    {
        return TrustedCookiePrefix +
               this.PortalId.ToString(CultureInfo.InvariantCulture) + "." +
               userId.ToString(CultureInfo.InvariantCulture);
    }

    private string TrustedCookiePath()
    {
        return string.IsNullOrEmpty(DotNetNuke.Common.Globals.ApplicationPath)
            ? "/"
            : DotNetNuke.Common.Globals.ApplicationPath;
    }

    private bool IsTrustedBrowser(int userId)
    {
        if (userId <= 0 || this.Request == null)
        {
            return false;
        }

        HttpCookie cookie = this.Request.Cookies[this.TrustedCookieName(userId)];
        string token = cookie != null ? cookie.Value : string.Empty;
        if (string.IsNullOrWhiteSpace(token))
        {
            return false;
        }

        try
        {
            string tokenHash = Convert.ToBase64String(this.HashTrustedToken(token));
            int trustedBrowserId = DataProvider.Instance().ExecuteScalar<int>(
                "Jacaranda2FA_ValidateTrustedBrowser",
                this.PortalId,
                userId,
                tokenHash);

            if (trustedBrowserId > 0)
            {
                return true;
            }

            this.ExpireTrustedBrowserCookie(userId);
            return false;
        }
        catch (Exception ex)
        {
            // A trusted-browser storage failure must fail closed: require normal 2FA.
            Exceptions.LogException(ex);
            this.LogDiagnostic("Trusted-browser validation failed closed; normal second-factor verification will be required.");
            return false;
        }
    }

    private bool TryRememberTrustedBrowser(int userId)
    {
        if (userId <= 0 || this.Response == null)
        {
            return false;
        }

        try
        {
            string token = this.GenerateTrustedToken();
            string tokenHash = Convert.ToBase64String(this.HashTrustedToken(token));
            DateTime expiresUtc = DateTime.UtcNow.AddDays(TrustedBrowserDays);

            DataProvider.Instance().ExecuteNonQuery(
                "Jacaranda2FA_AddTrustedBrowser",
                this.PortalId,
                userId,
                tokenHash,
                expiresUtc);

            HttpCookie cookie = new HttpCookie(this.TrustedCookieName(userId), token);
            cookie.HttpOnly = true;
            cookie.Secure = this.Request != null && this.Request.IsSecureConnection;
            cookie.Path = this.TrustedCookiePath();
            cookie.Expires = expiresUtc.ToLocalTime();
            cookie.SameSite = SameSiteMode.Lax;
            this.Response.Cookies.Set(cookie);

            this.LogDiagnostic("A trusted-browser token was created after successful second-factor verification.");
            return true;
        }
        catch (Exception ex)
        {
            // Login still succeeds; only the convenience token is withheld.
            Exceptions.LogException(ex);
            this.LogDiagnostic("Second-factor verification succeeded, but the trusted-browser token could not be created.");
            return false;
        }
    }

    private void ExpireTrustedBrowserCookie(int userId)
    {
        if (this.Response == null || userId <= 0)
        {
            return;
        }

        HttpCookie cookie = new HttpCookie(this.TrustedCookieName(userId), string.Empty);
        cookie.HttpOnly = true;
        cookie.Secure = this.Request != null && this.Request.IsSecureConnection;
        cookie.Path = this.TrustedCookiePath();
        cookie.Expires = DateTime.Now.AddDays(-1);
        cookie.SameSite = SameSiteMode.Lax;
        this.Response.Cookies.Set(cookie);
    }

    private string GenerateTrustedToken()
    {
        byte[] bytes = new byte[32];
        using (RandomNumberGenerator rng = RandomNumberGenerator.Create())
        {
            rng.GetBytes(bytes);
        }

        return Convert.ToBase64String(bytes)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    private byte[] HashTrustedToken(string token)
    {
        using (SHA256 sha = SHA256.Create())
        {
            return sha.ComputeHash(Encoding.UTF8.GetBytes(token ?? string.Empty));
        }
    }

    private string NormalizeRecoveryCode(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return string.Empty;
        }

        StringBuilder builder = new StringBuilder(12);
        string upper = value.Trim().ToUpperInvariant();
        for (int i = 0; i < upper.Length; i++)
        {
            char c = upper[i];
            if ((c >= 'A' && c <= 'Z') || (c >= '2' && c <= '9'))
            {
                builder.Append(c);
            }
        }
        return builder.ToString();
    }

    private bool HasUnusedRecoveryCodes(int userId)
    {
        if (userId <= 0)
        {
            return false;
        }

        try
        {
            int count = DataProvider.Instance().ExecuteScalar<int>("Jacaranda2FA_CountRecoveryCodes", this.PortalId, userId);
            return count > 0;
        }
        catch (Exception ex)
        {
            Exceptions.LogException(ex);
            return false;
        }
    }

    private bool TryConsumeRecoveryCode(int userId, string normalizedCode)
    {
        int matchingId = 0;
        try
        {
            using (IDataReader reader = DataProvider.Instance().ExecuteReader("Jacaranda2FA_GetRecoveryCodes", this.PortalId, userId))
            {
                while (reader.Read())
                {
                    int recoveryCodeId = Convert.ToInt32(reader["RecoveryCodeID"], CultureInfo.InvariantCulture);
                    string saltText = Convert.ToString(reader["CodeSalt"], CultureInfo.InvariantCulture);
                    string expectedText = Convert.ToString(reader["CodeHash"], CultureInfo.InvariantCulture);
                    if (string.IsNullOrEmpty(saltText) || string.IsNullOrEmpty(expectedText))
                    {
                        continue;
                    }

                    byte[] salt;
                    byte[] expected;
                    try
                    {
                        salt = Convert.FromBase64String(saltText);
                        expected = Convert.FromBase64String(expectedText);
                    }
                    catch (FormatException)
                    {
                        continue;
                    }

                    byte[] actual = this.HashCode(normalizedCode, salt);
                    if (this.FixedTimeEquals(expected, actual))
                    {
                        matchingId = recoveryCodeId;
                        break;
                    }
                }
            }

            if (matchingId <= 0)
            {
                return false;
            }

            int consumed = DataProvider.Instance().ExecuteScalar<int>("Jacaranda2FA_UseRecoveryCode", matchingId, this.PortalId, userId);
            return consumed == 1;
        }
        catch (Exception ex)
        {
            Exceptions.LogException(ex);
            this.ShowMessage("Recovery-code verification is temporarily unavailable. You can still use the emailed verification code.", true);
            return false;
        }
    }

    private string GenerateCode()
    {
        const uint range = 1000000U;
        uint limit = uint.MaxValue - (uint.MaxValue % range);
        uint value;
        byte[] bytes = new byte[4];

        using (RandomNumberGenerator rng = RandomNumberGenerator.Create())
        {
            do
            {
                rng.GetBytes(bytes);
                value = BitConverter.ToUInt32(bytes, 0);
            }
            while (value >= limit);
        }

        return (value % range).ToString("D6", CultureInfo.InvariantCulture);
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

    private bool CodeMatches(string code)
    {
        string saltText = Convert.ToString(this.Session[this.Key("CodeSalt")], CultureInfo.InvariantCulture);
        string expectedText = Convert.ToString(this.Session[this.Key("CodeHash")], CultureInfo.InvariantCulture);
        if (string.IsNullOrEmpty(saltText) || string.IsNullOrEmpty(expectedText))
        {
            return false;
        }

        byte[] salt;
        byte[] expected;
        try
        {
            salt = Convert.FromBase64String(saltText);
            expected = Convert.FromBase64String(expectedText);
        }
        catch (FormatException)
        {
            return false;
        }

        byte[] actual = this.HashCode(code, salt);
        return this.FixedTimeEquals(expected, actual);
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
        if (string.IsNullOrEmpty(value) || value.Length != CodeDigits)
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

    private bool HasChallenge()
    {
        return this.Session[this.Key("UserId")] != null &&
               this.Session[this.Key("CodeHash")] != null &&
               this.Session[this.Key("CodeSalt")] != null;
    }

    private void ClearChallenge()
    {
        string[] names =
        {
            "UserId", "UserName", "LoginStatus", "RememberMe", "ResendCount",
            "CodeSalt", "CodeHash", "ExpiresUtcTicks", "LastSentUtcTicks", "Attempts"
        };

        for (int i = 0; i < names.Length; i++)
        {
            this.Session.Remove(this.Key(names[i]));
        }
    }

    private int GetSessionInt(string name)
    {
        object value = this.Session[this.Key(name)];
        if (value == null)
        {
            return 0;
        }

        return Convert.ToInt32(value, CultureInfo.InvariantCulture);
    }

    private long GetSessionLong(string name)
    {
        object value = this.Session[this.Key(name)];
        if (value == null)
        {
            return 0L;
        }

        return Convert.ToInt64(value, CultureInfo.InvariantCulture);
    }

    private bool GetSessionBool(string name)
    {
        object value = this.Session[this.Key(name)];
        if (value == null)
        {
            return false;
        }

        return Convert.ToBoolean(value, CultureInfo.InvariantCulture);
    }

    private void LogDiagnostic(string message)
    {
        // Trial diagnostics only. Never include usernames, passwords, OTP values, email addresses,
        // session identifiers or other authentication secrets in these messages. Logging failure
        // must never interrupt the authentication flow.
        try
        {
            LogInfo log = new LogInfo();
            log.LogTypeKey = "ADMIN_ALERT";
            log.LogPortalID = this.PortalId;
            log.LogUserID = Null.NullInteger;
            log.LogProperties.Add(new LogDetailInfo("Jacaranda2FA " + Version, message));
            LogController.Instance.AddLog(log);
        }
        catch
        {
            // Diagnostic logging is deliberately non-fatal.
        }
    }

    private string MaskEmail(string email)
    {
        if (string.IsNullOrWhiteSpace(email))
        {
            return "the registered email address";
        }

        int at = email.IndexOf('@');
        if (at <= 0 || at == email.Length - 1)
        {
            return "the registered email address";
        }

        string local = email.Substring(0, at);
        string domain = email.Substring(at + 1);
        string visible = local.Substring(0, 1);
        int starCount = Math.Max(3, Math.Min(6, local.Length - 1));
        return visible + new string('*', starCount) + "@" + domain;
    }

    private void ShowLoginPanel()
    {
        this.pnlLogin.Visible = true;
        this.pnlVerify.Visible = false;
    }

    private void ShowVerificationPanel()
    {
        this.pnlLogin.Visible = false;
        this.pnlVerify.Visible = true;

        int userId = this.GetSessionInt("UserId");
        UserInfo user = userId > 0 ? UserController.GetUserById(this.PortalId, userId) : null;
        this.litDestination.Text = HttpUtility.HtmlEncode(user != null ? this.MaskEmail(user.Email) : "the registered email address");
        this.pnlRecovery.Visible = this.HasUnusedRecoveryCodes(userId);
    }

    private void ShowMessage(string message, bool isError)
    {
        this.messagePanel.Visible = true;
        this.messagePanel.Attributes["class"] = isError ? "dnnFormMessage dnnFormError jacaranda2fa-message" : "dnnFormMessage dnnFormInfo jacaranda2fa-message";
        this.litMessage.Text = HttpUtility.HtmlEncode(message);
    }

    private void HideMessage()
    {
        this.messagePanel.Visible = false;
        this.litMessage.Text = string.Empty;
    }
</script>

<link rel="stylesheet" type="text/css" href="<%= ResolveUrl("~/DesktopModules/AuthenticationServices/Jacaranda2FA/Login.css") %>" />

<div class="dnnForm dnnLoginService dnnClear jacaranda2fa-login">
    <asp:HiddenField ID="actionField" runat="server" />
    <div id="messagePanel" runat="server" visible="false" class="dnnFormMessage jacaranda2fa-message">
        <asp:Literal ID="litMessage" runat="server" />
    </div>

    <asp:Panel ID="pnlLogin" runat="server">
        <div class="jacaranda2fa-intro">
            <strong>Jacaranda2FA <span class="jacaranda2fa-version">00.00.15</span></strong><br />
            Enter your normal DNN username and password. If the current Jacaranda2FA policy requires a second factor for your account, a six-digit code will be sent to the email address registered on your account.
        </div>

        <div class="dnnFormItem">
            <div class="dnnLabel"><asp:Label ID="lblUsername" runat="server" AssociatedControlID="txtUsername" CssClass="dnnFormLabel" Text="Username" /></div>
            <asp:TextBox ID="txtUsername" runat="server" />
        </div>
        <div class="dnnFormItem">
            <div class="dnnLabel"><asp:Label ID="lblPassword" runat="server" AssociatedControlID="txtPassword" CssClass="dnnFormLabel" Text="Password" /></div>
            <asp:TextBox ID="txtPassword" runat="server" TextMode="Password" />
        </div>
        <div class="dnnFormItem">
            <asp:Label ID="lblRemember" runat="server" CssClass="dnnFormLabel" Text="Keep me signed in" />
            <span class="dnnLoginRememberMe"><asp:CheckBox ID="chkRemember" runat="server" /> <span class="jacaranda2fa-help">DNN persistent sign-in. This is separate from trusting a browser for 2FA.</span></span>
        </div>
        <div class="dnnFormItem jacaranda2fa-actions">
            <span class="dnnFormLabel">&nbsp;</span>
            <asp:Button ID="cmdLogin" runat="server" CssClass="dnnPrimaryAction" Text="Sign in" CausesValidation="false" UseSubmitBehavior="true" />
            <asp:HyperLink ID="cancelLink" runat="server" CssClass="dnnSecondaryAction" Text="Cancel" />
        </div>
        <div class="dnnFormItem">
            <span class="dnnFormLabel">&nbsp;</span>
            <div class="dnnLoginActions">
                <ul class="dnnActions dnnClear">
                    <li id="registerRow" runat="server"><asp:HyperLink ID="registerLink" runat="server" CssClass="dnnSecondaryAction" Text="Register" /></li>
                    <li><asp:HyperLink ID="passwordLink" runat="server" CssClass="dnnSecondaryAction" Text="Forgot password?" /></li>
                </ul>
            </div>
        </div>
    </asp:Panel>

    <asp:Panel ID="pnlVerify" runat="server" Visible="false">
        <div class="jacaranda2fa-intro">
            <strong>Verify your sign-in</strong><br />
            We sent a six-digit code to <strong><asp:Literal ID="litDestination" runat="server" /></strong>. The code expires after five minutes.
        </div>
        <div class="dnnFormItem jacaranda2fa-code-row">
            <div class="dnnLabel"><asp:Label ID="lblCode" runat="server" AssociatedControlID="txtCode" CssClass="dnnFormLabel" Text="Verification code" /></div>
            <asp:TextBox ID="txtCode" runat="server" CssClass="jacaranda2fa-code" />
        </div>
        <div class="dnnFormItem jacaranda2fa-trust-row">
            <asp:Label ID="lblTrustBrowser" runat="server" CssClass="dnnFormLabel" Text="Remember this browser for 2FA" />
            <span><asp:CheckBox ID="chkTrustBrowser" runat="server" /> <span class="jacaranda2fa-help">Skip the email/recovery-code step on this browser for 30 days after your password is accepted.</span></span>
        </div>
        <div class="dnnFormItem jacaranda2fa-actions">
            <span class="dnnFormLabel">&nbsp;</span>
            <asp:Button ID="cmdVerify" runat="server" CssClass="dnnPrimaryAction" Text="Verify code" CausesValidation="false" UseSubmitBehavior="true" />
            <asp:Button ID="cmdCancelVerification" runat="server" CssClass="dnnSecondaryAction" Text="Cancel 2FA / Return to login options" CausesValidation="false" UseSubmitBehavior="true" />
        </div>
        <div class="dnnFormItem jacaranda2fa-resend-row">
            <span class="dnnFormLabel">&nbsp;</span>
            <asp:Button ID="cmdResend" runat="server" CssClass="dnnSecondaryAction" Text="Resend code" CausesValidation="false" UseSubmitBehavior="true" />
        </div>
        <asp:Panel ID="pnlRecovery" runat="server" Visible="false" CssClass="jacaranda2fa-recovery">
            <div class="jacaranda2fa-recovery-heading"><strong>Recovery code</strong><br />If you cannot access the email code, you may use one unused Jacaranda2FA recovery code for this account.</div>
            <div class="dnnFormItem">
                <div class="dnnLabel"><asp:Label ID="lblRecoveryCode" runat="server" AssociatedControlID="txtRecoveryCode" CssClass="dnnFormLabel" Text="Recovery code" /></div>
                <asp:TextBox ID="txtRecoveryCode" runat="server" CssClass="jacaranda2fa-recovery-code" />
            </div>
            <div class="dnnFormItem jacaranda2fa-actions">
                <span class="dnnFormLabel">&nbsp;</span>
                <asp:Button ID="cmdRecovery" runat="server" CssClass="dnnSecondaryAction" Text="Use recovery code" CausesValidation="false" UseSubmitBehavior="true" />
            </div>
        </asp:Panel>
    </asp:Panel>
</div>
