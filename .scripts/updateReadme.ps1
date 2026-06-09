#requires -Version 7.0
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'scriptHelper.ps1')
Set-Location -LiteralPath $repoRoot

if ([string]::IsNullOrWhiteSpace($versionContents)) { throw "Version is empty: $version" }
if ($readmeContents -notmatch '<!-- Quick Reference --') { throw 'Could not find Quick Reference block in README.md.' }

$releaseBase = "$appURL/releases/download/$tag"
$quickReference = [ordered]@{ version = $versionContents }

foreach ($target in $winReleaseTargets) {
    $arch = $target.Architecture
    $label = if ($arch -eq 'arm64') { 'ARM64' } else { $arch }
    $quickReference["${label}Installer"] = "$releaseBase/$(Get-WinReleaseAssetName -Kind Installer -Architecture $arch)"
    $quickReference["${label}Portable"] = "$releaseBase/$(Get-WinReleaseAssetName -Kind Portable -Architecture $arch)"
}

$quickReference['osxX64Portable'] = "$releaseBase/$(Get-MacPortableReleaseAssetName -AssetTag 'macOS-intel')"
$quickReference['osxArm64Portable'] = "$releaseBase/$(Get-MacPortableReleaseAssetName -AssetTag 'macOS-arm')"

$winSvgLinks = @{
    'download_x64.svg'           = $quickReference['x64Installer']
    'download_x86.svg'           = $quickReference['x86Installer']
    'download_arm.svg'           = $quickReference['ARM64Installer']
    'download_portable_x64.svg'  = $quickReference['x64Portable']
    'download_portable_x86.svg'  = $quickReference['x86Portable']
    'download_portable_arm64.svg' = $quickReference['ARM64Portable']
}

$macSvgLinks = @{
    'download_portable_x64.svg'  = $quickReference['osxX64Portable']
    'download_portable_arm64.svg' = $quickReference['osxArm64Portable']
}

$preferredOrder = @(
    'version',
    'x64Installer', 'x64Portable',
    'x86Installer', 'x86Portable',
    'ARM64Installer', 'ARM64Portable',
    'osxX64Portable', 'osxArm64Portable'
)

$orderedLines = [System.Collections.Generic.List[string]]::new()
$remaining = [ordered]@{}
foreach ($entry in $quickReference.GetEnumerator()) { $remaining[$entry.Key] = $entry.Value }
foreach ($key in $preferredOrder) {
    if ($remaining.Contains($key)) {
        $orderedLines.Add("$key = $($remaining[$key])")
        $null = $remaining.Remove($key)
    }
}
foreach ($entry in $remaining.GetEnumerator()) {
    $orderedLines.Add("$($entry.Key) = $($entry.Value)")
}

$quickReferenceBlock = "<!-- Quick Reference --`n$($orderedLines -join ("`n`n"))`n-->"
$readmeUpdated = [regex]::Replace($readmeContents, '(?s)<!-- Quick Reference --.*?-->', $quickReferenceBlock)

if ($readmeUpdated -match '(?s)(?<section>### Windows\b.*?(?=### macOS|## Tabs))') {
    $sectionText = $Matches['section']
    $updatedSection = $sectionText
    foreach ($svgFile in $winSvgLinks.Keys) {
        $downloadUrl = $winSvgLinks[$svgFile]
        if ([string]::IsNullOrWhiteSpace($downloadUrl)) { continue }
        $escapedSvg = [regex]::Escape($svgFile)
        $updatedSection = $updatedSection -replace "(<a href=`")[^`"]+(`"><img src=`"\./\.resources/svg/$escapedSvg`")", "`${1}$downloadUrl`${2}"
    }
    $readmeUpdated = $readmeUpdated.Replace($sectionText, $updatedSection)
}

if ($readmeUpdated -match '(?s)(?<section>### macOS\b.*?(?=## Tabs))') {
    $sectionText = $Matches['section']
    $updatedSection = $sectionText
    foreach ($svgFile in $macSvgLinks.Keys) {
        $downloadUrl = $macSvgLinks[$svgFile]
        if ([string]::IsNullOrWhiteSpace($downloadUrl)) { continue }
        $escapedSvg = [regex]::Escape($svgFile)
        $updatedSection = $updatedSection -replace "(<a href=`")[^`"]+(`"><img src=`"\./\.resources/svg/$escapedSvg`")", "`${1}$downloadUrl`${2}"
    }
    $readmeUpdated = $readmeUpdated.Replace($sectionText, $updatedSection)
}

if ($readmeUpdated -eq $readmeContents) {
    Write-Host "README already up to date (v$versionContents)."
    exit 0
}
Set-Content -LiteralPath $readme -Value $readmeUpdated -NoNewline -Encoding utf8NoBOM
Write-Host "Updated README.md for v$versionContents"
