#!/usr/bin/env bash
# schematize-shell — o gate. Roda o `shellcheck` e cobra o piso de `references/piso.md` sobre todo
# `.sh` do repo.
#
# NOTA DE EXCEÇÃO DECLARADA (piso.md §1): este script usa `set -uo pipefail` SEM `-e` de propósito —
# ele é um COLETOR: precisa varrer todos os arquivos e somar os achados. Com `-e` ele abortaria no
# primeiro problema e reportaria um, escondendo os outros onze.
#
# uso: check-shell.sh [dir]   ·  0 = passa · 1 = REPROVA · 3 = nada para verificar
#
# POR QUE 3 E NÃO 2: em hook do Claude Code, exit 2 BLOQUEIA a ação (e devolve o stderr ao agente).
# "Nada para verificar" é estado do verificador, não ordem de bloqueio — com 2, rodar este gate como
# hook travaria o agente à toa. 3 não tem significado no Claude Code nem no git (piso.md §2 e §8).
set -uo pipefail

raiz="${1:-.}"
erros=(); avisos=()

# `find` com -print0 + read -d '': nome com espaço ou quebra de linha não quebra a lista.
arquivos=()
while IFS= read -r -d '' f; do arquivos+=("$f"); done < <(
  find "$raiz" -type f -name '*.sh' \
    -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/versions/*' \
    -not -path '*/target/*' -print0 2>/dev/null
)
# Script SEM extensão (bin/deploy, hooks) também é script: entra quando é executável e abre com
# shebang de bash/sh. O gate que só olha `*.sh` perde justamente o hook e o bin/.
while IFS= read -r -d '' f; do
  case "$(head -c 64 -- "$f" 2>/dev/null | tr -d '\0' | head -n 1)" in
    '#!/usr/bin/env bash'*|'#!/bin/bash'*|'#!/usr/bin/env sh'*|'#!/bin/sh'*) arquivos+=("$f") ;;
    *) ;;
  esac
done < <(
  find "$raiz" -type f -perm /111 ! -name '*.*' \
    -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/versions/*' \
    -not -path '*/target/*' -print0 2>/dev/null
)

# Arquivo ignorado pelo git do PRÓPRIO repo dele (lançador gerado, artefato local) não é código do repo:
# fora da lista. `git -C <dir>` resolve o repo mais interno, então catálogo com repos aninhados funciona.
if command -v git >/dev/null 2>&1; then
  rastreados=()
  for f in "${arquivos[@]}"; do
    git -C "$(dirname "$f")" check-ignore -q -- "$(basename "$f")" 2>/dev/null || rastreados+=("$f")
  done
  arquivos=("${rastreados[@]+"${rastreados[@]}"}")
fi

# Fail-closed: repo sem script nenhum NÃO passa — sai 2. "Não achei" nunca é "está tudo certo".
if [ "${#arquivos[@]}" -eq 0 ]; then
  echo "✖ nenhum script de shell em $raiz — nada para verificar (e ausência de material não é aprovação)." >&2
  exit 3
fi

# ---------------------------------------------------------------- 1. shellcheck (o gate)
if command -v shellcheck >/dev/null 2>&1; then
  saida="$(shellcheck --severity=warning --format=gcc "${arquivos[@]}" 2>/dev/null)"
  if [ -n "$saida" ]; then
    while IFS= read -r linha; do [ -n "$linha" ] && erros+=("shellcheck: $linha"); done <<< "$saida"
  fi
else
  # Aviso RUIDOSO, não silêncio: o gate sem shellcheck cobre menos, e quem lê precisa saber.
  avisos+=("shellcheck NÃO está instalado — o gate rodou só as regras próprias (bem menos). Instale: apt install shellcheck, ou o binário do release oficial (references/stack-versoes.md)")
fi

# dispensado <regex> <arquivo> — TODA linha que casa o regex traz um waiver `# shell-ok: <motivo>`?
#
# O waiver existe para a exceção real (o comando que É a configuração, o padrão que só parece
# perigoso) e é **rastreável**: fica no diff, aparece no `grep`, e exige o MOTIVO — `# shell-ok:`
# sozinho não vale. É o oposto de desligar o gate no CI, que some do código e ninguém revisa.
# Aceita o marcador na própria linha ou na linha imediatamente acima (onde a explicação cabe).
dispensado() {
  local regex="$1" arq="$2" n total=0 cobertas=0
  while IFS=: read -r n _; do
    total=$((total+1))
    if sed -n "${n}p;$((n>1?n-1:1))p" "$arq" | grep -qE '#[[:space:]]*shell-ok:[[:space:]]*[^[:space:]]+'; then
      cobertas=$((cobertas+1))
    fi
  done < <(grep -nE "$regex" "$arq" | grep -vE '^[0-9]+:[[:space:]]*#')
  [ "$total" -gt 0 ] && [ "$cobertas" = "$total" ]
}

# tirar_heredoc — imprime o arquivo SEM o corpo dos heredocs.
#
# Heredoc é DADO, não código: o conteúdo entre `<<EOF` e `EOF` pode ser um exemplo, um template, ou
# (no caso dos testes desta própria skill) um script de fixture com defeito DE PROPÓSITO. Analisar
# aquilo como se fosse o script produz achado inventado — e um gate que grita no arquivo errado é um
# gate que alguém desliga.
tirar_heredoc() {
  local arq="$1" linha dentro=0 fim=""
  while IFS= read -r linha; do
    if [ "$dentro" = 1 ]; then
      # o delimitador pode vir indentado (<<-)
      [ "$(printf '%s' "$linha" | tr -d '[:space:]')" = "$fim" ] && dentro=0
      continue
    fi
    if [[ "$linha" =~ \<\<-?[[:space:]]*[\'\"]?([A-Za-z_][A-Za-z0-9_]*)[\'\"]? ]]; then
      fim="${BASH_REMATCH[1]}"; dentro=1
    fi
    printf '%s\n' "$linha"
  done < "$arq"
}

# ---------------------------------------------------------------- 2. piso próprio
for f in "${arquivos[@]}"; do
  nome="${f#"$raiz"/}"
  cabeca="$(head -n 30 "$f")"
  sem_heredoc="$(tirar_heredoc "$f")"
  # ORDEM IMPORTA: tira as STRINGS primeiro, o comentário depois. O caminho inverso quebra numa
  # linha como `grep -qE '(eval|exec).*#\s*ok'` — o `#` dentro da string vira "comentário", a linha
  # é truncada no meio e sobra uma aspa órfã; o resultado é a regra casando com o próprio padrão
  # que ela procura. (Foi exatamente assim que o gate acusou o gate de Python.)
  corpo="$(printf '%s\n' "$sem_heredoc" | sed -E -e "s/'[^']*'/''/g" -e 's/"[^"]*"/""/g' -e 's/(^|[[:space:]])#.*$/\1/')"
  # `codigo` = sem comentário, mas COM as strings: as regras que olham expansão dentro de aspas
  # (`rm -rf "$var"`, `bash -c "$x"`) precisam ver o `$`. Usar `corpo` nelas as tornaria cegas —
  # o defeito real mora justamente dentro das aspas.
  codigo="$(printf '%s\n' "$sem_heredoc" | sed -E 's/(^|[[:space:]])#.*$/\1/')"
  corpo_j="$(printf '%s\n' "$corpo" | sed -e ':a' -e '/\\$/{N;s/\\\n[[:space:]]*/ /;ba' -e '}')"
  # `codigo_j` = `codigo` com as continuações `\` juntadas: `ssh host \⏎ rm -rf x` é UMA linha.
  codigo_j="$(printf '%s\n' "$codigo" | sed -e ':a' -e '/\\$/{N;s/\\\n[[:space:]]*/ /;ba' -e '}')"

  # 2.1 strict mode — com as exceções DECLARADAS de piso.md §1
  if ! grep -qE '^\s*set -[a-z]*e[a-z]*\b|^\s*set -o errexit' <<< "$codigo"; then
    # O marcador é EXPLÍCITO de propósito. A primeira versão desta regra aceitava palavras soltas
    # ("biblioteca", "coletor", "source") no cabeçalho — e `source "$dir/lib.sh"` na linha 12 dava
    # passe livre a qualquer script que carregasse uma lib. Gate que aceita por acidente é pior que
    # gate ausente: ele produz um verde que ninguém confere.
    declarada=$(grep -ciE 'strict-ok:[[:space:]]*[^[:space:]]+|EXCE(Ç|C)(Ã|A)O DECLARADA' <<< "$cabeca")
    if [ "$declarada" -gt 0 ]; then
      avisos+=("$nome: sem \`set -e\` — exceção declarada no cabeçalho (ok)")
    else
      erros+=("$nome: sem strict mode e SEM exceção declarada — use \`set -euo pipefail\`, ou declare no cabeçalho com \`# strict-ok: <motivo>\` (biblioteca sourceada, coletor que soma achados, harness de teste)")
    fi
  else
    grep -qE '^\s*set -[a-z]*u|^\s*set -o nounset' <<< "$codigo" || erros+=("$nome: \`set -e\` sem \`-u\` — variável com typo vira string vazia em silêncio")
    grep -qE 'pipefail' <<< "$codigo" || erros+=("$nome: sem \`pipefail\` — \`curl -f url | tar xz\` sai 0 quando o curl falha")
  fi

  # 2.2 eval e amigos
  # `# shell-ok: <motivo>` na MESMA linha dispensa a regra — com o motivo escrito, que é o ponto:
  # o waiver é rastreável no diff e no `grep`, ao contrário do gate desligado no CI. Sem motivo (só
  # `# shell-ok:`) ele NÃO vale: o gate cobra a explicação, não a palavra mágica.
  # dispensado <padrao> <arquivo> — true quando a linha que casa o padrão traz `# shell-ok: motivo`
  # na PRÓPRIA linha ou na linha IMEDIATAMENTE acima (é onde a explicação cabe, quando ela é longa —
  # mesma convenção do `# shellcheck disable`).
  if grep -qE '(^|[;&|(]\s*)eval\b' <<< "$corpo" && ! dispensado '(^|[;&|(][[:space:]]*)eval\b' "$f"; then
    erros+=("$nome: usa \`eval\` — VETADO (injeção de comando). Use array para montar comando e \`case\` para despachar")
  fi
  if grep -qE 'bash -c ["'"'"']?\$' <<< "$codigo" && ! dispensado 'bash -c' "$f"; then
    erros+=("$nome: \`bash -c\` com string variável — é \`eval\` com outro nome")
  fi

  # 2.3 temporário previsível
  grep -qE '/tmp/[A-Za-z0-9_.-]*\$\$|/tmp/[A-Za-z0-9_.-]+"?\s*$' <<< "$codigo" \
    && ! grep -q 'mktemp' <<< "$codigo" \
    && erros+=("$nome: caminho fixo em /tmp sem \`mktemp\` — /tmp é mundialmente gravável: nome previsível é symlink attack (\`\$\$\` não protege: PID é previsível)")

  # 2.4 rm recursivo sobre variável não validada — ERRO (piso.md §6/§7)
  # Cobre rm -rf, -fr, -r -f, -rf --, --recursive. `${x:?}` só vale para a PRÓPRIA variável do alvo
  # (um `${A:?}` em outro lugar não protege `$B`), e variável vinda de `mktemp` no próprio arquivo
  # é sabidamente não vazia. Resto: valide, use `${v:?}` ou escreva o waiver `# shell-ok: motivo`.
  rm_ruim=""
  while IFS= read -r linha; do
    [[ "$linha" =~ (^|[^A-Za-z0-9_./-])rm[[:space:]]+([^\;\&\|]*) ]] || continue
    read -ra toks <<< "${BASH_REMATCH[2]}"
    recursivo=0
    for t in "${toks[@]}"; do
      [[ "$t" =~ ^-[A-Za-z]*[rR] || "$t" = --recursive ]] && recursivo=1
    done
    [ "$recursivo" = 1 ] || continue
    for t in "${toks[@]}"; do
      [[ "$t" =~ ^[\"\']?\$\{?([A-Za-z_][A-Za-z0-9_]*|[0-9@*])(:\?)? ]] || continue
      v="${BASH_REMATCH[1]}"
      [[ "$t" =~ ^[\"\']?\$\{${v}:\? ]] && continue
      grep -qE "(^|[^A-Za-z0-9_])${v}=\\\$?\\(?[\"']?\\\$?\\(?mktemp" <<< "$codigo" && continue
      rm_ruim="$t"
    done
  done <<< "$codigo_j"
  if [ -n "$rm_ruim" ] && ! dispensado '(^|[^A-Za-z0-9_./-])rm[[:space:]]+-' "$f"; then
    erros+=("$nome: \`rm -rf sobre variável\` não validada ($rm_ruim) — vazia vira \`/\` ou \`/*\`. Use \"\${var:?motivo}\" NA PRÓPRIA variável, valide o caminho, ou waiver \`# shell-ok: <motivo>\`")
  fi

  # 2.5 trap de limpeza quando cria temporário
  if grep -q 'mktemp' <<< "$codigo" && ! grep -q 'trap ' <<< "$codigo"; then
    erros+=("$nome: cria temporário com \`mktemp\` e não tem \`trap ... EXIT\` — Ctrl-C deixa lixo (piso.md §3)")
  fi
  if grep -qE '^\s*trap ' <<< "$codigo" && ! grep -qE '^\s*trap .*(EXIT|INT|TERM)' <<< "$codigo"; then
    avisos+=("$nome: \`trap\` sem EXIT/INT/TERM — cobre menos caminhos do que parece")
  fi

  # 2.6 cd sem guarda
  grep -qE '^\s*cd +[^|&]*$' <<< "$corpo" \
    && ! grep -qE '^\s*cd .*(\|\||&&|; then)' <<< "$corpo" \
    && avisos+=("$nome: \`cd\` sem \`|| exit\` — se o diretório não existe, o resto do script roda no lugar errado (SC2164)")

  # 2.7 parse de ls
  grep -qE 'for .* in .*\$\(ls |`ls ' <<< "$corpo" && erros+=("$nome: parseia a saída de \`ls\` — nome com espaço quebra. Use glob ou \`find -print0\`")

  # 2.8 exit 0 incondicional no fim
  ultima="$(grep -vE '^\s*(#|$)' "$f" | tail -1)"
  [ "$ultima" = "exit 0" ] && erros+=("$nome: termina em \`exit 0\` incondicional — apaga o status de tudo o que veio antes")

  # 2.9 shebang
  primeira="$(head -1 "$f")"
  case "$primeira" in
    '#!/usr/bin/env bash'|'#!/bin/bash'|'#!/usr/bin/env sh'|'#!/bin/sh') ;;
    '#!'*) avisos+=("$nome: shebang incomum ($primeira)") ;;
    *)
      grep -q 'shellcheck shell=' "$f" \
        || avisos+=("$nome: sem shebang e sem \`# shellcheck shell=bash\` — se é biblioteca, declare")
      ;;
  esac
  if [ "$primeira" = '#!/bin/sh' ] || [ "$primeira" = '#!/usr/bin/env sh' ]; then
    if grep -qE '\[\[|declare -[aA]|local |\$\{[A-Za-z_]+\^\^|mapfile|<<<' <<< "$corpo"; then
      erros+=("$nome: shebang \`sh\` (POSIX = dash no Debian) com bashismo — funciona na sua máquina, quebra no container mínimo")
    fi
  fi

  # 2.10 segredo em argumento (aparece em `ps`)
  grep -qE '(curl|wget|psql|mysql|ssh)[^|]*(--password|-p ?\$|--token)[= ]' <<< "$corpo" \
    && avisos+=("$nome: possível segredo em argumento de comando — aparece em \`ps\` para qualquer usuário da máquina; use variável de ambiente ou stdin")

  # 2.11 deploy por cópia / mutação direta da VPS — ERRO (pisos 23 e 24 da engineering)
  # "Deploy só do git, via ops": o artefato chega pelo git; a IA e o script não copiam binário nem
  # mudam a máquina por SSH — pedem a operação nomeada do ops. scp, rsync para host remoto, pipe
  # para ssh, docker save/load e `ssh host <comando que muda estado>` são o deploy-por-cópia.
  # O `$cmd` ancora no INÍCIO do comando, para `echo "não use scp"` não disparar.
  cmd='(^|[;&|(]|[[:space:]]then|[[:space:]]do|[[:space:]]else|\$\()[[:space:]]*(!?[[:space:]]*)(sudo[[:space:]]+)?(exec[[:space:]]+)?'
  host='["'"'"']?(\$\{?[A-Za-z_][A-Za-z0-9_]*\}?|[A-Za-z0-9_][A-Za-z0-9_.-]*)(@[^[:space:]:/]+)?:[^[:space:]]'
  mut='(rm|mv|cp|chmod|chown|mkdir|kill|pkill|systemctl|service|docker|podman|psql|sed[[:space:]]+-i|tee|apt|apt-get|dpkg|git|sh|bash)([[:space:]"'"'"'`;]|$)'
  regras_remotas=(
    "scp§${cmd}scp[[:space:]]§${cmd}scp[[:space:]]"
    "rsync para host remoto§${cmd}rsync[[:space:]][^;&|]*([[:space:]]${host}|rsync://)§${cmd}rsync[[:space:]]"
    "pipe para ssh§\\|[[:space:]]*(sudo[[:space:]]+)?ssh[[:space:]]§\\|[[:space:]]*(sudo[[:space:]]+)?ssh[[:space:]]"
    "docker save/load§${cmd}docker[[:space:]]+(image[[:space:]]+)?(save|load)([[:space:]]|\$)§${cmd}docker[[:space:]]+(image[[:space:]]+)?(save|load)"
    "ssh com comando que muda estado§${cmd}ssh[[:space:]][^;&|]*[[:space:]\"'\`;(]${mut}§${cmd}ssh[[:space:]]"
  )
  for r in "${regras_remotas[@]}"; do
    rotulo="${r%%§*}"; resto="${r#*§}"; cabeca_re="${resto##*§}"; detecta_re="${resto%§*}"
    # 1) o COMANDO tem de existir fora de string (corpo_j: strings esvaziadas) — senão uma regex ou
    #    um texto de ajuda que cita `| ssh` viraria achado; 2) o ARGUMENTO se lê com as strings (codigo_j).
    if grep -qE "$cabeca_re" <<< "$corpo_j" && grep -qE "$detecta_re" <<< "$codigo_j" && ! dispensado "$cabeca_re" "$f"; then
      erros+=("$nome: $rotulo — VETADO: deploy só do git, via ops (pisos 23/24 da engineering). A IA/script não copia artefato nem muda a VPS por SSH: peça a operação nomeada do ops. Exceção real (host descartável, fora de prd): \`# shell-ok: <motivo>\`")
    fi
  done

  # 2.12 curl|bash, source de caminho externo e sudo embutido — VETADO em piso.md §5 e §7
  re_curlbash='(curl|wget)[^;&]*\|[[:space:]]*(sudo[[:space:]]+(-[A-Za-z]+[[:space:]]+)*)?(env[[:space:]]+)?(ba|da|z)?sh([[:space:]]|$)'
  re_shcurl='(ba|da|z)?sh[[:space:]]+(-[a-z]+[[:space:]]+)*(<\(|-c[[:space:]]+"?\$\()[[:space:]]*(curl|wget)'
  if { grep -qE "$re_curlbash" <<< "$corpo_j" || grep -qE "$re_shcurl" <<< "$codigo_j"; } \
    && ! dispensado "$re_curlbash|$re_shcurl" "$f"; then
    erros+=("$nome: \`curl | bash\` dentro de script — VETADO (executa o que o servidor mandar, sem checksum). Baixe para \`mktemp\`, confira o hash e só então execute (instalador.md §4)")
  fi
  externos=""
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    v="${m##*\$}"; v="${v#\{}"; v="${v%%[^A-Za-z0-9_@*(]*}"
    if [[ "$v" =~ ^([0-9@*]|\(curl|\(wget)$ ]] || ! grep -qE "(^|[^A-Za-z0-9_])(local[[:space:]]+|readonly[[:space:]]+|declare[[:space:]]+(-[A-Za-z]+[[:space:]]+)?|export[[:space:]]+)*${v}=|read[[:space:]]+(-[A-Za-z]+[[:space:]]+)*([A-Za-z_]+[[:space:]]+)*${v}([[:space:]]|\$)|for[[:space:]]+${v}[[:space:]]" <<< "$codigo"; then
      externos="$externos \$$v"
    fi
  done < <(grep -oE '(^|[;&|(]|[[:space:]]then|[[:space:]]do)[[:space:]]*(source|\.)[[:space:]]+["'"'"']?\$(\{?[A-Za-z_][A-Za-z0-9_]*|[0-9@*]|\((curl|wget))' <<< "$codigo_j")
  if [ -n "$externos" ] && ! dispensado '(^|[;&|(]|[[:space:]]then|[[:space:]]do)[[:space:]]*(source|\.)[[:space:]]+["'"'"']?\$' "$f"; then
    erros+=("$nome: source de caminho externo (${externos# }) — executa código de terceiro (piso.md §5). Derive o caminho do diretório do próprio script, ou waiver \`# shell-ok: <motivo>\`")
  fi
  if grep -qE '(^|[;&|(]|[[:space:]]then|[[:space:]]do|[[:space:]]else|\$\()[[:space:]]*sudo[[:space:]]' <<< "$corpo_j" \
    && ! dispensado '(^|[;&|(]|[[:space:]]then|[[:space:]]do|[[:space:]]else|\$\()[[:space:]]*sudo[[:space:]]' "$f"; then
    erros+=("$nome: sudo embutido — VETADO em script que já pode rodar como root (piso.md §7): decida fora (\`[ \"\$(id -u)\" = 0 ] || exec sudo ...\` na entrada, uma vez) ou waiver \`# shell-ok: <motivo>\`")
  fi

  # 2.13 hook: exit 2 BLOQUEIA no Claude Code (piso.md §8)
  if [[ "$f" =~ hook ]] && grep -qE '(^|[;&|(]|then|else)[[:space:]]*exit 2([[:space:]]|$)' <<< "$codigo"; then
    avisos+=("$nome: hook com \`exit 2\` — no Claude Code exit 2 BLOQUEIA a ação e devolve o stderr ao agente. Use só se a intenção é bloquear; falha do próprio hook é outro código (piso.md §8)")
  fi
done

# ---------------------------------------------------------------- saída
for a in "${avisos[@]:-}"; do [ -n "$a" ] && echo "  ! $a" >&2; done
if [ "${#erros[@]}" -gt 0 ]; then
  echo "" >&2
  echo "✖ SHELL REPROVADO — ${#erros[@]} problema(s) em ${#arquivos[@]} arquivo(s):" >&2
  for e in "${erros[@]}"; do echo "  · $e" >&2; done
  echo "" >&2
  echo "  Script de shell é código de produção: roda como root, apaga diretório e decide deploy." >&2
  exit 1
fi
echo "✔ shell: ${#arquivos[@]} arquivo(s) no piso$(command -v shellcheck >/dev/null 2>&1 && echo ' (shellcheck limpo)' || echo ' — SEM shellcheck, cobertura reduzida')."
