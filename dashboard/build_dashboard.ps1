# Builds the Power BI dashboard from the project files in dashboard/powerbi_project/.
#
# What it does:
#   1. Copies the Power BI Project (.pbip) to dashboard/build/ (git-ignored).
#   2. Points every table at this repository's data/processed/ folder.
#   3. Opens the project in Power BI Desktop, which loads the data.
# Then, in Power BI Desktop: File > Save as > dashboard\EBA_credit_risk_dashboard.pbix
#
# Run from PowerShell (any folder):
#   powershell -ExecutionPolicy Bypass -File "<repo>\dashboard\build_dashboard.ps1"
#       Local mode (default): tables read data/processed/ on this computer. Use while developing.
#   powershell -ExecutionPolicy Bypass -File "<repo>\dashboard\build_dashboard.ps1" -Source GitHub
#       GitHub mode: tables read the CSV files from the public repository, so the saved .pbix
#       contains no local folder path or user name and refreshes on any computer.
#       Use this for the .pbix that is published. The repository must already be pushed and public.

param(
    [ValidateSet("Local", "GitHub")] [string]$Source = "Local",
    [string]$GitHubRawBase = "https://raw.githubusercontent.com/agrawallachanchal/eba-credit-risk-analytics/main/data/processed/"
)

$ErrorActionPreference = "Stop"

$dashboardDir = $PSScriptRoot
$repoRoot     = Split-Path -Parent $dashboardDir
$dataFolder   = Join-Path $repoRoot "data\processed"
$template     = Join-Path $dashboardDir "powerbi_project"
$buildDir     = Join-Path $dashboardDir "build"
$projectName  = "EBA_credit_risk_dashboard"

Write-Host "Repository:  $repoRoot"
Write-Host "Data folder: $dataFolder"

# 1. Check the data files are present
$required = @("banks.csv", "countries.csv", "bank_exposure.csv", "sector.csv",
              "country_asset_quality.csv", "npe_trend.csv", "stress_results.csv")
foreach ($f in $required) {
    if (-not (Test-Path (Join-Path $dataFolder $f))) {
        throw "Missing data file: $f in $dataFolder. Run sql\09_exports\export_processed.sql first, or restore the file from the repository."
    }
}
Write-Host "All 7 data files found."

# 2. Fresh copy of the project
if (Test-Path $buildDir) { Remove-Item $buildDir -Recurse -Force }
Copy-Item $template $buildDir -Recurse
Write-Host "Project copied to $buildDir"

# 3. Point each table at its data
if ($Source -eq "GitHub") {
    $base = $GitHubRawBase.TrimEnd('/') + '/'
    try {
        Invoke-WebRequest -Uri ($base + "banks.csv") -UseBasicParsing -Method Head | Out-Null
    } catch {
        throw "Cannot reach $($base)banks.csv. Push the repository and make it public first, or run without -Source GitHub."
    }
    $find = 'File.Contents("__DATA_FOLDER__'
    $replace = 'Web.Contents("' + $base
    $where = $base
} else {
    $dataPath = (Resolve-Path $dataFolder).Path.TrimEnd('\') + '\'
    $find = "__DATA_FOLDER__"
    $replace = $dataPath
    $where = $dataPath
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$tmdlFiles = Get-ChildItem $buildDir -Recurse -Filter "*.tmdl"
foreach ($file in $tmdlFiles) {
    $text = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    if ($text.Contains($find)) {
        $text = $text.Replace($find, $replace)
        [System.IO.File]::WriteAllText($file.FullName, $text, $utf8NoBom)
    }
}
$left = Select-String -Path ($tmdlFiles | ForEach-Object FullName) -Pattern "__DATA_FOLDER__" -SimpleMatch
if ($left) { throw "Data source was not filled in every table." }
Write-Host "Mode: $Source. Tables now read from $where"
if ($Source -eq "GitHub") {
    Write-Host "If Power BI asks how to connect to raw.githubusercontent.com, choose Anonymous, then Connect."
}

# 4. Open in Power BI Desktop
$pbip = Join-Path $buildDir "$projectName.pbip"
$candidates = @(
    (Join-Path $env:ProgramFiles "Microsoft Power BI Desktop\bin\PBIDesktop.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Microsoft Power BI Desktop\bin\PBIDesktop.exe")
)
$exe = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if ($exe) {
    Start-Process -FilePath $exe -ArgumentList "`"$pbip`""
} else {
    # Microsoft Store installs register the .pbip file type instead of a fixed path
    Start-Process -FilePath $pbip
}

Write-Host ""
Write-Host "Power BI Desktop is opening the project. When it has loaded:"
Write-Host "  1. If asked, click Refresh (Home > Refresh) so all seven tables load."
Write-Host "  2. Check the visuals against the expected values in dashboard\README.md."
Write-Host "  3. Click page 1, then File > Save as > choose 'Power BI file (*.pbix)' and save to:"
Write-Host "     $(Join-Path $dashboardDir "$projectName.pbix")"
