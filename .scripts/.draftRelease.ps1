#requires -Version 7.0
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'scriptHelper.ps1')
Set-Location -LiteralPath $repoRoot

& (Join-Path $PSScriptRoot '.buildAll.ps1')

function New-ReleaseAssets {
    $paths = [System.Collections.Generic.List[string]]::new()

    foreach ($target in $winReleaseTargets) {
        $arch = $target.Architecture
        $portable = Join-Path $publishFolder (Get-WinReleaseAssetName -Kind Portable -Architecture $arch)
        $installer = Join-Path $publishFolder (Get-WinReleaseAssetName -Kind Installer -Architecture $arch)
        if (-not (Test-Path -LiteralPath $portable)) {
            throw "Missing Windows portable ($arch). Run .buildAll.ps1 on Windows first: $portable"
        }
        if (-not (Test-Path -LiteralPath $installer)) {
            throw "Missing Windows installer ($arch). Run .buildAll.ps1 on Windows first: $installer"
        }
        $paths.Add($portable)
        $paths.Add($installer)
    }

    foreach ($target in $macReleaseTargets) {
        $portable = Join-Path $publishFolder (Get-MacPortableReleaseAssetName -AssetTag $target.AssetTag)
        if (-not (Test-Path -LiteralPath $portable)) {
            throw "Missing macOS portable ($($target.AssetTag)). Run .buildAll.ps1 on macOS first: $portable"
        }
        $paths.Add($portable)
    }

    return @($paths)
}

function Get-ReleaseNotes {
    if (Test-Path -LiteralPath $buildNotes) {
        $fromFile = (Get-Content -LiteralPath $buildNotes -Raw -Encoding UTF8).Trim()
        if ($fromFile) {
            Write-Host "`nUsing .md/buildNotes.txt for release notes." -ForegroundColor Cyan
            return $fromFile
        }
    }

    Write-Host "`nEnter release notes (tabs -> spaces; finish with two empty lines):" -ForegroundColor Yellow
    $lines = [System.Collections.Generic.List[string]]::new()
    $emptyLines = 0
    $hasContent = $false
    while ($true) {
        $line = Read-Host '>'
        if ($line -eq '') {
            $emptyLines++
            if ($emptyLines -ge 2) { break }
            $lines.Add('')
        }
        else {
            $lines.Add(($line -replace "`t", '    '))
            $emptyLines = 0
            $hasContent = $true
        }
    }
    if (-not $hasContent) { throw 'No release notes entered.' }
    return ($lines -join "`n").Trim()
}

function Reset-GitTag {
    if (git tag -l $tag 2>$null) {
        Write-Host "Removing local tag $tag..."
        git tag -d $tag | Out-Null
    }
    if (git ls-remote --tags origin "refs/tags/$tag" 2>$null) {
        Write-Host "Removing remote tag $tag..."
        git push origin --delete $tag
        if ($LASTEXITCODE) { throw "Failed to delete remote tag: $tag" }
    }
}

function Invoke-DraftRelease {
    if ([string]::IsNullOrWhiteSpace($versionContents)) { throw "Version is empty: $version" }

    Write-Host "Version: $versionContents  Tag: $tag  Repo: $ghRepo"
    Write-Host "`nExpected release outputs (under publish/):"
    foreach ($target in $winReleaseTargets) {
        Write-Host "  Windows $($target.Architecture): $(Join-Path $publishFolder (Get-WinReleaseAssetName -Kind Portable -Architecture $target.Architecture))"
        Write-Host "    installer: $(Join-Path $publishFolder (Get-WinReleaseAssetName -Kind Installer -Architecture $target.Architecture))"
    }
    foreach ($target in $macReleaseTargets) {
        Write-Host "  macOS $($target.AssetTag): $(Join-Path $publishFolder (Get-MacPortableReleaseAssetName -AssetTag $target.AssetTag))"
    }

    $uploadFiles = @()
    $releaseNotesFile = $null
    try {
        $releaseNotes = Get-ReleaseNotes
        $releaseNotesFile = Join-Path $env:TEMP "releaseNotes_$tag.txt"
        Set-Content -LiteralPath $releaseNotesFile -Value $releaseNotes -NoNewline -Encoding utf8NoBOM

        Write-Host "`nStaging release assets..."
        $uploadFiles = New-ReleaseAssets
        $uploadFiles | ForEach-Object { Write-Host "  $([IO.Path]::GetFileName($_))" }

        Reset-GitTag
        git tag $tag; if ($LASTEXITCODE) { throw "git tag failed: $tag" }
        git push origin $tag; if ($LASTEXITCODE) { throw "git push tag failed: $tag" }

        Write-Host "`nCreating GitHub release..."
        & gh release create $tag @uploadFiles --repo $ghRepo --title $tag --notes-file $releaseNotesFile
        if ($LASTEXITCODE) { throw "gh release create failed (exit $LASTEXITCODE)" }

        Write-Host "Release $tag published: https://github.com/$ghRepo/releases/tag/$tag" -ForegroundColor Green
    }
    finally {
        if ($releaseNotesFile) {
            Remove-Item -LiteralPath $releaseNotesFile -Force -ErrorAction SilentlyContinue
        }
    }
}

Invoke-DraftRelease
