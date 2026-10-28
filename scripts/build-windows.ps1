$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Project = Join-Path $Root 'windows/ChainedMac.Windows/ChainedMac.Windows.csproj'
$PublishDirectory = Join-Path $Root 'dist/windows-x64'
$Zip = Join-Path $Root 'dist/ChainedMac-Windows-x64.zip'
$WebsiteZip = Join-Path $Root 'website/downloads/ChainedMac-Windows-x64.zip'

Remove-Item $PublishDirectory -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $Zip, $WebsiteZip -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path (Split-Path $Zip) -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path $WebsiteZip) -Force | Out-Null

dotnet publish $Project `
  --configuration Release `
  --runtime win-x64 `
  --self-contained true `
  --output $PublishDirectory `
  -p:PublishSingleFile=true `
  -p:EnableCompressionInSingleFile=true `
  -p:IncludeNativeLibrariesForSelfExtract=true `
  -p:DebugType=None

$PackageReadme = @'
ChainedMac for Windows x64

1. Extract this ZIP folder.
2. Run ChainedMac.exe.
3. Keep the app open from the notification area near the clock.
4. Arrange open windows, then use Shift+Left and Shift+Right to focus them.

Ctrl+Alt+R restores the positions saved when the strip was arranged.
Right-click the notification-area icon to open the controls or quit.
'@
Set-Content -Path (Join-Path $PublishDirectory 'README.txt') -Value $PackageReadme -Encoding utf8
Compress-Archive -Path (Join-Path $PublishDirectory '*') -DestinationPath $Zip -CompressionLevel Optimal
Copy-Item $Zip $WebsiteZip
Write-Host "Created $Zip"
