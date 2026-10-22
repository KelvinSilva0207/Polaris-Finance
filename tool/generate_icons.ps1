# Genera los derivados de icono a partir de assets/logo.png.
#
# El artwork original es un cuadrado redondeado azul marino con la brújula/
# estrella en cian. Ese margen propio (el cuadrado redondeado) es lo que hacia
# que el icono se viera pequeño dentro de la cuadricula del lanzador, porque
# ademas se le anadian el fondo azul de la capa adaptativa y el margen
# transparente del lienzo.
#
# Salidas:
# - icon_square.png    : logo completo al 100% del lienzo (Android legacy,
#                        web y Windows). El sistema aplica las esquinas.
# - icon_foreground.png: solo la brújula/estrella, al 61% del lienzo (la zona
#                        segura de los iconos adaptativos de Android) sobre
#                        fondo transparente. Se combina con el fondo navy.
# - icon_ios.png       : navy plano a sangre con la brújula al 81.6% (iOS no
#                        admite canal alfa, el squircle lo aplica el sistema).
#
# Uso:  powershell -File tool/generate_icons.ps1
#
# Nota sobre el icono adaptativo: Android muestra solo la zona central de
# 72/108 del lienzo (66.7%) y garantiza 66/108 (61%) sin recortes. Por eso la
# brújula ocupa el 61% del lienzo: llena por completo el circulo visible sin
# que las puntas se recorten.

param(
  [string]$LogoPath = "assets/logo.png",
  [double]$SquareFraction = 1.0,
  [double]$ForegroundFraction = 0.61,
  [double]$IosFraction = 0.816,
  [string]$BackgroundColor = "#041027",
  [string]$SquareOut = "icon_square.png",
  [string]$ForegroundOut = "icon_foreground.png",
  [string]$IosOut = "icon_ios.png",
  [int]$CanvasSize = 1024
)

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$logoFull = Join-Path $root $LogoPath
if (-not (Test-Path -LiteralPath $logoFull)) {
  throw "No se encontro el logo: $logoFull"
}

$src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $logoFull))
$bg = [System.Drawing.ColorTranslator]::FromHtml($BackgroundColor)

# --- Caja visible del logo (ignora el margen transparente) --------------------
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
$logoRect = New-Object System.Drawing.Rectangle($minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1))

# --- Mascara de la brujula (pixeles cian/azules sobre el navy) ---------------
$star = New-Object System.Drawing.Bitmap($src.Width, $src.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$sMinX = $src.Width; $sMinY = $src.Height; $sMaxX = -1; $sMaxY = -1
for ($y = 0; $y -lt $src.Height; $y++) {
  for ($x = 0; $x -lt $src.Width; $x++) {
    $c = $src.GetPixel($x, $y)
    $isStar = ($c.A -gt 250) -and (($c.G -gt 90) -or ($c.B -gt 110))
    if ($isStar) {
      $star.SetPixel($x, $y, $c)
      if ($x -lt $sMinX) { $sMinX = $x }
      if ($x -gt $sMaxX) { $sMaxX = $x }
      if ($y -lt $sMinY) { $sMinY = $y }
      if ($y -gt $sMaxY) { $sMaxY = $y }
    }
  }
}
if ($sMaxX -lt 0) { throw "No se detecto la brujula en el logo." }
$starRect = New-Object System.Drawing.Rectangle($sMinX, $sMinY, ($sMaxX - $sMinX + 1), ($sMaxY - $sMinY + 1))

# Lienzo transparente (o del color indicado) con el area de dibujo.
function New-Layer([System.Drawing.Color]$background) {
  $bmp = New-Object System.Drawing.Bitmap($CanvasSize, $CanvasSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.Clear($background)
  return ,@($bmp, $g)
}

# Dibuja una region del origen escalada a la fraccion indicada del lienzo.
function Draw-Scaled($g, $source, $region, [double]$fraction) {
  $target = [int]($CanvasSize * $fraction)
  $scale = [double]$target / [Math]::Max($region.Width, $region.Height)
  $drawW = [int]($region.Width * $scale)
  $drawH = [int]($region.Height * $scale)
  $offX = [int](($CanvasSize - $drawW) / 2)
  $offY = [int](($CanvasSize - $drawH) / 2)
  $dest = New-Object System.Drawing.Rectangle($offX, $offY, $drawW, $drawH)
  $g.DrawImage($source, $dest, $region, [System.Drawing.GraphicsUnit]::Pixel)
}

function Save-Layer($bmp, $g, [string]$outName) {
  $g.Dispose()
  $outFull = Join-Path $root $outName
  $bmp.Save($outFull, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Output "$outName generado"
}

# 1) Icono clasico: el logo completo al 100% del lienzo.
$layer = New-Layer ([System.Drawing.Color]::Transparent)
Draw-Scaled $layer[1] $src $logoRect $SquareFraction
Save-Layer $layer[0] $layer[1] $SquareOut

# 2) Primer plano adaptativo: solo la brujula, al 61% (zona segura).
$layer = New-Layer ([System.Drawing.Color]::Transparent)
Draw-Scaled $layer[1] $star $starRect $ForegroundFraction
Save-Layer $layer[0] $layer[1] $ForegroundOut

# 3) iOS: navy a sangre con la brujula (iOS no admite alfa).
$layer = New-Layer $bg
Draw-Scaled $layer[1] $star $starRect $IosFraction
Save-Layer $layer[0] $layer[1] $IosOut

$star.Dispose()
$src.Dispose()
