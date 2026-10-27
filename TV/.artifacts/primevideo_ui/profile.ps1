param(
  [Parameter(Mandatory=$true)][string]$Path,
  [string]$Axis = "row",
  [int]$X0 = 0,
  [int]$X1 = -1,
  [int]$Y0 = 0,
  [int]$Y1 = -1,
  [int]$Threshold = 40,
  [int]$MinCount = 3
)
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Bitmap]::FromFile($Path)
$w = $img.Width; $h = $img.Height
if ($X1 -lt 0) { $X1 = $w - 1 }
if ($Y1 -lt 0) { $Y1 = $h - 1 }

$rect = New-Object System.Drawing.Rectangle 0,0,$w,$h
$fmt = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
$d = $img.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $fmt)
$raw = New-Object byte[] ($d.Stride * $h)
[System.Runtime.InteropServices.Marshal]::Copy($d.Scan0, $raw, 0, $raw.Length)
$img.UnlockBits($d)

function Sample($x, $y) {
  $i = $y * $script:d.Stride + $x * 4
  return [math]::Max($script:raw[$i], [math]::Max($script:raw[$i+1], $script:raw[$i+2]))
}

$counts = @{}
if ($Axis -eq "row") {
  for ($y = $Y0; $y -le $Y1; $y++) {
    $c = 0
    for ($x = $X0; $x -le $X1; $x++) { if ((Sample $x $y) -gt $Threshold) { $c++ } }
    $counts[$y] = $c
  }
} else {
  for ($x = $X0; $x -le $X1; $x++) {
    $c = 0
    for ($y = $Y0; $y -le $Y1; $y++) { if ((Sample $x $y) -gt $Threshold) { $c++ } }
    $counts[$x] = $c
  }
}

$keys = $counts.Keys | Sort-Object
$runs = @()
$runStart = $null; $runEnd = $null
foreach ($k in $keys) {
  if ($counts[$k] -ge $MinCount) {
    if ($null -eq $runStart) { $runStart = $k }
    $runEnd = $k
  } else {
    if ($null -ne $runStart) { $runs += ,@($runStart, $runEnd); $runStart = $null }
  }
}
if ($null -ne $runStart) { $runs += ,@($runStart, $runEnd) }

Write-Output "axis=$Axis range=[$X0..$X1]x[$Y0..$Y1] threshold=$Threshold minCount=$MinCount"
foreach ($r in $runs) { Write-Output ("  span {0}..{1}   (len={2})" -f $r[0], $r[1], ($r[1]-$r[0]+1)) }
$img.Dispose()
