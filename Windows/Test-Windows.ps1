$ErrorActionPreference = 'Stop'
$app = Join-Path $PSScriptRoot 'TisaDynamicIsland.exe'
if (-not (Test-Path $app)) {
    Write-Host 'Unzip the whole download first. Test-Windows.cmd must be beside TisaDynamicIsland.exe.' -ForegroundColor Yellow
    exit 1
}
if (Get-Process -Name TisaDynamicIsland -ErrorAction SilentlyContinue) {
    Write-Host 'First quit Tisa Dynamic Island from its tray menu, then run this test again.' -ForegroundColor Yellow
    Write-Host 'Your running app will not be stopped automatically.'
    exit 1
}
$desktop = [Environment]::GetFolderPath('Desktop')
if (-not $desktop) { $desktop = [IO.Path]::GetTempPath() }
$output = Join-Path $desktop ('Tisa-Windows-Test-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $output | Out-Null
Write-Host "Results will be saved locally to: $output"
Write-Host 'No files are uploaded. The test does not save preference changes or record clipboard history.'
$exitCode = 1
try {
    $process = Start-Process -FilePath $app -ArgumentList @('--smoke-test', ('"{0}"' -f $output)) -PassThru
    if (-not $process.WaitForExit(120000)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw 'The native test took over two minutes and was stopped. Report this timeout.'
    }
    $result = Join-Path $output 'result.txt'
    if (-not (Test-Path $result)) { throw "The app exited without writing test results (exit code $($process.ExitCode))." }
    Get-Content $result | Write-Host
    if ($process.ExitCode -ne 0) { throw 'One or more native checks failed. Keep the result.txt file.' }
    $exitCode = 0
    Write-Host 'Automatic native checks passed. Complete the manual checklist before calling the app ready.' -ForegroundColor Green
}
catch {
    $_.Exception.Message | Set-Content (Join-Path $output 'runner-error.txt')
    Write-Host $_.Exception.Message -ForegroundColor Red
}
finally {
    [ordered]@{
        TestedAt = (Get-Date).ToString('o')
        WindowsVersion = [Environment]::OSVersion.Version.ToString()
        Is64BitOperatingSystem = [Environment]::Is64BitOperatingSystem
        ExitCode = $exitCode
    } | ConvertTo-Json | Set-Content (Join-Path $output 'environment.json')
    $checklist = Join-Path $PSScriptRoot 'WINDOWS-TEST-CHECKLIST.txt'
    if (Test-Path $checklist) { Copy-Item $checklist $output }
    try { Compress-Archive -Path (Join-Path $output '*') -DestinationPath ($output + '.zip') -Force }
    catch { Write-Host 'Could not zip results. The uncompressed results folder is still available.' }
    Write-Host "Open $output and review the screenshots. They show the app only, including any currently playing media."
    Write-Host 'Nothing has been uploaded. Review these files before sharing them.'
}
exit $exitCode
