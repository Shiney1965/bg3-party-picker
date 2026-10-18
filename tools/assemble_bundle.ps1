# Party Picker release-bundle assembler (same layout as the MIR bundle).
# Collects the committed PartyPicker.pak, the rendered docs and the licence into
# release\PartyPicker-<version>\, writes MANIFEST.txt with SHA256s, and zips the folder.
#
# The version is read from PP.VERSION in Shared\Common.lua (the string the running code prints in its
# load line) and cross-checked against meta.lsx's Version64. The pak is copied, never rebuilt: the
# bundle ships the exact binary that was tested.
#
# Usage:  powershell -File tools\assemble_bundle.ps1 [-Force]
# Refuses to overwrite an existing bundle folder or zip unless -Force is given (then files are
# overwritten in place; nothing is deleted).
param([switch]$Force)
$ErrorActionPreference = 'Stop'
$tools = Split-Path -Parent $MyInvocation.MyCommand.Path
$root  = Split-Path -Parent $tools

$common = Get-Content (Join-Path $root 'src\Mods\PartyPicker\ScriptExtender\Lua\Shared\Common.lua') -Raw
$m = [regex]::Match($common, 'PP\.VERSION\s*=\s*"(\d+)\.(\d+)\.(\d+)"')
if (-not $m.Success) { throw 'no PP.VERSION in Common.lua' }
$Version = "$($m.Groups[1].Value).$($m.Groups[2].Value).$($m.Groups[3].Value)"
$v64 = ([int64]$m.Groups[1].Value -shl 55) -bor ([int64]$m.Groups[2].Value -shl 47) -bor ([int64]$m.Groups[3].Value -shl 31)
$meta = Get-Content (Join-Path $root 'src\Mods\PartyPicker\meta.lsx') -Raw
$metaHits = ([regex]::Matches($meta, 'id="Version64" type="int64" value="' + $v64 + '"')).Count
if ($metaHits -lt 2) { throw "version mismatch: Common.lua says $Version but meta.lsx's two Version64 values are not $v64" }
Write-Output ("version: " + $Version)

$pak  = Join-Path $root 'PartyPicker.pak'
$docs = Join-Path $root 'dist_docs'
$rel  = Join-Path $root 'release'
$out  = Join-Path $rel ('PartyPicker-' + $Version)
$zip  = Join-Path $rel ('PartyPicker-' + $Version + '.zip')
if (-not (Test-Path $pak)) { throw 'PartyPicker.pak not found' }
# The pak must be the build recorded in RUN_CARD.md (the one that was tested).
$card = Get-Content (Join-Path $root 'RUN_CARD.md') -Raw
$want = [regex]::Match($card, 'SHA256 `([0-9a-fA-F]{64})`')
if (-not $want.Success) { throw 'no SHA256 line in RUN_CARD.md' }
$have = (Get-FileHash $pak -Algorithm SHA256).Hash
if ($have -ne $want.Groups[1].Value.ToUpper()) { throw "PartyPicker.pak ($have) is not the build recorded in RUN_CARD.md" }
$docList = @('README.md','README.docx','README.pdf','INSTALL.md','INSTALL.docx','INSTALL.pdf','CHANGELOG.md','LICENSE-THIRD-PARTY.md','NexusMods_BBCode.txt','NexusMods_Description.md')
if (((Test-Path $out) -or (Test-Path $zip)) -and -not $Force) { throw "bundle already exists: $out (or its zip); pass -Force to overwrite it" }
if ($Force -and (Test-Path $out)) {
    # Overwrite in place; a file that is no longer part of the bundle would be left behind, so refuse that.
    $extra = Get-ChildItem $out -File | Where-Object { $_.Name -notin (@('PartyPicker.pak','LICENSE','MANIFEST.txt') + $docList[0..7]) }
    if ($extra) { throw ("unexpected files in the old bundle: " + ($extra.Name -join ', ')) }
}
# Every check before anything is written, so a failure never leaves a half-built folder behind.
foreach ($f in $docList) {
    if (-not (Test-Path (Join-Path $docs $f))) { throw "missing doc: $f (run tools\make_docs.ps1)" }
}
if (-not (Test-Path (Join-Path $root 'LICENSE'))) { throw 'LICENSE not found' }
New-Item -ItemType Directory -Path $out -Force | Out-Null

Copy-Item $pak (Join-Path $out 'PartyPicker.pak')
foreach ($f in $docList[0..7]) { Copy-Item (Join-Path $docs $f) (Join-Path $out $f) }
Copy-Item (Join-Path $root 'LICENSE') (Join-Path $out 'LICENSE')

# The Nexus description is for the mod PAGE, not the download: kept beside the bundle.
Copy-Item (Join-Path $docs 'NexusMods_BBCode.txt') (Join-Path $rel ('NexusMods_BBCode_v' + $Version + '.txt'))
Copy-Item (Join-Path $docs 'NexusMods_Description.md') (Join-Path $rel ('NexusMods_Description_v' + $Version + '.md'))

$lines = @()
$lines += 'Party Picker - release bundle manifest'
$lines += ('version: ' + $Version)
$lines += ('assembled: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
$lines += ''
$lines += 'SHA256                                                            bytes  file'
Get-ChildItem $out -File | Where-Object { $_.Name -ne 'MANIFEST.txt' } | Sort-Object Name | ForEach-Object {
    $h = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
    $lines += ('{0}  {1,7}  {2}' -f $h, $_.Length, $_.Name)
}
$lines += ''
$lines += 'REQUIREMENTS: BG3 Script Extender (v29+); Mod Configuration Menu (Nexus 9162, v1.38+), loaded ABOVE Party Picker.'
$lines | Set-Content (Join-Path $out 'MANIFEST.txt') -Encoding utf8

# Flat zip (files at the top, no folder inside), like MIR-1.1.1.zip.
Compress-Archive -Path (Join-Path $out '*') -DestinationPath $zip -Force:$Force
Write-Output ('Bundle assembled: ' + $out)
Get-ChildItem $out | Select-Object Name, Length | Format-Table -AutoSize
$zipSha = (Get-FileHash $zip -Algorithm SHA256).Hash
Write-Output ('zip: ' + $zip + '  ' + (Get-Item $zip).Length + ' bytes  SHA256 ' + $zipSha)

# GitHub release notes, with this build's hashes filled in (written to release\ and the repo root).
$tpl = Join-Path $docs 'RELEASE_NOTES.md'
if (Test-Path $tpl) {
    $notes = [IO.File]::ReadAllText($tpl)
    $notes = $notes.Replace('{{VERSION}}', $Version).Replace('{{PAK_SHA}}', $have).Replace('{{PAK_BYTES}}', ('{0:N0}' -f (Get-Item $pak).Length)).Replace('{{ZIP_SHA}}', $zipSha).Replace('{{ZIP_BYTES}}', ('{0:N0}' -f (Get-Item $zip).Length))
    if ($notes -match '\{\{') { throw 'unfilled placeholder in RELEASE_NOTES.md' }
    $utf8 = New-Object Text.UTF8Encoding $false
    foreach ($dest in @((Join-Path $rel ('RELEASE_NOTES_v' + $Version + '.md')), (Join-Path $root ('RELEASE_NOTES_v' + $Version + '.md')))) {
        [IO.File]::WriteAllText($dest, $notes, $utf8)
    }
    Write-Output ('release notes: RELEASE_NOTES_v' + $Version + '.md')
}
