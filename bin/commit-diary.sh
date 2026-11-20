#!/bin/bash
# commit-diary — registra sua atividade de commits do trabalho em um
# repositório privado da conta pessoal do GitHub, guardando APENAS
# data e quantidade. Nenhum código, mensagem de commit, nome de arquivo,
# branch, projeto ou cliente sai da máquina.
set -uo pipefail

CONFIG="${COMMIT_DIARY_CONFIG:-$HOME/.config/commit-diary/config}"
if [[ ! -f "$CONFIG" ]]; then
  echo "erro: config não encontrada em $CONFIG — rode o install.sh primeiro" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG"

: "${DIARY_DIR:?defina DIARY_DIR na config}"
: "${PERSONAL_NAME:?defina PERSONAL_NAME na config}"
: "${PERSONAL_EMAIL:?defina PERSONAL_EMAIL na config}"
DIARY_FILE="${DIARY_FILE:-diario.md}"
DAYS_BACK="${DAYS_BACK:-14}"
SCAN_DIRS=("${SCAN_DIRS[@]:-}")
REPOS=("${REPOS[@]:-}")
AUTHOR_EMAILS=("${AUTHOR_EMAILS[@]:-}")

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# ---------------------------------------------------------------- repositórios
declare -a all_repos=()
for r in "${REPOS[@]}"; do
  [[ -n "$r" && -d "$r/.git" ]] && all_repos+=("$r")
done
for d in "${SCAN_DIRS[@]}"; do
  [[ -n "$d" && -d "$d" ]] || continue
  while IFS= read -r gitdir; do
    all_repos+=("$(dirname "$gitdir")")
  done < <(find "$d" -maxdepth 4 -type d -name .git -not -path "*/node_modules/*" 2>/dev/null)
done

# remove duplicatas e o próprio diário
declare -a repos=()
for r in "${all_repos[@]:-}"; do
  [[ -z "$r" ]] && continue
  [[ "$r" == "$DIARY_DIR" ]] && continue
  dup=0
  for s in "${repos[@]:-}"; do [[ "$s" == "$r" ]] && dup=1 && break; done
  [[ $dup -eq 0 ]] && repos+=("$r")
done

if [[ ${#repos[@]} -eq 0 ]]; then
  log "nenhum repositório de trabalho encontrado — confira SCAN_DIRS/REPOS na config"
  exit 0
fi
log "acompanhando ${#repos[@]} repositório(s)"

# filtro de autor (OR entre e-mails); sem e-mail configurado, conta tudo
declare -a author_args=()
for e in "${AUTHOR_EMAILS[@]:-}"; do
  [[ -n "$e" ]] && author_args+=(--author="$e")
done

# ------------------------------------------------------- contagem por data
# conta commits dos últimos DAYS_BACK dias, agregados por data local
tmp_counts="$(mktemp)"
trap 'rm -f "$tmp_counts"' EXIT
for r in "${repos[@]}"; do
  git -C "$r" log --all --no-merges \
    --since="${DAYS_BACK} days ago" \
    --date=short --pretty='%ad' \
    "${author_args[@]:-}" 2>/dev/null
done | sort | uniq -c | awk '{print $2" "$1}' > "$tmp_counts"

# ------------------------------------------------------------ atualiza diário
if [[ ! -d "$DIARY_DIR/.git" ]]; then
  log "erro: $DIARY_DIR não é um clone git do diário" >&2
  exit 1
fi

git -C "$DIARY_DIR" pull --rebase --quiet 2>/dev/null \
  || log "aviso: pull falhou (sem rede?) — seguindo com a cópia local"

diary_path="$DIARY_DIR/$DIARY_FILE"
cutoff="$(date -v-"${DAYS_BACK}"d '+%Y-%m-%d' 2>/dev/null || date -d "-${DAYS_BACK} days" '+%Y-%m-%d')"

# preserva linhas antigas (fora da janela) e reescreve a janela recente
tmp_diary="$(mktemp)"
{
  echo "# Diário de atividade"
  echo
  echo "Registro automático de constância: apenas **data e quantidade** de commits"
  echo "feitos no trabalho. Gerado pelo [commit-diary](https://github.com/lzAmaral/commit-diary)."
  echo
  {
    # linhas antigas existentes, anteriores à janela recalculada
    if [[ -f "$diary_path" ]]; then
      grep -E '^- [0-9]{4}-[0-9]{2}-[0-9]{2} — ' "$diary_path" | awk -v c="$cutoff" 'substr($2,1,10) < c'
    fi
    # janela recalculada
    while read -r d n; do
      [[ "$d" < "$cutoff" ]] && continue
      s="commits"; [[ "$n" == "1" ]] && s="commit"
      echo "- $d — $n $s de trabalho"
    done < "$tmp_counts"
  } | sort
} > "$tmp_diary"

mkdir -p "$(dirname "$diary_path")"
if [[ -f "$diary_path" ]] && cmp -s "$tmp_diary" "$diary_path"; then
  rm -f "$tmp_diary"
  log "sem novidades — diário já está em dia"
else
  mv "$tmp_diary" "$diary_path"
  git -C "$DIARY_DIR" add "$DIARY_FILE"
  git -C "$DIARY_DIR" \
    -c user.name="$PERSONAL_NAME" -c user.email="$PERSONAL_EMAIL" \
    commit --quiet -m "Atividade: $(date '+%Y-%m-%d')"
  log "diário atualizado e commitado"
fi

# empurra qualquer commit pendente (inclusive de execuções offline anteriores)
if ! git -C "$DIARY_DIR" push --quiet 2>/dev/null; then
  log "aviso: push falhou (sem rede?) — será reenviado na próxima execução"
else
  log "push concluído"
fi
