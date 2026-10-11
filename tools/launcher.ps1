# Doomscent launcher (Windows).  Doomscent.bat runs this.
#
# First run: offers to download GZDoom, converts your Descent files into
# dd_descent_assets.pk3, then starts the game.  Extra arguments are passed
# to GZDoom (e.g. .\Doomscent.bat -iwad DOOM2.WAD +map MAP01).

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # much faster Invoke-WebRequest
$Root = Split-Path -Parent $PSScriptRoot
$Data = Join-Path $Root 'data'
$GZDoomTag = 'g4.14.2'

function Fail($msg) {
    Write-Host ""
    Write-Host $msg -ForegroundColor Red
    exit 1
}

function Find-Python {
    if (Get-Command py -ErrorAction SilentlyContinue) { return @('py', '-3') }
    if (Get-Command python -ErrorAction SilentlyContinue) { return @('python') }
    return $null
}

# --- GZDoom -----------------------------------------------------------------
$GZDoom = $env:GZDOOM
if (-not $GZDoom) { $GZDoom = Join-Path $Root 'gzdoom\gzdoom.exe' }
if (-not (Test-Path $GZDoom)) {
    Write-Host "GZDoom was not found in $Root\gzdoom\."
    $answer = Read-Host "Download GZDoom $($GZDoomTag.TrimStart('g')) from github.com/ZDoom/gzdoom now? [Y/n]"
    if ($answer -match '^[nN]') {
        Fail "Get GZDoom from https://zdoom.org/downloads and unzip it into $Root\gzdoom\ (or set GZDOOM to gzdoom.exe)."
    }
    $release = Invoke-RestMethod "https://api.github.com/repos/ZDoom/gzdoom/releases/tags/$GZDoomTag"
    $asset = $release.assets | Where-Object { $_.name -match 'windows' -and $_.name -like '*.zip' } | Select-Object -First 1
    if (-not $asset) { Fail "Couldn't find a Windows download in the GZDoom $GZDoomTag release." }
    $zip = Join-Path $env:TEMP $asset.name
    Write-Host "Downloading $($asset.name)..."
    Invoke-WebRequest $asset.browser_download_url -OutFile $zip
    $dest = Join-Path $Root 'gzdoom'
    Expand-Archive $zip -DestinationPath $dest -Force
    Remove-Item $zip
    if (-not (Test-Path $GZDoom)) {
        # The zip may contain a top-level folder.
        $exe = Get-ChildItem $dest -Recurse -Filter gzdoom.exe | Select-Object -First 1
        if (-not $exe) { Fail "gzdoom.exe wasn't in the download." }
        Get-ChildItem $exe.DirectoryName | Move-Item -Destination $dest -Force
    }
    Write-Host "GZDoom installed." -ForegroundColor Green
}

# --- The mod ----------------------------------------------------------------
$ModPk3 = Join-Path $Root 'doomscent.pk3'
$ModSrc = Join-Path $Root 'mod'
if (Test-Path $ModSrc) {
    # A source checkout: rebuild the mod when any of its files changed.
    $newest = Get-ChildItem $ModSrc -Recurse -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not (Test-Path $ModPk3) -or $newest.LastWriteTime -gt (Get-Item $ModPk3).LastWriteTime) {
        $py = Find-Python
        if (-not $py) { Fail "Python 3 is needed to build the mod from source (https://www.python.org/downloads/)." }
        & $py[0] $py[1..9] (Join-Path $Root 'tools\build_pk3.py') $ModPk3
        if ($LASTEXITCODE) { Fail "Building doomscent.pk3 failed." }
    }
}
if (-not (Test-Path $ModPk3)) { Fail "doomscent.pk3 is missing; re-download the release." }

# --- Descent assets -----------------------------------------------------------
$Assets = Join-Path $Root 'dd_descent_assets.pk3'
$ConvExe = Join-Path $Root 'tools\ddconvert.exe'
$ConvPy = Join-Path $Root 'tools\ddconvert.py'
$converter = if (Test-Path $ConvExe) { Get-Item $ConvExe } else { Get-Item $ConvPy }
if (-not (Test-Path $Assets) -or $converter.LastWriteTime -gt (Get-Item $Assets).LastWriteTime) {
    if (-not (Test-Path (Join-Path $Data 'DESCENT.PIG')) -or -not (Test-Path (Join-Path $Data 'DESCENT.HOG'))) {
        Fail "Copy DESCENT.HOG and DESCENT.PIG from your copy of Descent 1 into $Data\ and run this again."
    }
    Write-Host "Converting your Descent data..."
    if ($converter.Extension -eq '.exe') {
        & $ConvExe $Data -o $Assets
    } else {
        $py = Find-Python
        if (-not $py) { Fail "Python 3 is needed to convert the Descent data (https://www.python.org/downloads/)." }
        & $py[0] $py[1..9] $ConvPy $Data -o $Assets
    }
    if ($LASTEXITCODE) { Fail "Converting the Descent data failed (see above)." }
}

# --- Play -------------------------------------------------------------------
$iwads = Get-ChildItem $Data -File | Where-Object { $_.Name -match '\.(wad|ipk3|pk3)$' }
if (-not $iwads) {
    Fail "Copy a Doom IWAD (DOOM.WAD, DOOM2.WAD, ... or Freedoom's freedoom2.wad) into $Data\."
}

# Run from data\ so GZDoom finds the IWADs there and offers a choice.
Set-Location $Data
& $GZDoom -file $Assets $ModPk3 @args
