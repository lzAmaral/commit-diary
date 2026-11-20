#!/bin/bash
# Instalador do commit-diary — rode no Mac DO TRABALHO.
set -euo pipefail

CONF_DIR="$HOME/.config/commit-diary"
INSTALL_DIR="$HOME/.commit-diary"
PLIST_LABEL="com.lzamaral.commit-diary"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "== commit-diary — instalação =="
echo
echo "Este Mac registra APENAS data e quantidade de commits em um"
echo "repositório privado da sua conta pessoal do GitHub."
echo

read -r -p "Pasta(s) com os projetos do trabalho (separe por vírgula) [ex: $HOME/Projetos]: " scan_in
read -r -p "E-mail(s) de autor dos commits do trabalho (vírgula) [$(git config --global user.email 2>/dev/null || echo '')]: " emails_in
emails_in="${emails_in:-$(git config --global user.email 2>/dev/null || echo '')}"
read -r -p "URL do repositório privado do diário (conta PESSOAL) [https://github.com/lzAmaral/diario-de-atividade.git]: " diary_url
diary_url="${diary_url:-https://github.com/lzAmaral/diario-de-atividade.git}"
read -r -p "Seu nome para os commits do diário [Luiz Amaral]: " pname
pname="${pname:-Luiz Amaral}"
read -r -p "Seu e-mail PESSOAL (o associado à conta pessoal do GitHub): " pemail
[[ -n "$pemail" ]] || { echo "e-mail pessoal é obrigatório (é ele que pinta os quadradinhos)"; exit 1; }
echo
echo "Para o push, use um Fine-grained Personal Access Token da conta PESSOAL"
echo "com acesso SOMENTE ao repositório do diário (Contents: Read and write)."
echo "Crie em: https://github.com/settings/personal-access-tokens/new"
read -r -s -p "Cole o token (fica salvo só no clone local do diário): " token
echo

# monta a URL autenticada
auth_url="$diary_url"
if [[ -n "$token" && "$diary_url" == https://github.com/* ]]; then
  auth_url="https://x-access-token:${token}@${diary_url#https://}"
fi

mkdir -p "$CONF_DIR" "$INSTALL_DIR"
chmod 700 "$CONF_DIR" "$INSTALL_DIR"

# clona (ou atualiza o remote) do diário
DIARY_DIR="$INSTALL_DIR/diario"
if [[ -d "$DIARY_DIR/.git" ]]; then
  git -C "$DIARY_DIR" remote set-url origin "$auth_url"
else
  git clone --quiet "$auth_url" "$DIARY_DIR"
fi

# copia o script
cp "$SRC_DIR/bin/commit-diary.sh" "$INSTALL_DIR/commit-diary.sh"
chmod +x "$INSTALL_DIR/commit-diary.sh"

# escreve a config
IFS=',' read -r -a scan_arr <<< "$scan_in"
IFS=',' read -r -a email_arr <<< "$emails_in"
{
  echo "# config do commit-diary (shell) — edite à vontade"
  printf 'SCAN_DIRS=('; for d in "${scan_arr[@]:-}"; do d="$(echo "$d" | xargs)"; [[ -n "$d" ]] && printf '"%s" ' "${d/#\~/$HOME}"; done; echo ')'
  echo 'REPOS=()  # repositórios avulsos, caminho completo'
  printf 'AUTHOR_EMAILS=('; for e in "${email_arr[@]:-}"; do e="$(echo "$e" | xargs)"; [[ -n "$e" ]] && printf '"%s" ' "$e"; done; echo ')'
  echo "DIARY_DIR=\"$DIARY_DIR\""
  echo 'DIARY_FILE="diario.md"'
  echo "PERSONAL_NAME=\"$pname\""
  echo "PERSONAL_EMAIL=\"$pemail\""
  echo 'DAYS_BACK=14'
} > "$CONF_DIR/config"
chmod 600 "$CONF_DIR/config"

# launchd: roda ao logar e todo dia às 18:45
mkdir -p "$HOME/Library/LaunchAgents"
sed -e "s|__SCRIPT__|$INSTALL_DIR/commit-diary.sh|g" \
    -e "s|__LABEL__|$PLIST_LABEL|g" \
    -e "s|__LOG__|$CONF_DIR/log.txt|g" \
    "$SRC_DIR/launchd/com.lzamaral.commit-diary.plist" > "$PLIST_PATH"
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo
echo "Instalado. Rodando a primeira sincronização..."
"$INSTALL_DIR/commit-diary.sh" || true
echo
echo "Pronto! Agenda: ao logar + todo dia às 18:45."
echo "Log: $CONF_DIR/log.txt   Config: $CONF_DIR/config"
echo "Não esqueça de ativar 'Private contributions' no perfil pessoal do GitHub."
