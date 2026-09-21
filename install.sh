#!/usr/bin/env bash
# Install jev-orchestration for one or more agent providers.
#
#   ./install.sh                              interactive agent selection when possible
#   ./install.sh --agent omp,claude           selected agents
#   ./install.sh --scope project --project .  project-local installation
#   ./install.sh --mode symlink               development link (local checkout only)
#   ./install.sh --from-git --force           fetch and replace copies
#   curl -fsSL https://raw.githubusercontent.com/aldokruger/jev-skill/main/install.sh | bash
set -euo pipefail

REPO_URL="https://github.com/aldokruger/jev-skill.git"
SKILL_NAME="jev-orchestration"
AGENT_DIR="${OMP_AGENT_DIR:-$HOME/.omp/agent}"
DEFAULT_DEST="$AGENT_DIR/skills"
DEST=""
FROM_GIT=0
FORCE=0
DRY_RUN=0
REF=""
AGENT_ARG=""
SCOPE="global"
PROJECT_DIR="$PWD"
MODE="copy"
INTERACTIVE=0

say()  { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die()  { printf 'erro: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Install jev-orchestration for one or more agent providers.

  ./install.sh                              choose discovered agents interactively
  ./install.sh --agent omp,claude           install for selected agents
  ./install.sh --all                        install for all supported agents
  ./install.sh --scope project --project .  project-local installation
  ./install.sh --mode symlink               symlink a local checkout
  ./install.sh --from-git --force           fetch and replace copies

Options:
  --agent LIST       comma-separated: omp,claude,codex,gemini,opencode,agents
  --all              select every supported agent
  --list-agents      show detected agents and target roots
  --interactive      prompt even when stdin is not a TTY
  --scope SCOPE      global (default) or project
  --project DIR      project root for --scope project (default: cwd)
  --mode MODE        copy (default) or symlink (local checkout only)
  --from-git         fetch the repository instead of using this checkout
  --ref REF          branch, tag, or commit when fetching
  --dest DIR         override the generated skills root
  --force            replace existing installations
  --dry-run          show the plan without changing files
  --help             show this help

Global roots: ~/.omp/agent/skills, ~/.claude/skills, ~/.codex/skills,
~/.gemini/skills, ~/.config/opencode/skills, ~/.agents/skills.
Project roots use the same provider directory below --project.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --agent)        shift; [ $# -gt 0 ] || die "--agent precisa de um valor"; AGENT_ARG="$1" ;;
    --all)          AGENT_ARG="all" ;;
    --list-agents)  AGENT_ARG="__list__" ;;
    --interactive)  INTERACTIVE=1 ;;
    --scope)        shift; [ $# -gt 0 ] || die "--scope precisa de um valor"; SCOPE="$1" ;;
    --project)      shift; [ $# -gt 0 ] || die "--project precisa de um valor"; PROJECT_DIR="$1" ;;
    --mode)         shift; [ $# -gt 0 ] || die "--mode precisa de um valor"; MODE="$1" ;;
    --ref)          shift; [ $# -gt 0 ] || die "--ref precisa de um valor"; REF="$1" ;;
    --dest)         shift; [ $# -gt 0 ] || die "--dest precisa de um valor"; DEST="$1" ;;
    --force)        FORCE=1 ;;
    --dry-run)      DRY_RUN=1 ;;
    -h|--help)      usage; exit 0 ;;
    *)              die "argumento desconhecido: $1 (use --help)" ;;
  esac
  shift
done

case "$SCOPE" in global|project) ;; *) die "--scope deve ser global ou project" ;; esac
case "$MODE" in copy|symlink) ;; *) die "--mode deve ser copy ou symlink" ;; esac
if [ "$SCOPE" = project ]; then
  PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)" || die "projeto inexistente: $PROJECT_DIR"
fi
command -v python3 >/dev/null 2>&1 || die "python3 nao encontrado"

TMP=""
cleanup() { [ -z "$TMP" ] || rm -rf "$TMP"; return 0; }
trap cleanup EXIT

# name -> global root / project root
agent_root() {
  case "$1:$SCOPE" in
    omp:global)      printf '%s' "$AGENT_DIR/skills" ;;
    claude:global)   printf '%s' "$HOME/.claude/skills" ;;
    codex:global)    printf '%s' "$HOME/.codex/skills" ;;
    gemini:global)   printf '%s' "$HOME/.gemini/skills" ;;
    opencode:global) printf '%s' "$HOME/.config/opencode/skills" ;;
    agents:global)   printf '%s' "$HOME/.agents/skills" ;;
    omp:project)      printf '%s' "$PROJECT_DIR/.omp/skills" ;;
    claude:project)   printf '%s' "$PROJECT_DIR/.claude/skills" ;;
    codex:project)    printf '%s' "$PROJECT_DIR/.codex/skills" ;;
    gemini:project)   printf '%s' "$PROJECT_DIR/.gemini/skills" ;;
    opencode:project) printf '%s' "$PROJECT_DIR/.config/opencode/skills" ;;
    agents:project)   printf '%s' "$PROJECT_DIR/.agents/skills" ;;
    *) return 1 ;;
  esac
}
SUPPORTED=(omp claude codex gemini opencode agents)
agent_label() { [ "$1" = agents ] && printf '%s' 'agents (.agents)' || printf '%s' "$1"; }
agent_detected() { [ -d "$(agent_root "$1")" ]; }

list_agents() {
  say "Agentes suportados ($SCOPE):"
  for a in "${SUPPORTED[@]}"; do
    root="$(agent_root "$a")"
    if [ -d "$root" ]; then state="instalado/detectado"; else state="nao detectado (sera criado)"; fi
    printf '  %-16s %s  [%s]\n' "$a" "$root" "$state"
  done
}

if [ "$AGENT_ARG" = __list__ ]; then list_agents; exit 0; fi

SELECTED=()
if [ -n "$AGENT_ARG" ] && [ "$AGENT_ARG" != all ]; then
  IFS=',' read -r -a SELECTED <<< "$AGENT_ARG"
elif [ "$AGENT_ARG" = all ]; then
  SELECTED=("${SUPPORTED[@]}")
elif [ "$INTERACTIVE" = 1 ] || [ -t 0 ]; then
  list_agents
  printf 'Escolha agentes separados por virgula [omp]: '
  IFS= read -r answer || true
  if [ -n "$answer" ]; then IFS=',' read -r -a SELECTED <<< "$answer"; else SELECTED=(omp); fi
else
  SELECTED=(omp)
  say "nenhum agente indicado: usando omp (use --interactive, --all ou --agent)"
fi

VALIDATED=()
for a in "${SELECTED[@]}"; do
  case "$a" in omp|claude|codex|gemini|opencode|agents) VALIDATED+=("$a") ;; *) die "agente desconhecido: $a (use --list-agents)" ;; esac
done
SELECTED=("${VALIDATED[@]}")
[ "${#SELECTED[@]}" -gt 0 ] || die "nenhum agente selecionado"

if [ "$MODE" = symlink ] && [ "$FROM_GIT" = 1 ]; then
  die "--mode symlink exige checkout local; clone temporario seria um link quebrado"
fi

# Resolve local checkout or fetch the source.
RAW_BASE="https://raw.githubusercontent.com/aldokruger/jev-skill/${REF:-main}"
if [ "$FROM_GIT" = 1 ]; then
  command -v git >/dev/null 2>&1 || die "git nao encontrado"
  TMP="$(mktemp -d)"
  say "clonando $REPO_URL${REF:+ (ref $REF)}"
  if [ "$DRY_RUN" = 0 ]; then
    git clone --quiet --depth 1 ${REF:+--branch "$REF"} "$REPO_URL" "$TMP/repo" || die "falha no clone"
  fi
  SRC="$TMP/repo/$SKILL_NAME"
else
  SELF_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
  if [ -f "$SELF_DIR/$SKILL_NAME/SKILL.md" ]; then SRC="$SELF_DIR/$SKILL_NAME"
  elif [ -f "$SELF_DIR/SKILL.md" ]; then SRC="$SELF_DIR"
  else
    command -v curl >/dev/null 2>&1 || die "sem checkout local e sem curl"
    TMP="$(mktemp -d)"; SRC="$TMP/$SKILL_NAME"; mkdir -p "$SRC/scripts"
    say "sem checkout local: baixando de $RAW_BASE"
    [ "$DRY_RUN" = 1 ] || {
      curl -fsSL "$RAW_BASE/$SKILL_NAME/SKILL.md" -o "$SRC/SKILL.md" || die "falha ao baixar SKILL.md"
      curl -fsSL "$RAW_BASE/$SKILL_NAME/scripts/jev.py" -o "$SRC/scripts/jev.py" || die "falha ao baixar jev.py"
    }
  fi
fi

[ "$DRY_RUN" = 1 ] || { [ -f "$SRC/SKILL.md" ] || die "SKILL.md nao encontrado em $SRC"; [ -f "$SRC/scripts/jev.py" ] || die "jev.py nao encontrado em $SRC"; }

ROOTS=()
if [ -n "$DEST" ]; then ROOTS=("$DEST")
else for a in "${SELECTED[@]}"; do ROOTS+=("$(agent_root "$a")"); done
fi

say "skill: $SKILL_NAME | scope: $SCOPE | mode: $MODE"
for root in "${ROOTS[@]}"; do
  target="$root/$SKILL_NAME"
  say "destino: $target"
  if [ -e "$target" ] && [ "$FORCE" = 0 ]; then
    [ "$DRY_RUN" = 1 ] && say "  [dry-run] existe; exigiria --force" || die "$target ja existe; use --force"
  fi
  if [ "$DRY_RUN" = 1 ]; then say "  [dry-run] instalar"; continue; fi
  mkdir -p "$root"
  if [ "$MODE" = symlink ]; then
    rm -rf "$target"
    ln -s "$SRC" "$target"
  else
    stage="$root/.$SKILL_NAME.tmp.$$"
    rm -rf "$stage"; mkdir -p "$stage/scripts"
    cp "$SRC/SKILL.md" "$stage/SKILL.md"; cp "$SRC/scripts/jev.py" "$stage/scripts/jev.py"; chmod +x "$stage/scripts/jev.py"
    rm -rf "$target"; mv "$stage" "$target"
  fi
  say "instalado: $target"
done

if [ "$DRY_RUN" = 1 ]; then say "dry-run: nada foi alterado"; exit 0; fi
if [ -n "${TYPESAFE_API_KEY:-}" ]; then python3 "$SRC/scripts/jev.py" selftest | tail -2 | sed 's/^/  /'; else say "TYPESAFE_API_KEY ausente: selftest nao rodado"; fi
say "reinicie o OMP; confirme com read skill://$SKILL_NAME"
