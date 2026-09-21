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

```bash
curl -fsSL https://raw.githubusercontent.com/aldokruger/jev-skill/main/install.sh | bash
```

or from a checkout:

```bash
git clone https://github.com/aldokruger/jev-skill.git
cd jev-skill
./install.sh              # into ~/.omp/agent/skills
./install.sh --dry-run    # show the plan, change nothing
./install.sh --dest DIR   # somewhere else
./install.sh --force      # replace an existing install
```

Flags: `--from-git` (fetch from GitHub instead of the local checkout), `--ref TAG`
(pin a tag or branch), `--dest DIR`, `--force`, `--dry-run`, `--help`.
The installer never touches your API key.

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
