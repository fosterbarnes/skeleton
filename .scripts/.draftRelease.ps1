. "$PSScriptRoot\scriptHelper.ps1"; Set-Location -LiteralPath $repoRoot

if ([string]::IsNullOrWhiteSpace($versionContents)) { throw "Version is empty: $version" }

& "$PSScriptRoot\.buildAll.ps1"

Write-Host "Version: $versionContents  Tag: $tag  Repo: $ghRepo"
Write-Host "`nBuild outputs:"
foreach ($target in $buildTargets) {
    Write-Host "  $($target.Architecture): $($target.BinFolder)  installer: $installerOutput\$($target.InstallerName)"
}

function Get-ReleaseNotes {
    if (Test-Path -LiteralPath $buildNotes) {
        $fromFile = (Get-Content -LiteralPath $buildNotes -Raw -Encoding UTF8).Trim()
        if ($fromFile) {
            Write-Host "`nUsing .md\.buildNotes.txt for release notes." -ForegroundColor Cyan
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

function New-ReleaseAssets {
    $paths = [System.Collections.Generic.List[string]]::new()
    foreach ($target in $buildTargets) {
        $arch = $target.Architecture
        $portable = "$env:TEMP\$(Get-ReleaseAssetName -Kind Portable -Architecture $arch)"
        Compress-Archive -Path "$($target.BinFolder)\*" -DestinationPath $portable -Force
        $paths.Add($portable)

        $builtInstaller = "$installerOutput\$($target.InstallerName)"
        if (-not (Test-Path -LiteralPath $builtInstaller)) { throw "Missing installer (run buildInstaller.ps1): $builtInstaller" }
        $installer = "$env:TEMP\$(Get-ReleaseAssetName -Kind Installer -Architecture $arch)"
        Copy-Item -LiteralPath $builtInstaller -Destination $installer -Force
        $paths.Add($installer)
    }
    return @($paths)
}

$uploadFiles = @()
$releaseNotesFile = $null
try {
    $releaseNotes = Get-ReleaseNotes
    $releaseNotesFile = "$env:TEMP\releaseNotes_$tag.txt"
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
    @($uploadFiles + $releaseNotesFile) | Where-Object { $_ } |
        ForEach-Object { Remove-Item -LiteralPath $_ -Force -ErrorAction SilentlyContinue }
}
