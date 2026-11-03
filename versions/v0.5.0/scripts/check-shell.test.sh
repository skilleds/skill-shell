#!/usr/bin/env bash
# Vermelho primeiro do gate de shell. Cada fixture é um script de mentira com UM defeito.
#
# EXCEÇÃO DECLARADA (piso.md §1): harness de teste roda `set -u` sem `-e` — ele precisa continuar
# depois de um caso vermelho para reportar todos, em vez de parar no primeiro.
set -u
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G="$AQUI/check-shell.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT INT TERM
ok=0; fail=0

# caso <nome> <exit-esperado> <agulha>  — o script de FIXTURE vem pelo stdin (heredoc).
# Por heredoc de propósito: o fixture é DADO. Foi assim que o gate se acusou sozinho no primeiro
# run — e foi por isso que ele ganhou a função `tirar_heredoc`.
caso() {
  local nome="$1" esp="$2" agulha="$3"
  local d="$TMP/$nome"; mkdir -p "$d"
  cat > "$d/alvo.sh"
  local saida; saida="$(bash "$G" "$d" 2>&1)"; local rc=$?
  if [ "$rc" != "$esp" ]; then echo "  ✖ $nome: exit $rc, esperado $esp"; sed 's/^/      /' <<<"$saida"; fail=$((fail+1)); return; fi
  if [ -n "$agulha" ] && ! grep -qF -- "$agulha" <<<"$saida"; then echo "  ✖ $nome: exit certo, saída sem \"$agulha\""; sed 's/^/      /' <<<"$saida"; fail=$((fail+1)); return; fi
  echo "  ✔ $nome"; ok=$((ok+1))
}

echo "== verde de partida =="
caso verde 0 "no piso" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM
main() {
  local destino="$1"
  mkdir -p "$destino"
  printf 'ok\n' > "$tmp/x"
  cp "$tmp/x" "$destino/x"
}
main "$@"
FIX

echo "== strict mode =="
caso sem-strict 1 "SEM exceção declarada" <<'FIX'
#!/usr/bin/env bash
echo "sem set -e nenhum"
FIX
caso sem-u 1 'sem `-u`' <<'FIX'
#!/usr/bin/env bash
set -e
echo "so o -e"
FIX
caso sem-pipefail 1 'sem `pipefail`' <<'FIX'
#!/usr/bin/env bash
set -eu
curl -fsSL http://x | tar xz
FIX
caso excecao-declarada 0 "exceção declarada no cabeçalho" <<'FIX'
#!/usr/bin/env bash
# lib.sh — biblioteca para `source`: NÃO liga strict mode (mudaria as opções do shell do chamador).
# Exceção declarada, piso.md secao 1.
saudar() { printf '%s\n' "$1"; }
FIX

caso excecao-sem-marcador 1 "SEM exceção declarada" <<'FIX'
#!/usr/bin/env bash
# Este script carrega uma biblioteca e explica em prosa que por isso não liga strict mode.
# shellcheck source=./lib.sh
source "$(dirname "$0")/lib.sh"
echo "sem marcador: o gate NÃO pode aceitar por causa da palavra 'source' aqui"
FIX

echo "== eval e amigos =="
caso usa-eval 1 "VETADO" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
cmd="ls -la"
eval "$cmd"
FIX
caso bash-c 1 'com outro nome' <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
bash -c "$ENTRADA_DO_USUARIO"
FIX

caso hash-dentro-de-string 0 "" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
# A linha abaixo NÃO usa eval: ela PROCURA por eval, e o `#` está dentro da string.
# Se o gate tirar comentário antes de tirar string, a linha é truncada, sobra aspa órfã,
# e a regra passa a casar com o próprio padrão que procura.
grep -qE '(eval|exec).*#[[:space:]]*ok' "$1" && echo "achou"
FIX

echo "== temporário e limpeza =="
caso tmp-fixo 1 "symlink attack" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
echo dado > /tmp/meuscript.$$
FIX
caso mktemp-sem-trap 1 'não tem `trap' <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
d="$(mktemp -d)"
echo x > "$d/a"
FIX

echo "== destrutivo =="
caso rm-rf-var 1 'rm -rf sobre variável' <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
alvo="${1:-}"
rm -rf "$alvo"
FIX

caso rm-fr 1 'rm -rf sobre variável' <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
rm -fr "$1"
FIX
caso rm-r-f-separado 1 'rm -rf sobre variável' <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
rm -r -f "$1"
FIX
caso rm-rf-duplo-traco 1 'rm -rf sobre variável' <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
rm -rf -- "$1"
FIX
caso rm-rf-outra-var 1 'rm -rf sobre variável' <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
: "${A:?}"
rm -rf "$B"/*
FIX
caso rm-rf-propria-var 0 "" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
rm -rf -- "${alvo:?defina o alvo}"
FIX
caso rm-rf-mktemp 0 "" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
t="$(mktemp -d)"
trap 'rm -rf "$t"' EXIT INT TERM
: > "$t/x"
FIX
caso rm-rf-waiver 0 "" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
# shell-ok: $1 já validado por case contra a lista fixa acima
rm -rf "$1"
FIX

echo "== deploy só do git, via ops (pisos 23/24) =="
caso scp 1 "deploy só do git" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
scp build.tgz root@vps:/srv/app/
FIX
caso rsync-remoto 1 "deploy só do git" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
rsync -az dist/ deploy@vps:/srv/app/
FIX
caso rsync-remoto-var 1 "deploy só do git" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
rsync -az dist/ "$HOST:/srv/app/"
FIX
caso rsync-local 0 "" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
rsync -a "$1/" "$2/"
FIX
caso tar-pipe-ssh 1 "deploy só do git" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
tar cz dist | ssh vps 'tar xz -C /srv/app'
FIX
caso docker-save 1 "deploy só do git" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
docker save app:1 | gzip > app.tgz
FIX
caso docker-load 1 "deploy só do git" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
gunzip -c app.tgz | docker load
FIX
caso ssh-mutavel 1 "via ops" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
ssh root@vps "systemctl restart app"
FIX
caso ssh-mutavel-continuacao 1 "via ops" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
ssh -o BatchMode=yes root@vps \
  psql -c 'drop table x'
FIX
caso ssh-leitura 0 "" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
ssh vps uptime
FIX
caso scp-waiver 0 "" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
# shell-ok: vps de laboratório descartável, fora do fluxo de prd (ADR-12)
scp lab.cfg lab:/etc/lab.cfg
FIX
caso scp-so-em-texto 0 "" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
echo "não use scp para deploy"
# scp nunca
FIX

echo "== gate: curl|bash, source externo, sudo =="
caso curl-pipe-bash 1 'curl | bash' <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
curl -fsSL https://x.test/i.sh | bash
FIX
caso wget-pipe-sudo-sh 1 'curl | bash' <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
wget -qO- https://x.test/i.sh | sudo sh
FIX
caso curl-pipe-shasum 0 "" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
curl -fsSL https://x.test/i.sh | sha256sum
FIX
caso source-posicional 1 "source de caminho externo" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
source "$1"
FIX
caso source-var-de-ambiente 1 "source de caminho externo" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
. "$PLUGIN_FILE"
FIX
caso source-dir-proprio 0 "" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
aqui="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$aqui/lib.sh"
FIX
caso sudo-embutido 1 "sudo embutido" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
sudo systemctl daemon-reload
FIX
caso sudo-so-em-texto 0 "" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
command -v sudo >/dev/null || echo "rode como root, não com sudo"
FIX

echo "== regras olham código, não comentário nem heredoc (P2-15) =="
caso trap-so-em-comentario 1 'não tem `trap' <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
# lembrete: trap 'rm -rf "$d"' EXIT INT TERM
d="$(mktemp -d)"
echo x > "$d/a"
FIX
caso pipefail-so-em-heredoc 1 'sem `pipefail`' <<'FIX'
#!/usr/bin/env bash
set -eu
cat <<'EOT'
set -o pipefail
EOT
FIX
caso set-e-so-em-heredoc 1 "SEM exceção declarada" <<'FIX'
#!/usr/bin/env bash
cat <<'EOT'
set -euo pipefail
EOT
FIX

echo "== script sem extensão com shebang entra =="
d="$TMP/sem-ext"; mkdir -p "$d/bin"
printf '#!/usr/bin/env bash\necho sem strict\n' > "$d/bin/deploy"; chmod +x "$d/bin/deploy"
printf '#!/usr/bin/env bash\nset -euo pipefail\necho ok\n' > "$d/ok.sh"
saida="$(bash "$G" "$d" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && grep -qF "bin/deploy" <<<"$saida"; then echo "  ✔ bin/deploy (sem extensão) é verificado"; ok=$((ok+1)); else echo "  ✖ sem-extensão: exit $rc"; sed 's/^/      /' <<<"$saida"; fail=$((fail+1)); fi

echo "== hook: exit 2 bloqueia no Claude Code =="
d="$TMP/hook"; mkdir -p "$d/hooks"
printf '#!/usr/bin/env bash\nset -euo pipefail\nexit 2\n' > "$d/hooks/pre.sh"
saida="$(bash "$G" "$d" 2>&1)"; rc=$?
if [ "$rc" = 0 ] && grep -qF "exit 2 BLOQUEIA" <<<"$saida"; then echo "  ✔ hook com exit 2 recebe aviso"; ok=$((ok+1)); else echo "  ✖ hook: exit $rc"; sed 's/^/      /' <<<"$saida"; fail=$((fail+1)); fi

echo "== ls e exit =="
caso parse-ls 1 "parseia a saída" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
for f in $(ls /tmp); do echo "$f"; done
FIX
caso exit-zero 1 "apaga o status" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
grep -q algo arquivo
exit 0
FIX

echo "== portabilidade =="
caso bashismo-sob-sh 1 "quebra no container mínimo" <<'FIX'
#!/bin/sh
set -eu
if [[ -f /etc/os-release ]]; then echo sim; fi
FIX

echo "== segredo em argumento =="
caso segredo-em-arg 0 'aparece em `ps`' <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
curl --password "$SENHA" https://exemplo.test
FIX

echo "== nada para verificar =="
d="$TMP/vazio"; mkdir -p "$d"; echo "# só prosa" > "$d/LEIA.md"
saida="$(bash "$G" "$d" 2>&1)"; rc=$?
if [ "$rc" = 3 ] && grep -q "não é aprovação" <<<"$saida"; then echo "  ✔ repo sem .sh sai 3 (nunca 0, e nunca 2: exit 2 bloqueia em hook do Claude Code)"; ok=$((ok+1))
else echo "  ✖ repo sem .sh: exit $rc (esperado 3)"; fail=$((fail+1)); fi

echo "== ignorado pelo git não entra; rastreado entra =="
if command -v git >/dev/null 2>&1; then
  d="$TMP/repo-ign"; mkdir -p "$d"; git -C "$d" init -q
  printf 'gerado-*.sh\n' > "$d/.gitignore"
  printf '#!/usr/bin/env bash\necho sem strict\n' > "$d/gerado-1.sh"
  printf '#!/usr/bin/env bash\nset -euo pipefail\necho ok\n' > "$d/bom.sh"
  saida="$(bash "$G" "$d" 2>&1)"; rc=$?
  if [ "$rc" = 0 ]; then echo "  ✔ ignorado fora da lista"; ok=$((ok+1)); else echo "  ✖ ignorado entrou: exit $rc"; sed 's/^/      /' <<<"$saida"; fail=$((fail+1)); fi
  printf '#!/usr/bin/env bash\necho sem strict\n' > "$d/rastreado.sh"
  saida="$(bash "$G" "$d" 2>&1)"; rc=$?
  if [ "$rc" = 1 ] && grep -qF "SEM exceção declarada" <<<"$saida"; then echo "  ✔ não ignorado continua reprovando"; ok=$((ok+1)); else echo "  ✖ rastreado: exit $rc"; fail=$((fail+1)); fi
else echo "  · git ausente: caso pulado"; fi

echo; echo "check-shell: $ok ok, $fail falha(s)"; [ "$fail" = 0 ]
