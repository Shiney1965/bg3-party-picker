# Party Picker - render the shipping documents.
#   dist_docs\README.md          -> README.docx (python-docx) and README.pdf (Word)
#   dist_docs\INSTALL.md         -> INSTALL.docx              and INSTALL.pdf
#   dist_docs\NexusMods_BBCode.txt -> NexusMods_Description.md (a Markdown preview of the Nexus page)
#
# Same route as the MIR and Save Search bundles. Word occasionally stalls while BG3 has the display;
# close the game if a PDF step hangs. One Word process per document (docx2pdf.ps1).
$ErrorActionPreference = 'Stop'
$tools = Split-Path -Parent $MyInvocation.MyCommand.Path
$root  = Split-Path -Parent $tools
$docs  = Join-Path $root 'dist_docs'
$py    = 'C:\Users\Alan\AppData\Local\Programs\Python\Python313\python.exe'
if (-not (Test-Path $py)) { $py = 'python' }

$set = @(
    @{ md = 'README.md';  docx = 'README.docx';  pdf = 'README.pdf';  title = 'Party Picker - README' },
    @{ md = 'INSTALL.md'; docx = 'INSTALL.docx'; pdf = 'INSTALL.pdf'; title = 'Party Picker - Install' }
)

foreach ($d in $set) {
    $md = Join-Path $docs $d.md
    if (-not (Test-Path $md)) { throw "missing $md" }
    & $py (Join-Path $tools 'md2docx.py') $md (Join-Path $docs $d.docx) $d.title
    if ($LASTEXITCODE -ne 0) { throw "md2docx failed for $($d.md)" }
    Write-Output ("docx: " + $d.docx + "  " + (Get-Item (Join-Path $docs $d.docx)).Length + " bytes")
}

if (Get-Process -Name 'bg3','bg3_dx11' -ErrorAction SilentlyContinue) {
    Write-Warning 'BG3 is running - Word has been seen to stall in that state. Close the game if this hangs.'
}
foreach ($d in $set) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tools 'docx2pdf.ps1') `
        -Docx (Join-Path $docs $d.docx) -Pdf (Join-Path $docs $d.pdf)
    if ($LASTEXITCODE -ne 0) { throw "docx2pdf failed for $($d.docx)" }
}

& $py (Join-Path $tools 'bbcode2md.py') (Join-Path $docs 'NexusMods_BBCode.txt') (Join-Path $docs 'NexusMods_Description.md')
if ($LASTEXITCODE -ne 0) { throw "bbcode2md failed" }
Write-Output "documents rendered."
