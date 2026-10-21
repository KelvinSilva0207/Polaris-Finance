# Genera los derivados de icono a partir de assets/logo.png.
#
# - icon_square.png    : logo clasico (Android legacy, iOS, web, Windows).
# - icon_foreground.png: primer plano adaptativo (Android), dentro de la zona
#                        segura para que el logo se vea con buen tamano.
#
# Uso:  powershell -File tool/generate_icons.ps1
#
# El logo se recorta a su caja visible y se centra en un lienzo transparente
# de 1024x1024 escalado para ocupar la fraccion indicada del lienzo.

param(
  [string]$LogoPath = "assets/logo.png",
  [double]$SquareFraction = 0.78,
  [double]$ForegroundFraction = 0.72,
  [string]$SquareOut = "icon_square.png",
  [string]$ForegroundOut = "icon_foreground.png",
  [int]$Canvas = 1024
)

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$logoFull = Join-Path $root $LogoPath
if (-not (Test-Path -LiteralPath $logoFull)) {
  throw "No se encontro el logo: $logoFull"
}

$src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $logoFull))

# Caja visible del logo (ignora margen transparente).
$minX = $src.Width; $minY = $src.Height; $maxX = -1; $maxY = -1
for ($y = 0; $y -lt $src.Height; $y++) {
  for ($x = 0; $x -lt $src.Width; $x++) {
    if ($src.GetPixel($x, $y).A -gt 10) {
      if ($x -lt $minX) { $minX = $x }
      if ($x -gt $maxX) { $maxX = $x }
      if ($y -lt $minY) { $minY = $y }
      if ($y -gt $maxY) { $maxY = $y }
    }
  }
}
if ($maxX -lt 0) { throw "El logo no tiene pixeles visibles." }
$cropW = $maxX - $minX + 1
$cropH = $maxY - $minY + 1

function New-Icon([double]$fraction, [string]$outName) {
  $target = [int]($Canvas * $fraction)
  $scale = [double]$target / [Math]::Max($cropW, $cropH)
  $drawW = [int]($src.Width * $scale)
  $drawH = [int]($src.Height * $scale)
  $offX = [int](($Canvas - $drawW) / 2)
  $offY = [int](($Canvas - $drawH) / 2)

  $canvasBmp = New-Object System.Drawing.Bitmap($Canvas, $Canvas, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($canvasBmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.Clear([System.Drawing.Color]::Transparent)
  $dest = New-Object System.Drawing.Rectangle($offX, $offY, $drawW, $drawH)
  $g.DrawImage($src, $dest)
  $g.Dispose()

  $outFull = Join-Path $root $outName
  $canvasBmp.Save($outFull, [System.Drawing.Imaging.ImageFormat]::Png)
  $canvasBmp.Dispose()
  Write-Output "$outName -> contenido $target px ($([Math]::Round($fraction * 100))%)"
}

New-Icon $SquareFraction $SquareOut
New-Icon $ForegroundFraction $ForegroundOut
$src.Dispose()
