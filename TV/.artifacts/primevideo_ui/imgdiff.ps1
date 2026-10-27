param(
  [Parameter(Mandatory=$true)][string]$A,
  [Parameter(Mandatory=$true)][string]$B,
  [int]$Tolerance = 8
)
Add-Type -AssemblyName System.Drawing

$imgA = [System.Drawing.Bitmap]::FromFile($A)
$imgB = [System.Drawing.Bitmap]::FromFile($B)
if ($imgA.Width -ne $imgB.Width -or $imgA.Height -ne $imgB.Height) { Write-Output "SIZE MISMATCH"; exit 1 }

$w = $imgA.Width; $h = $imgA.Height
$rect = New-Object System.Drawing.Rectangle 0,0,$w,$h
$fmt = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
$mode = [System.Drawing.Imaging.ImageLockMode]::ReadOnly

$dA = $imgA.LockBits($rect, $mode, $fmt)
$dB = $imgB.LockBits($rect, $mode, $fmt)
$byteLen = $dA.Stride * $h
$rawA = New-Object byte[] $byteLen
$rawB = New-Object byte[] $byteLen
[System.Runtime.InteropServices.Marshal]::Copy($dA.Scan0, $rawA, 0, $byteLen)
[System.Runtime.InteropServices.Marshal]::Copy($dB.Scan0, $rawB, 0, $byteLen)
$imgA.UnlockBits($dA)
$imgB.UnlockBits($dB)

$px = [int]($byteLen / 4)
$intA = New-Object int[] $px
$intB = New-Object int[] $px
[Buffer]::BlockCopy($rawA, 0, $intA, 0, $byteLen)
[Buffer]::BlockCopy($rawB, 0, $intB, 0, $byteLen)

$minX = $w; $maxX = -1; $minY = $h; $maxY = -1; $count = 0
$T = [int]$Tolerance

for ($i = 0; $i -lt $px; $i++) {
  $va = $intA[$i]; $vb = $intB[$i]
  $dr = (($va -band 0xFF) - ($vb -band 0xFF)); if ($dr -lt 0) { $dr = -$dr }
  $dg = ((($va -shr 8) -band 0xFF) - (($vb -shr 8) -band 0xFF)); if ($dg -lt 0) { $dg = -$dg }
  $db = ((($va -shr 16) -band 0xFF) - (($vb -shr 16) -band 0xFF)); if ($db -lt 0) { $db = -$db }
  if ($dr -gt $T -or $dg -gt $T -or $db -gt $T) {
    $count++
    $x = $i % $w
    $y = [math]::Floor($i / $w)
    if ($x -lt $minX) { $minX = $x }
    if ($x -gt $maxX) { $maxX = $x }
    if ($y -lt $minY) { $minY = $y }
    if ($y -gt $maxY) { $maxY = $y }
  }
}

if ($count -eq 0) {
  Write-Output "NO CHANGE"
} else {
  Write-Output "changed_pixels=$count  ($([math]::Round(100.0*$count/$px,3))%)"
  Write-Output "bbox: x=$minX..$maxX  y=$minY..$maxY  (w=$($maxX-$minX+1) h=$($maxY-$minY+1))"
}

$imgA.Dispose(); $imgB.Dispose()
