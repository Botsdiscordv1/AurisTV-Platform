$dir = "E:\AurisTV_plataformas(Web_Desktop"
$oldStr = "package:auris_sdk/live/auris_core.dart"
$newStr = "package:auris_core/auris_core.dart"

$files = Get-ChildItem -Path $dir -Recurse -File -Filter *.dart -ErrorAction SilentlyContinue
$count = 0
foreach ($file in $files) {
    try {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -and $content -match [regex]::Escape($oldStr)) {
            $content = $content -replace [regex]::Escape($oldStr), $newStr
            Set-Content $file.FullName -Value $content -NoNewline -ErrorAction SilentlyContinue
            $count++
        }
    } catch { }
}
Write-Host "Web_Desktop: Replaced in $count files"