## 2026-05-24 — Avalonia migration

Migrated skeleton template from WinForms to Avalonia 12 (`net8.0`):

- Added `skeleton.Core` shared library (models, settings catalog, storage, update services, `AppBranding`, `IPlatformServices`).
- Main app: Avalonia MVVM (`MainWindow.axaml`, settings catalog UI, theme, search, update prompt).
- Updater: Avalonia (`UpdaterWindow.axaml`) + `--silent --install` CLI preserved.
- Build scripts: `net8.0` TFM, Windows RIDs unchanged; macOS/Linux RIDs commented as future targets.
- IDE: `.vscode/extensions.json` recommends vscode-avalonia + C# Dev Kit.

Release build verified: `dotnet build skeleton.sln -c Release`.

## 2026-05-24 — WinForms-look Avalonia restyle

- Base theme: `FluentTheme DensityStyle="Compact"` + `skeleton/Themes/` custom styles.
- Runtime palettes: VS-dark, Dracula light/dark, light defaults via `UiTheme.ApplyAppTheme` / `ThemeBrushKeys`.
- Flat tab strip (`app-tabs`), search overlaid on tab header row, status bar + GroupBox-style expanders.
- `OptionPanelBuilder` row metrics restored; About tab 160px icon; updater shares linked theme assets.

## 2026-05-24 — General tab scroll/layout fix

- General tab: single `ScrollViewer` for composite expanders + settings grid (removed nested DockPanel/ScrollViewer clip).
- `TabControl.app-tabs`: stretch tab content; tab strip reserves space for search box; search vertically centered via `UiMetrics.SearchBoxMargin`.
- Nested `group-box` expanders: tighter padding; multi-select rows top-align label/value columns.

## 2026-05-24 — Configurable UI font sizes

- `UiFontDefaults` + `UiPreferences` store body/tab/token/menu/status/section sizes (defaults 12/12/11/12/12/12).
- Theme styles bind `{DynamicResource ThemeFont*}`; `UiFontService.Apply` pushes prefs to app resources at startup and on change.
- Advanced tab: six numeric catalog rows (`ui_font_*`) wired via `OptionPanelPreferenceBridge` (checkbox enables custom size; uncheck restores default).

## 2026-05-24 — WinForms look-and-feel parity

- Tab content pane + selected tab use `ThemeFieldBrush`; scroll backgrounds scoped to `TabControl.app-tabs`.
- Replaced Expander group-box with `Border.group-box` classic caption-on-border layout (`UiTheme.CreateGroupBox`).
- App Settings: horizontal theme radios, normal-weight labels, WinForms spacing via `UiMetrics`.
- Classic `CheckBox`/`RadioButton` control themes + sharp buttons; `ThemeAccentBrush` applied at runtime per palette.

## 2026-05-24 — NumericUpDown borders

- `{x:Type NumericUpDown}` + `{x:Type ButtonSpinner}` control themes in `ClassicControls.axaml` (vertical `UniformGrid` spin column, single outer border); `TextBox.numeric-inner` in `TextBox.axaml` resets global TextBox height so the field does not overflow the border inset.
- Missing top/bottom strokes were caused by inner TextBox inheriting global `Height`/`MinHeight`=26; `/template/` style overrides could not reach content inside ButtonSpinner's ContentPresenter.
- Cleanup: merged chrome into `{x:Type NumericUpDown}` theme, promoted `SkeletonButtonSpinner` to `{x:Type ButtonSpinner}`, deleted `NumericUpDown.axaml`, trimmed `TextBox.numeric-inner` to height reset + combined `PART_BorderElement` rule.

## 2026-05-24 — Boolean setting row alignment

- `CheckBoxBool` rows no longer span both grid columns; checkbox + token stay in column 0 like other settings.

## 2026-05-24 — App Settings text sizes

- Moved six `ui_font_*` settings from Advanced to `SettingCategory.App`; built on App Settings tab via `FontSizePanelBuilder` (label + spinner, no enable checkbox).
- `OptionPanelPreferenceBridge.WireDirectFontSizes` applies changes live; **Reset to defaults** restores `UiFontDefaults` (12/13/11/12/12/12).
- Search navigates to App Settings and focuses the matching spinner (`_navByToken`).

## 2026-05-24 — Consolidated text size settings

- Merged body/menu/status/section into single **Main text** (`MainFontSize` / `ui_font_main`); `UiFontService` applies it to all four theme font keys.
- App Settings text sizes: one horizontal row (Main, Tabs, Tokens). Legacy `BodyFontSize` in ui.json migrates to `MainFontSize` on load.

## 2026-05-24 — Uniform settings field height

- Unified `ControlHeight` / `ButtonHeight` at 26px; TextBox, Button, ComboBox, and NumericUpDown use fixed `Height` + `MinHeight` so string fields match browse rows.

## 2026-05-24 — Browse button alignment and hover

- Button content centered via `HorizontalContentAlignment` / `VerticalContentAlignment`.
- Hover uses `ThemeFormBrush` instead of `ThemeFieldBrush` so browse buttons stay visibly grey, not white-on-white.

## 2026-05-24 — Setting display flags

- `SettingDisplayFlags` (`EnableCheckbox`, `Token`) on `SettingDefinition`; default `None` (opt-in).
- All settings in `SettingCatalog` including App prefs and General composites; builders honor flags.
- `OptionPanelBuilder` gates value controls when `EnableCheckbox` set; `AppSettingsPanelBuilder` replaces hand-built App Settings tab.

## 2026-05-24 — Code review fixes

- Search popup binds `DisplayText`; System theme uses OS `PlatformSettings`; startup update gate is async before main window.
- Font sizes clamped in `AppConfigStore`; updater refresh skips download when local updater is current; `build.ps1` chains `buildUpdater.ps1`.
- Pre-Avalonia updater errors use `NativeDialog`; dead code removed; shared `SettingTooltipHelper` and `FileDeleteHelper`.

## 2026-05-24 — AGENTS.md Avalonia guidance

- Expanded `AGENTS.md` with Avalonia development section: MCP workflow, hybrid UI architecture, styling/theming, MVVM conventions, UI change checklists, fork checklist.
- Reorganized settings/build content; folded migration notes into ongoing Avalonia rules; fixed typos in General Guidelines.

## 2026-05-24 — buildNotes.md policy in AGENTS.md

- Added **Agent build log (`buildNotes.md`)** section: append-only permanent change history, never delete or rewrite prior entries, correct mistakes via follow-up notes only.
- Clarified distinction between AGENTS.md Agent Notes (conventions/troubleshooting) and `.md/buildNotes.md` (chronological session log).

## 2026-05-24 — Tab header text rendering

- Tab styles: `FontWeight` Normal, `ThemeTextBrush` on selected/unselected/hover/pressed (overrides Fluent SemiLight + muted tab foreground).
- Removed tab `MaxHeight` clamp; `TabHeight` 28 / `TabStripHeight` 30 / vertical padding 2 for clearer glyphs.
- `TabChromeHelper` width probe uses Normal weight to match rendered headers.

## 2026-05-24 — Light mode input brush parity

- `ThemeInputBrush` now matches `ThemeFormBrush` on Light and Dracula Light (was white/field, causing gray inset on text boxes).
- Dark/Dracula Dark unchanged: Input = Form, Field = lifted group-box fill.
- ComboBox inner template border uses `ThemeInputBrush` (same fix as TextBox focus sliver).
- Documented Form/Input/Field/Surface brush roles in AGENTS.md.

## 2026-05-24 — Light mode input fill (#FFFFFF)

- Light `ThemeInputBrush` = `#FFFFFF` (white interiors on `#F0F0F0` canvas); Dracula Light = `#FCFCF8`.
- Double-border avoided via TextBox/ComboBox template overrides, not by matching Form.

## 2026-05-24 — Light mode Fluent template inset fix

- `ApplyFluentControlResources` in `UiTheme.cs` maps Fluent `TextControl*` / `ComboBoxBackground*` keys to `ThemeInputBrush` and keeps focus border at 1px.
- TextBox, ComboBox, ListBox styles pin `PART_BorderElement` + inner template borders to `ThemeInputBrush` on default, hover, and focus (same pattern as dark).
- TextBox template `Panel`, inset content `Border`, and `ScrollViewer` backgrounds pinned to `ThemeInputBrush` so Form (#F0F0F0) does not show through padding/margin gaps.
- `TextBox.numeric-inner` (NumericUpDown field) uses same white template fill; borders stay 0 so outer spinner chrome is unchanged.
- ListBox: `{x:Type ListBox}` ControlTheme in `AppTheme.axaml` `Styles.Resources`; bordered inputs use shared `Border.setting-input-frame` (multi-select, entry list).

## 2026-05-25 — Harden theme colors

- Replaced flat `ThemeColors` with `ThemePalette` in `UiTheme.cs`: palette groups (MainBorder, MainText, InputBg, FieldBg, FormBg, SurfaceBg, MutedText, Accent, Link, MenuBack) plus optional per-role overrides.
- `ApplyThemeBrushes` expands groups into 10 palette-group keys, 5 tab-state keys, 11 border roles, 12 text roles, and 12 background roles; all wired in `ThemeBrushKeys.cs` and Light defaults in `ThemeBrushes.axaml`.
- Control styles migrated to role-specific brush keys (Tab, Search, StringBox, ChoiceBox, NumberBox, Button, CheckBox, RadioGroup, Composite/EntryList frames).
- Setting name labels use `.setting-label` → `ThemeSettingTextBrush`; tokens use `ThemeTokenTextBrush`.
- AGENTS.md documents color model, grouping table, per-theme hex values, and outlier policy.

## 2026-05-25 — .NET 10 TFM migration

- All projects: net8.0 → net10.0 (skeleton, skeleton.Core, updater).
- scriptHelper.ps1: $dotnetFramework = net10.0.
- Added global.json pinning .NET 10 SDK.
- README: documented .NET 10 Desktop Runtime prerequisite.
- AGENTS.md: updated TFM references.

## 2026-05-25 — Leverage .NET 10 benefits

- Added `Directory.Build.props` (LangVersion, Nullable, ImplicitUsings); deduped from csproj files.
- `skeleton.Core`: `IsAotCompatible=true` for trim/AOT analyzers.
- GitHub release fetch: STJ source generation (`GitHubReleaseJsonContext.cs`) replaces `JsonDocument` parsing.
- C# 14 extension member: `GitHubRelease.FindPortableAsset()` via `GitHubReleaseExtensions`.
- `build.ps1`: runs `dotnet restore skeleton.sln` before publish.
- AGENTS.md: .NET 10 subsection + deployment options in Agent Notes.

## 2026-05-25 — Group box title left alignment

- Removed `GroupBoxHeaderLeftPx` inset; group box headers use negative left margin to sit on the border line instead of indented from it.
- Added `GroupBoxNestedHeaderMargin` for nested group boxes (General tab composites) so titles align the same way with smaller nested padding.

## 2026-05-25 — Group box title slight inset

- Added `GroupBoxHeaderInsetPx` (3px) so titles sit slightly in from the left border instead of flush; nested boxes use the same inset via shared margin formula.

## 2026-05-25 — Group box header font weight

- Group box section titles use `FontWeight.Medium` for slightly heavier emphasis vs body text.

## 2026-05-25 — Group box header font weight bump

- Group box section titles: `Medium` → `SemiBold`.

## 2026-05-25 — App Settings Theme section labels

- Preferences group box title → `Theme`; removed redundant `App theme` row label (radios only; tooltip on radio row).

## 2026-05-25 — Status footer Apply / Reset buttons

- `MainWindow.axaml` status bar: status text left; `Reset to defaults` + `Apply` (rightmost) on the right.
- `ApplySettingsCommand` persists `ui.json` and sets status text; theme/font changes preview live but no longer auto-save on every tweak.
- `ResetToDefaultsCommand` restores catalog defaults for General option rows, App prefs, and demo composites (window bounds preserved); user clicks Apply to save.
- Added `OptionPanelValueBridge.ResetToDefaults`; App Settings controls register with the ViewModel for reset sync.

## 2026-05-25 — Search box text vertical centering

- `TextBox.app-search`: `VerticalContentAlignment=Center` and zero vertical padding so placeholder and typed text sit centered in the 26px box.

## 2026-05-25 — Raw text tab type

- Added reusable raw-text tab infrastructure migrated from rEFInd Config Editor: `RawTextTabBuilder` (monospace multiline editor + Apply from raw bar), `RawTextTabSession` (document/raw/GUI sync, lazy refresh on tab select, conflict confirm), `OptionPanelDocumentBridge` (key=value serialize/parse), and `OptionPanelDirtyBridge` (GUI edit tracking).
- Demo **Raw text** tab on General catalog rows; `TextBox.raw-editor` style; `IPlatformServices.ShowYesNoAsync` for apply conflicts.
- Reset to defaults refreshes the raw tab document from restored GUI bindings.

## 2026-05-25 — Raw text tab simplified

- Removed Apply from raw, settings sync, and document bridge; **Raw text** is now a standalone monospace editor baseline (`RawTextTabBuilder` + `TextBox.raw-editor`).
- `MainWindowViewModel.RawTextEditor` exposed for forks to load/save plain text. Deleted `RawTextTabSession`, `OptionPanelDocumentBridge`, `OptionPanelDirtyBridge`, and `ShowYesNoAsync`.

## 2026-05-25 — Text Editor tab polish

- Tab renamed **Text Editor**, moved after About; placeholder is `# Raw text editor` only.
- Footer **Open** button visible on Text Editor tab (`OpenTextFileCommand`); `TextEditor` property replaces `RawTextEditor`.

## 2026-05-25 — About tab rightmost

- Tab order: General → App Settings → Text Editor → About.

## 2026-05-25 — Text Editor Save As

- Footer **Save As** button on Text Editor tab; `SaveTextFileAsCommand` writes editor text via `IPlatformServices.PickSaveFileAsync`.

## 2026-05-25 — Debug logging and Log tab

- Added `skeleton.Core/Diagnostics/DebugLog.cs`: opt-in ring buffer (500 lines), `%AppData%\{slug}\debug.log` append, `EntryAdded` event; zero work when `Enabled` is false (guard interpolated calls with `if (DebugLog.Enabled)`).
- App setting `ui_enable_debug_logging` in Developer section; persisted on `UiPreferences.EnableDebugLogging`.
- New **Log** tab (`LogTabBuilder`, read-only `TextBox.raw-editor`) after Text Editor; live updates via `EntryAdded`.
- Curated instrumentation: startup, prefs save, theme change, update gate/check/refresh flows.

## 2026-05-25 — App Settings Logging section label

- Renamed App Settings section **Developer** → **Logging** (`AppSectionLogging`); Log tab placeholder updated.

## 2026-05-25 — Preference change debug logging

- Apply and window-close saves diff against last persisted snapshot; log each changed setting with `Apply:` or `Close:` prefix and catalog token names.

## 2026-05-25 — Grid view tab type

- Added reusable **Files** grid tab: `GridViewTabBuilder` (DataGrid + Add/Remove toolbar), `FileListEntry` model, `DataGrid.file-list-grid` theme overrides.
- `Avalonia.Controls.DataGrid` package + Fluent DataGrid styles in `App.axaml`.
- Demo tab after Log; `AddFileCommand` / `RemoveFileCommand` use file picker and grid selection; reset restores sample entries.

## 2026-05-25 — Grid View tab polish

- Tab header renamed **Grid View**; Add/Remove toolbar buttons use uniform width (`GridViewToolbarButtonWidth`).
- DataGrid selection: hide cell right grid lines, focus/current cell chrome, and vertical grid lines to fix black slivers on selected rows.

## 2026-05-25 — Grid View toolbar width crash fix

- `GridViewToolbarButtonWidth` changed to `double` — `x:Static` int on `Button.Width`/`MinWidth` caused startup `InvalidCastException`.

## 2026-05-25 — Grid View cell padding

- Hide row headers (`HeadersVisibility=Column`); cell/header padding reduced to 4px (`DataGridCellPadH`) so entry text aligns with column headers.

## 2026-05-25 — Grid View text alignment

- Cell text was double-indented: Fluent DataGrid adds 4px `TextBlock` margin on top of cell padding. Zeroed TextBlock margin in `file-list-grid`; header and cell both use 4px padding to align.

## 2026-05-25 — Grid View monospace text

- `file-list-grid` uses `UiMetrics.MonoFontFamily` (Consolas) for headers and cell text.

## 2026-05-25 — Updater DataGrid theme exclude

- `DataGrid.axaml` excluded from updater linked `Themes/Controls/**` — updater does not reference `Avalonia.Controls.DataGrid`.

## 2026-05-25 — Debug log per-run scope

- `DebugLog` no longer seeds the in-memory buffer from `debug.log`; Log tab shows only the current process run.
- Each run writes a `========== Run … (pid …) ==========` header to the file (blank line between runs); re-enabling logging in the same session restores that header in the tab without a second file marker.

## 2026-05-25 — MDI icon infrastructure

- Added `Material.Icons.Avalonia` (Pictogrammers MDI); `MaterialIconStyles` in `App.axaml`.
- `MdiIcons` / `MdiButtons` helpers in `skeleton/UI/MdiIcons.cs`; `icon-btn` and `icon-text-btn` button styles; `UiMetrics.IconSize`.
- Path picker Browse buttons use icon-only folder/file MDI glyphs with catalog tooltip text.
- `MaterialIcon.axaml` sets `ThemeButtonForegroundBrush` on icons inside buttons so glyphs render as one solid fill color.

## 2026-05-25 — Grid View MDI icon fill

- Grid View toolbar restored to `PlusBox` / `MinusBox`; `MaterialIcon` uses `IconSize` and theme foreground style for solid single-color glyphs.

## 2026-05-25 — Code review alignment fixes

- Updater: merge `ThemeFonts.axaml`; fix `UpdaterPlatformServices.ShowError` to match main-app dialog pattern; `UpdaterWindow` uses `UiMetrics`, `SizeToContent` height.
- Build: remove duplicate `buildUpdater` step from `.buildAll.ps1`; copy `Version`/`VersionBuild` after updater publish; validate `updater.exe` before installer; check `buildUpdater` exit code.
- Update flow: verify portable asset exists at check time; skip nested `updater.exe` in apply; do not treat bare cancellation as network error.
- Grid View: remove dead `grid-view-toolbar-btn` style; theme column headers and selected rows; `DataGridCellPad` in `UiMetrics`; pin `Avalonia.Controls.DataGrid` 12.0.3.
- `SettingCatalog` duplicate-token validation runs in Release builds.

## 2026-05-25 — DataGrid package version correction

- Correction: `Avalonia.Controls.DataGrid` stays at **12.0.0** — NuGet has no 12.0.3 for this package (latest is 12.0.0; main Avalonia packages remain 12.0.3).

## 2026-05-25 — Updater App.axaml.cs using fix

- Correction: restore `using skeleton.Models` in `.updater/App.axaml.cs` — `UiThemeKind` lives in that namespace, not `skeleton.UI`.

## 2026-05-25 — UiMetrics Spacing type fix

- `AppSettingsControlGapPx` changed to `double` — Avalonia compiled XAML requires `double` for `StackPanel.Spacing` via `{x:Static}`.

## 2026-05-25 — Strip unnecessary publish artifacts

- Release builds: `DebugType=none` / `DebugSymbols=false` in `Directory.Build.props`.
- `Remove-PublishArtifacts` in `scriptHelper.ps1` drops native `.pdb` files, Avalonia designer/non-Windows platform DLLs, duplicate root icons, and unused `VersionBuild` from publish output after main app + updater publish.
- `build.ps1` no longer copies `VersionBuild` into the install folder.

## 2026-05-25 — Uninstaller optional settings removal

- Added `.installer/skeleton.uninstall.iss` (included by all three arch installers): on uninstall, prompts to delete `%AppData%\{#AppName}` (Roaming settings, logs); defaults to keeping settings; silent uninstall skips the prompt and keeps settings.

## 2026-05-25 — Uninstaller WizardSilent fix

- Correction: use `UninstallSilent()` instead of `WizardSilent()` in `skeleton.uninstall.iss` — wizard APIs are not available during uninstall and caused a runtime error.

## 2026-05-25 — App Settings font family pickers

- Added `MainFontFamily` / `MonoFontFamily` to `UiPreferences` with curated choices in `UiFontFamilies`.
- App Settings → Fonts: dropdowns for general and monospace fonts; persisted in `ui.json`; applied at runtime via `ThemeFontMainFamily` / `ThemeFontMonoFamily` resources.
- Mono surfaces (tokens, log, text editor, status bar, grid) and window default font family follow the selected fonts.

## 2026-05-25 — Font picker preview faces

- Font family dropdown items render each option label in its own typeface via `ComboBox.ItemTemplate`.

## 2026-05-25 — Tab-scoped reset to defaults

- Removed per-section reset buttons from App Settings (Fonts, Text size).
- Footer **Reset to defaults** now resets only the active tab: General demo controls, App Settings prefs, text editor content, or grid file list.

## 2026-05-25 — Startup and General-tab scroll perf

- **Tab strip:** `TabChromeHelper` syncs tab widths once on `Loaded` (removed permanent `LayoutUpdated` handler); header text width is cached by font size.
- **General scroll:** settings rows use `ItemsControl` + `VirtualizingStackPanel`; settings `ScrollViewer` sets `BringIntoViewOnFocusChange=false`; demo entry list disables inner `ListBox` scroll to avoid nested wheel fighting.
- **Lazy tabs:** `EnsureTabContent` builds tab bodies on first visit; About moved to `AboutTabBuilder`; App Settings no longer built in `OnOpened`.
- **Deferred startup:** picker wiring and startup update check post at `Background` priority; pending updater zip refresh runs on a thread-pool task after `MainWindow` is shown.
- **Reset/search:** `OptionPanelValueBridge` tolerates non-materialized virtualized rows; search ensures the target tab is built before focus.

## 2026-05-25 — Virtualized settings row recycle crash

- Correction: `OptionPanelBuilder` item template returns an empty row when `SettingDefinition` is null during `VirtualizingStackPanel` container recycle; fixes `NullReferenceException` on General-tab scroll.

## 2026-05-25 — README Quick Reference block

- Restored `<!-- Quick Reference -->` metadata block at end of `README.md` so `updateReadme.ps1` can run after `.buildAll.ps1`.

## 2026-05-25 — Perf cleanup pass

- `EnsureTabContent` marks `_builtTabs` only after a successful build; unknown tab keys no longer stick as built.
- Path picker wiring: `RegisterPickerButtons` tracks wired buttons per instance; called when virtualized General rows materialize and from deferred startup.
- Removed unused `OptionPanelBuilder.Build`; extracted `AttachShell` helper; dropped redundant `RegisterPickerButtonsAsync`.

## 2026-05-25 — draftRelease release-notes input fix

- Fixed `.draftRelease.ps1` `Get-ReleaseNotes`: wrap `-replace` in parentheses so `$lines.Add(...)` receives one string, not two arguments (PowerShell comma parsing).
- Matched rEFInd loop: `$hasContent` guard and break on two consecutive empty lines.

## 2026-05-28 — Faster app startup

- **Deferred tab bodies:** `MainWindowViewModel` skips `EnsureTabContent` until `EndDeferTabContentBuild()` from `MainWindow.OnOpened` (`Background` priority), so tab restore in the ctor no longer builds panels before the window shows.
- **OnOpened:** theme variant only (brushes applied earlier in `App`); first-tab build + picker wiring on `Background`; startup update check on `ApplicationIdle`.
- **Theme:** `UiTheme.ApplyAppTheme` runs in `App.axaml.cs` after prefs/fonts; `ApplyWindowThemeVariant` for initial window chrome.
- **OptionPanelBuilder:** picker registration removed from item template; `RegisterPickerButtons` runs once after tab content is built.
- **StartupUpdateGate:** comment clarifies pre-UI gate is silent auto-install only; check-for-updates alone must never await network before `MainWindow`.
- **Publish:** `.scripts/build.ps1` Release publish uses `PublishReadyToRun=true` for faster FDD cold start (larger output).
- **Lazy DataGrid styles:** removed global DataGrid Fluent `StyleInclude` from `App.axaml`; `DataGridStyles.EnsureLoaded()` merges it when Grid View tab builds (`StyleInclude(Uri)` ctor — no parameterless constructor).
- **General tab:** settings grid builds first; composite demo panels (EntryList, RadioGroup) append on `Background`; `GeneralCompositePending` record + `EnsureGeneralCompositesReady()` for search navigation.
- **Cleanup:** `ScheduleDeferredStartupWork()` in `MainWindow.axaml.cs`; composite pending cleared when tab rebuild or append is stale.

## 2026-05-29 — Segoe UI default font

- Default main font switched from Inter to Segoe UI; `UiFontFamilies.SegoeUiStack` resolves to `Segoe UI, Segoe UI Variable` at apply/preview time.
- `ThemeFonts.axaml` static default updated; Inter remains a picker option via bundled `.WithInterFont()`.
- Grid View and other monospace roles unchanged.

## 2026-05-29 — Selected tab hover color

- `TabControl.axaml`: selected tab hover keeps `ThemeTabSelectedBgBrush` instead of `ThemeTabSelectedHoverBgBrush`.

## 2026-05-29 — Font and tab cleanup

- Removed unused `ThemeTabSelectedHoverBgBrush` from palette keys, `UiTheme`, and `ThemeBrushes.axaml`.
- Consolidated selected-tab layout-root styles; moved `ResolveMainStack` to `UiFontFamilies`.

## 2026-05-29 — Remove Inter font

- Dropped `Avalonia.Fonts.Inter` package and `.WithInterFont()` from main app and updater.
- Removed Inter from `UiFontFamilies.MainChoices`; stored `Inter` prefs normalize to Segoe UI on load.

## 2026-05-30 — macOS publish support (dual-host scripts)

- Added `osx-x64` / `osx-arm64` RIDs; `_IsWinRid` in `Directory.Build.props` drives conditional `WinExe`, `app.manifest`, and `.ico` (Windows unchanged).
- `PlatformBinaryNames` + OS-aware `UpdateConstants`; portable update applies `chmod +x` on macOS; `NativeDialog` uses `osascript` on Mac.
- Release portable assets: Windows keeps `_x64` / `_x86` / `_arm64`; macOS uses `_osx-arm64` / `_osx-x64` via `ReleaseAssetNames.GetPortableAssetTag()`.
- `.scripts/scriptHelper.ps1`: OS detection via `$BuildHostWindows` / `$BuildHostMacOS` (not `$IsWindows` — reserved in pwsh 7), separate target arrays, lazy Inno Setup, RID-aware `Remove-PublishArtifacts`, `New-MacAppBundle`.
- Same entry points on both hosts: `build.ps1`, `buildInstaller.ps1`, `.buildAll.ps1`, `.draftRelease.ps1`, `updateReadme.ps1`, `.run.ps1` branch by host.
- macOS: `.resources/mac/Info.plist`, `.app` bundle in `publish/osx-*`, optional codesign via `SKELETON_MAC_SIGN_IDENTITY`.

Correction: host detection variables renamed to `$BuildHostWindows` / `$BuildHostMacOS` — pwsh 7 treats `$IsWindows` and `$IsMacOS` as read-only automatic variables.

## 2026-05-30 — macOS script path separators

- `.scripts/scriptHelper.ps1` and sibling entry scripts: repo/publish paths use `/` instead of `\` so `[IO.File]` and `Test-Path` resolve on macOS (backslashes are literal filename characters on Unix).
- Fixes first-run `.run.ps1` failing with “Could not find file …\.version\version” when `.version/version` exists.

## 2026-05-31 — macOS app bundle icon

- `New-MacAppBundle` copies `.resources/icon/skeleton.icns` into `Contents/Resources/` of each published `.app`.
- `.resources/mac/Info.plist`: added `CFBundleIconFile` (`skeleton`) so Finder/Dock use the bundled icon.

## 2026-06-01 — macOS unified title bar window drag

- `MacWindowChrome`: use `WindowDecorationProperties.ElementRole=TitleBar` on the chrome bar and tab header strip (native macOS drag; `BeginMoveDrag` is ineffective on macOS).
- Tab `ListBox` no longer marked `User`; items use `IsHitTestVisible=false` so drags hit the title bar. Click-to-select tabs via pointer release + 4px movement threshold.
- `MainWindow.axaml`: tab headers left-aligned in `Auto,*` grid so empty space beside tabs is title-bar draggable.

## 2026-06-01 — macOS default main font Tahoma

- `UiFontFamilies.DefaultMain` returns Tahoma on macOS, Segoe UI on Windows; font picker choices stay explicit (no longer tied to platform default value).

## 2026-06-01 — macOS default window size

- `UiMetrics.DefaultWidth` / `DefaultHeight`: 928×725 on macOS, 880×680 on Windows; `MainWindow.axaml` binds initial size to these values.

## 2026-06-01 — macOS default monospace font Menlo

- `UiFontFamilies.DefaultMono` returns Menlo on macOS, Consolas on Windows; `ResolveMonoStack` supplies `Menlo, SF Mono, Monaco` fallbacks.
- Stored `Consolas` mono prefs normalize to Menlo on macOS load; Menlo/SF Mono/Monaco added to mono picker choices.
