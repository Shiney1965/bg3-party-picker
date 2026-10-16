# Convert ONE .docx to .pdf with Word COM.
# Deliberately one document per process: driving several documents from a single long-lived Word
# instance was seen to stall indefinitely on this machine, while a fresh instance per document
# completes in about two seconds. Called once per document by make_docs.ps1.
param(
    [Parameter(Mandatory = $true)][string]$Docx,
    [Parameter(Mandatory = $true)][string]$Pdf
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Docx)) { throw "missing $Docx" }
if (Test-Path $Pdf) { Remove-Item $Pdf -Force }

$w = New-Object -ComObject Word.Application
$w.Visible = $false
$w.DisplayAlerts = 0
try {
    $doc = $w.Documents.Open($Docx, $false, $true)   # ConfirmConversions=false, ReadOnly=true
    $doc.ExportAsFixedFormat($Pdf, 17)               # 17 = wdExportFormatPDF
    $doc.Close($false)
} finally {
    $w.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($w) | Out-Null
}
if (-not (Test-Path $Pdf)) { throw "no PDF produced for $Docx" }
Write-Output ("pdf: " + (Split-Path $Pdf -Leaf) + "  " + (Get-Item $Pdf).Length + " bytes")
