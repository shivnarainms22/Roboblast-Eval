"""Build the single-file HTML writeup.

Every image is inlined as a data URI, so the result is one self-contained file that
opens in any browser with no build step, no server, and no relative-path breakage,
which is exactly what the brief asks for.

    python make_writeup.py        ->  RoboBlast/writeup.html
"""
import base64
import json
import pathlib

RESULTS = pathlib.Path(__file__).parent / "results"
OUT = pathlib.Path(__file__).parent.parent / "RoboBlast" / "writeup.html"


def data_uri(name: str) -> str:
    p = RESULTS / name
    mime = "image/gif" if p.suffix == ".gif" else "image/png"
    return f"data:{mime};base64,{base64.b64encode(p.read_bytes()).decode()}"


def score(label: str) -> dict:
    return json.loads((RESULTS / label / "score.json").read_text())


def metrics(label: str) -> dict:
    return json.loads((RESULTS / label / "visual.json").read_text())["metrics"]


S = {k: score(k) for k in ("original", "ablated", "run1", "run2", "run3", "flash_control")}
M = {k: metrics(k) for k in ("original", "run1", "run2", "run3", "flash_control")}
PROBES = json.loads((RESULTS / "probes_summary.json").read_text())

GIF = {k: data_uri(f"{k}.gif") for k in ("original", "ablated", "run1", "run2", "run3")}
COMPARISON = data_uri("comparison.png")

# --- the rise-time chart: the single measurement the whole calibration rests on ---
RISE = [("original", M["original"]["rise_frames"], "#7ee2a8"),
        ("run3", M["run3"]["rise_frames"], "#ff8b7a"),
        ("run2", M["run2"]["rise_frames"], "#ff8b7a"),
        ("run1", M["run1"]["rise_frames"], "#ff8b7a")]
MAXR = 18
bars = []
for i, (name, rise, colour) in enumerate(RISE):
    y = 14 + i * 34
    w = max(2, rise / MAXR * 380)
    bars.append(
        f'<text x="0" y="{y + 15}" fill="#9aa6b6" font-size="13" font-family="ui-monospace,monospace">{name}</text>'
        f'<rect x="72" y="{y}" width="{w:.0f}" height="20" rx="3" fill="{colour}"/>'
        f'<text x="{78 + w:.0f}" y="{y + 15}" fill="#e8edf4" font-size="13" font-family="ui-monospace,monospace">'
        f'{rise} frame{"s" if rise != 1 else ""}</text>')
gate_x = 72 + 4 / MAXR * 380
bars.append(f'<line x1="{gate_x:.0f}" y1="4" x2="{gate_x:.0f}" y2="150" stroke="#ffd479" '
            f'stroke-width="2" stroke-dasharray="4 3"/>')
bars.append(f'<text x="{gate_x + 6:.0f}" y="164" fill="#ffd479" font-size="12" '
            f'font-family="ui-monospace,monospace">flash gate (4 frames)</text>')
RISE_SVG = f'<svg viewBox="0 0 520 175" width="100%" role="img" aria-label="Rise time to peak: the original flashes in 1 frame, all three agents swell over 12 to 16 frames, against a gate of 4 frames.">{"".join(bars)}</svg>'

probe_rows = "".join(
    f'<tr><td><code>{p["probe"]}</code></td><td class="num">{p["total"]:g}</td><td>{p["caught_by"]}</td></tr>'
    for p in PROBES)


def video(name: str, caption: str) -> str:
    """Real gameplay, referenced by relative path.

    The GIFs are inlined as data URIs so the page always reads standalone. The full
    recordings come to ~29 MB and are referenced from the repo rather than embedded,
    which keeps the file openable instead of turning it into a 40 MB blob. Opened from
    a clone, as the repo intends, they play with no build step.
    """
    return (f'<figure><video src="eval/recordings/{name}.mp4" controls preload="metadata" '
            f'muted playsinline style="width:100%;border-radius:10px;border:1px solid var(--line);'
            f'display:block;background:#000"></video>'
            f'<figcaption>{caption}</figcaption></figure>')


HTML = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>RoboBlast: an agent-coding eval task and verifier</title>
<style>
  :root {{ --bg:#0d1016; --panel:#161a22; --panel2:#1b2130; --ink:#e8edf4; --muted:#9aa6b6;
          --accent:#7fd4ff; --good:#7ee2a8; --warn:#ffd479; --bad:#ff8b7a; --line:#262c38; }}
  * {{ box-sizing:border-box; }}
  body {{ margin:0; background:var(--bg); color:var(--ink);
         font:16px/1.65 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; }}
  a {{ color:var(--accent); }}
  .wrap {{ max-width:940px; margin:0 auto; padding:44px 24px 90px; }}
  .kicker {{ color:var(--accent); font-size:13px; letter-spacing:.14em; text-transform:uppercase; font-weight:700; }}
  h1 {{ font-size:34px; line-height:1.2; margin:8px 0 12px; }}
  .lead {{ color:var(--muted); font-size:18px; margin:0 0 24px; }}
  h2 {{ font-size:22px; margin:44px 0 12px; padding-top:26px; border-top:1px solid var(--line); }}
  h2 .n {{ color:var(--accent); font-variant-numeric:tabular-nums; margin-right:10px; }}
  h3 {{ font-size:16px; margin:24px 0 6px; }}
  p {{ margin:12px 0; }}
  code {{ background:#0b0e14; border:1px solid var(--line); border-radius:5px; padding:1px 6px;
          font-size:13.5px; color:#bcd; }}
  pre {{ background:#0b0e14; border:1px solid var(--line); border-radius:10px; padding:14px 16px;
         overflow-x:auto; font-size:13.5px; }}
  pre code {{ border:0; padding:0; background:none; }}
  .card {{ background:var(--panel); border:1px solid var(--line); border-radius:14px; padding:18px 22px; margin:20px 0; }}
  .callout {{ border-left:3px solid var(--accent); background:var(--panel); border-radius:0 12px 12px 0;
             padding:14px 20px; margin:20px 0; }}
  .callout.warn {{ border-left-color:var(--warn); }}
  .callout.bad {{ border-left-color:var(--bad); }}
  .callout.good {{ border-left-color:var(--good); }}
  table {{ border-collapse:collapse; width:100%; margin:14px 0; font-size:14.5px; }}
  th, td {{ border:1px solid var(--line); padding:9px 12px; text-align:left; vertical-align:top; }}
  th {{ background:var(--panel2); font-size:12.5px; text-transform:uppercase; letter-spacing:.04em; }}
  td.num {{ text-align:right; font-variant-numeric:tabular-nums; font-family:ui-monospace,monospace; }}
  .good {{ color:var(--good); }} .bad {{ color:var(--bad); }} .warn {{ color:var(--warn); }}
  .muted {{ color:var(--muted); }}
  .grid {{ display:grid; grid-template-columns:1fr 1fr; gap:16px; }}
  .grid3 {{ display:grid; grid-template-columns:1fr 1fr 1fr; gap:16px; }}
  @media (max-width:760px) {{ .grid, .grid3 {{ grid-template-columns:1fr; }} }}
  figure {{ margin:0; }}
  figure img {{ width:100%; border-radius:10px; border:1px solid var(--line); display:block; }}
  figcaption {{ color:var(--muted); font-size:13px; margin-top:7px; }}
  .tag {{ display:inline-block; font-size:11.5px; border-radius:20px; padding:2px 9px; margin-right:5px;
          border:1px solid var(--line); color:var(--muted); }}
  .tag.pass {{ color:var(--good); border-color:#2c5c44; }}
  .tag.fail {{ color:var(--bad); border-color:#5c3a34; }}
  .scoreline {{ font-family:ui-monospace,monospace; font-size:15px; }}
  ul {{ margin:12px 0; padding-left:22px; }}
  li {{ margin:8px 0; }}
  .foot {{ color:var(--muted); font-size:13px; margin-top:50px; border-top:1px solid var(--line); padding-top:18px; }}
</style>
</head>
<body>
<div class="wrap">

  <div class="kicker">Agent-coding evaluation</div>
  <h1>Rebuild the grenade detonation</h1>
  <p class="lead">One real feature is cut from <b>RoboBlast</b> (Godot 4.6). An AI agent gets a
     behavioural spec and the broken game, nothing else. A deterministic grader scores what it
     builds, out of 100. <b>The grader is the artefact.</b></p>

  <div class="card">
    <table style="margin:0">
      <tr><th>Subject</th><th>Damage /35</th><th>Visual /65</th><th>Total /100</th><th>Verdict</th></tr>
      <tr><td><b>Original</b> <span class="muted">(locked base)</span></td><td class="num">35</td><td class="num">65</td>
          <td class="num good"><b>{S['original']['total']:g}</b></td><td>the feature, as shipped</td></tr>
      <tr><td><b>Ablated</b> <span class="muted">(what the agent sees)</span></td><td class="num">0</td><td class="num">0</td>
          <td class="num bad"><b>{S['ablated']['total']:g}</b></td><td>grenade goes bang, nothing happens</td></tr>
      <tr><td><b>Agent run 1</b></td><td class="num bad">0 <span class="muted">(35)</span></td><td class="num">55</td>
          <td class="num warn"><b>{S['run1']['total']:g}</b></td><td>damage works, but it crashes doing it. Swells.</td></tr>
      <tr><td><b>Agent run 2</b></td><td class="num bad">0 <span class="muted">(35)</span></td><td class="num">55</td>
          <td class="num warn"><b>{S['run2']['total']:g}</b></td><td>same crash. Swells. Also self-damages.</td></tr>
      <tr><td><b>Agent run 3</b></td><td class="num">35</td><td class="num">55</td>
          <td class="num warn"><b>{S['run3']['total']:g}</b></td><td>damage correct, but it swells</td></tr>
    </table>
    <p class="muted" style="margin:12px 0 0;font-size:13.5px">Agent: <b>Claude Code v2.1.207</b>,
      model <b><code>claude-opus-4-8</code></b>, with the <b>Godot MCP</b> available.
      <code>Bash</code>, <code>WebFetch</code> and <code>WebSearch</code> disabled. Three runs.<br>
      The bracketed <b>(35)</b> is what run1 and run2 <em>measured</em> on damage before forfeiting the
      dimension for a runtime error. Their enemies do die. See section 3.</p>
  </div>

  <h2><span class="n">1.</span>Why this feature</h2>
  <p>The brief says the visual dimension is how you keep an agent off an easy 100, so I picked the
     element that is <em>hardest to grade honestly</em>: an <b>explosion</b>. But a purely visual
     verifier is the riskiest kind to make bullet-proof, and verifier validity is the axis that
     matters most. So I ablated the <b>whole detonation</b>: the fiery blast <em>and</em> the radial
     damage to nearby enemies.</p>
  <p>That gives the grader a <b>deterministic backbone</b> (did the right enemies get hit? were the
     far ones spared?) underneath the hard visual layer, and it produces natural partial credit,
     because the logic is easy and the look is not. The detonation <em>sound</em> was deliberately
     left intact, so the ablation stays subtle. The grenade still "goes off", it just does nothing.</p>

  <h3>The ablation had to be complete</h3>
  <p>Deleting the code was not enough. The answer leaked in three other places, and each had to go:</p>
  <table>
    <tr><th>Leak</th><th>Why it gave the answer away</th></tr>
    <tr><td>the <code>ExplosionArea</code> node in the grenade scene</td>
        <td>its <b>3.0 m</b> radius literally <em>is</em> the blast size</td></tr>
    <tr><td>a shader "prewarm" in <code>main.tscn</code></td>
        <td>hardcoded <code>Color(0.97, 0.52, 0)</code>, the exact orange, and preloaded the explosion shaders by path</td></tr>
    <tr><td>the whole <code>explosion_visuals/</code> folder</td>
        <td>scene, shaders, materials and meshes: the solution, sitting in the project</td></tr>
  </table>
  <p class="muted">Total: <b>994 deletions across 20 files</b>. The spec (<code>TASK.md</code>) is
     behavioural only. No file, class, method, node or signal names. It describes <em>what happens</em>,
     never <em>how</em>.</p>

  <h2><span class="n">2.</span>Before and after</h2>
  <div class="grid">
    <figure><img src="{GIF['original']}" alt="The original explosion: a bright orange blast flares instantly at the impact point, then fades.">
      <figcaption><b class="good">Original.</b> Flares, expands, fades, cleans up. Scores <b>100</b>.</figcaption></figure>
    <figure><img src="{GIF['ablated']}" alt="The ablated build: the grenade detonates and nothing appears at all.">
      <figcaption><b class="bad">Ablated.</b> The grenade detonates and <em>nothing happens</em>. Scores <b>0</b>.</figcaption></figure>
  </div>
  <p class="muted">Both are graded inside the game's real <code>playground.tscn</code> level, with its
     own sky, glow, tonemap and lighting, rather than a synthetic scene. The blast is isolated by
     frame-differencing against a pre-detonation baseline, by <em>colour change</em>, so only pixels
     the blast actually alters are measured.</p>

  <h3>The same thing, played by a human</h3>
  <div class="grid">
    {video("original", "<b class='good'>Original.</b> Throw a grenade: the blast punches, and enemies are flung.")}
    {video("ablated", "<b class='bad'>Ablated.</b> The grenade arcs, bounces, and <em>bangs</em>. Nothing happens. Enemies walk on. This is the game the agent is handed.")}
  </div>
  <p class="muted">The detonation <em>sound</em> is deliberately left in. A grenade that vanished in
     total silence would advertise a gutted function. One that goes off and does nothing forces the
     agent to reason from the spec about what a detonation <em>should do</em>.</p>

  <h2><span class="n">3.</span>How the verifier scores</h2>
  <div class="grid">
    <div>
      <h3>Damage: 35 pts <span class="muted">(true <code>--headless</code> physics)</span></h3>
      <p class="scoreline">score = 35 × coverage × precision</p>
      <p><b>Multiplicative on purpose.</b> A do-nothing solution scores 0 (coverage 0). A
         "damage everything" cheat also scores 0 (precision 0). You must get <b>both</b> right.
         Enemy distances are randomised from a seed, so a hard-coded hit-list fails.</p>
    </div>
    <div>
      <h3>Visual: 65 pts <span class="muted">(rendered, pixel-analysed)</span></h3>
      <table style="margin-top:6px">
        <tr><td>appears</td><td class="num">10</td><td class="muted">did anything render?</td></tr>
        <tr><td>localized-at-impact</td><td class="num">15</td><td class="muted">at the blast's <b>world</b> point</td></tr>
        <tr><td>fiery hue</td><td class="num">8</td><td class="muted">orange or red</td></tr>
        <tr><td>heat</td><td class="num">7</td><td class="muted">a genuinely bright core</td></tr>
        <tr><td><b>flash</b></td><td class="num"><b>10</b></td><td class="muted"><b>does it flare, or swell?</b></td></tr>
        <tr><td>fades</td><td class="num">10</td><td class="muted">collapses after the peak</td></tr>
        <tr><td>fully-gone</td><td class="num">5</td><td class="muted">leaves nothing behind</td></tr>
      </table>
    </div>
  </div>
  <p>Every sub-behaviour is a <em>generic</em> property of an explosion, tied to the spec's wording
     rather than copied from the original's implementation. <b>Blast size, ember count and effect
     structure are deliberately not scored</b>, because they are implementation choices and grading
     them would over-fit to the original. run1's fireball covers <b>3.4×</b> more screen than run2's,
     and neither is penalised for it.</p>
  <p><b>Any runtime error during a graded run forfeits that dimension.</b> A solution that throws while
     performing the behaviour is broken, however much of it completed first.</p>

  <div class="callout warn">
    <b>To be clear about what a forfeit means.</b> run1 and run2 score <b>0/35</b> on damage, but their
    damage logic actually <em>works</em>: both hit every in-radius enemy and spared every far one, for a
    <b>measured 35/35</b>. Their enemies really do die. The score file records both numbers side by side
    (<code>damage_measured: 35</code>, <code>damage: 0</code>), so nothing is hidden.
    <p style="margin-bottom:0">They forfeit because they <b>raise a runtime error while doing it</b>. And
      the error is not cosmetic: the group is iterated in insertion order, the debris happens to sit
      <em>last</em>, so the loop damages all three enemies and only <em>then</em> throws. Anything added
      to that group <b>after</b> the debris would be silently skipped, so an enemy that spawns once a
      crate has been broken takes no damage at all. run1 gets away with it by luck of ordering, not by
      correctness. Had I scored the measurement instead, run1 would read <b>90/100</b> and the crash would
      vanish from the report entirely. So the rule is: <b>grade the error, not the accident.</b></p>
  </div>

  <div class="callout good">
    <b>Determinism, and how it was broken.</b> A review found the grader was <em>not</em> reproducible:
    re-grading the same unchanged solution moved its score. The harness measured the blast in
    <em>rendered frames</em>, but the game animates it on <em>wall-clock delta</em>, and the frame rate
    was never pinned, so the score was partly measuring <b>machine speed</b>. A cold shader cache
    pushed one run to a <b>false 100</b>. Fixed three ways: <code>--fixed-fps 60</code> pins <em>when</em>,
    fixed particle seeds pin <em>what</em>, and an explicit <code>--import</code> pins the starting state.
    Repeated grades are now <b>bit-identical</b>, a cache-less clean clone scores the same, and the scores
    are <b>seed-independent</b>. <span class="muted">A grader that is not reproducible is not a grader.
    This was the single most important fix in the project, and I did not find it myself.</span>
  </div>

  <pre><code>$env:GODOT4 = "C:\\path\\to\\Godot_v4.6-stable_win64_console.exe"

git worktree add ../abl task/explosion-ablated
./eval/run_verifier.ps1 -Project ../abl -Label ablated    # -&gt; 0
./eval/run_probes.ps1   -Project ../abl                   # anti-cheat suite</code></pre>

  <h2><span class="n">4.</span>Calibration: why nobody scores 100</h2>
  <p>The first rubric gave two of three agents a clean 100, which is a red flag. The brief is explicit
     that a strong agent must land <em>partial</em>. Rather than invent a gate to force that, I measured
     the temporal brightness curve of every blast and found a real, generic discriminator hiding in it.</p>

  <div class="card">
    <h3 style="margin-top:4px">Time from onset to peak brightness</h3>
    {RISE_SVG}
    <p class="muted" style="margin-bottom:0">The original <b>flares</b>, reaching full brightness in a
      single frame, like a detonation. Every agent <b>swells</b> like an inflating balloon over 12 to 16
      frames. Same colour, same brightness, same cleanup. Wrong <em>attack</em>. All three lose the
      10-point <code>flash</code> sub-score, and the margin is 3 to 4×, not a hair's breadth.</p>
  </div>

  <figure style="margin-top:20px"><img src="{COMPARISON}" alt="Frame-by-frame comparison strip of the original explosion against the ablated build and the three agent attempts.">
    <figcaption>Frame-by-frame, at the same moments after detonation. The original is at full intensity
      immediately. The agents are still growing.</figcaption></figure>

  <div class="callout warn">
    <b>Is 90 just a ceiling?</b> No, and I proved it rather than claiming it. I took <b>run3's own
    solution</b> and changed <em>one number</em>: its expansion tween, <code>0.35s</code> to
    <code>0.05s</code>. Nothing else. Rise went from <b>12 frames to 1</b>, and the score went from
    <b>90 to 100</b>. So the last 10 points are winnable <em>by the agent's own code-driven design</em>,
    which is structurally nothing like the original's shader and mesh approach. The gate is real,
    reachable, and not a false negative against a different implementation. The agents' miss is
    <b>a real defect in their work</b>, fixable with a single constant in their own file.
  </div>

  <h2><span class="n">5.</span>The three attempts</h2>
  <div class="grid3">
    <figure><img src="{GIF['run1']}" alt="Agent run 1's explosion: a large orange fireball that grows outward.">
      <figcaption><b>run1</b>, <b class="warn">55</b><br><span class="tag fail">runtime crash</span><span class="tag fail">swells</span></figcaption></figure>
    <figure><img src="{GIF['run2']}" alt="Agent run 2's explosion: a smaller orange fireball that grows outward.">
      <figcaption><b>run2</b>, <b class="warn">55</b><br><span class="tag fail">runtime crash</span><span class="tag fail">swells</span><span class="tag fail">self-damage</span></figcaption></figure>
    <figure><img src="{GIF['run3']}" alt="Agent run 3's explosion: an orange fireball that grows outward.">
      <figcaption><b>run3</b>, <b class="warn">90</b><br><span class="tag pass">damage correct</span><span class="tag fail">swells</span></figcaption></figure>
  </div>
  <p>All three wrote <b>structurally different</b> solutions. run1 a single 110-line script, run2 a
     script <em>plus a scene file</em>, run3 a 91-line script. None of them used shaders, unlike the
     original. They also picked their own blast radius, <b>4.0 m</b> each, where the original's is
     <b>3.0 m</b>. Nobody recovered it. The verifier grades what happens on screen and to the enemies,
     so all three are judged fairly despite sharing no implementation with the original, or with each
     other.</p>

  <h3>Played by a human, and this is the point</h3>
  <div class="grid3">
    {video("run1", "<b>run1.</b> Looks like a good explosion.")}
    {video("run2", "<b>run2.</b> Looks like a good explosion.")}
    {video("run3", "<b>run3.</b> Looks like a good explosion.")}
  </div>
  <div class="callout warn">
    <b>They all look fine.</b> I played all three back to back against the original and
    <b>could not see the defect by eye</b>. The blasts are bright, orange, centred, and they clean up
    after themselves. The swell is a <em>temporal</em> property lasting a fraction of a second, and at
    full speed it simply reads as "a decent explosion".
    <p style="margin-bottom:0">That is the whole argument for grading the visual outcome
      <em>frame-by-frame</em> rather than eyeballing it. <b>The grader catches something a human
      reviewer plausibly would not</b>, which is precisely the "logic right, on-screen result wrong"
      failure the brief is hunting for. The crash in section 8 is worse still: it stays invisible in
      normal play until you happen to blow up a crate first.</p>
  </div>

  <h2><span class="n">6.</span>Anti-cheat: fake solutions that <em>look</em> right</h2>
  <table>
    <tr><th>Probe</th><th>Score</th><th>Caught by</th></tr>
    {probe_rows}
  </table>
  <p>Every cheat is caught, and the best a fake manages is <b>87</b>. Only a correct solution reaches
     100. Two of these probes were written <em>because</em> earlier ones found real holes: a
     screen-filling orange flash once scored <b>91</b>, which is what forced the <b>compactness</b> gate,
     since a blast that fills the screen is not a localized blast and so forfeits the whole visual score.
     The <code>small_radius</code> entry is <b>not</b> a cheat. It is an honest, under-built solution,
     included to prove the damage axis awards <b>graded partial credit</b> (coverage ⅓ × precision 1.0)
     rather than just 0 or 35.</p>

  <h2><span class="n">7.</span>How the agent was stopped from cheating</h2>
  <div class="grid">
    <div class="card">
      <h3 style="margin-top:0">The sandbox</h3>
      <p style="margin-bottom:0">Each rollout ran in a <code>git archive</code> extract of the ablated
        branch: <b>history depth 1</b>, no <code>main</code>, <b>no remotes</b>, and no verifier anywhere
        on disk. The original is unreachable via branches, history, or the grader.</p>
    </div>
    <div class="card">
      <h3 style="margin-top:0">The tools</h3>
      <p style="margin-bottom:0">The game is public on GitHub, so obscurity is worthless. Integrity has
        to be enforced at the tool layer. <code>Bash</code>, <code>WebFetch</code> and
        <code>WebSearch</code> were <b>disallowed</b>; file tools and the Godot MCP were allowed.
        No shell means no <code>curl</code> to fetch the answer.</p>
    </div>
  </div>
  <div class="callout good">
    <b>And it held, verifiably.</b> Auditing the run transcripts, <b>two of the three agents actually
    reached for <code>Bash</code></b> and were refused:
    <code>Error: No such tool available: Bash</code>. The lockdown is <b>enforced at runtime</b>, not
    merely configured &mdash; when an agent reached for the shell, the shell was not there. The verbatim
    tool calls and refusals are published in
    <a href="https://github.com/shivnarainms22/Roboblast-Eval/blob/eval/eval/rollouts/README.md"><code>eval/rollouts/</code></a>,
    along with the exact prompt and tool policy, so this is checkable rather than merely claimed.
    <p style="margin-bottom:0"><b>And read honestly:</b> neither attempt was an attempt to <em>cheat</em>.
    One agent wanted to locate the Godot binary, the other to grep its own log for script errors &mdash;
    ordinary developer reflexes, not a reach for the answer. What this proves is narrower and more useful
    than "the agents tried to escape": the restriction was <b>real at runtime</b>. The stronger evidence
    that nobody recovered the original is the solutions themselves &mdash; all three are
    <b>code-driven</b> while the original is <b>shader-driven</b>, none reproduced its shaders, and all
    three chose a <b>4.0 m</b> blast radius where the original's is <b>3.0 m</b>. A copied answer would
    not have missed that.</p>
  </div>

  <h2><span class="n">8.</span>Failure analysis: real defect, or grader artefact?</h2>
  <p>The brief asks whether each failure is a genuine agent bug or an artefact of my verifier.
     Investigating honestly produced <b>three</b> categories, not two.</p>

  <div class="callout bad">
    <b>1. Real agent defects. The verifier is right.</b>
    <p><b>The crash (run1, run2).</b> Both iterate the <code>damageables</code> group and call
      <code>damage()</code> on <em>destroyed-crate debris</em>, which is in that group but is a plain
      node with no such method. The result is
      <code>SCRIPT ERROR: Nonexistent function 'damage'</code>, in normal gameplay, whenever a grenade
      goes off near a broken crate. run3 guards with <code>has_method()</code> and is correct.</p>
    <p style="margin-bottom:0"><b>The swell (all three).</b> Measured, generic, and fixable with one
      constant. See section 4.</p>
  </div>

  <div class="callout warn">
    <b>2. Real verifier artefacts. The grader was wrong, and I fixed it.</b>
    <p><b>Non-determinism.</b> Scores drifted with machine speed (section 3). Found by review, not by me.</p>
    <p style="margin-bottom:0"><b>A threshold in the wrong place.</b> The <code>hue</code> gate sat at
      0.6 &mdash; <em>inside the very cluster it had to accept</em>. Measured, every fiery effect (the
      original, all three agent runs, and the orange probes) lands between <b>0.57 and 0.96</b>, while the
      genuinely not-fiery ones sit at <b>0.00</b> (a blue blast) and <b>0.26</b> (a screen-space dot). So
      0.6 was cutting straight through the accept cluster: the worst correct solution cleared it by only
      <b>12%</b>, and one genuinely orange blast fell <em>below</em> it altogether and was marked not-fiery.
      Worse, a warm-<em>pixel-fraction</em> is size-biased, so the gate was quietly grading <b>blast
      size</b>, an implementation choice, rather than <b>colour</b>. The separating region, 0.26 to 0.57,
      is <b>empty</b> &mdash; which is where the boundary belongs. At <b>0.35</b>, every fiery effect clears
      it by at least <b>63%</b>, and the worst correct solution by <b>92%</b>. <b>No graded subject's score
      moved.</b> That score-neutrality is the tell that it was a genuine robustness fix and not a thumb on
      the scale.</p>
  </div>

  <div class="callout">
    <b>3. Neither. An incomplete spec.</b>
    <p style="margin-bottom:0">The Player is <em>also</em> in <code>damageables</code>, and <b>run2
      damages you with your own grenade</b>. The original does not. But my spec says <em>"it damages
      nearby <b>enemies</b>"</em> and is <b>silent on the player</b>, so an agent that hurts the player
      has satisfied every word it was given. Docking run2 for it would mean grading an <b>unstated
      requirement</b>, which is exactly the false-negative failure the brief warns against hardest. So the
      harness <b>measures and reports</b> it (<code>player_damaged_DIAGNOSTIC_NOT_SCORED</code>) and
      <b>does not score it</b>. The fault is in my spec, not proven to be in their code. Spec and verifier
      must stay aligned: everything the grader scores, the spec must state.</p>
  </div>

  <div class="callout bad">
    <b>The one that should worry you most.</b> The crash was found by <em>a human playing the game</em>,
    not by the grader, which had happily given those solutions <b>90/100</b>. My damage harness spawned
    only enemies, and my visual harness <em>stripped the crates out</em>. I had even written that
    narrowness down as an accepted limitation. It was hiding a gameplay-breaking bug in <b>two of three</b>
    solutions. Worse, <b>my own ablation caused it</b>: removing the <code>ExplosionArea</code>, which
    leaked the radius, is precisely what pushed every agent off the safe physics query and onto the group
    query that hits the trap. <span class="muted">The ablation reshaped the solution space, and the
    harness failed to model the shape it had created. A documented gap is still a gap.</span>
  </div>

  <h2><span class="n">9.</span>Honest limitations</h2>
  <ul>
    <li><b>"Headless" has a caveat.</b> The damage half is true <code>--headless</code>. The visual half
      needs a real render context, because Godot's dummy renderer produces no pixels. It runs fully
      automated with no human, but on a headless CI it would need a virtual display.</li>
    <li><b>Cross-hardware reproducibility is untested.</b> Determinism is demonstrated on one machine,
      GPU and Godot build. The margins are wide (the flash discriminator has 3 to 4× headroom; every fiery
      effect clears the hue gate by at least 63%), so the risk is low, but it is untested and I would
      rather say so.</li>
    <li><b>The verifier cannot rank two <em>equally good</em> attempts.</b> run1 and run2 tie at 55 with
      identical visual sub-scores despite very different effects, because every sub-behaviour is a
      threshold test and they land on the same side of all seven. It resolves <em>categories</em>
      (correct, missing, cheat, broken) rather than shades of polish.</li>
    <li><b>Damage is tested against beetles and crate debris</b>, not bee-bots or intact crates. Better
      than it was, since that gap hid the crash, but still not the full cast.</li>
  </ul>

  <div class="foot">
    <b>Repo:</b> <a href="https://github.com/shivnarainms22/Roboblast-Eval">github.com/shivnarainms22/Roboblast-Eval</a>,
    a fork of <a href="https://github.com/gdquest-demos/godot-4-3d-third-person-controller">RoboBlast: TPS Demo</a>.
    <code>main</code> is the untouched base. <code>task/explosion-ablated</code> is what the agent sees.
    <code>agent/run1-3</code> are the rollouts, verbatim. <code>eval</code> holds the verifier, the probes
    and the results.
    <div style="margin-top:10px">
      <span class="tag">Godot 4.6</span><span class="tag">deterministic grading</span>
      <span class="tag">anti reward-hacking</span><span class="tag">claude-opus-4-8</span>
      <span class="tag">Godot MCP</span>
    </div>
  </div>

</div>
</body>
</html>
"""

OUT.write_text(HTML, encoding="utf-8")
kb = OUT.stat().st_size / 1024
print(f"wrote {OUT}  ({kb:.0f} KB, self-contained)")
