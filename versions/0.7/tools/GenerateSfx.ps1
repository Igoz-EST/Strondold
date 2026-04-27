# Generates procedural mono 16-bit 44.1kHz WAV files for SFX (no external deps).
$ErrorActionPreference = "Stop"
$Rate = 44100
$Root = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $Root "assets\audio\sfx"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Write-WavMono16 {
    param([string]$Path, [int16[]]$Samples, [int]$SampleRate = 44100)
    $num = $Samples.Length
    $dataBytes = $num * 2
    $fs = [System.IO.File]::Create($Path)
    try {
        $bw = New-Object System.IO.BinaryWriter $fs
        $bw.Write([char[]]"RIFF")
        $bw.Write([int32](36 + $dataBytes))
        $bw.Write([char[]]"WAVE")
        $bw.Write([char[]]"fmt ")
        $bw.Write([int32]16)
        $bw.Write([int16]1)
        $bw.Write([int16]1)
        $bw.Write([int32]$SampleRate)
        $br = $SampleRate * 2
        $bw.Write([int32]$br)
        $bw.Write([int16]2)
        $bw.Write([int16]16)
        $bw.Write([char[]]"data")
        $bw.Write([int32]$dataBytes)
        foreach ($s in $Samples) { $bw.Write([int16]$s) }
    } finally { $fs.Close() }
}

function ClampI16([double]$v) {
    if ($v -gt 32766) { return [int16]32766 }
    if ($v -lt -32767) { return [int16]-32767 }
    return [int16][math]::Round($v)
}

function NoiseSample([System.Random]$rng) {
    return ($rng.NextDouble() * 2.0 - 1.0)
}

function NormalizePeak([int16[]]$arr, [double]$peak = 0.92) {
    $m = 0.0001
    foreach ($x in $arr) { $a = [math]::Abs([int]$x); if ($a -gt $m) { $m = $a } }
    $g = ($peak * 32767.0) / $m
    for ($i = 0; $i -lt $arr.Length; $i++) {
        $arr[$i] = ClampI16([double]$arr[$i] * $g)
    }
    return $arr
}

$rng = [System.Random]::new(42)

# --- sword_swing.wav (~0.22s) ---
$n = [int]($Rate * 0.22)
$sword = New-Object int16[] $n
for ($i = 0; $i -lt $n; $i++) {
    $t = [double]$i / $Rate
    $env = [math]::Sin([math]::PI * $i / $n)
    $f = 2200.0 - 7000.0 * $t
    $sw = [math]::Sin(2.0 * [math]::PI * $f * $t)
    $nz = NoiseSample($rng) * 0.35
    $v = ($sw * 0.45 + $nz) * $env * 0.85
    $sword[$i] = ClampI16($v * 12000)
}
NormalizePeak $sword 0.88 | Out-Null
Write-WavMono16 (Join-Path $OutDir "sword_swing.wav") $sword

# --- jump.wav (~0.14s) ---
$n = [int]($Rate * 0.14)
$jump = New-Object int16[] $n
for ($i = 0; $i -lt $n; $i++) {
    $u = [double]$i / $n
    $env = [math]::Sin([math]::PI * $u)
    $f = 140.0 + 480.0 * $u
    $t = [double]$i / $Rate
    $v = [math]::Sin(2.0 * [math]::PI * $f * $t) * $env
    $jump[$i] = ClampI16($v * 11000)
}
NormalizePeak $jump 0.9 | Out-Null
Write-WavMono16 (Join-Path $OutDir "jump.wav") $jump

# --- grass_walk.wav (~0.42s seamless-ish loop) ---
$n = [int]($Rate * 0.42)
$grass = New-Object int16[] $n
for ($i = 0; $i -lt $n; $i++) {
    $t = [double]$i / $Rate
    $rustle = NoiseSample($rng) * 0.22 + NoiseSample($rng) * 0.18
    $lfo = 0.55 + 0.45 * [math]::Sin(2.0 * [math]::PI * 2.4 * $t)
    $v = $rustle * $lfo * 7000.0
    $grass[$i] = ClampI16($v)
}
# Crossfade ends for smoother loop
$blend = 220
for ($k = 0; $k -lt $blend; $k++) {
    $a = [double]$k / $blend
    $i0 = $k
    $i1 = $n - $blend + $k
    $v = $grass[$i0] * (1.0 - $a) + $grass[$i1] * $a
    $grass[$i0] = ClampI16($v)
    $grass[$i1] = ClampI16($v)
}
NormalizePeak $grass 0.55 | Out-Null
Write-WavMono16 (Join-Path $OutDir "grass_walk.wav") $grass

# --- punch.wav (~0.13s) ---
$n = [int]($Rate * 0.13)
$punch = New-Object int16[] $n
for ($i = 0; $i -lt $n; $i++) {
    $t = [double]$i / $Rate
    $dec = [math]::Exp(-$t * 38.0)
    $th = [math]::Sin(2.0 * [math]::PI * 95.0 * $t) * $dec
    $nk = if ($i -lt 480) { NoiseSample($rng) * [math]::Exp(-$t * 80.0) } else { 0 }
    $v = ($th * 0.75 + $nk * 0.4) * 13000.0
    $punch[$i] = ClampI16($v)
}
NormalizePeak $punch 0.92 | Out-Null
Write-WavMono16 (Join-Path $OutDir "punch.wav") $punch

# --- npc_death.wav (~1.25s) ---
$n = [int]($Rate * 1.25)
$death = New-Object int16[] $n
for ($i = 0; $i -lt $n; $i++) {
    $u = [double]$i / $n
    $t = [double]$i / $Rate
    $env = (1.0 - $u) * (1.0 - $u)
    $breath = NoiseSample($rng) * 0.5 + NoiseSample($rng) * 0.35
    $f = 280.0 * (1.0 - 0.55 * $u) + 40.0
    $tone = [math]::Sin(2.0 * [math]::PI * $f * $t) * 0.15 * (1.0 - $u)
    $v = ($breath + $tone) * $env * 9000.0
    $death[$i] = ClampI16($v)
}
NormalizePeak $death 0.85 | Out-Null
Write-WavMono16 (Join-Path $OutDir "npc_death.wav") $death

# --- shield_hit.wav (~0.26s) ---
$n = [int]($Rate * 0.26)
$shield = New-Object int16[] $n
for ($i = 0; $i -lt $n; $i++) {
    $t = [double]$i / $Rate
    $ring = [math]::Sin(2.0 * [math]::PI * 520.0 * $t) * [math]::Exp(-$t * 9.0)
    $ring2 = [math]::Sin(2.0 * [math]::PI * 780.0 * $t) * [math]::Exp(-$t * 12.0)
    $click = if ($i -lt 90) { NoiseSample($rng) * [math]::Exp(-$t * 200.0) } else { 0 }
    $v = ($ring * 0.55 + $ring2 * 0.25 + $click * 0.35) * 11000.0
    $shield[$i] = ClampI16($v)
}
NormalizePeak $shield 0.88 | Out-Null
Write-WavMono16 (Join-Path $OutDir "shield_hit.wav") $shield

# --- hit_wood.wav (~0.2s) ---
$n = [int]($Rate * 0.2)
$wood = New-Object int16[] $n
for ($i = 0; $i -lt $n; $i++) {
    $t = [double]$i / $Rate
    $d = [math]::Exp(-$t * 14.0)
    $a = [math]::Sin(2.0 * [math]::PI * 190.0 * $t) * $d
    $b = [math]::Sin(2.0 * [math]::PI * 410.0 * $t) * $d * 0.6
    $nk = NoiseSample($rng) * 0.12 * $d
    $v = ($a + $b + $nk) * 10000.0
    $wood[$i] = ClampI16($v)
}
NormalizePeak $wood 0.9 | Out-Null
Write-WavMono16 (Join-Path $OutDir "hit_wood.wav") $wood

# --- hit_stone.wav (~0.17s) ---
$n = [int]($Rate * 0.17)
$stone = New-Object int16[] $n
for ($i = 0; $i -lt $n; $i++) {
    $t = [double]$i / $Rate
    $hi = if ($i -lt 120) { [math]::Sin(2.0 * [math]::PI * 2100.0 * $t) * [math]::Exp(-$t * 55.0) } else { 0 }
    $lo = [math]::Sin(2.0 * [math]::PI * 130.0 * $t) * [math]::Exp(-$t * 22.0)
    $nk = NoiseSample($rng) * 0.2 * [math]::Exp(-$t * 35.0)
    $v = ($hi * 0.35 + $lo * 0.65 + $nk) * 10500.0
    $stone[$i] = ClampI16($v)
}
NormalizePeak $stone 0.9 | Out-Null
Write-WavMono16 (Join-Path $OutDir "hit_stone.wav") $stone

# --- hit_chest.wav (~0.21s) ---
$n = [int]($Rate * 0.21)
$chest = New-Object int16[] $n
for ($i = 0; $i -lt $n; $i++) {
    $t = [double]$i / $Rate
    $d = [math]::Exp(-$t * 12.0)
    $w = [math]::Sin(2.0 * [math]::PI * 220.0 * $t) * $d * 0.55
    $ping = [math]::Sin(2.0 * [math]::PI * 920.0 * $t) * [math]::Exp(-$t * 18.0) * 0.45
    $met = if ($i -lt 140) { NoiseSample($rng) * 0.15 * [math]::Exp(-$t * 40.0) } else { 0 }
    $v = ($w + $ping + $met) * 10500.0
    $chest[$i] = ClampI16($v)
}
NormalizePeak $chest 0.88 | Out-Null
Write-WavMono16 (Join-Path $OutDir "hit_chest.wav") $chest

Write-Host "Wrote SFX to $OutDir"
