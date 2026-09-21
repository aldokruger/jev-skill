---
name: jev-orchestration
description: Route and filter work through Jev (TypeSafe System One) so expensive frontier chat models receive fewer, better tokens. Use when reviewing a large diff/log/retrieval set, deciding which model tier or skill a task needs, deduplicating candidates, verifying a cheap model's output before escalating, or whenever context is about to be re-read by an expensive model. Triggers include "token budget", "cheap model first", "escalate", "prefilter context", "route this task", "which skill", "verify extraction", "dedup candidates", "jev", "typesafe".
---

# Jev orchestration

Jev is a **decision primitive**, not a chat model: one `POST /v1/systemone` carries
a `state` (text) plus N named typed questions, and returns N answers constrained to
the options you supplied. No streaming, no tools, no text generation, no
`/v1/chat/completions`. Everything here is "ask a typed question about text I
already hold"; anything that must *write* prose, code, or a summary stays on a
chat model — but it stays *gated* by Jev.

The whole economic argument: **Jev bills input only at $0.042 per Mtok; output
tokens are free.** ~$0.0001 buys a complete five-judgment workflow. One frontier
turn at 20k input tokens costs dollars. Filtering, routing, and verifying are
therefore free relative to what they save — the only question is whether the
judgment is accurate, and the answer to that is a threshold you tune.

## Non-negotiable rules

1. **One request, all questions.** Questions are evaluated in parallel and are
   mutually independent. Never loop one question per call.
   Measured on this machine (8.6 KB state, 12 questions): batched **2274 input
   tokens / 0.78 s** vs serial **25440 tokens / 9.39 s** — **11.2x** the tokens
   for identical information. The bigger the shared state, the closer to Nx.
2. **Name the state path in every question.** `"Does \`passages[3]\` address the
   query?"`, never `"Does this passage…"`. With several items in one state, an
   unnamed referent makes every question answer about *some* passage — measured:
   all four passages scored 0.94 on injection instead of 0.04/0.98/0.06/0.09.
3. **Write questions in English even when the content is not.** Jev is
   English-primary; state text in any language is fine, questions are not.
4. **Code owns the decision.** Read `probabilities`/`noul`, compare to a threshold
   you chose, and branch. Never ask Jev "what should I do" — that is a System Two
   task and it will answer badly.
5. **Keep the state small and relevant.** Accuracy falls as unrelated text grows
   (context rot), and 140 KB hard-fails with `max_tokens_exceeded`. Budget: 32k
   tokens for `state` + the longest question.
6. **One question = one snap judgment.** Split multi-factor judgments into one
   question per factor and combine with your own weights in code.

## The four primitives

The client is `skill://jev-orchestration/scripts/jev.py` — on disk
`~/.omp/agent/skills/jev-orchestration/scripts/jev.py` (`$SKILL_DIR` below means
that directory). It is stdlib-only, takes `TYPESAFE_API_KEY` from the
environment, and holds every question and threshold in one review surface at the
top of the file. Run the self-check before trusting it:

```bash
SKILL_DIR=~/.omp/agent/skills/jev-orchestration
python3 "$SKILL_DIR/scripts/jev.py" selftest   # 5 live calls, asserts shapes, prints real cost
```

To drive it from anywhere, import it by absolute path:

```bash
PYTHONPATH="$SKILL_DIR/scripts" python3 -c 'import jev; print(jev.EVIDENCE_THRESHOLDS)'
```

| Primitive | Question it answers | Token effect |
|---|---|---|
| `screen_evidence(query, passages, chunk=10)` | relevant / has evidence / injection / contradicts premise | removes 2/3+ of retrieved text before the expensive prompt, and the injection check is a security gate |
| `route(task) -> tier, human` | cheapest tier that finishes without a redo; is a human needed | skips the expensive model entirely for mechanical work |
| `verify(source, {field: value})` | per-field "is this unsupported or absent from source?" | gates the repair call; a max gate over fields, not a mean |
| `pick(candidates, request)` | which one of N | only the winner enters the expensive prompt; a bare name list usually returns `None`, which is the signal to narrow in code |

Answer shapes: `noul` → `{"noul": p}` (no confidence field); `choice` →
`{"choice", "confidence", "probabilities"}`; `score` → `{"score", "confidence",
"legend", "probabilities"}`. Limits: 255 Choice options, 2-10 Score levels.

## Escalation policy

Gate on `confidence` for "do I act at all", on `probabilities` for combining
answers. Three bands: act / confirm or gather more / do not act. Per-action
thresholds, never one global number. Treat `None` from `pick` and low-confidence
tiers as *escalate one level up*, not as a value to pass along. Do not carry a
threshold tuned on a `noul` over to a `choice` — they answer different questions.

## Wiring inside this harness

- Typed internal judgments already route to TypeSafe: `providers.judgmentProvider: auto`.
- From an eval cell, `judge(state, questions).wait()` is the zero-code path
  (accepts `bool`/`score`/`choice`; `bool` is returned as a probability field).
- `completion(prompt, {model: "smol"|"default"|"slow"})` is the cheap chat tier;
  feed it only screened input.
- Work that must reach a real chat model still goes through `agent()`/`workpool()`,
  but with filtered state and a Jev-chosen scope.

## Do not

- Ask Jev to generate, rewrite, summarize, or classify into free text.
- Ask it anything code can compute exactly (counts, date arithmetic, ordering).
- Trust structural invariants between questions — `P(x) + P(not x) ≠ 1` measured.
- Ship without a confidence floor: an unfiltered 0.5 is the model saying
  "none of your options fit".

Accuracy claims, the model-jaggedness list, and pricing live with the vendor at
`https://docs.typesafe.ai`; re-check them before quoting a number to a user.
