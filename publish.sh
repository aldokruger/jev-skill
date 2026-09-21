#!/usr/bin/env bash
# Push this skill repo to GitHub: https://github.com/aldokruger/jev-skill
#
#   publish.sh            init the repo (if needed), commit everything, push
#   publish.sh --tag v1.0.0   also create and push an annotated tag
#   publish.sh --dry-run  show what would happen, change nothing
#
# Auth: uses the gh CLI credential helper if `gh auth status` is logged in;
# otherwise plain git over HTTPS with your configured credential helper.
set -euo pipefail

REPO_URL="https://github.com/aldokruger/jev-skill.git"
BRANCH="main"
TAG=""
DRY_RUN=0

say()  { printf '%s\n' "$*"; }
die()  { printf 'erro: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --tag)     shift; [ $# -gt 0 ] || die "--tag precisa de um valor"; TAG="$1" ;;
    --branch)  shift; [ $# -gt 0 ] || die "--branch precisa de um valor"; BRANCH="$1" ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)         die "argumento desconhecido: $1" ;;
  esac
  shift
done

cd "$(cd "$(dirname "$0")" && pwd)"
say "repo local : $(pwd)"

command -v git >/dev/null 2>&1 || die "git nao encontrado"

run() {
  if [ "$DRY_RUN" = "1" ]; then say "  [dry-run] $*"; else "$@"; fi
}

# --- init -------------------------------------------------------------------
if [ ! -d .git ]; then
  say "sem .git: inicializando"
  run git init -q -b "$BRANCH"
else
  say "repositorio ja inicializado"
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  say "adicionando remote origin -> $REPO_URL"
  run git remote add origin "$REPO_URL"
elif [ "$(git remote get-url origin)" != "$REPO_URL" ]; then
  say "ajustando origin: $(git remote get-url origin) -> $REPO_URL"
  run git remote set-url origin "$REPO_URL"
else
  say "origin ja aponta para $REPO_URL"
fi

# --- what will be published -------------------------------------------------
say ""
say "arquivos que entram no commit:"
if [ "$DRY_RUN" = "1" ]; then
  git add -A --dry-run 2>/dev/null | sed 's/^/  /' || true
else
  git add -A
  git diff --cached --name-status | sed 's/^/  /'
fi

if [ "$DRY_RUN" != "1" ] && git diff --cached --quiet; then
  say "  (nada novo para commitar)"
else
  MSG="jev-orchestration: Jev orchestration skill for OMP"
  say ""
  say "commit: $MSG"
  run git commit -q -m "$MSG" || true
fi

# --- push -------------------------------------------------------------------
say ""
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  say "auth: gh CLI logado (credential helper do gh)"
else
  say "auth: credential helper do git (gh ausente ou nao logado)"
fi

run git push -u origin "$BRANCH"

if [ -n "$TAG" ]; then
  say ""
  say "tag: $TAG"
  run git tag -a "$TAG" -m "jev-orchestration $TAG"
  run git push origin "$TAG"
fi

say ""
say "pronto: https://github.com/aldokruger/jev-skill"
say "instalacao em outra maquina:"
say "  curl -fsSL https://raw.githubusercontent.com/aldokruger/jev-skill/$BRANCH/install.sh | bash"
