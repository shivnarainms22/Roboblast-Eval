# Rollout setup, and the evidence that the lockdown held

The writeup claims the agents could not reach the answer, and that the tool lockdown was
**enforced in the wild, not merely configured**. This is the evidence for that claim,
taken verbatim from the three rollout transcripts.

## What each agent was given

All three runs got the **identical prompt**, with no hints about the implementation:

```
Read TASK.md in this project and implement the feature it describes. This is a Godot 4.6
project (RoboBlast); edit the project's files to implement the behavior. Use the Godot MCP
tools to run and inspect the project as you work. Implement the full behavior described in
TASK.md, and make sure the project still runs without errors when you are done.
```

| | |
|---|---|
| Agent | Claude Code **v2.1.207** |
| Model | **`claude-opus-4-8`** |
| Permission mode | `acceptEdits` |
| Tools **allowed** | file tools (Read/Write/Edit/Glob/Grep), and the **Godot MCP** |
| Tools **disabled** | **`Bash`**, **`WebFetch`**, **`WebSearch`** |
| Working dir | the sandbox (`rollouts/run1|2|3`), one per run |

**Why disable the shell and the network.** The game is public on GitHub, so obscurity is
worth nothing: the original `_explode()` is one `curl` away. Integrity has to be enforced at
the tool layer, not by hoping the agent does not look. No shell means no `curl`, no `git
log`, no reading the grader.

## The sandbox

Each rollout ran in a **history-stripped extract of the ablated branch**, verified from the
artifacts rather than asserted:

* **history depth 1** — the baseline *is* the root commit, so `git log` reveals nothing
* **no `main`, no `task/explosion-ablated`** — only a local `master`
* **no remotes** — nothing to fetch from
* **no verifier anywhere on disk** — the grader is not in the project it grades

## The evidence: two agents reached for `Bash`, and were refused

`run1` and `run3` each attempted exactly one `Bash` call. Both were refused by the harness.
`run2` never attempted one.

### run1

> **Tool call** — `Bash`, described by the agent as *"Locate the Godot executable"*
> ```
> where godot 2>nul; where Godot_v4.6-stable_win64.exe 2>nul; echo "---GODOT_BIN env---"; echo "$GODOT_BIN"; echo "$GODOT4"
> ```
>
> **Harness reply**
> ```
> Error: No such tool available: Bash. Bash exists but is not enabled in this
> context. Use one of the available tools instead.
> ```

### run3

> **Tool call** — `Bash`
> ```
> grep -oE '(SCRIPT ERROR|Parser Error|Debugger Break|Invalid call|Nonexistent function|Cannot open|non-existent resource)[^"]*' "<its own session transcript>"
> ```
> *(the transcript path is redacted — it was an absolute path on the machine that ran the rollout)*
>
> **Harness reply**
> ```
> Error: No such tool available: Bash. Bash exists but is not enabled in this
> context. Use one of the available tools instead.
> ```

### Read this honestly

**Neither attempt was an attempt to cheat.** run1 wanted to find the Godot binary; run3
wanted to grep its own log for script errors. Both are ordinary developer reflexes, and
neither was reaching for the original implementation.

So this is **not** evidence that the agents tried to escape the sandbox. It is evidence of
something narrower and more useful: the restriction was **real at runtime**, not just a flag
in a config file. When an agent reached for the shell, the shell was not there.

The stronger evidence that nobody recovered the original is in the solutions themselves:
all three are **code-driven** while the original is **shader-driven**, none reproduced its
shaders, and all three picked a blast radius of **4.0 m** where the original's is **3.0 m**.
A copied answer would not have missed that.

## One disclosure

Before `run1`'s rollout, a separate **one-minute session** ran in the same sandbox with the
prompt *"Call the Godot MCP tool `get_godot_version` and report ONLY the version string it
returns."* That was a smoke test confirming the Godot MCP was actually wired up before the
real runs began. It made no edits and attempted no task work. It is disclosed here so the
transcript record is complete.
