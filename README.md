# skeleton

<img src="./.resources/icon/skeleton256.png" align="left" width="160">Skeleton repo for .NET 10 C# projects using Avalonia

Cross-platform Avalonia app skeleton for .NET C# projects with theming, tabs, search, and reusable setting panels. Includes mock readme (this), scripts, helper, ISCC scripts, version control, resources, VScode & Visual Studio project templates



<br><br><br>

## Downloads

### Windows

<table border="0"><tbody><tr>
<td align="center" valign="top">
<a href="https://github.com/fosterbarnes/skeleton/releases/download/v0.4.2/skeletonInstaller_v0.4.2_x64.exe">
<img src="./.resources/svg/download_x64.svg" width="180" height="auto" alt="x64 installer"/></a></td>
<td align="center" valign="top">
<a href="https://github.com/fosterbarnes/skeleton/releases/download/v0.4.2/skeletonInstaller_v0.4.2_x86.exe">
<img src="./.resources/svg/download_x86.svg" width="180" height="auto" alt="x86 installer"/></a></td>
<td align="center" valign="top">
<a href="https://github.com/fosterbarnes/skeleton/releases/download/v0.4.2/skeletonInstaller_v0.4.2_arm64.exe"><img src="./.resources/svg/download_arm.svg" width="180" height="auto" alt="ARM64 installer"/></a></td>
</tr></tbody></table>

<table border="0"><tbody><tr>
<td align="center" valign="top">
<a href="https://github.com/fosterbarnes/skeleton/releases/download/v0.4.2/skeletonPortable_v0.4.2_x64.zip">
<img src="./.resources/svg/download_portable_x64.svg" width="180" height="auto" alt="x64 portable"/></a></td>
<td align="center" valign="top">
<a href="https://github.com/fosterbarnes/skeleton/releases/download/v0.4.2/skeletonPortable_v0.4.2_x86.zip">
<img src="./.resources/svg/download_portable_x86.svg" width="180" height="auto" alt="x86 portable"/></a></td>
<td align="center" valign="top">
<a href="https://github.com/fosterbarnes/skeleton/releases/download/v0.4.2/skeletonPortable_v0.4.2_arm64.zip">
<img src="./.resources/svg/download_portable_arm64.svg" width="180" height="auto" alt="ARM64 portable"/></a></td>
</tr></tbody></table>

### macOS

<table border="0"><tbody><tr>
<td align="center" valign="top">
<a href="https://github.com/fosterbarnes/skeleton/releases/download/v0.4.2/skeleton_v0.4.2_macOS-intel.zip">
<img src="./.resources/svg/download_appleIntel.svg" width="180" height="auto" alt="x64 portable"/></a></td>
<td align="center" valign="top">
<a href="https://github.com/fosterbarnes/skeleton/releases/download/v0.4.2/skeleton_v0.4.2_macOS-arm.zip"><img src="./.resources/svg/download_appleArm.svg" width="180" height="auto" alt="ARM64 portable"/></a></td>
</tr></tbody></table>

### Debian Linux

#### Install dependencies: 

[.NET 10 runtime](https://learn.microsoft.com/en-us/dotnet/core/install/linux-debian)

```bash
wget https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
```

#### Install skeleton:

x64 (amd64)

```bash
wget https://github.com/fosterbarnes/skeleton/releases/download/v0.4.2/skeleton_v0.4.2_debian-amd64.deb
sudo apt install ./skeleton_v0.4.2_debian-amd64.deb
```

(arm64)

```bash
wget https://github.com/fosterbarnes/skeleton/releases/download/v0.4.2/skeleton_v0.4.2_debian-arm64.deb
sudo apt install ./skeleton_v0.4.2_debian-arm64.deb
```

## Tabs

<details>
<summary>[Click to Expand]</summary>

| <h3>General</h3> |
|:---:|
| ![General](./.resources/scr/1.png) |

| <h3>App Settings</h3> |
|:---:|
| ![App Settings](./.resources/scr/2.png) |

| <h3>Text Editor</h3> |
|:---:|
| ![Text Editor](./.resources/scr/3.png) |

| <h3>Log</h3> |
|:---:|
| ![Log](./.resources/scr/4.png) |

| <h3>Grid View</h3> |
|:---:|
| ![Grid View](./.resources/scr/5.png) |

| <h3>About</h3> |
|:---:|
| ![About](./.resources/scr/6.png) |

</details>

## App Themes

<details>
<summary>[Click to Expand]</summary>

| <h3>Light</h3> |
|:---:|
| ![Light](./.resources/scr/7.png) |

| <h3>Dark</h3> |
|:---:|
| ![Dark](./.resources/scr/8.png) |

| <h3>Dracula</h3> |
|:---:|
| ![Dracula](./.resources/scr/10.png) |

</details>

## Compatibility

| Platform  | Architecture
|------------|-----------------|
| Windows 10 | x86, x64, arm64
| Windows 11 | x86, x64, arm64
| macOS      | x64, arm64
| Debian Linux | x64, arm64

<!-- Quick Reference --
version = 0.4.2

x64Installer = https://github.com/fosterbarnes/skeleton/releases/download/v0.4.2/skeletonInstaller_v0.4.2_x64.exe

x64Portable = https://github.com/fosterbarnes/skeleton/releases/download/v0.4.2/skeletonPortable_v0.4.2_x64.zip

x86Installer = https://github.com/fosterbarnes/skeleton/releases/download/v0.4.2/skeletonInstaller_v0.4.2_x86.exe

x86Portable = https://github.com/fosterbarnes/skeleton/releases/download/v0.4.2/skeletonPortable_v0.4.2_x86.zip

ARM64Installer = https://github.com/fosterbarnes/skeleton/releases/download/v0.4.2/skeletonInstaller_v0.4.2_arm64.exe

ARM64Portable = https://github.com/fosterbarnes/skeleton/releases/download/v0.4.2/skeletonPortable_v0.4.2_arm64.zip

osxX64Portable = https://github.com/fosterbarnes/skeleton/releases/download/v0.4.2/skeleton_v0.4.2_macOS-intel.zip

osxArm64Portable = https://github.com/fosterbarnes/skeleton/releases/download/v0.4.2/skeleton_v0.4.2_macOS-arm.zip

linuxAmd64Deb = https://github.com/fosterbarnes/skeleton/releases/download/v0.4.2/skeleton_v0.4.2_debian-amd64.deb

linuxArm64Deb = https://github.com/fosterbarnes/skeleton/releases/download/v0.4.2/skeleton_v0.4.2_debian-arm64.deb
-->

