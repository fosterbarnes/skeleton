. "$PSScriptRoot/scriptHelper.ps1"; Set-Location $repoRoot
if ([string]::IsNullOrWhiteSpace($versionContents)) { throw "Version is empty: $version" }
if ($readmeContents -notmatch '(?s)<!-- Quick Reference --(?<body>.*?)-->') { throw 'Could not find Quick Reference block in README.md.' }

function Get-QuickReferenceMap {
    param([string]$Body)

    $map = [ordered]@{}
    foreach ($line in ($Body -split "`n")) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^(\S+)\s*=\s*(.+)$') {
            $map[$Matches[1]] = $Matches[2].Trim()
        }
    }
    return $map
}

$releaseBase = "$appURL/releases/download/$tag"
$existingBody = $Matches['body']
$quickReference = Get-QuickReferenceMap $existingBody
$quickReference['version'] = $versionContents

foreach ($target in $buildTargets) {
    $architecture = $target.Architecture
    $refKey = if ($target.AssetTag -eq 'osx-arm64') { 'osxArm64Portable' } else { 'osxX64Portable' }
    $downloadUrl = "$releaseBase/$(Get-ReleaseAssetName -Kind Portable -Architecture $architecture)"
    $quickReference[$refKey] = $downloadUrl
}

$macSvgLinks = @{
    'download_portable_x64.svg' = $quickReference['osxX64Portable']
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
foreach ($key in $preferredOrder) {
    if ($quickReference.Contains($key)) {
        $orderedLines.Add("$key = $($quickReference[$key])")
        $null = $quickReference.Remove($key)
    }
}
foreach ($entry in $quickReference.GetEnumerator()) {
    $orderedLines.Add("$($entry.Key) = $($entry.Value)")
}

$quickReferenceBlock = "<!-- Quick Reference --`n$($orderedLines -join ("`n`n"))`n-->"
$readmeUpdated = [regex]::Replace($readmeContents, '(?s)<!-- Quick Reference --.*?-->', $quickReferenceBlock)

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
Write-Host "Updated README.md macOS links for v$versionContents"
