#!/usr/bin/env bash
# Install the jev-orchestration skill into the OMP agent skills directory.
#
#   install.sh                      install from this checkout into ~/.omp/agent/skills
#   install.sh --from-git           same, but fetched from the GitHub repo below
#   install.sh --from-git --ref v1.0.0
#   install.sh --dest DIR           install somewhere else
#   install.sh --force              overwrite an existing install
#   install.sh --dry-run            print the plan, change nothing
#
# curl | bash:
#   curl -fsSL https://raw.githubusercontent.com/aldokruger/jev-skill/main/install.sh | bash
#
# The skill needs TYPESAFE_API_KEY in the environment. This installer never
# asks for, writes, or prints the key: persist it yourself with `omp /login
# typesafe` (stored in ~/.omp/agent/agent.db) or by exporting it in your shell.
set -euo pipefail

REPO_URL="https://github.com/aldokruger/jev-skill.git"
SKILL_NAME="jev-orchestration"
DEFAULT_DEST="${OMP_AGENT_DIR:-$HOME/.omp/agent}/skills"
AGENT_DIR="${OMP_AGENT_DIR:-$HOME/.omp/agent}"

DEST=""
FROM_GIT=0
FORCE=0
DRY_RUN=0
REF=""

say()  { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die()  { printf 'erro: %s\n' "$*" >&2; exit 1; }

usage() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --from-git) FROM_GIT=1 ;;
    --ref)      shift; [ $# -gt 0 ] || die "--ref precisa de um valor"; REF="$1" ;;
    --dest)     shift; [ $# -gt 0 ] || die "--dest precisa de um valor"; DEST="$1" ;;
    --force)    FORCE=1 ;;
    --dry-run)  DRY_RUN=1 ;;
    -h|--help)  usage; exit 0 ;;
    *)          die "argumento desconhecido: $1 (use --help)" ;;
  esac
  shift
done

# --- prerequisites ----------------------------------------------------------
command -v python3 >/dev/null 2>&1 || die "python3 nao encontrado (a skill usa somente a stdlib, mas precisa do interpretador)"

TMP=""
cleanup() { [ -z "$TMP" ] || rm -rf "$TMP"; return 0; }
trap cleanup EXIT

# --- locate the source ------------------------------------------------------
RAW_BASE="https://raw.githubusercontent.com/aldokruger/jev-skill/${REF:-main}"

if [ "$FROM_GIT" = "1" ]; then
  command -v git >/dev/null 2>&1 || die "git nao encontrado (necessario para --from-git)"
  TMP="$(mktemp -d)"
  say "clonando $REPO_URL${REF:+ (ref $REF)}"
  if [ "$DRY_RUN" = "1" ]; then
    say "  [dry-run] git clone --depth 1 ${REF:+--branch $REF }$REPO_URL $TMP/repo"
  else
    git clone --quiet --depth 1 ${REF:+--branch "$REF"} "$REPO_URL" "$TMP/repo" \
      || die "falha no clone de $REPO_URL${REF:+ (ref $REF)}"
  fi
  SRC="$TMP/repo/$SKILL_NAME"
else
  SELF_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
  if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/$SKILL_NAME/SKILL.md" ]; then
    # Running from a checkout.
    SRC="$SELF_DIR/$SKILL_NAME"
  elif [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/SKILL.md" ]; then
    # Running from inside the skill directory itself.
    SRC="$SELF_DIR"
  else
    # Piped into bash (`curl ... | bash`): there is no local checkout, so fetch
    # the two files straight from GitHub over HTTPS - no git, no clone.
    command -v curl >/dev/null 2>&1 || die "sem checkout local e sem curl: use --from-git ou clone o repositorio"
    TMP="$(mktemp -d)"
    SRC="$TMP/$SKILL_NAME"
    say "sem checkout local: baixando de $RAW_BASE"
    if [ "$DRY_RUN" = "1" ]; then
      say "  [dry-run] curl -fsSL $RAW_BASE/jev-orchestration/SKILL.md"
      say "  [dry-run] curl -fsSL $RAW_BASE/jev-orchestration/scripts/jev.py"
    else
      mkdir -p "$SRC/scripts"
      curl -fsSL "$RAW_BASE/$SKILL_NAME/SKILL.md" -o "$SRC/SKILL.md" \
        || die "falha ao baixar SKILL.md de $RAW_BASE"
      curl -fsSL "$RAW_BASE/$SKILL_NAME/scripts/jev.py" -o "$SRC/scripts/jev.py" \
        || die "falha ao baixar scripts/jev.py de $RAW_BASE"
    fi
  fi
fi

DEST="${DEST:-$DEFAULT_DEST}"
TARGET="$DEST/$SKILL_NAME"

say "skill      : $SKILL_NAME"
say "origem     : $SRC"
say "destino    : $TARGET"

if [ "$DRY_RUN" != "1" ]; then
  [ -f "$SRC/SKILL.md" ]            || die "SKILL.md nao encontrado em $SRC"
  [ -f "$SRC/scripts/jev.py" ]      || die "scripts/jev.py nao encontrado em $SRC"
fi

# --- collision check --------------------------------------------------------
if [ -e "$TARGET" ] && [ "$FORCE" != "1" ]; then
  if [ "$DRY_RUN" = "1" ]; then
    say "  [dry-run] $TARGET ja existe: a copia real exigiria --force"
  else
    die "$TARGET ja existe. Rode com --force para substituir, ou remova o diretorio."
  fi
fi

if [ "$DRY_RUN" = "1" ]; then
  say "  [dry-run] copiar $SRC/ -> $TARGET/ (SKILL.md + scripts/jev.py, chmod +x)"
  say "  [dry-run] nada foi alterado"
  exit 0
fi

# --- install ----------------------------------------------------------------
mkdir -p "$DEST"
STAGE="$DEST/.$SKILL_NAME.tmp.$$"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp "$SRC/SKILL.md" "$STAGE/SKILL.md"
mkdir -p "$STAGE/scripts"
cp "$SRC/scripts/jev.py" "$STAGE/scripts/jev.py"
chmod +x "$STAGE/scripts/jev.py"
# Swap in atomically so a half-written skill is never discoverable.
rm -rf "$TARGET"
mv "$STAGE" "$TARGET"

say "instalado  : $TARGET"
find "$TARGET" -type f -printf '  %M %8s %p\n' 2>/dev/null || find "$TARGET" -type f

# --- verify -----------------------------------------------------------------
say ""
say "verificacao"
if [ -n "${TYPESAFE_API_KEY:-}" ]; then
  if python3 "$TARGET/scripts/jev.py" selftest >/tmp/jev-install-check.$$ 2>&1; then
    tail -2 /tmp/jev-install-check.$$ | sed 's/^/  /'
  else
    warn "  selftest falhou — veja /tmp/jev-install-check.$$"
    tail -3 /tmp/jev-install-check.$$ | sed 's/^/  /' >&2
    rm -f /tmp/jev-install-check.$$
    exit 1
  fi
  rm -f /tmp/jev-install-check.$$
else
  say "  TYPESAFE_API_KEY ausente: selftest nao rodado."
  say "  Persista a chave com \`omp\` e depois \`/login typesafe\` (grava em $AGENT_DIR/agent.db),"
  say "  ou exporte a variavel no seu shell, e entao rode:"
  say "    python3 $TARGET/scripts/jev.py selftest"
fi

say ""
say "A skill e descoberta no start do omp: reinicie a sessao, depois confirme com"
say "  read skill://$SKILL_NAME"
