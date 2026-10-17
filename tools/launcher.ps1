# Doomscent launcher (Windows).  Doomscent.bat runs this.
#
# First run: offers to download GZDoom, converts your Descent files into
# dd_descent_assets.pk3, then starts the game.  -descent2 plays in Descent
# II mode (dd_descent2_assets.pk3).  Other arguments are passed to GZDoom
# (e.g. .\Doomscent.bat -iwad DOOM2.WAD +map MAP01).

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
    if (Get-Command python -ErrorAction SilentlyContinue) { return ,@('python') }   # , keeps it an array
    return $null
}

# --- Other mods ---------------------------------------------------------------
# mods\mods.txt lists the mods folder, loaded top to bottom.  A # in front
# switches a mod off; [doom] (or [heretic], [hexen], [chex], or several:
# [doom,chex]) limits it to those games, no tag means every game.  New
# files are added switched on, for Doom: gameplay mods are usually Doom-only.
$ModsDir = Join-Path $Root 'mods'
$ModList = Join-Path $ModsDir 'mods.txt'
$GameNames = @('doom', 'heretic', 'hexen', 'chex')

function Read-ModList {
    $files = @(Get-ChildItem $ModsDir -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @('mods.txt', 'README.txt') } | Sort-Object Name | ForEach-Object { $_.Name })
    $mods = [System.Collections.ArrayList]@()
    if (Test-Path $ModList) {
        foreach ($line in Get-Content $ModList) {
            $t = $line.Trim()
            $on = -not $t.StartsWith('#')
            $t = $t.TrimStart('#').Trim()
            $games = ''
            if ($t -match '^\[([^\]]*)\]\s*(.*)$') { $games = $Matches[1].Trim().ToLower(); $t = $Matches[2].Trim() }
            if ($files -contains $t -and -not ($mods | Where-Object { $_.Name -eq $t })) {
                [void]$mods.Add([pscustomobject]@{ Name = $t; On = $on; Games = $games })
            }
        }
    }
    foreach ($f in $files) {
        if (-not ($mods | Where-Object { $_.Name -eq $f })) { [void]$mods.Add([pscustomobject]@{ Name = $f; On = $true; Games = 'doom' }) }
    }
    return ,$mods
}

function Save-ModList($mods) {
    $lines = @('# Doomscent mods, loaded top to bottom (or use Mods.bat).',
               '# # in front switches a mod off; [doom], [heretic], [hexen], [chex]',
               '# (or several, [doom,chex]) limits it to those games.')
    foreach ($m in $mods) {
        $tag = $(if ($m.Games) { "[$($m.Games)] " } else { '' })
        $lines += $(if ($m.On) { '' } else { '#' }) + $tag + $m.Name
    }
    Set-Content -Path $ModList -Value $lines -Encoding UTF8
}

function Get-GamesLabel($games) {
    if (-not $games) { return 'all games' }
    return (($games -split ',') | ForEach-Object { (Get-Culture).TextInfo.ToTitleCase($_.Trim()) }) -join ', '
}

# The game an IWAD is for.
function Get-IwadGame($file) {
    $n = [System.IO.Path]::GetFileName($file).ToLower()
    if ($n -match '^heretic') { return 'heretic' }
    if ($n -match '^hex') { return 'hexen' }
    if ($n -match '^chex') { return 'chex' }
    return 'doom'
}

if ($args -contains '-mods') {
    # Mods.bat: switch mods on and off, and choose their games.
    if (-not (Test-Path $ModsDir)) { New-Item -ItemType Directory $ModsDir | Out-Null }
    $mods = Read-ModList
    $cycle = @('') + $GameNames
    while ($true) {
        Write-Host ""
        Write-Host "Doomscent mods (in $ModsDir), loaded top to bottom:"
        if ($mods.Count -eq 0) { Write-Host "  (none yet: put mod files or folders in the mods folder)" }
        for ($i = 0; $i -lt $mods.Count; $i++) {
            Write-Host ("  {0,2}. [{1}] {2}  ({3})" -f ($i + 1), $(if ($mods[$i].On) { 'x' } else { ' ' }), $mods[$i].Name, (Get-GamesLabel $mods[$i].Games))
        }
        Save-ModList $mods
        if ($mods.Count -eq 0) { exit 0 }
        Write-Host ""
        Write-Host "  [x] = on, [ ] = off.  After the name: the games it loads for."
        Write-Host "  1, 2, 3...  switch that mod on or off"
        Write-Host "  g1, g2...   change the games mod 1, 2... loads for (all games, Doom,"
        Write-Host "              Heretic, Hexen, Chex Quest; each press moves to the next)"
        Write-Host "  Enter       save and close"
        $answer = Read-Host "Choice"
        if ($answer -eq '') { exit 0 }
        $n = 0
        if ($answer -match '^[gG]\s*(\d+)$') {
            $n = [int]$Matches[1]
            if ($n -ge 1 -and $n -le $mods.Count) {
                $k = [array]::IndexOf($cycle, $mods[$n - 1].Games)
                $mods[$n - 1].Games = $cycle[($k + 1) % $cycle.Count]
            }
        }
        elseif ([int]::TryParse($answer, [ref]$n) -and $n -ge 1 -and $n -le $mods.Count) { $mods[$n - 1].On = -not $mods[$n - 1].On }
    }
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
# Descent 1 by default.  "-descent2" (Doomscent2.bat) plays in Descent II
# mode, which uses its own asset pack; so does having only Descent II's files.
# Other mods (mods\mods.txt, or -file on the command line) load before
# Doomscent so its ship, HUD and replacements win.
$D2 = $false
$GZArgs = @()
$ModFiles = @()
$inFile = $false
foreach ($a in $args) {
    if ($a -ieq '-descent2' -or $a -ieq '--descent2') { $D2 = $true; $inFile = $false }
    elseif ($a -ieq '-mods') { }
    elseif ($a -ieq '-file') { $inFile = $true }
    elseif ($inFile -and -not ($a.StartsWith('-') -or $a.StartsWith('+'))) { $ModFiles += (Resolve-Path $a).Path }
    else { $inFile = $false; $GZArgs += $a }
}
$D1Files = (Test-Path (Join-Path $Data 'DESCENT.PIG')) -and (Test-Path (Join-Path $Data 'DESCENT.HOG'))
$D2Files = (Test-Path (Join-Path $Data 'DESCENT2.HOG')) -and (Test-Path (Join-Path $Data 'DESCENT2.HAM')) -and
           (Test-Path (Join-Path $Data 'GROUPA.PIG')) -and
           ((Test-Path (Join-Path $Data 'DESCENT2.S22')) -or (Test-Path (Join-Path $Data 'DESCENT2.S11')))
if (-not $D2 -and -not $D1Files -and $D2Files) { $D2 = $true }

if ($D2) {
    $Assets = Join-Path $Root 'dd_descent2_assets.pk3'
    $ConvArgs = @('--descent2', $Data, '-o', $Assets)
    $Missing = if ($D2Files) { $null } else { "Copy DESCENT2.HOG, DESCENT2.HAM, GROUPA.PIG and DESCENT2.S22 from your copy of Descent II into $Data\ and run this again." }
} else {
    $Assets = Join-Path $Root 'dd_descent_assets.pk3'
    $ConvArgs = @($Data, '-o', $Assets)
    $Missing = if ($D1Files) { $null } else { "Copy DESCENT.HOG and DESCENT.PIG from your copy of Descent 1 into $Data\ and run this again." }
}
$ConvExe = Join-Path $Root 'tools\ddconvert.exe'
$ConvPy = Join-Path $Root 'tools\ddconvert.py'
$converter = if (Test-Path $ConvExe) { Get-Item $ConvExe } else { Get-Item $ConvPy }
# Ick Mode's face (optional): reconvert when it is added or changed.
$IckFace = Join-Path $Data 'ickface.png'
$stale = -not (Test-Path $Assets)
if (-not $stale) {
    $built = (Get-Item $Assets).LastWriteTime
    $stale = $converter.LastWriteTime -gt $built -or ((Test-Path $IckFace) -and (Get-Item $IckFace).LastWriteTime -gt $built)
}
if ($stale) {
    if ($Missing) { Fail $Missing }
    Write-Host "Converting your Descent data..."
    if ($converter.Extension -eq '.exe') {
        & $ConvExe @ConvArgs
    } else {
        $py = Find-Python
        if (-not $py) { Fail "Python 3 is needed to convert the Descent data (https://www.python.org/downloads/)." }
        & $py[0] $py[1..9] $ConvPy @ConvArgs
    }
    if ($LASTEXITCODE) { Fail "Converting the Descent data failed (see above)." }
}

# --- Play -------------------------------------------------------------------
$iwads = Get-ChildItem $Data -File | Where-Object { $_.Name -match '\.(wad|ipk3|pk3)$' }
if (-not $iwads) {
    Fail "Copy a Doom IWAD (DOOM.WAD, DOOM2.WAD, ... or Freedoom's freedoom2.wad) into $Data\."
}

# Mods for only some games need to know which game this is: from -iwad,
# the only IWAD, or by asking (instead of GZDoom's own picker).
if (Test-Path $ModsDir) {
    $mods = Read-ModList
    Save-ModList $mods
    $on = @($mods | Where-Object { $_.On })
    $game = $null
    $k = [array]::IndexOf(@($GZArgs | ForEach-Object { $_.ToLower() }), '-iwad')
    if ($k -ge 0 -and $k + 1 -lt $GZArgs.Count) { $game = Get-IwadGame $GZArgs[$k + 1] }
    elseif (@($iwads).Count -eq 1) { $game = Get-IwadGame @($iwads)[0].Name }
    elseif ($on | Where-Object { $_.Games }) {
        Write-Host "Which game?"
        $list = @($iwads | Sort-Object Name)
        for ($i = 0; $i -lt $list.Count; $i++) { Write-Host ("  {0,2}. {1}" -f ($i + 1), $list[$i].Name) }
        $n = 0
        do { $answer = Read-Host "Number" } until ([int]::TryParse($answer, [ref]$n) -and $n -ge 1 -and $n -le $list.Count)
        $GZArgs = @('-iwad', $list[$n - 1].Name) + $GZArgs
        $game = Get-IwadGame $list[$n - 1].Name
    }
    $use = @($on | Where-Object { -not $_.Games -or ($game -and (($_.Games -split ',') | ForEach-Object { $_.Trim() }) -contains $game) })
    foreach ($m in $on) {
        if ($use -notcontains $m) { Write-Host "Not loading $($m.Name) ($(Get-GamesLabel $m.Games) only)." }
    }
    $ModFiles = @($use | ForEach-Object { Join-Path $ModsDir $_.Name }) + $ModFiles
}

# Run from data\ so GZDoom finds the IWADs there and offers a choice.
Set-Location $Data
& $GZDoom -file @ModFiles $Assets $ModPk3 @GZArgs
