# Changelog — schematize-shell

Todas as mudanças relevantes deste pacote, no formato [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
com versionamento [SemVer](https://semver.org/lang/pt-BR/).

## [0.5.0] — 2026-11-03

### Alterado (quebra de contrato do gate)
- `check-shell.sh` sai **`3`** (e não `2`) para "nada para verificar": em hook do Claude Code, exit 2 BLOQUEIA. `piso.md` §2, `SKILL.md`, `assets/CLAUDE.md` e `/shell-review` limitam 0/1/3 a verificadores/gates; `piso.md` ganha §8 "Hooks" (stdin JSON, exit 2 bloqueia, git hooks, teste).
- CI (`assets/ci/github-actions-ci.yml`): gatilho `workflow_dispatch` + tags `hml-*`/`v*` com `concurrency` e `paths-ignore` (piso 27; sem `pull_request`). Lista scripts por `git ls-files -z` incluindo os **sem extensão com shebang**; fim do `for t in $(...)` (word splitting) e do `bats ... || bats` que escondia erro.
- Herda os pisos 22–29 da engineering (bloco curto em `SKILL.md` e `assets/CLAUDE.md`).

### Adicionado
- Gate: **deploy só do git, via ops** (pisos 23/24) — ERRO para `scp`, `rsync` para host remoto, `| ssh`, `docker save/load` e `ssh host <comando mutável>`; waiver `# shell-ok: <motivo>`.
- Gate: `curl | bash`, `source` de caminho externo (posicional, ambiente, `curl`) e `sudo` embutido viram ERRO; script sem extensão com shebang entra na varredura; aviso para `exit 2` em script de hook.
- `piso.md` §9 (robustez de produção): `inherit_errexit`, `set -E`/`trap ERR`, `${var:?}`, `--`, `printf` vs `echo`, `command -v`, `flock`, `set -x` vazando segredo, `PATH`/`umask` em script root; `IFS` desencorajado; correção de que `-e` não é herdado por `$(...)`.
- 32 casos novos no teste (51 no total), cada um com vermelho antes do verde.

### Corrigido
- `rm -rf` sobre variável não validada agora **reprova** (antes só avisava, e um `${x:?}` qualquer calava o aviso); cobre `-fr`, `-r -f`, `-rf --`, `--recursive`; `${v:?}` só vale para a própria variável; variável de `mktemp` é aceita.
- As checagens de strict mode, `mktemp`, `trap` e `pipefail` olham o código (sem comentário nem heredoc): `trap`/`pipefail` citados em comentário ou heredoc não dão mais falso verde. `$#` e `${#x}` não são mais tratados como comentário.
- `README.md` e `/shell-review`: versão e contagem de casos.

### On-hold
- P2-14: `stack-versoes.md` mantém `shellcheck` sem versão fixada e a narrativa "shellcheck não instalado" (histórica) — reverificar com a doc oficial no próximo release.

## [0.4.0] — 2026-10-14
Description reduzida para o orçamento de listagem do catálogo; o gate de shell passa a respeitar o `.gitignore`.

### Alterado
- Description encurtada para ≤190 caracteres (catálogo estourou o orçamento de 9000 com 45 skills), mantendo O QUE + gatilho concreto + divisa com as irmãs.

### Corrigido
- `scripts/check-shell.sh`: arquivo ignorado pelo `.gitignore` do próprio repo (lançador gerado pelo app em `.schematize/overdev/`, artefato local) deixa de ser varrido; antes ele reprovava o gate do catálogo sem ser código do repo. Caso vermelho e verde no teste.

## [0.3.1] — 2026-10-14
Ressincronização dos blocos herdados com a engineering v0.27.0; sem mudança de piso próprio.

### Alterado
- Description reduzida (≤235 chars) para caber no orçamento de listagem de skills (soma ≤8300); mesmo território, fronteiras com as irmãs preservadas.
- Blocos herdados ressincronizados com a `schematize-engineering` v0.27.0 (`tools/sync-herdados.mjs`): orquestração com a regra de imagem (nunca pelo Claude; detecta Codex/Gemini e pergunta ao usuário qual usar, Codex como sugestão) e `schematize overdev delegar` (comando do app) no lugar do falso nome de skill `schematize-overdev`.

## [0.3.0] — 2026-10-14
Saneamento: description válida e ancorada nos artefatos, herança explícita da base e CI de referência — porque a skill não dizia o que herdava (nem qual era o papel dela no §2.2 de `linguagens.md`) e o instalador prometia hooks que não existem.

### Corrigido
- `description` em bloco `>-`, ≤350 caracteres, YAML válido, ancorada nos artefatos da linguagem.
- Seção "Precedência e herança": §28 archive, §35 DoD, §39 índice, IAM, efeito externo, orquestração herdados da base; papel ancorado em `schematize-engineering → references/linguagens.md` §2.2; QA/ops/IAM/índice vêm de `/eng-*` (`/eng-overdev`, `/eng-plan`, `/eng-scan`, `/eng-review`).
- `install.sh`: removido o trecho que copiava `assets/hooks` e mandava registrar `assets/settings.claude.example.json` — nenhum dos dois existe (mensagem enganosa).
- `shell-help`: `/shell-load` listava "(piso, plataforma)"; corrigido para os arquivos reais.

### Adicionado
- `assets/ci/github-actions-ci.yml` (actions pinadas por SHA) e arquivo de config do linter em `assets/lint/`; referenciados no SKILL.md.

### Atualizado
- Anexo volátil: bash 5.3 existe, 5.2 é a linha comum (Debian 13).
- **Description** reduzida (~270 chars) para caber no orçamento de listagem (soma das 31 skills ≤ 8500; o Claude Code corta a listagem acima disso).

### Alterado
- Bloco "Precedência e herança" passa a ser herdado da base (`schematize-engineering` → `assets/herdados/precedencia.md`), gerado por `tools/sync-herdados.mjs`; corpo sem mudança de conteúdo.

## [0.2.2] — 2026-09-30
O piso de orquestração passa a ser **herdado** da base em vez de copiado à mão: uma mudança na engineering não exige mais editar 38 arquivos.

### Alterado
- Piso "Orquestrador não desenvolve; subagent barato executa" em `assets/CLAUDE.md` e `SKILL.md` agora é um bloco `<!-- herdado:engineering/orquestracao:… -->`, sincronizado de `schematize-engineering/assets/herdados/orquestracao.md` por `tools/sync-herdados.mjs` (checado no CI). Redação normalizada; conteúdo inalterado.

### Mantido (piso inalterado)
- Sonnet por default, escada até opus, sem frota ociosa (engineering `references/orquestracao.md` §9/§9.6).

## [0.2.1] — 2026-09-30
Pedido do dono: agents idle poluem a tela e seguram recurso.

### Adicionado
- Piso de orquestração ganha a regra de frota ociosa (idle com pendência volta ao trabalho; dependente de outro agent → mata e enfileira com gatilho; terminou → mata); detalhe na `schematize-engineering` §9.6.

## [0.2.0] — 2026-09-30

Pedido do dono, por **custo**: o orquestrador não desenvolve; ação onerosa vira micro-tasks baratas; `sonnet` é o default dos subagents e `opus` só entra após falha.

### Adicionado
- **Piso "Orquestrador não desenvolve; subagent barato executa"** no `assets/CLAUDE.md` e no `SKILL.md`: o agent principal só planeja, despacha e revisa; ação onerosa vira micro-tasks para subagents em `sonnet` (falhou → o mesmo subagent corrige → re-decompõe → só então `opus`, com motivo). Detalhe na base: `schematize-engineering` → `references/orquestracao.md` §9.

### Mantido (piso inalterado)
- Todos os pisos anteriores e o gate de `scripts/` seguem exatamente como estavam; a mudança é só de orquestração, não de código.

## [0.1.0] — 2026-08-21

Primeira versão. A vistoria de 2026-08-21 mediu o catálogo e achou o buraco: **shell é a linguagem mais usada da casa** — instalador, gate de CI, hook, ops, harness de teste — e era **a única sem piso, sem skill e sem gate**; `shellcheck` sequer estava instalado na máquina, e a casa distribuía scripts sem strict mode dentro de outras skills, como andaime normativo.

### Adicionado
- **`references/piso.md`** — o piso executável. Strict mode **e o que ele NÃO cobre**, que é a parte que morde: `-e` não dispara dentro de condição (`if`, `&&`, `||`, `!`), não vê a última linha de função usada como condição, não pega comando dentro de `echo "$(...)"`, e **`local x=$(cmd)` mascara o status** (o `local` é o comando, e sai 0). Mais exit code como contrato (**`2` = não deu para verificar**, obrigatório), `trap` em `EXIT INT TERM`, `mktemp` (com o porquê: `/tmp` é mundialmente gravável, nome previsível é **symlink attack**, e `$$` não protege), **`eval` vetado** com o substituto (array + `case`), e idempotência.
- **As três exceções legítimas ao strict mode, e a regra que as governa:** biblioteca sourceada (onde `set -e` muda as opções do **shell do chamador**), coletor que precisa somar achados, harness de teste — válidas **quando declaradas em comentário**. *A regra real não é "todo script tem `set -euo pipefail`": é **nenhum script tem o modo de falha por acidente**.*
- **`references/qualidade.md`** — aspas e word splitting (com os dois exemplos que apagam arquivo errado), `"$@"` vs `$*`, `while IFS= read -r`, nunca parsear `ls`; **`shellcheck` como gate** (`--severity=warning`, silenciar só com motivo na linha, o que ele pega e **o que ele não pega**); e **bash vs POSIX** de verdade: `/bin/sh` é dash no Debian, busybox no Alpine, e o **macOS ainda traz bash 3.2**.
- **`references/instalador.md`** — o contrato do instalador que **se adapta e nunca culpa quem rodou**: descobrir o usuário real sob `sudo` (`$SUDO_USER`, senão o arquivo nasce com dono root), o gerenciador de pacotes, o arquivo de perfil certo, e o que já existe; falhar dizendo **o que fazer agora**; e a posição sobre `curl | bash` (aceitável para bootstrap externo, **VETADO dentro** de script da casa, onde há repo, versão e checksum).
- **`scripts/check-shell.sh`** — o gate, com **waiver rastreável**: `# shell-ok: <motivo>` na linha (ou na de cima) dispensa uma regra **exigindo a explicação** — o oposto de desligar o gate no CI, que some do código. Ele também **ignora corpo de heredoc** (heredoc é dado, não código) — regra que nasceu do próprio gate se acusando no primeiro run.
- **`scripts/check-shell.test.sh`** — **17 casos**, 12 vermelhos de propósito, com os fixtures em heredoc.
- **Ordem de limpeza do código antes de analisar:** tira **string primeiro, comentário depois**. O inverso quebra numa linha como `grep -qE '(eval|exec).*#\s*ok'` — o `#` dentro da string vira "comentário", a linha é truncada e sobra aspa órfã, fazendo a regra casar com **o próprio padrão que ela procura**. Descoberto quando este gate acusou o gate da `schematize-python`; tem caso vermelho próprio (`hash-dentro-de-string`).

### Corrigido durante a própria escrita (vale registro)
- A regra de strict mode aceitava a exceção por **palavra solta no cabeçalho** (*biblioteca*, *coletor*, *source*) — e um `source "$dir/lib.sh"` na linha 12 dava **passe livre a qualquer script que carregasse uma lib**. Trocado por **marcador explícito com motivo** (`# strict-ok: <motivo>`), que é `grep`-ável e auditável. *Gate que aceita por acidente é pior que gate ausente: ele produz um verde que ninguém confere.* O caso vermelho está no teste (`excecao-sem-marcador`).

### Medido nesta versão
- `shellcheck` **instalado** (0.11.0) e rodado sobre os **155 `.sh`** do catálogo: **0 erros e 0 avisos**.
- O gate próprio, rodado sobre o catálogo inteiro, achou e fechou **~50 casos reais**: coletores e harnesses sem exceção declarada, `mktemp` sem `trap`, `exit 0` incondicional no fim, e `bash -c` com string variável.
