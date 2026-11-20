# commit-diary

Mantém o gráfico de contribuições da sua conta **pessoal** do GitHub vivo
enquanto você trabalha na conta da empresa — **sem misturar as contas e sem
vazar nada do trabalho**.

Uma vez por dia, a ferramenta conta os commits que você fez nos repositórios
do trabalho e registra **apenas a data e a quantidade** em um arquivo de um
repositório **privado** da sua conta pessoal:

```
- 2026-11-20 — 7 commits de trabalho
```

Cada atualização desse diário vira 1 commit na conta pessoal — e, com
*Private contributions* habilitado, 1 quadradinho verde no dia em que você
realmente trabalhou.

## O que sai da máquina do trabalho

Somente datas e números. Código, mensagens de commit, nomes de arquivos,
branches, projetos e clientes **nunca** são lidos nem enviados.

## Instalação (no Mac do trabalho)

1. **Na conta pessoal (lzAmaral)**, crie um *Fine-grained Personal Access Token*
   em <https://github.com/settings/personal-access-tokens/new>:
   - Repository access: **Only select repositories** → `diario-de-atividade`
   - Permissions → Contents: **Read and write**

   Assim, mesmo estando no Mac do trabalho, o token só alcança o diário — nada
   mais da conta pessoal.

2. No Mac do trabalho:

   ```bash
   git clone https://github.com/lzAmaral/commit-diary.git
   cd commit-diary
   ./install.sh
   ```

   O instalador pergunta: pastas dos projetos do trabalho, e-mail de autor dos
   commits do trabalho, URL do diário, seu nome/e-mail pessoais e o token.

3. **No perfil pessoal do GitHub**, ative *Private contributions*:
   foto de perfil → *Your profile* → engrenagem **Contribution settings** →
   marque **Private contributions**.

Pronto. O agendador (launchd) roda ao logar e todo dia às **18:45**, só
commitando quando há novidade — no máximo ~1 commit por dia trabalhado.

## Comandos úteis

```bash
~/.commit-diary/commit-diary.sh          # rodar manualmente agora
cat ~/.config/commit-diary/log.txt       # ver o log
open ~/.config/commit-diary/config       # editar config (pastas, e-mails, janela)
launchctl unload ~/Library/LaunchAgents/com.lzamaral.commit-diary.plist  # pausar
```

## Como funciona

- Varre as pastas configuradas (`SCAN_DIRS`) atrás de repositórios git e conta,
  por dia, os commits dos últimos 14 dias (`DAYS_BACK`) cujo autor seja um dos
  e-mails configurados — então rebases e pushes atrasados se corrigem sozinhos.
- Reescreve a janela recente do `diario.md` de forma idempotente: sem mudança,
  sem commit.
- Commita com sua identidade **pessoal** (`-c user.name/user.email`), sem tocar
  na configuração git do trabalho, e faz push pela URL com o token. Offline?
  Sem problema: o push pendente sai na execução seguinte.

## Transparência

Os quadradinhos gerados representam os commits do diário, não uma transferência
oficial dos commits da empresa — é um registro honesto de constância: *nesse
dia eu trabalhei*. O volume real fica documentado no arquivo, no repositório
privado.
