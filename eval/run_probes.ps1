<#
.SYNOPSIS
  Runs the anti-cheat probe suite: applies each "almost right" fake solution
  onto the ablated project, grades it, and confirms the verifier catches it
  (targeted sub-score -> 0, and no probe reaches 100).
#>
param(
  [Parameter(Mandatory = $true)][string]$Project,
  [string]$Godot = $(if ($env:GODOT4) { $env:GODOT4 } else { "godot" })
)
$ErrorActionPreference = "Stop"
$probesDir = Join-Path $PSScriptRoot "probes"
$grenade   = Join-Path $Project "player\grenade.gd"

# probe -> the guard it should trip
$expect = [ordered]@{
  damage_all   = "precision (far enemies spared) -> damage 0"
  screen_flash = "localized (compactness) -> 0"
  centered_dot = "world-space localization (blast not at impact point) -> 0"
  persistent   = "fades + fully_gone -> 0"
  # Caught by hue ALONE. It still earns `heat` (7): its core is genuinely bright,
  # and the game's bloom washes the hottest pixels toward white, which passes the
  # not-blue test. Correct partial credit — it is a real, bright, localized blast
  # that fades and cleans up. It is simply the wrong colour.
  wrong_color  = "hue -> 0 (blue). Keeps heat/fades/gone: correct partial credit"
  # Not a cheat: an honest under-built attempt, here to prove the damage axis
  # awards graded partial credit rather than all-or-nothing.
  small_radius = "PARTIAL-CREDIT CHECK: coverage ~1/3 -> damage ~11.7 (not 0, not 35)"
}

$rows = @()
foreach ($name in $expect.Keys) {
  $probeGd = Join-Path $probesDir "$name\grenade.gd"
  Copy-Item $probeGd $grenade -Force
  try {
    & (Join-Path $PSScriptRoot "run_verifier.ps1") -Project $Project -Label "probe_$name" -Seed 12345 -Godot $Godot *> $null
    $s = Get-Content (Join-Path $PSScriptRoot "results\probe_$name\score.json") -Raw | ConvertFrom-Json
    $rows += [pscustomobject]@{
      probe      = $name
      total      = $s.total
      damage     = $s.damage
      visual     = $s.visual
      localized  = $s.visual_parts.localized
      hue        = $s.visual_parts.fiery_hue
      heat       = $s.visual_parts.heat
      fades      = $s.visual_parts.fades
      gone       = $s.visual_parts.fully_gone
      caught_by  = $expect[$name]
    }
  }
  finally {
    # restore the committed ablated grenade.gd
    & git -C $Project checkout -- player/grenade.gd
  }
}

Write-Host ""
Write-Host "================= ANTI-CHEAT PROBE RESULTS ================="
$rows | Format-Table probe,total,damage,visual,localized,hue,heat,fades,gone -AutoSize | Out-String | Write-Host
$rows | Select-Object probe,caught_by | Format-Table -AutoSize | Out-String | Write-Host
$maxTotal = ($rows | Measure-Object total -Maximum).Maximum
Write-Host ("Highest probe score: {0}/100 (a correct solution scores 100). All cheats caught: {1}" -f $maxTotal, ($maxTotal -lt 100))
$rows | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $PSScriptRoot "results\probes_summary.json")
