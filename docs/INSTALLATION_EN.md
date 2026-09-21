# Jev Orchestration for OMP — installation and usage

Complete guide for installing, selecting agents, choosing scope, and using the
`jev-orchestration` skill with [Oh My Pi (OMP)](https://github.com/aldokruger/jev-skill).

## 1. Prerequisites

### OMP

OMP discovers the skill in a new session. The installer does not modify OMP itself.

### Python 3

Required to run `scripts/jev.py` and the self-test:

```bash
python3 --version
```

On Windows:

```powershell
python --version
# or
py -3 --version
```

### Jev credentials

The client uses `TYPESAFE_API_KEY`. For OMP's internal judgments, the recommended
path is to store the credential through OMP itself:

```text
omp
/login typesafe
```

The installer never asks for, writes, or prints the API key.

To run `jev.py` outside OMP, the variable must also be available in that process:

Linux/macOS/WSL:

```bash
export TYPESAFE_API_KEY="your-key"
```

PowerShell:

```powershell
$env:TYPESAFE_API_KEY = "your-key"
```

## 2. Quick installation

### Linux, macOS, and WSL

```bash
curl -fsSL https://raw.githubusercontent.com/aldokruger/jev-skill/main/install.sh | bash
```

Defaults:

- agent: `omp`;
- scope: `global`;
- mode: `copy`;
- destination: `~/.omp/agent/skills/jev-orchestration`.

### Windows PowerShell

```powershell
irm https://raw.githubusercontent.com/aldokruger/jev-skill/main/install.ps1 | iex
```

Default destination:

```text
%USERPROFILE%\.omp\agent\skills\jev-orchestration
```

More explicit and auditable form:

```powershell
$script = "$env:TEMP\jev-install.ps1"
irm https://raw.githubusercontent.com/aldokruger/jev-skill/main/install.ps1 -OutFile $script
powershell -ExecutionPolicy Bypass -File $script
```

## 3. Installation from a checkout

```bash
git clone https://github.com/aldokruger/jev-skill.git
cd jev-skill
./install.sh
```

On Windows:

```powershell
git clone https://github.com/aldokruger/jev-skill.git
cd jev-skill
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

## 4. Supported agents

The installers support these skill roots:

| Name | Global scope |
|---|---|
| `omp` | `~/.omp/agent/skills` |
| `claude` | `~/.claude/skills` |
| `codex` | `~/.codex/skills` |
| `gemini` | `~/.gemini/skills` |
| `opencode` | `~/.config/opencode/skills` |
| `agents` | `~/.agents/skills` |

On Windows, `~` means `%USERPROFILE%`.

Detection checks whether the known skills directory exists. It does not check
whether the provider executable is installed or authenticated.

List targets:

```bash
./install.sh --list-agents
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -ListAgents
```

## 5. Selecting agents

### Specific agents

```bash
./install.sh --agent omp,claude,opencode
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Agent omp,claude,opencode
```

### All agents

```bash
./install.sh --all
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -All
```

### Interactive selection

```bash
./install.sh --interactive
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Interactive
```

With no arguments and no interactive terminal, the installer selects only `omp`.
This avoids installing globally into providers the user did not request.

## 6. Global or project scope

### Global

The skill is available to all projects and sessions for the user:

```bash
./install.sh --agent omp,claude --scope global
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 `
  -Agent omp,claude `
  -Scope global
```

### Project-local

Install inside a specific project:

```bash
./install.sh \
  --agent omp,agents \
  --scope project \
  --project /path/to/project
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 `
  -Agent omp,agents `
  -Scope project `
  -Project C:\src\my-project
```

The project directory must already exist. Example destinations:

```text
<project>/.omp/skills/jev-orchestration
<project>/.agents/skills/jev-orchestration
```

Use project scope when the skill should travel with a repository, be reviewed
alongside its code, or remain inactive in other projects.

Use global scope when the skill is a personal preference for every session.

## 7. Copy or symlink

### Copy — recommended for normal use

```bash
./install.sh --agent omp --mode copy
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 `
  -Agent omp `
  -Mode copy
```

A copy is independent from the checkout. Repository updates do not change the
installation until the installer is run again.

### Symlink — recommended for development

Run it from a local checkout:

```bash
./install.sh --agent omp --mode symlink
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 `
  -Agent omp `
  -Mode symlink
```

The installed path points at the local `jev-orchestration` directory. Changes in
the checkout become visible immediately.

`symlink` cannot be combined with `--from-git`, because the clone is temporary and
the link would point to a directory removed when the installer exits.

On Windows, creating a symlink may require Developer Mode or an elevated
PowerShell.

## 8. Repository, branch, and version

Use the local checkout:

```bash
./install.sh
```

Fetch the repository:

```bash
./install.sh --from-git
```

Use a branch or tag:

```bash
./install.sh --from-git --ref main
./install.sh --from-git --ref v1.0.0
```

The skill is staged in a temporary directory and then moved into place. This
prevents a partially written installation from becoming discoverable.

## 9. Custom destination

`--dest` installs into one custom skills root and ignores generated roots for the
selected agents:

```bash
./install.sh --dest /opt/omp/skills --force
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 `
  -Destination C:\tools\omp\skills `
  -Force
```

## 10. Preview, update, and collisions

Preview without changing files:

```bash
./install.sh --agent omp,claude --dry-run
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 `
  -Agent omp,claude `
  -DryRun
```

For safety, an existing installation is not replaced automatically:

```text
error: .../jev-orchestration already exists; use --force
```

Replace explicitly:

```bash
./install.sh --agent omp --force
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Agent omp -Force
```

## 11. Verify after installation

Skill discovery occurs when the OMP session starts. Restart OMP and confirm that
the skill resolves:

```text
read skill://jev-orchestration
```

Run the self-test directly:

```bash
python3 ~/.omp/agent/skills/jev-orchestration/scripts/jev.py selftest
```

On Windows:

```powershell
py -3 "$env:USERPROFILE\.omp\agent\skills\jev-orchestration\scripts\jev.py" selftest
```

The self-test makes real Jev calls and has a small cost. Without the API key, the
installation can still complete, but the self-test is skipped.

## 12. Using the skill

The skill can be activated by description matching when a request involves:

- reducing tokens spent by expensive models;
- filtering a diff, log, file list, or retrieved set;
- choosing a model tier or skill;
- verifying a cheaper model's output;
- selecting one candidate from many;
- detecting injection in retrieved context;
- deciding when to escalate to a more expensive model.

Explicit activation:

```text
Use skill://jev-orchestration to filter this log before sending it to the expensive model.
```

Interactive command, when enabled:

```text
/skill:jev-orchestration
```

The skill provides four primitives:

| Primitive | Function |
|---|---|
| `screen_evidence` | filters relevance, evidence, injection, and contradiction |
| `route` | chooses the cheapest sufficient tier and indicates human escalation |
| `verify` | checks extracted fields against a source |
| `pick` | chooses one candidate or returns `None` when ambiguous |

Core rules:

1. Put all independent questions into one Jev request.
2. Name the item path in every question (`passages[3]`, for example).
3. Use English questions; the `state` may be Portuguese or another language.
4. Calibrate thresholds and probabilities against your domain before relying on them.
5. `None` or low confidence means escalate or gather evidence; never guess.
6. Jev handles typed decisions; it does not generate code, summaries, prose, or tools.

## 13. Known limitations

- Jev is English-primary; non-English questions may lose accuracy.
- Unrelated context reduces accuracy.
- Keep the combined state and longest question within the API context limit.
- Do not use Jev for counting, arithmetic, ordering, or date comparison.
- Probabilities from separate questions are not necessarily complementary.
- `copy` is a snapshot; `symlink` requires the local checkout to remain present.
- Global skills can be discovered in every project; project skills are discovered
  when OMP starts in the corresponding project.

## 14. Manual removal

Remove only the destinations you installed:

```bash
rm -rf ~/.omp/agent/skills/jev-orchestration
```

For a project installation:

```bash
rm -rf /path/to/project/.omp/skills/jev-orchestration
```

Restart OMP afterward so discovery is refreshed.
