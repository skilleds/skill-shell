# Quoting, `shellcheck` e portabilidade — o que separa script de armadilha

> Parte da skill **schematize-shell**. O piso executável está em `piso.md`; aqui ficam as três
> coisas que fazem um script "que funciona na minha máquina" quebrar na do outro: **expansão sem
> aspas**, **falta de análise estática** e **suposição de bash onde só há `sh`**.

---

## 1. Aspas — a regra é sempre, e a exceção se declara

**Toda expansão vai entre aspas.** `"$var"`, `"$(cmd)"`, `"${array[@]}"`, `"$@"`. Sem aspas, o shell
faz **word splitting** (quebra por `IFS`) e **glob** (expande `*`, `?`, `[`), nessa ordem — e as
duas mordem em produção:

```bash
arquivo="meu relatorio.pdf"
rm $arquivo        # tenta apagar "meu" E "relatorio.pdf"  ← dois arquivos errados
rm "$arquivo"      # certo

dir="/dados/*"
rm -rf $dir        # o glob expande AQUI, e o -rf recebe cada item
rm -rf "$dir"      # não expande — falha limpo se o caminho não existe
```

Regras que caem sempre:

- **`"$@"` e `"${array[@]}"`, nunca `$*` nem `${array[*]}`** — o primeiro par preserva os elementos;
  o segundo junta tudo numa string só. Passar argumentos adiante é o caso nº 1.
- **Comparação:** `[ "$a" = "$b" ]` (com aspas, senão string vazia vira erro de sintaxe) — ou, em
  bash, `[[ $a == "$b" ]]`, que não faz splitting dentro. Use `-eq` **só para número**;
  `[ "$s" -eq 0 ]` com `$s` textual é erro.
- **Onde NÃO citar:** na direita de `=~` e nos padrões de `[[ ... == padrao* ]]`, onde a aspa
  transforma o padrão em literal. Isso é **exceção deliberada**, e merece o comentário.
- **`IFS`:** mudar `IFS` global é ação à distância. Prefira `while IFS= read -r linha; do` — o
  `IFS=` vazio preserva espaços da linha, e o `-r` impede que `\` vire escape (sem ele, um caminho
  do Windows some).
- **Nunca parseie `ls`.** Nome com espaço, quebra de linha ou `-` inicial quebra tudo. Use glob
  (`for f in ./*.log`) ou `find -print0` com `read -d ''`.

---

## 2. `shellcheck` — o gate, não a sugestão

**MUST:** `shellcheck` roda no CI sobre **todo** `.sh` do repo e **trava o merge**.

```bash
shellcheck --severity=warning --shell=bash scripts/*.sh   # o piso da casa
```

- **Severidade:** o piso é `warning` (inclui `error`). `info`/`style` entram quando o repo estiver
  limpo — subir a régua depois é fácil; começar impossível faz o time desligar o gate.
- **Silenciar é permitido — e é rastreável.** `# shellcheck disable=SC2086` vale **para a próxima
  linha**, com o **motivo escrito ao lado**. Um `disable` no topo do arquivo desliga o resto do
  arquivo inteiro e é o jeito mais comum de o gate virar enfeite.
- **Diretivas úteis:** `# shellcheck shell=bash` em arquivo sem shebang (biblioteca);
  `# shellcheck source=./lib.sh` para ele seguir o `source` e parar de reclamar do que vem de lá.
- **O que ele pega e vale ouro:** `SC2086` (expansão sem aspas), `SC2046` (word splitting no
  `$(...)`), `SC2115` (`rm -rf "$dir/"` com `$dir` possivelmente vazio), `SC2164` (`cd` sem `||`),
  `SC2181` (`$?` em vez de testar o comando), `SC2155` (`local x=$(cmd)` mascarando status).
- **O que ele NÃO pega:** lógica errada, idempotência, `eval` "justificado", falta de `trap`,
  segredo em argumento. Shellcheck limpo **não** é script revisado (`/shell-review`).

---

## 3. `bash` ou `sh` — decida, declare, e teste no que declarou

- **A casa escreve `bash`** por default: array, `[[ ]]`, `local`, `${var//x/y}` e process
  substitution valem a dependência. O shebang é **`#!/usr/bin/env bash`**, não `#!/bin/sh`.
- **`#!/bin/sh` significa POSIX**, e num Debian/Ubuntu `sh` é o **dash**: `[[ ]]`, array, `local`,
  `source` (use `.`), `${var^^}`, `+=` e `echo -e` **não existem** ou se comportam diferente. O erro
  clássico é escrever bashismo sob shebang `sh` — funciona na sua máquina (onde `sh` é bash), quebra
  no container mínimo.
- **Escreva POSIX quando o alvo exige:** script que roda em Alpine (busybox), em `initramfs`, em
  hook de sistema, ou embutido num Dockerfile `FROM alpine`. Aí **`shellcheck --shell=sh`** cobra a
  conformidade — e é ele que descobre o bashismo antes do container.
- **macOS ainda traz bash 3.2** (licença): `declare -A` (array associativo), `${var,,}` e `mapfile`
  **não existem** lá. Script que precisa rodar em Mac ou é POSIX, ou exige bash moderno
  **explicitamente** (checar `${BASH_VERSINFO[0]}` e falhar com mensagem clara é melhor do que
  quebrar com erro de sintaxe).
- **Não confie no `PATH`, nem nos utilitários:** BSD (macOS) e GNU (Linux) divergem em `sed -i`,
  `date`, `readlink -f`, `stat`, `find -printf`. Onde a diferença importa, detecte a variante ou use
  o subconjunto comum — e **teste nos dois** se você suporta os dois.

---

## 4. Estrutura — script que outra pessoa consegue ler

- **Cabeçalho** com: o que faz · o que muda no sistema · como desfazer · variáveis de ambiente que
  lê · exit codes.
- **`main()` no fim, funções antes**, e a última linha `main "$@"` — assim o script não executa
  metade de si mesmo se for truncado no download (o clássico do `curl | bash` mal feito).
- **Funções pequenas com nome de verbo** (`instalar_unit`, `checar_porta`); constantes em
  `readonly MAIUSCULO`; variável local **sempre** `local`.
- **Nada de lógica no nível superior** além de parsing de argumento e a chamada de `main`.
- **`usage()` + `--help` que sai `0`** — script sem `--help` é script que ninguém rerroda seis meses
  depois.
