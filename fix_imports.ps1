$dir = "E:\AurisTV_plataformas(Web_Desktop"
$oldStr = "package:auris_sdk/live/auris_core.dart"
$newStr = "package:auris_core/auris_core.dart"

$files = Get-ChildItem -Path $dir -Recurse -File -Filter *.dart
$count = 0
foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match [regex]::Escape($oldStr)) {
        $content = $content -replace [regex]::Escape($oldStr), $newStr
        Set-Content $file.FullName -Value $content -NoNewline
        $count++
    }
}
Write-Host "Web_Desktop: Replaced in $count files"