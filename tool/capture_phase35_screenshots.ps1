$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path $PSScriptRoot -Parent)
$fontPath = Join-Path (Get-Location) '.dart_tool/phase35_inter.ttf'
if (-not (Test-Path -LiteralPath $fontPath)) {
  Invoke-WebRequest -Uri 'https://fonts.gstatic.com/s/a/15b294b67f2f8bbc04d990023ef4aec66502b87dc9040d84abe5f896ccb693de.ttf' -OutFile $fontPath
}
flutter test test/phase35_visual_capture_test.dart --update-goldens --dart-define=PHASE35_CAPTURE=true
if ($LASTEXITCODE -ne 0) { throw 'Phase 3.5 render capture failed.' }
$gallery = Join-Path (Get-Location) 'docs/screenshots/phase_3'
Copy-Item -LiteralPath (Join-Path $gallery '01_onboarding_stage1_mobile_390.png') -Destination (Join-Path $gallery '01_onboarding_mobile_390.png')
Copy-Item -LiteralPath (Join-Path $gallery '01_onboarding_stage1_medium_920.png') -Destination (Join-Path $gallery '01_onboarding_medium_920.png')
Copy-Item -LiteralPath (Join-Path $gallery '05_role_selection_modal_desktop_1440.png') -Destination (Join-Path $gallery '05_role_selection_modal_desktop.png')
Copy-Item -LiteralPath (Join-Path $gallery '06_student_register_lens_preview_desktop_1440.png') -Destination (Join-Path $gallery '06_student_register_lens_preview_desktop.png')
