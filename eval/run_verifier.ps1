<#
.SYNOPSIS
  Deterministic headless grader for the "grenade detonation" eval task.

.DESCRIPTION
  Injects the verifier harnesses into a target Godot project, runs both
  dimensions, aggregates a score out of 100, writes results (JSON + frames)
  to an external folder, then removes the injected files from the target so
  the graded project is never left holding the verifier.

    score = damage (35, headless physics) + visual (65, rendered pixels)

.EXAMPLE
  ./run_verifier.ps1 -Project "D:\Philo Labs\RoboBlast" -Label original -Seed 12345
#>
param(
  [Parameter(Mandatory = $true)][string]$Project,
  [string]$Label = "run",
  [int]$Seed = 12345,
  # Path to the Godot 4.6 executable. On Windows prefer the *_console* build, so the
  # harness's stdout (and any SCRIPT ERROR) is actually captured. Override with -Godot
  # or the GODOT4 environment variable; otherwise we fall back to `godot` on PATH.
  [string]$Godot = $(if ($env:GODOT4) { $env:GODOT4 } else { "godot" })
)

$ErrorActionPreference = "Stop"
$godot = $Godot
if (-not (Get-Command $godot -ErrorAction SilentlyContinue)) {
  throw "Godot not found: '$godot'. Pass -Godot <path-to-godot-4.6> or set `$env:GODOT4."
}
$src     = Join-Path $PSScriptRoot "src"
$inject  = Join-Path $Project "verifier"
$results = Join-Path $PSScriptRoot ("results\" + $Label)

if (-not (Test-Path $Project)) { throw "Project not found: $Project" }
if (-not (Test-Path (Join-Path $Project "project.godot"))) { throw "Not a Godot project: $Project" }

# --- inject a fresh copy of the verifier into the target project ---
if (Test-Path $inject) { Remove-Item -Recurse -Force $inject }
New-Item -ItemType Directory -Force -Path $inject | Out-Null
Copy-Item "$src\*" $inject -Recurse

try {
  # Build the import cache (.godot/) before grading. A fresh clone has none —
  # it is git-ignored — and without it Godot cannot resolve imported assets or
  # the script class cache, so the project fails to run and the grade is junk.
  # Importing explicitly also means the first graded frame is never paying for
  # asset import or shader compilation, which is what made timings drift.
  & $godot --headless --path $Project --import 2>&1 |
    Select-String -Pattern "SCRIPT ERROR|Parse Error" | ForEach-Object { Write-Host $_ }

  # Dimension 1: damage (headless, pure physics)
  $dmgOut = & $godot --headless --path $Project "res://verifier/harness_damage.tscn" -- "seed=$Seed" 2>&1
  $dmgOut | Select-String -Pattern "VERIFIER_DAMAGE|SCRIPT ERROR|Parse Error" | ForEach-Object { Write-Host $_ }
  $dmgErr = ($dmgOut | Select-String -Pattern "SCRIPT ERROR|Parse Error" |
    ForEach-Object { $_.ToString().Trim() } | Select-Object -First 3) -join " | "

  # Dimension 2: visual (rendered, frame capture + pixel analysis)
  #
  # --fixed-fps is REQUIRED for determinism, not a performance knob. The harness
  # measures the blast's timing in captured frames, but the game animates it on
  # wall-clock delta. Without a fixed delta, a slower render (GPU load, cold
  # shader cache) stretches the effect across fewer frames and silently changes
  # temporal sub-scores. --fixed-fps pins delta to 1/FIXED_FPS, so frame index
  # IS simulation time and the grade no longer depends on machine speed.
  $visOut = & $godot --path $Project "res://verifier/harness_visual.tscn" --resolution 320x180 --fixed-fps 60 2>&1
  $visOut | Select-String -Pattern "VERIFIER_VISUAL|SCRIPT ERROR|Parse Error" | ForEach-Object { Write-Host $_ }
  $visErr = ($visOut | Select-String -Pattern "SCRIPT ERROR|Parse Error" |
    ForEach-Object { $_.ToString().Trim() } | Select-Object -First 3) -join " | "

  $dmgFile = Join-Path $inject "out\damage.json"
  $visFile = Join-Path $inject "out\visual.json"
  if (-not (Test-Path $dmgFile)) { throw "damage.json not produced (harness crashed?)" }
  if (-not (Test-Path $visFile)) { throw "visual.json not produced (harness crashed?)" }

  $dmg = Get-Content $dmgFile -Raw | ConvertFrom-Json
  $vis = Get-Content $visFile -Raw | ConvertFrom-Json

  # A solution that raises a RUNTIME ERROR while performing the graded behaviour is
  # broken, however much of the behaviour it completed before erroring — so the
  # affected dimension scores 0. We do NOT let the score depend on how far the loop
  # got before it threw: `damageables` is not a homogeneous group (destroyed-box
  # debris has no damage() method), so an unguarded loop aborts partway through, and
  # how many enemies it happened to reach first is an artifact of group ordering,
  # not a measure of the solution. Grade the error, not the accident.
  $dmgScore = if ($dmgErr) { 0.0 } else { $dmg.score }
  $visScore = if ($visErr) { 0.0 } else { $vis.score }
  $total = [math]::Round($dmgScore + $visScore, 2)
  if ($dmgErr) { Write-Host "  !! RUNTIME ERROR in damage run -> damage forfeited: $dmgErr" -ForegroundColor Red }
  if ($visErr) { Write-Host "  !! RUNTIME ERROR in visual run -> visual forfeited: $visErr" -ForegroundColor Red }

  # --- persist results outside the project ---
  if (Test-Path $results) { Remove-Item -Recurse -Force $results }
  New-Item -ItemType Directory -Force -Path $results | Out-Null
  Copy-Item $dmgFile (Join-Path $results "damage.json")
  Copy-Item $visFile (Join-Path $results "visual.json")
  if (Test-Path (Join-Path $inject "out\frames")) {
    Copy-Item (Join-Path $inject "out\frames") (Join-Path $results "frames") -Recurse
  }
  $summary = [ordered]@{
    label            = $Label
    project          = $Project
    seed             = $Seed
    total            = $total
    max              = 100
    damage           = $dmgScore
    damage_max       = $dmg.max
    visual           = $visScore
    visual_max       = $vis.max
    visual_parts     = $vis.subscores
    runtime_error    = (($dmgErr, $visErr) | Where-Object { $_ }) -join " || "
    # what the run WOULD have scored had it not errored — for analysis, not grading
    damage_measured  = $dmg.score
    visual_measured  = $vis.score
  }
  $summary | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $results "score.json")

  Write-Host ""
  Write-Host ("=========== VERIFIER RESULT [{0}] ===========" -f $Label)
  Write-Host ("  DAMAGE : {0,5} / {1}" -f $dmg.score, $dmg.max)
  Write-Host ("  VISUAL : {0,5} / {1}" -f $vis.score, $vis.max)
  Write-Host ("  TOTAL  : {0,5} / 100" -f $total)
  Write-Host "  results -> $results"
  Write-Host "============================================="
}
finally {
  # Always remove the injected verifier so the graded project stays clean.
  if (Test-Path $inject) { Remove-Item -Recurse -Force $inject }
}
