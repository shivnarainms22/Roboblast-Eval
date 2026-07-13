# RoboBlast, grenade detonation: an agent-coding eval task + verifier

### → **[Read the writeup](https://shivnarainms22.github.io/Roboblast-Eval/writeup.html)** *(opens in your browser — figures, frame-by-frame comparisons, and gameplay recordings of all five builds)*

An evaluation environment built on **[RoboBlast: TPS Demo](https://github.com/gdquest-demos/godot-4-3d-third-person-controller)** (Godot 4.6).
One real feature, the **grenade detonation**, is removed. An AI agent is asked to rebuild
it from a behavioural spec alone, and a **deterministic grader scores the result out of 100**.

The grader is the point of this repo.

## Branches

| Branch | What it is |
|---|---|
| `main` | The untouched upstream game, the locked base. **The answer lives here; the agent never sees it.** |
| `task/explosion-ablated` | The detonation removed, plus `TASK.md` (the behavioural spec). **This is exactly what the agent is given.** |
| `agent/run1` · `agent/run2` · `agent/run3` | Three Claude Code rollouts, verbatim. Each is one commit on top of the ablated branch, so its diff *is* the agent's work. |
| `eval` | This branch: the verifier, the probes, the results, and the writeup. |

## Results

| Subject | Damage /35 | Visual /65 | **Total /100** |
|---|---|---|---|
| Original (`main`) | 35 | 65 | **100** |
| Ablated (`task/explosion-ablated`) | 0 | 0 | **0** |
| `agent/run1` | 0 *(measured 35)* | 55 | **55** |
| `agent/run2` | 0 *(measured 35)* | 55 | **55** |
| `agent/run3` | 35 | 55 | **90** |

> **What "0 *(measured 35)*" means.** run1 and run2's damage logic genuinely works: both hit every
> in-radius enemy and spared every far one, for a measured 35/35. Their enemies really do die. They
> **forfeit** the dimension because they raise a **runtime error while doing it**, and `score.json`
> records both numbers (`damage_measured: 35`, `damage: 0`) so nothing is hidden.
>
> The error is not cosmetic. The group is iterated in insertion order and the debris sits *last*, so
> the loop damages all three enemies and only *then* throws. Anything added to that group **after** the
> debris is silently skipped, so an enemy spawning once a crate has been broken would take no damage at
> all. run1 gets away with it by luck of ordering, not by correctness. Scoring the measurement instead
> would put run1 at **90/100** and make the crash disappear from the report. So: **grade the error, not
> the accident.**

Agent: **Claude Code v2.1.207**, model **`claude-opus-4-8`**, with the **Godot MCP**
available. `Bash`, `WebFetch` and `WebSearch` were disabled, and each agent worked in a
depth-1 sandbox with no remotes and no verifier present, so the original was unreachable
via history, branches, or the network.

**Two real defects, both caught:**

* **run1 and run2 crash at runtime.** They iterate the `damageables` group and call
  `damage()` on destroyed-crate debris, which is in the group but has no such method. It
  is a latent, gameplay-reachable error, invisible until a crate has been broken. run3
  guards with `has_method()` and is correct.
* **All three swell instead of flashing.** The original blast peaks in **1 frame**; every
  agent's inflates over **12 to 16**. Same colour, same brightness, same cleanup, wrong
  attack. It cannot be seen by eye in live play, and it is obvious frame-by-frame.

## Play it yourself

The most convincing thing in this repo is not a number: **play the builds back to back.**
The agents' explosions look *fine* in motion — that is the whole point of grading them
frame-by-frame.

Requires **[Godot 4.6](https://godotengine.org/download)** and nothing else. From a clone
of this repo:

```powershell
# Check out whichever build you want to play, side by side:
git worktree add ../orig main                    # the real detonation
git worktree add ../abl  task/explosion-ablated  # nothing happens (what the agent got)
git worktree add ../r1   agent/run1              # agent attempts
git worktree add ../r2   agent/run2
git worktree add ../r3   agent/run3

# Launch one. The first run imports the project (~20s), then the game starts:
godot --path ../orig
```

**Controls:** `WASD` move · `Space` jump · **`Tab` to switch to the grenade launcher** ·
right-click to aim · **left-click to throw** · `Esc` pause.

Throw a grenade near the crates and the beetles. On `main` it detonates; on
`task/explosion-ablated` it goes *bang* and nothing happens. Then try the three agent
runs — and see whether you can spot, by eye, the defect the grader catches. (I could not.
Recordings of all five are embedded in the [writeup](https://shivnarainms22.github.io/Roboblast-Eval/writeup.html).)

> To reproduce run1's and run2's **runtime crash**, break a crate first, *then* throw a
> grenade near the debris. That is the whole reason it stayed invisible: it needs a broken
> crate to exist before it can fire.

## Running the verifier

Requires **Godot 4.6** and PowerShell. On Windows use the `_console` build, so the
harness's stdout (and any `SCRIPT ERROR`) is actually captured.

Run these from the **root of a clone of this repo** — the relative paths below are
resolved from there.

```powershell
$env:GODOT4 = "C:\path\to\Godot_v4.6-stable_win64_console.exe"   # or pass -Godot

# Grade any checkout of the game. Imports it, injects the harnesses, runs both
# dimensions, writes eval/results/<label>/, then removes itself from the target:
./eval/run_verifier.ps1 -Project <path-to-a-game-checkout> -Label original

# Prove discrimination. The original passes, the ablated build fails:
git worktree add ../orig main
git worktree add ../abl  task/explosion-ablated
./eval/run_verifier.ps1 -Project ../orig -Label original   # -> 100
./eval/run_verifier.ps1 -Project ../abl  -Label ablated    # -> 0

# Grade an agent run:
git worktree add ../r3 agent/run3
./eval/run_verifier.ps1 -Project ../r3 -Label run3         # -> 90

# Anti-cheat probe suite. Applies each fake solution, grades it, restores:
./eval/run_probes.ps1 -Project ../abl
```

Nothing needs to be cached beforehand: the verifier builds the Godot import cache itself
(`--import`), so a fresh clone grades correctly.

> **Note:** grading writes into **`eval/results/<label>/`**, which is a *tracked* directory
> — so re-grading `original`, `ablated` or `run1|2|3` **overwrites the reference results
> shipped in this repo** with your own run. That is fine (they should match), but it will
> leave your checkout dirty. `git checkout -- eval/results` restores the shipped copies, or
> pass a fresh `-Label` to keep them untouched.

## How it scores

**Damage: 35 pts, true `--headless` physics.**
`score = 35 × coverage × precision`, where *coverage* is the fraction of in-radius enemies
damaged and *precision* the fraction of far enemies correctly spared. It is multiplicative
on purpose. A do-nothing solution scores 0 (coverage 0), and a "damage everything" cheat
also scores 0 (precision 0). You must get **both** right. Enemy distances are randomised
per run from a seed, so a hard-coded hit-list fails.

**Visual: 65 pts, rendered in the game's real `playground.tscn`** (its own sky, glow,
tonemap and lighting), frame-differenced against a pre-detonation baseline by *colour
change*, so only pixels the blast actually alters are measured:

| Sub-behaviour | Pts | Asks |
|---|---|---|
| appears | 10 | did anything render at all? |
| localized-at-impact | 15 | at the detonation's **world** point (a screen-space overlay fails) |
| fiery hue | 8 | orange/red, pooled over the blast's substantial phase |
| heat | 7 | a genuinely bright hot core |
| **flash** | 10 | does it **flare**, peaking almost instantly, rather than swell? |
| fades | 10 | does it collapse after the peak? |
| fully-gone | 5 | does it leave nothing behind? |

**Any runtime error during a graded run forfeits that dimension.** A solution that throws
while performing the behaviour is broken, however much of it completed first.

## Determinism

Repeated grades of the same project are **bit-identical**, and a cache-less clean clone
scores the same as a warm one. Three things make that true, and all three are load-bearing:

* **`--fixed-fps 60`** pins *when*. The harness measures the blast in captured frames, but
  the game animates it on wall-clock delta. Unpinned, a slower render stretches the effect
  over fewer frames and silently changes the temporal sub-scores.
* **Fixed particle seeds** pin *what*. Particle systems re-seed every run, moving the peak
  frame and the colour fractions.
* **`--import`** pins the starting state, so a fresh clone does not pay for asset import
  during the first graded frames.

Scores are also **seed-independent**: re-grading at an unused seed changes the enemy layout
but not a single score.

## Anti-cheat probes

Five fake "almost right" solutions, plus one honest-but-underbuilt control. All are caught.
The best a cheat manages is **87**, and only a correct solution reaches 100.

| Probe | Score | Caught by |
|---|---|---|
| `damage_all`, hit everything, ignore distance | 0 | precision → damage 0 |
| `screen_flash`, flood the screen orange | 35 | compactness → visual 0 |
| `centered_dot`, a screen-space overlay rather than a world blast | 35 | world-space localization → visual 0 |
| `persistent`, a blast that never fades | 75 | fades + fully-gone → 0 |
| `wrong_color`, a blue "explosion" | 87 | hue → 0. Correct partial credit: it is right in every other respect |
| `small_radius`, **not a cheat**: an honest 1.0 m blast | 11.67 | **partial-credit control.** Coverage ⅓ × precision 1.0, proving the damage axis is graded rather than all-or-nothing |

## Honest limitations

* **"Headless" has a caveat.** The damage half is true `--headless`. The visual half needs a
  real render context, because Godot's dummy renderer produces no pixels. It runs fully
  automated with no human, but on a headless CI it would need a virtual display.
* **Cross-hardware reproducibility is untested.** Determinism is demonstrated on a fixed
  machine, GPU and Godot build. Margins are wide (the flash discriminator has 3 to 4×
  headroom), so the risk is low, but it is untested and we say so.
* **The spec is silent on the player.** The Player is *also* in `damageables`, and run2
  damages you with your own grenade. The original does not. We **measure and report** this
  (`player_damaged_DIAGNOSTIC_NOT_SCORED` in `damage.json`) but deliberately **do not score
  it**, because grading a requirement the spec never stated would be a false negative. It is
  a gap in *our spec*, not proven to be a defect in their code.
* **Blast size, ember count and effect structure are deliberately not scored.** They are
  implementation choices rather than spec'd behaviour, and grading them would over-fit to the
  original. run1's fireball is 3.4× larger on screen than run2's, and neither is penalised.
