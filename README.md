# jev-orchestration

An [OMP](https://github.com/aldokruger/jev-skill) agent skill that routes work
through **Jev** (TypeSafe System One) so the most expensive chat models receive
fewer, better tokens.

Jev is a *decision primitive*, not a chat model: one `POST /v1/systemone` carries
a `state` (text) plus N named typed questions and returns N answers constrained to
the options you supplied. Input is billed at \$0.042/Mtok, output is free. A whole
five-judgment workflow measured **\$0.000101** — the lever is that you filter,
route, verify, and select *before* an expensive model ever reads the input.

## Install

The installers detect supported skill roots and let you select one or more
providers. Detection means the provider's known config/skills directory exists;
it does not probe whether the provider executable is installed.

Supported providers: `omp`, `claude`, `codex`, `gemini`, `opencode`, and
`agents` (`~/.agents`). Default is global `omp` only. Use `--list-agents` to
inspect all roots before installing.

Linux/macOS/WSL:

```bash
curl -fsSL https://raw.githubusercontent.com/aldokruger/jev-skill/main/install.sh | bash
./install.sh --list-agents
./install.sh --agent omp,claude --scope global --mode copy
./install.sh --scope project --project /path/to/repo --agent omp,agents
./install.sh --mode symlink --agent omp
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/aldokruger/jev-skill/main/install.ps1 | iex
powershell -ExecutionPolicy Bypass -File .\install.ps1 -ListAgents
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Agent omp,claude -Scope global -Mode copy
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Scope project -Project C:\src\repo -Agent omp,agents
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Mode symlink -Agent omp
```

`copy` is the safe default and works with remote repositories. `symlink` is
for local checkout development only; Windows may require Developer Mode or an
elevated PowerShell. A symlink keeps the installed skill synchronized with the
checkout, while copy creates an independent snapshot.

Scopes and resulting roots:

| Scope | Provider | Root |
|---|---|---|
| global | omp | `~/.omp/agent/skills` |
| global | claude | `~/.claude/skills` |
| global | codex | `~/.codex/skills` |
| global | gemini | `~/.gemini/skills` |
| global | opencode | `~/.config/opencode/skills` |
| global | agents | `~/.agents/skills` |
| project | any | `<project>/.omp/skills`, `.claude/skills`, `.codex/skills`, `.gemini/skills`, `.config/opencode/skills`, or `.agents/skills` |

Use `--all` / `-All` to install in every supported provider root. Use
`--force` / `-Force` to replace existing copies and `--dry-run` / `-DryRun` to
preview changes. `--dest` / `-Destination` overrides the generated root and is
intended for one custom target.

The Bash installer supports `--from-git` and falls back to HTTPS when piped.
The PowerShell installer uses Git when available and falls back to the GitHub
ZIP archive. Both installers never touch your API key.

## API key

The skill and its script read `TYPESAFE_API_KEY` from the environment. Inside OMP,
store it once so it survives reboots:

```
omp          # start a session
/login typesafe
```

That writes the credential to `~/.omp/agent/agent.db`, which both `judge()` and
OMP's internal typed judgments consult. To run `scripts/jev.py` outside OMP too,
export the variable in your shell as well. Optional: pin the model with
`TYPESAFE_DEFAULT_MODEL=jev-1.13.0` instead of `jev-latest`, so threshold tuning
is not invalidated by a silent model bump.

## What is inside

```
jev-orchestration/
  SKILL.md              rules, the four primitives, escalation policy, failure modes
  scripts/jev.py        stdlib-only client + primitives + selftest
```

`scripts/jev.py` is one file with every question and threshold in a single
`REVIEW SURFACE` block at the top — read that block before trusting the output.
Run the self-check first:

```bash
python3 scripts/jev.py selftest     # 5 live calls, asserts shapes, prints real cost
```

| Primitive | Answers | Token effect |
|---|---|---|
| `screen_evidence(query, passages)` | relevant / has evidence / injection / contradicts premise | removes most retrieved text before the expensive prompt |
| `route(task)` | cheapest tier that finishes without a redo; human needed? | skips the expensive model for mechanical work |
| `verify(source, {field: value})` | per-field "is this unsupported by the source?" | gates the repair call |
| `pick(candidates, request)` | which one of N | only the winner enters the expensive prompt |

## Measured, not quoted

On an 8.6 KB state with 12 questions: **2 274 input tokens in one batched call
(0.78 s)** against **25 440 tokens across 12 serial calls (9.39 s)** — **11.2x**.
Batching is the whole point: one request carries every question, and the shared
state is paid for once.

Two failure modes are documented in `SKILL.md` because both are silent:

- **Name the state path in every question.** With several items in one state and a
  question saying "this passage", every question answers about the same item
  (measured: all four passages scored 0.94 on injection instead of
  0.04/0.98/0.06/0.09).
- **Fire-action semantics.** Map the action taken when a question *fires*, with an
  explicit fall-through default, or keep-tests and hazard-tests collapse into one.

## Limits

Jev does not stream, call tools, generate text, or expose `/v1/chat/completions`.
It is English-primary (non-English state is fine, non-English questions lose
accuracy). It reads literally: no arithmetic, date comparison, or counting.
Structural identities between questions do not hold (`P(x) + P(not x) ≠ 1`
measured). Keep the state small — accuracy falls as unrelated text grows, and
140 KB hard-fails with `max_tokens_exceeded`.
