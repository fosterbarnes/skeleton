#requires -Version 7.0
param(
    [Alias('b')][switch]$build
)
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'scriptHelper.ps1')
Set-Location -LiteralPath $repoRoot

if ($build) {
    & (Join-Path $PSScriptRoot '.buildAll.ps1')
    if ($LASTEXITCODE) { throw "buildAll failed (exit $LASTEXITCODE)." }
}

function Assert-ReleasePath([string]$Path, [string]$Message) {
    if (-not (Test-Path -LiteralPath $Path)) { throw $Message }
}

function Get-ReleaseNotes {
    if (Test-Path -LiteralPath $buildNotes) {
        $text = (Get-Content -LiteralPath $buildNotes -Raw -Encoding UTF8).Trim()
        if ($text) {
            Write-Host "`nUsing .md/buildNotes.txt for release notes." -ForegroundColor Cyan
            return $text
        }
    }

    Write-Host "`nEnter release notes (tabs -> spaces; finish with two empty lines):" -ForegroundColor Yellow
    $lines = [System.Collections.Generic.List[string]]::new()
    $empty = 0
    do {
        $line = Read-Host '>'
        if ($line -eq '') { $empty++; $lines.Add('') }
        else { $lines.Add(($line -replace "`t", '    ')); $empty = 0 }
    } until ($empty -ge 2)

    $text = ($lines -join "`n").Trim()
    if (-not $text) { throw 'No release notes entered.' }
    return $text
}

function Invoke-DraftRelease {
    if ([string]::IsNullOrWhiteSpace($versionContents)) { throw "Version is empty: $version" }

    Write-Host "Version: $versionContents  Tag: $tag  Repo: $ghRepo"
    Write-Host "`nExpected release outputs (under publish/):"
    foreach ($t in $winReleaseTargets) {
        $a = $t.Architecture
        Write-Host "  Windows $a`: $(Join-Path $publishFolder (Get-WinReleaseAssetName -Kind Portable -Architecture $a))"
        Write-Host "    installer: $(Join-Path $publishFolder (Get-WinReleaseAssetName -Kind Installer -Architecture $a))"
    }
    foreach ($t in $macReleaseTargets) {
        Write-Host "  macOS $($t.AssetTag): $(Join-Path $publishFolder (Get-MacPortableReleaseAssetName -AssetTag $t.AssetTag))"
    }

    $notesFile = Join-Path $env:TEMP "releaseNotes_$tag.txt"
    try {
        Set-Content -LiteralPath $notesFile -Value (Get-ReleaseNotes) -NoNewline -Encoding utf8NoBOM

        Write-Host "`nStaging release assets..."
        $uploadFiles = @(
            foreach ($t in $winReleaseTargets) {
                foreach ($kind in 'Portable', 'Installer') {
                    $p = Join-Path $publishFolder (Get-WinReleaseAssetName -Kind $kind -Architecture $t.Architecture)
                    Assert-ReleasePath $p "Missing Windows $($kind.ToLower()) ($($t.Architecture)). Run .buildAll.ps1 on Windows first: $p"
                    $p
                }
            }
            foreach ($t in $macReleaseTargets) {
                $p = Join-Path $publishFolder (Get-MacPortableReleaseAssetName -AssetTag $t.AssetTag)
                Assert-ReleasePath $p "Missing macOS portable ($($t.AssetTag)). Run .buildAll.ps1 on macOS first: $p"
                $p
            }
        )
        $uploadFiles | ForEach-Object { Write-Host "  $([IO.Path]::GetFileName($_))" }

        if (git tag -l $tag 2>$null) { Write-Host "Removing local tag $tag..."; git tag -d $tag | Out-Null }
        if (git ls-remote --tags origin "refs/tags/$tag" 2>$null) {
            Write-Host "Removing remote tag $tag..."
            git push origin --delete $tag
            if ($LASTEXITCODE) { throw "Failed to delete remote tag: $tag" }
        }

        git tag $tag; if ($LASTEXITCODE) { throw "git tag failed: $tag" }
        git push origin $tag; if ($LASTEXITCODE) { throw "git push tag failed: $tag" }

        Write-Host "`nCreating GitHub release..."
        & gh release create $tag @uploadFiles --repo $ghRepo --title $tag --notes-file $notesFile
        if ($LASTEXITCODE) { throw "gh release create failed (exit $LASTEXITCODE)" }

        Write-Host "Release $tag published: https://github.com/$ghRepo/releases/tag/$tag" -ForegroundColor Green
    }
    finally {
        Remove-Item -LiteralPath $notesFile -Force -ErrorAction SilentlyContinue
    }
}

Invoke-DraftRelease
