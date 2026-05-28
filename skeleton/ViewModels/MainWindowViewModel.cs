using System.Collections.ObjectModel;
using System.Reflection;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using skeleton.Diagnostics;
using skeleton.Models;
using skeleton.Settings;
using skeleton.Storage;
using skeleton.UI;
using skeleton.Update;
using skeleton.Views;

namespace skeleton.ViewModels;

public sealed partial class MainWindowViewModel : ViewModelBase
{
    private readonly AppConfigStore _store;
    private readonly Dictionary<string, (TabItem Page, Control FocusTarget)> _navByToken = new(StringComparer.Ordinal);
    private readonly List<(ScrollViewer Panel, List<OptionBinding> Bindings)> _optionPanels = [];
    private IReadOnlyList<FontSizeBinding> _fontSizeBindings = [];
    private IReadOnlyList<FontFamilyBinding> _fontFamilyBindings = [];
    private IReadOnlyList<RadioButton>? _themeRadios;
    private IReadOnlyDictionary<string, CheckBox>? _appCheckboxes;
    private IReadOnlyList<RadioButton>? _demoRadios;
    private bool _updateCheckStarted;
    private bool _suppressTabRestore;
    private bool _deferTabContentBuild = true;
    private readonly HashSet<Button> _wiredPickers = [];

    [ObservableProperty] private string _statusText = string.Empty;
    [ObservableProperty] private string _searchQuery = string.Empty;
    [ObservableProperty] private UiThemeKind _selectedTheme = UiThemeKind.System;
    [ObservableProperty] private bool _rememberLastSelectedTab;
    [ObservableProperty] private bool _checkForUpdates = true;
    [ObservableProperty] private bool _automaticallyInstallUpdates;
    [ObservableProperty] private bool _enableDebugLogging;
    [ObservableProperty] private bool _searchEnabled = SettingCatalog.All.Count > 0;
    [ObservableProperty] private int _selectedTabIndex;
    [ObservableProperty] private string _versionText = string.Empty;
    [ObservableProperty] private string _repoUrl = AppBranding.RepoUrl;
    [ObservableProperty] private string _aboutLeadText =
        "A cross-platform Avalonia app skeleton for .NET C# projects with theming, tabs, search, and reusable setting panels.";

    public ObservableCollection<SettingSearchHit> SearchResults { get; } = [];
    public ObservableCollection<TabItem> TabItems { get; } = [];
    public ObservableCollection<string> DemoListItems { get; } = ["Item 1", "Item 2", "Item 3"];
    public ObservableCollection<FileListEntry> FileListItems { get; } =
    [
        new() { Path = @"C:\Example\readme.txt" },
        new() { Path = @"C:\Example\config.ini" },
    ];
    public ObservableCollection<(string Label, UiThemeKind Theme)> ThemeOptions { get; } =
    [
        ("System", UiThemeKind.System),
        ("Light", UiThemeKind.Light),
        ("Dark", UiThemeKind.Dark),
        ("Dracula Light", UiThemeKind.DraculaLight),
        ("Dracula Dark", UiThemeKind.DraculaDark),
    ];

    [ObservableProperty] private int _selectedDemoRadioIndex;
    [ObservableProperty] private bool _isTextEditorTabSelected;

    internal const string GeneralTabKey = "General";
    internal const string AppSettingsTabKey = "AppSettings";
    internal const string TextEditorTabKey = "TextEditor";
    internal const string LogTabKey = "Log";
    internal const string GridViewTabKey = "GridView";
    internal const string AboutTabKey = "About";

    private readonly HashSet<string> _builtTabs = new(StringComparer.Ordinal);
    private GeneralCompositePending? _generalCompositesPending;

    private sealed record GeneralCompositePending(
        TabItem Page,
        StackPanel Stack,
        IReadOnlyList<SettingDefinition> Definitions);

    public MainWindowViewModel(AppConfigStore store, UiPreferences prefs)
    {
        _store = store;
        DebugLog.EntryAdded += OnDebugLogEntryAdded;
        LoadPreferences(prefs);
        BuildTabs();
        ApplyPendingStartupStatusMessage();
    }

    partial void OnSearchQueryChanged(string value) => UpdateSearch(value);

    partial void OnSelectedThemeChanged(UiThemeKind value)
    {
        SyncPreferencesFromPanel();
        ThemeChanged?.Invoke(value);
    }

    partial void OnRememberLastSelectedTabChanged(bool value) => SyncPreferencesFromPanel();
    partial void OnCheckForUpdatesChanged(bool value)
    {
        if (!value)
            AutomaticallyInstallUpdates = false;
        SyncPreferencesFromPanel();
    }

    partial void OnAutomaticallyInstallUpdatesChanged(bool value) => SyncPreferencesFromPanel();

    partial void OnEnableDebugLoggingChanged(bool value)
    {
        DebugLog.Enabled = value;
        SyncPreferencesFromPanel();
        RefreshLogViewer();
    }

    partial void OnSelectedTabIndexChanged(int value)
    {
        IsTextEditorTabSelected = IsTextEditorTab(value);

        if (value >= 0 && value < TabItems.Count)
            EnsureTabContent(TabItems[value].Name);

        if (_suppressTabRestore || !RememberLastSelectedTab)
            return;
        if (SelectedTabIndex >= 0 && SelectedTabIndex < TabItems.Count)
            _uiPrefs.LastSelectedTabKey = TabItems[SelectedTabIndex].Name;
    }

    internal TextBox? TextEditor { get; private set; }
    internal TextBox? LogViewer { get; private set; }
    internal DataGrid? FileGrid { get; private set; }

    public event Action<UiThemeKind>? ThemeChanged;
    public event Action? FontsChanged;

    private UiPreferences _uiPrefs = new();
    private UiPreferences _lastPersistedPrefs = new();

    private enum PrefsSaveReason
    {
        Apply,
        WindowClose,
    }

    private void LoadPreferences(UiPreferences prefs)
    {
        _uiPrefs = prefs;
        _uiPrefs.MainFontSize = UiFontService.Clamp(prefs.MainFontSize);
        _uiPrefs.TabFontSize = UiFontService.Clamp(prefs.TabFontSize);
        _uiPrefs.TokenFontSize = UiFontService.Clamp(prefs.TokenFontSize);
        _uiPrefs.MainFontFamily = UiFontFamilies.NormalizeMain(prefs.MainFontFamily);
        _uiPrefs.MonoFontFamily = UiFontFamilies.NormalizeMono(prefs.MonoFontFamily);
        SelectedTheme = prefs.Theme;
        RememberLastSelectedTab = prefs.RememberLastSelectedTab;
        CheckForUpdates = prefs.CheckForUpdates;
        AutomaticallyInstallUpdates = prefs.AutomaticallyInstallUpdates;
        EnableDebugLogging = prefs.EnableDebugLogging;
        _lastPersistedPrefs = prefs.Clone();

        var version = Assembly.GetExecutingAssembly()
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? "?";
        VersionText = $"{AppBranding.DisplayName} v{version}  - Copyright © 2026 {AppBranding.CopyrightHolder}";
    }

    private void BuildTabs()
    {
        TabItems.Clear();
        _navByToken.Clear();
        _optionPanels.Clear();
        _builtTabs.Clear();
        _wiredPickers.Clear();
        _generalCompositesPending = null;

        TabItems.Add(new TabItem { Header = "General", Name = GeneralTabKey, Content = null });
        TabItems.Add(new TabItem { Header = "App Settings", Name = AppSettingsTabKey, Content = null });
        TabItems.Add(new TabItem { Header = "Text Editor", Name = TextEditorTabKey, Content = null });
        TabItems.Add(new TabItem { Header = "Log", Name = LogTabKey, Content = null });
        TabItems.Add(new TabItem { Header = "Grid View", Name = GridViewTabKey, Content = null });
        TabItems.Add(new TabItem { Header = "About", Name = AboutTabKey, Content = null });

        ApplyLastSelectedTab();
        IsTextEditorTabSelected = IsTextEditorTab(SelectedTabIndex);
    }

    public void EndDeferTabContentBuild() => _deferTabContentBuild = false;

    public void EnsureSelectedTabContent()
    {
        if (SelectedTabIndex < 0 || SelectedTabIndex >= TabItems.Count)
            return;

        EnsureTabContent(TabItems[SelectedTabIndex].Name);
    }

    public void EnsureTabContent(string? tabKey)
    {
        if (_deferTabContentBuild || string.IsNullOrEmpty(tabKey) || _builtTabs.Contains(tabKey))
            return;

        var tab = FindTab(tabKey);
        if (tab is null)
            return;

        switch (tabKey)
        {
            case GeneralTabKey:
                BuildGeneralTabContent(tab);
                break;
            case AppSettingsTabKey:
                tab.Content = AppSettingsPanelBuilder.Build(tab, this);
                break;
            case TextEditorTabKey:
                BuildTextEditorTabContent(tab);
                break;
            case LogTabKey:
                BuildLogTabContent(tab);
                break;
            case GridViewTabKey:
                BuildGridViewTabContent(tab);
                break;
            case AboutTabKey:
                tab.Content = AboutTabBuilder.Build(this);
                break;
            default:
                return;
        }

        _builtTabs.Add(tabKey);
    }

    private TabItem? FindTab(string name)
    {
        foreach (var item in TabItems)
        {
            if (string.Equals(item.Name, name, StringComparison.Ordinal))
                return item;
        }

        return null;
    }

    internal void WireAppFontSizes(TabItem tab, IReadOnlyList<FontSizeBinding> bindings)
    {
        _fontSizeBindings = bindings;
        OptionPanelPreferenceBridge.WireDirectFontSizes(bindings, _uiPrefs, OnFontPreferencesChanged);
        foreach (var binding in bindings)
            _navByToken[binding.Token] = (tab, binding.FocusTarget);
    }

    internal void WireAppFontFamilies(TabItem tab, IReadOnlyList<FontFamilyBinding> bindings)
    {
        _fontFamilyBindings = bindings;
        OptionPanelPreferenceBridge.WireFontFamilies(bindings, _uiPrefs, OnFontPreferencesChanged);
        foreach (var binding in bindings)
            _navByToken[binding.Token] = (tab, binding.FocusTarget);
    }

    private void OnFontPreferencesChanged()
    {
        if (Application.Current is { } app)
            UiFontService.Apply(app, _uiPrefs);
        FontsChanged?.Invoke();
    }

    internal void RegisterNavTarget(TabItem tab, string token, Control focusTarget) =>
        _navByToken[token] = (tab, focusTarget);

    internal void RegisterAppSettingsControls(
        IReadOnlyList<RadioButton> themeRadios,
        IReadOnlyDictionary<string, CheckBox> checkboxes)
    {
        _themeRadios = themeRadios;
        _appCheckboxes = checkboxes;
    }

    internal void RegisterDemoRadios(IReadOnlyList<RadioButton> radios) =>
        _demoRadios = radios;

    private void BuildGeneralTabContent(TabItem page)
    {
        var (settingsPanel, bindings) = OptionPanelBuilder.BuildContent(
            SettingCategory.General,
            GeneralTabKey,
            (token, target) => _navByToken[token] = (page, target));

        var contentStack = new StackPanel
        {
            Spacing = 12,
            Margin = UiMetrics.TabContentPadding,
            Children = { settingsPanel },
        };

        var pageContent = OptionPanelBuilder.CreateScrollHost(contentStack);
        page.Content = pageContent;
        _optionPanels.Add((pageContent, bindings));

        var compositeDefs = SettingCatalog.ForCategory(SettingCategory.General)
            .Where(d => !SettingCatalog.IsPanelRow(d))
            .ToList();
        if (compositeDefs.Count == 0)
            return;

        _generalCompositesPending = new GeneralCompositePending(page, contentStack, compositeDefs);
        Dispatcher.UIThread.Post(EnsureGeneralCompositesReady, DispatcherPriority.Background);
    }

    private void EnsureGeneralCompositesReady()
    {
        if (_generalCompositesPending is not { } pending)
            return;

        if (!_builtTabs.Contains(GeneralTabKey)
            || FindTab(GeneralTabKey) != pending.Page
            || pending.Page.Content is not ScrollViewer { Content: StackPanel stack }
            || !ReferenceEquals(stack, pending.Stack)
            || stack.Children.Count > 1)
        {
            _generalCompositesPending = null;
            return;
        }

        var compositeChildren = new List<Control>();
        foreach (var def in pending.Definitions)
        {
            var (content, focusTarget) = CompositePanelBuilder.Build(def, this);
            compositeChildren.Add(UiTheme.CreateGroupBox(def.Label, content, nested: true));
            _navByToken[def.Token] = (pending.Page, focusTarget);
        }

        var compositeStack = new StackPanel { Spacing = 12 };
        foreach (var child in compositeChildren)
            compositeStack.Children.Add(child);

        var compositeGroup = UiTheme.CreateGroupBox("Composite control examples", compositeStack);
        compositeGroup.Margin = new Thickness(UiMetrics.TabContentPaddingPx, 0, UiMetrics.TabContentPaddingPx, 8);
        pending.Stack.Children.Add(compositeGroup);
        _generalCompositesPending = null;
    }

    private void BuildTextEditorTabContent(TabItem page)
    {
        var (content, editor) = RawTextTabBuilder.Build();
        page.Content = content;
        TextEditor = editor;
    }

    private void BuildLogTabContent(TabItem page)
    {
        var initialText = EnableDebugLogging ? DebugLog.GetText() : LogTabBuilder.DisabledPlaceholder;
        var (content, viewer) = LogTabBuilder.Build(initialText);
        page.Content = content;
        LogViewer = viewer;
    }

    private void BuildGridViewTabContent(TabItem page)
    {
        var (content, handle) = GridViewTabBuilder.Build(FileListItems);
        handle.AddButton.Click += (_, _) => AddFileCommand.Execute(null);
        handle.RemoveButton.Click += (_, _) => RemoveFileCommand.Execute(null);
        page.Content = content;
        FileGrid = handle.Grid;
    }

    private void RefreshLogViewer()
    {
        EnsureTabContent(LogTabKey);
        if (LogViewer is null)
            return;

        LogViewer.Text = EnableDebugLogging ? DebugLog.GetText() : LogTabBuilder.DisabledPlaceholder;
        if (EnableDebugLogging)
            LogViewer.CaretIndex = LogViewer.Text?.Length ?? 0;
    }

    private void OnDebugLogEntryAdded(string _)
    {
        Avalonia.Threading.Dispatcher.UIThread.Post(() =>
        {
            if (LogViewer is null || !EnableDebugLogging)
                return;

            LogViewer.Text = DebugLog.GetText();
            LogViewer.CaretIndex = LogViewer.Text?.Length ?? 0;
        });
    }

    private bool IsTextEditorTab(int tabIndex)
    {
        if (tabIndex < 0 || tabIndex >= TabItems.Count)
            return false;

        return string.Equals(TabItems[tabIndex].Name, TextEditorTabKey, StringComparison.Ordinal);
    }

    private void ApplyLastSelectedTab()
    {
        if (!_uiPrefs.RememberLastSelectedTab || string.IsNullOrEmpty(_uiPrefs.LastSelectedTabKey))
            return;

        for (var i = 0; i < TabItems.Count; i++)
        {
            if (string.Equals(TabItems[i].Name, _uiPrefs.LastSelectedTabKey, StringComparison.Ordinal))
            {
                _suppressTabRestore = true;
                SelectedTabIndex = i;
                _suppressTabRestore = false;
                return;
            }
        }
    }

    private void SyncPreferencesFromPanel()
    {
        _uiPrefs.Theme = SelectedTheme;
        _uiPrefs.RememberLastSelectedTab = RememberLastSelectedTab;
        _uiPrefs.CheckForUpdates = CheckForUpdates;
        _uiPrefs.AutomaticallyInstallUpdates = AutomaticallyInstallUpdates;
        _uiPrefs.EnableDebugLogging = EnableDebugLogging;
    }

    public void SaveWindowState(Window window)
    {
        _uiPrefs.Theme = SelectedTheme;
        if (window.WindowState != WindowState.Maximized)
        {
            _uiPrefs.WindowX = window.Position.X;
            _uiPrefs.WindowY = window.Position.Y;
            _uiPrefs.WindowWidth = (int)window.Width;
            _uiPrefs.WindowHeight = (int)window.Height;
        }
        _uiPrefs.WindowMaximized = window.WindowState == WindowState.Maximized;
        _uiPrefs.RememberLastSelectedTab = RememberLastSelectedTab;
        _uiPrefs.CheckForUpdates = CheckForUpdates;
        _uiPrefs.AutomaticallyInstallUpdates = AutomaticallyInstallUpdates;
        _uiPrefs.EnableDebugLogging = EnableDebugLogging;
        if (_uiPrefs.RememberLastSelectedTab && SelectedTabIndex >= 0 && SelectedTabIndex < TabItems.Count)
            _uiPrefs.LastSelectedTabKey = TabItems[SelectedTabIndex].Name;
        PersistUiPreferences(PrefsSaveReason.WindowClose);
    }

    public void RestoreWindowBounds(Window window)
    {
        if (_uiPrefs.WindowX is null || _uiPrefs.WindowY is null
            || _uiPrefs.WindowWidth is null || _uiPrefs.WindowHeight is null
            || _uiPrefs.WindowWidth < 200 || _uiPrefs.WindowHeight < 150)
        {
            window.WindowStartupLocation = WindowStartupLocation.CenterScreen;
            return;
        }

        window.WindowStartupLocation = WindowStartupLocation.Manual;
        window.Position = new PixelPoint(_uiPrefs.WindowX.Value, _uiPrefs.WindowY.Value);
        window.Width = _uiPrefs.WindowWidth.Value;
        window.Height = _uiPrefs.WindowHeight.Value;
        if (_uiPrefs.WindowMaximized)
            window.WindowState = WindowState.Maximized;
    }

    private void PersistUiPreferences(PrefsSaveReason reason)
    {
        var changes = CollectPreferenceChanges(_uiPrefs, _lastPersistedPrefs, reason);
        try
        {
            _store.SaveUiPreferences(_uiPrefs);
            _lastPersistedPrefs = _uiPrefs.Clone();
            if (DebugLog.Enabled)
            {
                foreach (var change in changes)
                    DebugLog.Write("Prefs", change);
            }
        }
        catch (Exception ex)
        {
            UpdaterLogger.Write($"Failed to save UI preferences: {ex}");
            if (DebugLog.Enabled)
                DebugLog.Write("Prefs", $"Failed to save UI preferences: {ex}");
        }
    }

    private static List<string> CollectPreferenceChanges(
        UiPreferences current,
        UiPreferences baseline,
        PrefsSaveReason reason)
    {
        var prefix = reason == PrefsSaveReason.Apply ? "Apply" : "Close";
        var changes = new List<string>();

        if (current.Theme != baseline.Theme)
            changes.Add($"{prefix}: ui_theme {baseline.Theme} → {current.Theme}");
        if (current.RememberLastSelectedTab != baseline.RememberLastSelectedTab)
            changes.Add($"{prefix}: ui_remember_last_tab {baseline.RememberLastSelectedTab} → {current.RememberLastSelectedTab}");
        if (current.CheckForUpdates != baseline.CheckForUpdates)
            changes.Add($"{prefix}: ui_check_for_updates {baseline.CheckForUpdates} → {current.CheckForUpdates}");
        if (current.AutomaticallyInstallUpdates != baseline.AutomaticallyInstallUpdates)
            changes.Add($"{prefix}: ui_auto_install_updates {baseline.AutomaticallyInstallUpdates} → {current.AutomaticallyInstallUpdates}");
        if (current.EnableDebugLogging != baseline.EnableDebugLogging)
            changes.Add($"{prefix}: ui_enable_debug_logging {baseline.EnableDebugLogging} → {current.EnableDebugLogging}");
        if (current.MainFontSize != baseline.MainFontSize)
            changes.Add($"{prefix}: ui_font_main {baseline.MainFontSize} → {current.MainFontSize}");
        if (current.TabFontSize != baseline.TabFontSize)
            changes.Add($"{prefix}: ui_font_tab {baseline.TabFontSize} → {current.TabFontSize}");
        if (current.TokenFontSize != baseline.TokenFontSize)
            changes.Add($"{prefix}: ui_font_token {baseline.TokenFontSize} → {current.TokenFontSize}");
        if (!string.Equals(current.MainFontFamily, baseline.MainFontFamily, StringComparison.Ordinal))
            changes.Add($"{prefix}: ui_font_family_main {baseline.MainFontFamily} → {current.MainFontFamily}");
        if (!string.Equals(current.MonoFontFamily, baseline.MonoFontFamily, StringComparison.Ordinal))
            changes.Add($"{prefix}: ui_font_family_mono {baseline.MonoFontFamily} → {current.MonoFontFamily}");

        if (reason == PrefsSaveReason.WindowClose)
        {
            if (!string.Equals(current.LastSelectedTabKey, baseline.LastSelectedTabKey, StringComparison.Ordinal))
            {
                changes.Add($"{prefix}: last_selected_tab {FormatOptionalString(baseline.LastSelectedTabKey)} → {FormatOptionalString(current.LastSelectedTabKey)}");
            }

            if (WindowBoundsChanged(current, baseline))
            {
                changes.Add(
                    $"{prefix}: window {FormatWindowBounds(baseline)} → {FormatWindowBounds(current)}");
            }
        }

        return changes;
    }

    private static bool WindowBoundsChanged(UiPreferences current, UiPreferences baseline) =>
        current.WindowX != baseline.WindowX
        || current.WindowY != baseline.WindowY
        || current.WindowWidth != baseline.WindowWidth
        || current.WindowHeight != baseline.WindowHeight
        || current.WindowMaximized != baseline.WindowMaximized;

    private static string FormatWindowBounds(UiPreferences prefs)
    {
        if (prefs.WindowMaximized)
            return "maximized";

        if (prefs.WindowX is null || prefs.WindowY is null || prefs.WindowWidth is null || prefs.WindowHeight is null)
            return "default";

        return $"{prefs.WindowX},{prefs.WindowY} {prefs.WindowWidth}x{prefs.WindowHeight}";
    }

    private static string FormatOptionalString(string? value) =>
        string.IsNullOrEmpty(value) ? "(none)" : value;

    private void ApplyPendingStartupStatusMessage()
    {
        var message = StartupUpdateState.ConsumePendingStatusMessage();
        if (!string.IsNullOrWhiteSpace(message))
            StatusText = message;
    }

    public void BeginStartupUpdateCheck()
    {
        if (_updateCheckStarted || !CheckForUpdates || AutomaticallyInstallUpdates)
            return;

        _updateCheckStarted = true;
        var installDirectory = AppContext.BaseDirectory;
        _ = Task.Run(async () =>
        {
            try
            {
                var result = await UpdateCheckService.CheckAsync(installDirectory).ConfigureAwait(false);
                if (!result.IsOutdated)
                    return;

                if (DebugLog.Enabled)
                    DebugLog.Write("Update", $"Startup update available: {result.LatestVersion}");

                await Avalonia.Threading.Dispatcher.UIThread.InvokeAsync(() => _ = HandleStartupUpdateAsync(result, installDirectory));
            }
            catch (Exception ex)
            {
                UpdaterLogger.Write($"Startup update check failed: {ex}");
                if (DebugLog.Enabled)
                    DebugLog.Write("Update", $"Startup update check failed: {ex}");
            }
        });
    }

    [RelayCommand]
    private void OpenRepo() => Platform.PlatformServices.Current.OpenUrl(AppBranding.RepoUrl);

    [RelayCommand]
    private async Task OpenTextFileAsync()
    {
        EnsureTabContent(TextEditorTabKey);
        if (TextEditor is null)
            return;

        var path = await Platform.PlatformServices.Current.PickFileAsync(
            "Open text file",
            "Text files (*.txt)|*.txt|All files (*.*)|*.*");
        if (path is null)
            return;

        try
        {
            TextEditor.Text = await File.ReadAllTextAsync(path).ConfigureAwait(true);
            StatusText = path;
        }
        catch (Exception ex)
        {
            Platform.PlatformServices.Current.ShowError(AppBranding.DisplayName, $"Could not open file:\n{ex.Message}");
        }
    }

    [RelayCommand]
    private async Task AddFileAsync()
    {
        EnsureTabContent(GridViewTabKey);
        var path = await Platform.PlatformServices.Current.PickFileAsync(
            "Add file",
            "All files (*.*)|*.*");
        if (path is null)
            return;

        if (FileListItems.Any(e => string.Equals(e.Path, path, StringComparison.OrdinalIgnoreCase)))
        {
            StatusText = "File is already in the list.";
            return;
        }

        FileListItems.Add(new FileListEntry { Path = path });
        StatusText = path;
    }

    [RelayCommand]
    private void RemoveFile()
    {
        EnsureTabContent(GridViewTabKey);
        if (FileGrid?.SelectedItem is not FileListEntry entry)
        {
            StatusText = "Select a file to remove.";
            return;
        }

        FileListItems.Remove(entry);
        StatusText = "File removed.";
    }

    [RelayCommand]
    private async Task SaveTextFileAsAsync()
    {
        EnsureTabContent(TextEditorTabKey);
        if (TextEditor is null)
            return;

        var path = await Platform.PlatformServices.Current.PickSaveFileAsync(
            "Save text file as",
            "Text files (*.txt)|*.txt|All files (*.*)|*.*",
            "untitled.txt");
        if (path is null)
            return;

        try
        {
            await File.WriteAllTextAsync(path, TextEditor.Text ?? string.Empty).ConfigureAwait(true);
            StatusText = path;
        }
        catch (Exception ex)
        {
            Platform.PlatformServices.Current.ShowError(AppBranding.DisplayName, $"Could not save file:\n{ex.Message}");
        }
    }

    [RelayCommand]
    private void ApplySettings()
    {
        SyncPreferencesFromPanel();
        if (Application.Current is { } app)
            UiFontService.Apply(app, _uiPrefs);
        ThemeChanged?.Invoke(SelectedTheme);
        FontsChanged?.Invoke();
        PersistUiPreferences(PrefsSaveReason.Apply);
        StatusText = "Settings applied.";
    }

    [RelayCommand]
    private void ResetToDefaults()
    {
        if (SelectedTabIndex < 0 || SelectedTabIndex >= TabItems.Count)
            return;

        EnsureSelectedTabContent();

        switch (TabItems[SelectedTabIndex].Name)
        {
            case GeneralTabKey:
                ResetGeneralTab();
                break;
            case AppSettingsTabKey:
                ResetAppSettingsTab();
                break;
            case TextEditorTabKey:
                ResetTextEditorTab();
                break;
            case GridViewTabKey:
                ResetGridViewTab();
                break;
            default:
                StatusText = "Nothing to reset on this tab.";
                break;
        }
    }

    private void ResetGeneralTab()
    {
        foreach (var (_, bindings) in _optionPanels)
            OptionPanelValueBridge.ResetToDefaults(bindings);

        SelectedDemoRadioIndex = 0;
        DemoListItems.Clear();
        foreach (var item in new[] { "Item 1", "Item 2", "Item 3" })
            DemoListItems.Add(item);

        SyncDemoRadios();
        StatusText = "General tab restored to defaults.";
    }

    private void ResetAppSettingsTab()
    {
        var windowX = _uiPrefs.WindowX;
        var windowY = _uiPrefs.WindowY;
        var windowWidth = _uiPrefs.WindowWidth;
        var windowHeight = _uiPrefs.WindowHeight;
        var windowMaximized = _uiPrefs.WindowMaximized;
        var lastTabKey = _uiPrefs.LastSelectedTabKey;

        _uiPrefs = new UiPreferences
        {
            WindowX = windowX,
            WindowY = windowY,
            WindowWidth = windowWidth,
            WindowHeight = windowHeight,
            WindowMaximized = windowMaximized,
            LastSelectedTabKey = lastTabKey,
        };

        LoadPreferences(_uiPrefs);
        OptionPanelPreferenceBridge.ResetFontSizesToDefaults(_fontSizeBindings, _uiPrefs, OnFontPreferencesChanged);
        OptionPanelPreferenceBridge.ResetFontFamiliesToDefaults(_fontFamilyBindings, _uiPrefs, OnFontPreferencesChanged);
        SyncAppSettingsControls();
        ThemeChanged?.Invoke(SelectedTheme);
        StatusText = "App settings restored to defaults. Click Apply to save.";
    }

    private void ResetTextEditorTab()
    {
        EnsureTabContent(TextEditorTabKey);
        if (TextEditor is null)
            return;

        TextEditor.Text = RawTextTabBuilder.DefaultPlaceholder;
        StatusText = "Text editor restored to defaults.";
    }

    private void ResetGridViewTab()
    {
        EnsureTabContent(GridViewTabKey);
        FileListItems.Clear();
        foreach (var entry in new[] { @"C:\Example\readme.txt", @"C:\Example\config.ini" })
            FileListItems.Add(new FileListEntry { Path = entry });

        StatusText = "Grid view restored to defaults.";
    }

    [RelayCommand]
    private void CheckForUpdatesManual() =>
        _ = Task.Run(async () =>
        {
            try
            {
                await UpdaterLauncher.StartInteractiveAsync(AppContext.BaseDirectory).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                UpdaterLogger.Write($"Interactive updater launch failed: {ex}");
                if (DebugLog.Enabled)
                    DebugLog.Write("Update", $"Interactive updater launch failed: {ex}");
            }
        });

    [RelayCommand]
    private void PickSearchResult(SettingSearchHit? hit)
    {
        if (hit is null)
            return;

        if (!_navByToken.TryGetValue(hit.Token, out var entry))
        {
            var def = SettingCatalog.All.FirstOrDefault(d =>
                string.Equals(d.Token, hit.Token, StringComparison.Ordinal));
            if (def is null)
                return;

            var tabKey = def.Category == SettingCategory.App ? AppSettingsTabKey : GeneralTabKey;
            EnsureTabContent(tabKey);
            if (tabKey == GeneralTabKey)
                EnsureGeneralCompositesReady();
            if (!_navByToken.TryGetValue(hit.Token, out entry))
                return;
        }

        SearchQuery = string.Empty;
        SearchResults.Clear();

        for (var i = 0; i < TabItems.Count; i++)
        {
            if (ReferenceEquals(TabItems[i], entry.Page))
            {
                SelectedTabIndex = i;
                break;
            }
        }

        entry.FocusTarget?.Focus();
    }

    public void RegisterPickerButtons()
    {
        foreach (var (_, bindings) in _optionPanels)
        {
            foreach (var binding in bindings)
            {
                if (binding.PickerButton is null || binding.ValueControl is null)
                    continue;
                if (!_wiredPickers.Add(binding.PickerButton))
                    continue;

                binding.PickerButton.Click += async (_, _) =>
                {
                    if (binding.ValueControl is not TextBox textBox)
                        return;

                    var def = binding.Definition;
                    string? picked = def.PathPicker switch
                    {
                        PathPickerKind.File => await Platform.PlatformServices.Current.PickFileAsync(def.Label, def.FileFilter),
                        PathPickerKind.Directory => await Platform.PlatformServices.Current.PickFolderAsync(def.Label),
                        _ => null,
                    };
                    if (picked is null)
                        return;

                    textBox.Text = picked;
                    if (binding.EnableCheck is not null)
                        binding.EnableCheck.IsChecked = true;
                };
            }
        }
    }

    private async Task HandleStartupUpdateAsync(UpdateCheckResult result, string installDirectory)
    {
        if (!UpdatePromptWindow.Prompt(result))
        {
            if (DebugLog.Enabled)
                DebugLog.Write("Update", "Startup update declined by user");
            return;
        }

        try
        {
            await UpdaterLauncher.LaunchInstallAsync(installDirectory).ConfigureAwait(true);
            Environment.Exit(0);
        }
        catch (Exception ex)
        {
            UpdaterLogger.Write($"Manual update launch failed: {ex}");
            if (DebugLog.Enabled)
                DebugLog.Write("Update", $"Startup update launch failed: {ex}");
            Platform.PlatformServices.Current.ShowWarning(
                AppBranding.DisplayName,
                $"Could not start the updater:\n{ex.Message}");
        }
    }

    private void UpdateSearch(string query)
    {
        SearchResults.Clear();
        if (string.IsNullOrWhiteSpace(query))
            return;

        foreach (var hit in SettingSearch.Find(query))
            SearchResults.Add(hit);
    }

    private void SyncAppSettingsControls()
    {
        if (_themeRadios is not null)
        {
            foreach (var radio in _themeRadios)
            {
                if (radio.Tag is UiThemeKind theme)
                    radio.IsChecked = theme == SelectedTheme;
            }
        }

        if (_appCheckboxes is null)
            return;

        if (_appCheckboxes.TryGetValue("ui_remember_last_tab", out var rememberTab))
            rememberTab.IsChecked = RememberLastSelectedTab;
        if (_appCheckboxes.TryGetValue("ui_check_for_updates", out var checkUpdates))
            checkUpdates.IsChecked = CheckForUpdates;
        if (_appCheckboxes.TryGetValue("ui_auto_install_updates", out var autoInstall))
        {
            autoInstall.IsChecked = AutomaticallyInstallUpdates;
            autoInstall.IsEnabled = CheckForUpdates;
        }
        if (_appCheckboxes.TryGetValue("ui_enable_debug_logging", out var debugLogging))
            debugLogging.IsChecked = EnableDebugLogging;

        SyncFontFamilyCombos();
    }

    private void SyncFontFamilyCombos()
    {
        foreach (var binding in _fontFamilyBindings)
        {
            var index = binding.Token switch
            {
                "ui_font_family_main" => UiFontFamilies.IndexOfMain(_uiPrefs.MainFontFamily),
                "ui_font_family_mono" => UiFontFamilies.IndexOfMono(_uiPrefs.MonoFontFamily),
                _ => -1,
            };
            if (index >= 0)
                binding.Combo.SelectedIndex = index;
        }
    }

    private void SyncDemoRadios()
    {
        if (_demoRadios is null)
            return;

        for (var i = 0; i < _demoRadios.Count; i++)
            _demoRadios[i].IsChecked = i == SelectedDemoRadioIndex;
    }
}
