using System;
using System.Drawing;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace ChiaKey.Settings
{
    internal sealed class UpdatePane : Panel
    {
        private readonly UpdateService service = UpdateService.Default();

        private sealed class Section : GroupBox
        {
            internal readonly CheckBox automatic = new CheckBox();
            internal readonly Label latest = new Label(), current = new Label(), checkedAt = new Label(), status = new Label();
            internal readonly Button check = new Button(), install = new Button();
            internal readonly FlowLayoutPanel options = new FlowLayoutPanel();
            internal UpdateOffer offer;
            internal bool busy;

            internal Section(string title, string option)
            {
                SuspendLayout();
                DoubleBuffered = true;
                UseCompatibleTextRendering = true;
                Text = title;
                Dock = DockStyle.Top;
                AutoSize = true;
                AutoSizeMode = AutoSizeMode.GrowAndShrink;
                Padding = new Padding(12, 6, 12, 10);
                Margin = new Padding(0, 0, 0, 12);
                TableLayoutPanel rows = new TableLayoutPanel {
                    Dock = DockStyle.Top, AutoSize = true, ColumnCount = 3, RowCount = 5,
                    Margin = Padding.Empty, Padding = Padding.Empty };
                rows.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
                rows.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
                rows.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
                for (int i = 0; i < 5; ++i) rows.RowStyles.Add(new RowStyle(SizeType.AutoSize));
                Row(rows, Ui.Text("最新版本："), latest, 0);
                Row(rows, Ui.Text("目前版本："), current, 1);
                Row(rows, Ui.Text("上次檢查："), checkedAt, 2);
                latest.Text = Ui.Text("尚未檢查"); checkedAt.Text = Ui.Text("尚未檢查");
                automatic.Text = option; automatic.AutoSize = true;
                automatic.UseCompatibleTextRendering = true;
                automatic.Margin = new Padding(0, 8, 0, 4);
                options.AutoSize = true; options.Dock = DockStyle.Fill;
                options.Margin = Padding.Empty;
                options.Controls.Add(automatic);
                rows.Controls.Add(options, 0, 3); rows.SetColumnSpan(options, 3);
                check.Text = Ui.Text("檢查更新");
                install.Text = Ui.Text("下載安裝");
                foreach (Button button in new[] { check, install })
                {
                    button.FlatStyle = FlatStyle.System;
                    button.UseVisualStyleBackColor = true;
                    button.AutoSize = true;
                    button.AutoSizeMode = AutoSizeMode.GrowAndShrink;
                    button.MinimumSize = new Size(112, 30);
                    button.Margin = new Padding(12, 0, 0, 4);
                }
                rows.Controls.Add(check, 2, 0); rows.Controls.Add(install, 2, 1);
                status.AutoSize = true; status.UseCompatibleTextRendering = true;
                status.Margin = new Padding(0, 4, 0, 0);
                status.Visible = false;
                status.TextChanged += delegate { status.Visible = status.Text.Length > 0; };
                rows.Controls.Add(status, 0, 4); rows.SetColumnSpan(status, 3);
                rows.SizeChanged += delegate { status.MaximumSize = new Size(rows.ClientSize.Width, 0); };
                Controls.Add(rows);
                Buttons();
                ResumeLayout(true);
            }

            private void Row(TableLayoutPanel rows, string text, Label value, int row)
            {
                Label caption = new Label { Text = text, AutoSize = true,
                    UseCompatibleTextRendering = true, Margin = new Padding(0, 4, 6, 4) };
                value.AutoSize = true; value.UseCompatibleTextRendering = true;
                value.Margin = new Padding(0, 4, 0, 4);
                value.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
                value.AutoEllipsis = true;
                rows.Controls.Add(caption, 0, row); rows.Controls.Add(value, 1, row);
            }

            internal void Buttons()
            {
                check.Enabled = !busy;
                install.Visible = offer != null;
                install.Enabled = !busy && offer != null;
            }
        }

        private readonly Section app;
        private readonly Section lexicon;
        private readonly CheckBox beta = new CheckBox { Text = Ui.Text("接受 Beta 版"), AutoSize = true,
            UseCompatibleTextRendering = true, Margin = new Padding(16, 8, 0, 4) };

        internal UpdatePane(Action changed)
        {
            SuspendLayout();
            DoubleBuffered = true;
            AutoScroll = true;
            app = new Section(Ui.Text("輸入法更新"), Ui.Text("自動檢查輸入法更新"));
            lexicon = new Section(Ui.Text("詞庫更新"), Ui.Text("自動更新詞庫"));
            TableLayoutPanel sections = new TableLayoutPanel { Dock = DockStyle.Top, AutoSize = true,
                ColumnCount = 1, RowCount = 2, Padding = new Padding(16), Margin = Padding.Empty };
            sections.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            sections.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            sections.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            sections.Controls.Add(app, 0, 0); sections.Controls.Add(lexicon, 0, 1);
            Controls.Add(sections);
            app.automatic.Checked = service.Preferences.GetBool("AutoUpdateApp", true);
            lexicon.automatic.Checked = service.Preferences.GetBool("AutoUpdateLexicon", true);
            beta.Checked = service.Preferences.GetBool("IncludeBetaReleases", false);
            app.options.Controls.Add(beta);
            beta.CheckedChanged += async delegate
            {
                changed();
                app.offer = null; app.Buttons();
                if (Visible) await Check(app, false);
            };
            app.automatic.CheckedChanged += delegate { changed(); };
            lexicon.automatic.CheckedChanged += delegate { changed(); };
            app.check.Click += async delegate { await Check(app, false); };
            lexicon.check.Click += async delegate { await Check(lexicon, true); };
            app.install.Click += async delegate { await Install(app, false); };
            lexicon.install.Click += async delegate { await Install(lexicon, true); };
            VisibleChanged += async delegate
            {
                if (!Visible) return;
                await Task.WhenAll(Check(app, false), Check(lexicon, true));
            };
            app.current.Text = service.AppReleaseVersion;
            lexicon.current.Text = Ui.Text("尚未檢查");
            ResumeLayout(true);
        }

        private void RefreshCurrent()
        {
            app.current.Text = service.AppReleaseVersion;
            try { lexicon.current.Text = service.CurrentLexiconVersion(); }
            catch (Exception error) { lexicon.status.Text = Ui.Text("無法讀取詞庫：") + error.Message; }
        }

        private void SetBusy(Section section, bool isLexicon, bool busy)
        {
            section.busy = busy;
            if (!IsDisposed)
            {
                section.Buttons();
                if (!isLexicon) beta.Enabled = !busy;
            }
        }

        private async Task Check(Section section, bool isLexicon)
        {
            if (section.busy || IsDisposed) return;
            bool includeBeta = beta.Checked;
            section.offer = null;
            SetBusy(section, isLexicon, true);
            section.status.Text = Ui.Text("正在檢查更新…");
            try
            {
                string currentVersion = service.AppReleaseVersion;
                if (isLexicon)
                {
                    currentVersion = await Task.Run(delegate
                    {
                        service.RecoverLexicon();
                        return service.CurrentLexiconVersion();
                    });
                }
                if (IsDisposed) return;
                section.current.Text = currentVersion;
                UpdateOffer offer = await Task.Run(delegate
                {
                    if (isLexicon) return service.CheckLexicon(false);
                    return service.CheckApp(includeBeta, false);
                });
                if (IsDisposed) return;
                section.latest.Text = offer == null ? Ui.Text("無可用版本") : offer.Version;
                bool newer = offer != null && (isLexicon
                    ? UpdateService.CompareVersions(offer.Version, currentVersion)
                    : UpdateService.CompareAppVersions(offer.Version, service.AppUpdateVersion)) > 0;
                section.offer = newer ? offer : null;
                section.checkedAt.Text = DateTime.Now.ToString("yyyy-MM-dd HH:mm");
                section.status.Text = offer == null ? Ui.Text("無可用版本") :
                    newer ? Ui.Text("有新版本可供下載。") : Ui.Text("已是最新版本。");
            }
            catch (Exception error) { if (!IsDisposed) section.status.Text = Ui.Text("檢查失敗：") + error.Message; }
            finally { SetBusy(section, isLexicon, false); }
        }

        private async Task Install(Section section, bool isLexicon)
        {
            UpdateOffer offer = section.offer;
            if (offer == null) return;
            SetBusy(section, isLexicon, true);
            section.status.Text = Ui.Text("正在下載更新…");
            try
            {
                string installer = null;
                await Task.Run(delegate
                {
                    if (isLexicon) service.InstallLexicon(offer);
                    else installer = service.DownloadApp(offer);
                });
                if (IsDisposed) return;
                if (!isLexicon) UpdateService.InstallApp(installer, offer.Sha256);
                else { section.offer = null; RefreshCurrent(); }
                section.status.Text = isLexicon ? Ui.Text("詞庫已更新。") : Ui.Text("已開啟安裝器。");
            }
            catch (Exception error) { if (!IsDisposed) section.status.Text = Ui.Text("更新失敗：") + error.Message; }
            finally { SetBusy(section, isLexicon, false); }
        }

        internal void Save() { service.Configure(app.automatic.Checked, lexicon.automatic.Checked, beta.Checked); }
    }

    // What the background helper opens for an app update: nothing is downloaded until the
    // user agrees, and each step is reported until the window is closed.
    internal sealed class AppUpdatePrompt : Form
    {
        private readonly UpdateService service;
        private readonly UpdateOffer offer;
        private readonly Label message = new Label { AutoSize = true, MaximumSize = new Size(400, 0),
            Margin = new Padding(0, 0, 0, 14) };
        private readonly ProgressBar progress = new ProgressBar { Style = ProgressBarStyle.Marquee,
            Size = new Size(400, 16), Margin = new Padding(0, 0, 0, 14), Visible = false };
        private readonly Button install = PreferenceLayout.Button(Ui.Text("下載並安裝"));
        private readonly Button later = PreferenceLayout.Button(Ui.Text("稍後提醒"));
        private readonly Button skip = PreferenceLayout.Button(Ui.Text("略過這個版本"));
        private readonly Button close = PreferenceLayout.Button(Ui.Text("關閉"));

        internal AppUpdatePrompt(UpdateService service, UpdateOffer offer)
        {
            this.service = service;
            this.offer = offer;
            SuspendLayout();
            AutoScaleDimensions = new SizeF(96F, 96F);
            AutoScaleMode = AutoScaleMode.Dpi;
            Text = Ui.Text("千秋輸入法更新");
            Font = new Font("Microsoft JhengHei UI", 9F);
            Icon = PhraseEditorForm.LoadIcon("app.ico");
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            AutoSize = true;
            AutoSizeMode = AutoSizeMode.GrowAndShrink;
            Padding = new Padding(18, 16, 18, 12);
            message.Text = Ui.Text("千秋輸入法 ") + offer.Version + Ui.Text(" 已推出，目前使用的是 ") +
                service.AppReleaseVersion + Ui.Text("。") + "\n\n" +
                Ui.Text("要下載並安裝嗎？安裝時 Windows 會詢問是否允許變更。");
            FlowLayoutPanel buttons = new FlowLayoutPanel { AutoSize = true, WrapContents = false,
                FlowDirection = FlowDirection.RightToLeft, Anchor = AnchorStyles.Right, Margin = Padding.Empty };
            foreach (Button button in new[] { close, install, later, skip })
            {
                button.Margin = new Padding(8, 0, 0, 0);
                buttons.Controls.Add(button);
            }
            close.Visible = false;
            TableLayoutPanel layout = new TableLayoutPanel { AutoSize = true, ColumnCount = 1,
                Dock = DockStyle.Fill, Margin = Padding.Empty };
            layout.Controls.Add(message);
            layout.Controls.Add(progress);
            layout.Controls.Add(buttons);
            Controls.Add(layout);
            install.Click += async delegate { await Install(); };
            later.Click += delegate { Close(); };
            skip.Click += delegate
            {
                Plist preferences = service.Preferences;
                preferences.SetString("SkippedAppVersion", offer.Version);
                preferences.Save();
                Close();
            };
            close.Click += delegate { Close(); };
            AcceptButton = install;
            CancelButton = later;
            ResumeLayout(true);
        }

        private async Task Install()
        {
            install.Visible = later.Visible = skip.Visible = false;
            progress.Visible = true;
            message.Text = Ui.Text("正在下載千秋輸入法 ") + offer.Version + "…";
            try
            {
                string installer = await Task.Run(delegate { return service.DownloadApp(offer); });
                message.Text = Ui.Text("正在安裝千秋輸入法 ") + offer.Version + "…";
                System.Diagnostics.Process process = UpdateService.InstallApp(installer, offer.Sha256, null, true);
                int code = await Task.Run(delegate
                {
                    using (process) { process.WaitForExit(); return process.ExitCode; }
                });
                message.Text = code == 0
                    ? Ui.Text("已更新至 ") + offer.Version + Ui.Text("。開著的程式會在輸入閒置時自動載入新版。")
                    : Ui.Text("安裝沒有完成（代碼 ") + code + Ui.Text("）。");
            }
            catch (System.ComponentModel.Win32Exception error)
            {
                // 1223: the user declined the UAC prompt
                message.Text = error.NativeErrorCode == 1223 ? Ui.Text("已取消安裝。") : Ui.Text("更新失敗：") + error.Message;
            }
            catch (Exception error) { message.Text = Ui.Text("更新失敗：") + error.Message; }
            progress.Visible = false;
            close.Visible = true;
            AcceptButton = close;
            CancelButton = close;
            close.Focus();
        }
    }
}
