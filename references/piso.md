# O piso do shell — o que todo script da casa tem, sem exceção

> Parte da skill **schematize-shell**. Este arquivo é o **piso executável**: o que o
> `scripts/check-shell.sh` cobra e o que reprova o merge. Quoting, `shellcheck` e portabilidade
> estão em `qualidade.md`; o contrato do instalador, em `instalador.md`.
>
> **Por que esta skill existe:** shell é a linguagem **mais usada da casa** — instalador, gate de
> CI, ops, hook, teste — e era a **única sem piso nenhum**. A vistoria de 2026-08-21 mediu: dezenas
> de scripts sem strict mode e **`shellcheck` sequer instalado** na máquina. Script de shell é
> código de produção: ele roda como root no servidor, apaga diretório e decide deploy.

Convenção: **MUST** = regra que o gate cobra · **VETADO** = piso.

---

## 1. Strict mode — e o que ele NÃO cobre

Todo script **executável** abre com:

```bash
#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true   # bash >= 4.4: o -e passa a valer dentro de $(...)
```

O que cada um faz, porque usar sem saber é como não usar:

| Flag | O que muda |
|---|---|
| `-e` | o script **aborta** no primeiro comando que sai != 0 |
| `-u` | usar variável **não definida** é erro (pega o typo em `$RESUTLADO` antes de ele virar string vazia) |
| `-o pipefail` | o **pipe** falha se **qualquer** estágio falhar, não só o último |
| `shopt -s inherit_errexit` | (bash >= 4.4) sem ele, o `-e` **não vale dentro de `$(...)`**: `x="$(false; echo ok)"` segue em frente. Declare-o logo após o `set` |
| `set -E` (ou `-o errtrace`) | o `trap ... ERR` passa a valer dentro de funções e subshells; sem ele, o `trap ERR` do topo não dispara onde a falha acontece |

`IFS=$'\n\t'` é **desencorajado** como boilerplate: mascara bug de quoting em vez de corrigi-lo e quebra
código que supõe o `IFS` padrão. Quote tudo e deixe o `IFS` em paz; mude-o só localmente
(`IFS=, read -r ...`), na própria linha.

**`pipefail` é o que mais importa e o mais esquecido:** sem ele,
`curl -f url | tar xz` **sai 0** quando o `curl` falha e o `tar` recebe vazio — você "instalou" nada
e o script seguiu feliz.

### O que o strict mode NÃO cobre (e é o que morde)

- **`-e` não dispara dentro de condição.** Em `if cmd; then`, `cmd && …`, `cmd || …`, `!cmd` e no
  meio de um `&&`, a falha é **esperada** e não aborta. Isso é o que faz o clássico
  `[ -f x ] && cp x y` no meio do script **não** parar quando o `cp` falha — só o último comando de
  um `&&` conta.
- **`-e` não vê a última linha de uma função usada em `if`.** A função inteira vira "condição".
- **`-e` não salva de comando **dentro** de substituição:** `resultado="$(comando_que_falha)"` aborta,
  mas `echo "$(comando_que_falha)"` **não** — o `echo` sai 0.
- **`local x=$(cmd)`** mascara o status: o `local` é o comando, e ele sai 0 mesmo com o `cmd`
  falhando. Declare e atribua em **duas linhas** quando o status importa.
- **`-u` não pega índice de array inexistente** em todas as versões, nem argumento posicional
  faltando quando você usa `${1:-}` (que é o certo — mas então **você** trata o vazio).
- **O `-e` NÃO é herdado por `$(...)` por padrão** (só com `shopt -s inherit_errexit`, bash >= 4.4),
  e nunca é herdado por job em background (`&`): ele falha em silêncio se ninguém der `wait` **e
  checar o status**. (Subshell `( ... )` herda; a substituição de comando é que não.)

**MUST:** onde a falha é aceitável, escreva-a **explicitamente** (`cmd || true`, com comentário
dizendo por quê). Falha silenciosa que o `-e` não pegou é o pior dos dois mundos: parece estrito e
não é.

### As exceções legítimas — e elas se declaram

- **Biblioteca para `source`** (ex.: `lib.sh`) **não liga strict mode**: `set -e` num arquivo
  sourceado muda as opções do **shell do chamador**, que é ação à distância. Quem liga é o script
  que a usa. O arquivo declara isso num comentário no topo.
- **Gate/coletor** que precisa **rodar tudo e somar** (um verificador que junta 12 achados) usa
  `set -uo pipefail` **sem `-e`** — senão ele aborta no primeiro achado e reporta um problema em vez
  de doze. Também se declara, com o motivo.
- **Harness de teste** que continua após um caso vermelho: mesma coisa.

O gate aceita as três **quando a exceção está declarada com marcador explícito** no cabeçalho:

```bash
# strict-ok: harness de teste — roda todos os casos e soma; com `-e` pararia no primeiro vermelho
set -uo pipefail
```

**Por que marcador e não "explicação em prosa":** a primeira versão desta regra procurava palavras
soltas no cabeçalho (*biblioteca*, *coletor*, *source*) — e um `source "$dir/lib.sh"` na linha 12
dava passe livre a **qualquer** script que carregasse uma lib. Gate que aceita por acidente é pior
que gate ausente: ele produz um verde que ninguém confere. O marcador exige o **motivo** junto
(`# strict-ok:` sozinho não vale), e é `grep`-ável — dá para auditar todas as exceções da casa numa
linha de comando.

A regra real da casa não é "todo script tem `set -euo pipefail`": é **nenhum script tem o modo de
falha por acidente**.

---

## 2. Exit code é contrato

- **`0` = sucesso. Qualquer outro = falhou**, e o número **significa alguma coisa** no seu script
  (documente no cabeçalho). O padrão da casa vale para **verificadores/gates** (script que olha
  outra coisa e dá veredito): **`0` passa · `1` reprova · `3` nada verificável**.
- **`3` para "não deu para verificar" é obrigatório** — devolver `0` quando o script não achou o que
  checar é a condição vacuamente verdadeira que este catálogo persegue em toda parte: o CI fica
  verde porque **nada foi olhado**.
- **Por que `3` e NÃO `2`:** `2` tem significado nos consumidores. Em **hook do Claude Code, exit 2
  BLOQUEIA a ação** e devolve o stderr ao agente; no `bash`, `2` é "uso errado de builtin"; em
  `grep`/`diff`, "erro de verdade". Um verificador que sai `2` por "nada a verificar" trava o agente
  quando é plugado como hook. **Hooks e scripts consumidos por outro programa NÃO seguem 0/1/3: seguem
  o contrato do consumidor (§8).**
- **VETADO** terminar com `exit 0` incondicional no fim do script ("para garantir"). Isso apaga o
  status de tudo o que veio antes.
- **Mensagem de erro vai para `stderr`**, resultado vai para `stdout`. Script cuja saída é consumida
  por outro (`$(...)`, pipe) **não** pode misturar log com dado.

---

## 3. Sinais e limpeza — `trap` que roda em todos os caminhos

```bash
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM
```

- **`EXIT` cobre o caminho normal e o `set -e`;** `INT` e `TERM` cobrem o Ctrl-C e o `kill` do
  orquestrador. Sem os três, o `Ctrl-C` deixa o diretório temporário para trás — e, num script que
  monta/desmonta ou trava lock, deixa o **sistema** num estado intermediário.
- **A limpeza tem de ser idempotente** (`rm -rf` em caminho que talvez não exista é ok; `umount` de
  algo já desmontado precisa de `|| true`), porque o `trap` pode rodar depois de uma falha parcial.
- **Nunca `trap ... EXIT` numa biblioteca sourceada** — você sequestra o `trap` do chamador.
- Script de longa duração que segura recurso (lock, mount, container) **também** trata `HUP`.

---

## 4. Arquivo temporário: `mktemp`, sempre

- **MUST:** `mktemp` / `mktemp -d` — nunca `/tmp/meuscript.$$`, nunca nome fixo.
- **Por quê:** nome previsível em `/tmp` (que é **mundialmente gravável**) é **symlink attack**: um
  usuário local cria antes um link de `/tmp/meuscript.123` para `/etc/passwd`, e o seu script,
  rodando como root, escreve lá. `$$` não protege — PID é previsível e reciclável.
- **MUST:** o diretório temporário sai no `trap` (§3). Diretório temporário abandonado em máquina de
  CI é lixo; em servidor, é disco cheio às 3h da manhã.
- Precisa de arquivo previsível para retomada? Então **não** é temporário: vai para o diretório de
  estado da aplicação, com dono e limpeza próprios.

---

## 5. `eval` — VETADO

- **VETADO `eval`**, `bash -c "$string"` montado com dado externo, e o "truque" de
  `cmd="rm -rf $dir"; $cmd` (que é `eval` com outro nome — a variável é re-dividida e re-expandida).
- **Por quê:** é injeção de comando, ponto. E o argumento "mas o dado vem de mim" é o mesmo que se
  diz do SQL antes de o cliente digitar aspas.
- **O que usar no lugar:** **array** para montar comando com partes variáveis —
  `args=(--porta "$porta"); comando "${args[@]}"` — e `case` para despachar por valor conhecido.
  Precisa mesmo de indireção? `${!nome}` (bash) resolve o nome da variável sem executar nada.
- Idem para `source "$arquivo_vindo_de_fora"`: é executar código de terceiro.

---

## 6. Idempotência — rodar duas vezes tem de dar o mesmo resultado

Script de ops/instalação é rodado de novo por definição (falhou no meio, alguém repetiu, o CI
reexecutou). O piso:

- **Criar:** `mkdir -p`, `ln -sfn`, `install -D`, `useradd ... || true` só com o teste antes
  (`id -u "$u" >/dev/null 2>&1 || useradd ...`).
- **Anexar a arquivo é o erro clássico:** `echo "export X=1" >> ~/.bashrc` rodado três vezes escreve
  três linhas. Use um **marcador** (`grep -qF "$linha" arquivo || echo "$linha" >> arquivo`) ou um
  bloco delimitado que você **substitui** inteiro.
- **Verifique antes de mudar** e **diga o que fez** ("já estava configurado" é uma saída válida e
  útil).
- **Destrutivo é explícito:** `rm -rf` só sobre caminho **construído e validado** (nunca
  `rm -rf "$dir/"*` com `$dir` possivelmente vazio — com `-u` isso vira erro, sem ele vira `/*`).
  O gate **reprova** `rm -rf` (também `-fr`, `-r -f`, `-rf --`, `--recursive`) sobre variável que não
  seja da forma `"${PROPRIA:?motivo}"` — o `:?` só protege a **própria** variável, não as outras —
  nem venha de `mktemp` no mesmo arquivo. Exceção real: waiver `# shell-ok: <motivo>`.

---

## 7. O que mais reprova, em uma lista

**VETADO**
- `set -e` ausente sem exceção declarada · `eval` · `curl | bash` dentro de script da casa ·
  `rm -rf` sobre variável não validada (o gate **reprova**) · nome fixo em `/tmp` · `cd` sem checar (`cd "$d" || exit`) ·
  parsear saída de `ls` · `[ $x = y ]` sem aspas · comparar string com `-eq` ·
  `sudo` embutido em script que já pode rodar como root (decida fora, não dentro) ·
  senha/token em argumento de comando (aparece em `ps`) ou ecoado em log.

**MUST**
- Cabeçalho dizendo **o que o script faz, o que ele muda no sistema e como desfazer** ·
  `usage()` quando aceita argumento · `--help` que sai `0` · toda variável entre aspas ·
  `"${array[@]}"` com as chaves e as aspas · `readonly` para o que não muda ·
  função pequena com nome de verbo · **shellcheck limpo** (`qualidade.md`).

---

## 8. Hooks — o contrato é do consumidor, não do piso 0/1/3

Hook é script chamado por **outro programa**, e quem manda no exit code e na entrada é ele.

**Hook do Claude Code** (`PreToolUse`, `PostToolUse`, `Stop`, `SessionStart`...):
- **Entrada: JSON no stdin** (nome da ferramenta, argumentos, `cwd`, ...). Leia com `jq`, nunca com
  regex: `input="$(cat)"; tool="$(jq -r '.tool_name // empty' <<< "$input")"`. Sem `jq`, falhe com
  mensagem clara — não siga com a entrada vazia.
- **Exit `0`** = segue (o stdout pode devolver JSON de decisão) · **exit `2` = BLOQUEIA** a ação, e o
  **stderr** vira a mensagem que o agente lê · **qualquer outro != 0** = erro **não bloqueante**
  (a ação segue; o usuário vê o erro). Consequência: hook que **quer bloquear** sai `2` com o
  motivo no stderr; hook que **quebrou** sai `1` e **não** pode usar `2` por acidente.
- **Não use o `3` "nada verificável" do §2 como se fosse bloqueio:** é não bloqueante aqui. Se
  "não consegui verificar" tem de bloquear (fail-closed), é **decisão explícita**: `exit 2` + mensagem.
- **Rápido e idempotente:** hook roda a cada ferramenta; sem rede, sem `sleep`, sem efeito colateral
  fora de `mktemp`/estado próprio. Segredo da entrada nunca vai para log nem para `set -x`.
- **Teste:** alimente o JSON por pipe (`printf '%s' "$json" | ./hook.sh; echo $?`) e afirme **exit e
  stderr** para os casos "permite", "bloqueia" e "entrada inválida" — no harness `*.test.sh` com `mktemp`.
- O gate avisa quando um script de hook contém `exit 2`, para que o bloqueio seja intencional.

**Git hooks** (`pre-commit`, `commit-msg`, `pre-push`):
- Exit **!= 0 aborta** a operação (`pre-commit`, `commit-msg`, `pre-push`); `0` segue. Aqui `1` é o
  normal de "reprovou" — o `3` do §2 também aborta, então "nada a verificar" num hook de git **tem**
  de sair `0` de propósito (não há o que bloquear), com uma linha no stderr.
- Entrada: `commit-msg` recebe o **caminho** do arquivo da mensagem em `$1`; `pre-push` recebe os
  `refs` no **stdin** (`local_ref local_sha remote_ref remote_sha`); `pre-commit` olha o índice
  (`git diff --cached --name-only -z`), não a árvore de trabalho.
- Versione o hook no repo (`scripts/` + `core.hooksPath`), nunca só em `.git/hooks` (não é clonado).
- `--no-verify` existe: o hook é a **primeira** barreira local; a que vale é a do gate que roda
  também em outro lugar (pisos 22/27 da engineering).

---

## 9. Robustez de produção — o que falta depois do strict mode

- **`${var:?motivo}`** para parâmetro obrigatório (`: "${DESTINO:?defina DESTINO}"`): aborta com
  mensagem, em vez de seguir com vazio. `${var:-padrão}` só quando o padrão é **seguro**.
- **`--` encerra opções:** `rm -- "$f"`, `grep -e "$padrao" -- "$arq"`, `cp -- "$a" "$b"`. Nome de
  arquivo começando com `-` vira flag (e `-rf` é um nome válido). Prefixe glob com `./` quando não
  puder usar `--`.
- **`printf` em vez de `echo`:** `echo "$x"` interpreta `-n`/`-e`, e `\n` varia entre shells. Dado
  vai em `printf '%s\n' "$x"`. `echo` fica para texto fixo sem `-`.
- **`command -v nome`**, nunca `which`: `which` não é POSIX, varia por distro e não sabe de função ou
  alias. Dependência ausente = erro com instrução ("instale X"), antes de começar a mudar coisa.
- **`flock` para exclusão mútua** (cron, deploy, instalador): `exec 9>"$lock"; flock -n 9 || { echo
  'já está rodando' >&2; exit 0; }`. `[ -e lock ] && exit` é corrida (check-then-act) e deixa lock
  órfão após kill -9. O arquivo de lock mora em diretório próprio, não em `/tmp` mundial.
- **`set -x` vaza segredo:** o trace imprime a linha **já expandida**, com senha e token, no
  stderr/log do CI. Nunca `set -x` global em script que toca segredo; localmente, `{ set +x; } 2>/dev/null`
  antes do comando sensível. Em CI, mascare o valor (`::add-mask::`) antes de qualquer trace.
- **Script que roda como root fixa o ambiente na entrada:** `PATH` explícito
  (`export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`) — `PATH` herdado pode
  trazer `.` ou diretório gravável por outro usuário; `umask 027` (ou `077` se mexe em segredo) —
  arquivo criado como root com `umask 000` nasce legível por todos; `unset` de variável perigosa
  herdada (`IFS`, `BASH_ENV`, `ENV`, `LD_PRELOAD`) quando vem de sudo/cron.
- **`trap ... ERR` com `set -E`** para dar contexto à falha ("linha N, comando X"): ajuda a
  diagnosticar, **não** substitui o `EXIT` de limpeza.

---

## 10. Deploy só do git, via ops (pisos 23 e 24 da engineering)

Shell é onde o deploy-por-cópia nasce. O gate **reprova**: `scp`; `rsync` para host remoto
(`host:/dir`, `rsync://`); qualquer `... | ssh host`; `docker save`/`docker load`; e
`ssh host '<comando que muda estado>'` (`rm`, `mv`, `cp`, `chmod`, `systemctl`, `docker`, `psql`,
`sed -i`, `tee`, `git`, `sh`/`bash`...). O artefato chega à máquina **pelo git** (pull no servidor ou
pipeline), e a mudança de estado é uma **operação nomeada do ops** — o script (e a IA) **pede**, não
executa. Também reprovam, por serem vetados no §7: `curl | bash`, `source` de caminho externo
(posicional, vindo do ambiente ou de `curl`) e `sudo` embutido.

Exceção real (host descartável de laboratório, fora de prd): **`# shell-ok: <motivo>`** na linha ou na
de cima — rastreável no diff e no `grep`.
