# Piso de shell (schematize-shell) — sempre-on

Script de shell **é código de produção**: roda como root, apaga diretório e decide deploy.

1. **Strict mode, ou a exceção escrita.** `#!/usr/bin/env bash` + `set -euo pipefail` em todo script
   executável. Biblioteca sourceada, coletor e harness de teste podem não ter — **declarando o
   motivo em comentário**. Nenhum script tem o modo de falha por acidente.
2. **Saiba o que o `-e` NÃO pega:** dentro de `if`/`&&`/`||`/`!`, na última linha de função usada
   como condição, em `echo "$(cmd)"`, e em `local x=$(cmd)` (o `local` sai 0). Job em background
   falha calado sem `wait` + checagem.
3. **`shellcheck --severity=warning` trava o merge.** Silenciar exige `# shellcheck disable=SCxxxx`
   com motivo, na linha.
4. **VETADO `eval`** e `bash -c "$string"` com dado externo. Monte comando com **array**
   (`"${args[@]}"`) e despache com `case`.
5. **Exit code é contrato:** em gate, `0` passa · `1` reprova · **`3` = não deu para verificar**
   (nunca `2`: em hook do Claude Code, exit 2 bloqueia; hook segue o contrato do consumidor). Nunca
   `exit 0` incondicional no fim.
6. **`trap 'limpa' EXIT INT TERM`** sempre que criar temporário, montar ou travar lock. **`mktemp`**,
   nunca nome fixo em `/tmp` (symlink attack; `$$` não protege).
7. **Aspas em toda expansão**; `"$@"` e `"${array[@]}"`; `while IFS= read -r`; **nunca** parseie `ls`.
8. **Idempotente:** rodar duas vezes dá o mesmo resultado; anexar a arquivo exige marcador.
9. **Instalador se adapta e nunca culpa o usuário:** descobre o usuário real sob `sudo`, o
   gerenciador de pacotes e o shell; falha dizendo **o que fazer agora**.
10. **Segredo nunca em argumento** (aparece em `ps`) nem em log.
11. <!-- herdado:engineering/orquestracao:curto -->**Orquestrador não desenvolve; subagent barato executa.** O agent principal só planeja, despacha e revisa; ação onerosa vira micro-tasks para o executor mais barato que resolve: `haiku` (mecânico) / `sonnet` (código; falhou → mesmo subagent corrige, até 2 rodadas) → Codex `gpt-5.6-terra` → Cursor → subagent `opus` (motivo) → `park`; **visual vai direto ao Codex**; **imagem nunca pelo Claude: detectar Codex/Gemini e perguntar ao usuário qual usar (Codex é a sugestão), nunca API de imagem paga**; papéis em `agentes.toml`. No overdev, cada item do checklist vai a um subagent e o principal revisa antes do `- [x]`. **Sem frota ociosa:** idle com pendência volta ao trabalho; dependente de outro agent → mata e enfileira com gatilho; terminou → mata (§9.6). Detalhe: `schematize-engineering` → `references/orquestracao.md` §9.<!-- /herdado -->

12. **Deploy só do git, via ops:** sem `scp`/`rsync` remoto/`| ssh`/`docker save|load`/`ssh host <mutável>`;
    sem `curl | bash`, `source` externo, `sudo` embutido, `rm -rf $var` sem `${var:?}`.

<!-- herdado:engineering/pisos-22-29:bloco -->**Herda os pisos 22–29 da `schematize-engineering`** (texto completo em `assets/CLAUDE.md` dela): 22 tudo no git — sem remote, push falho ou HEAD≠origin a demanda NÃO se conclui; 23 deploy só do git (VETADO scp/rsync/tar|ssh/docker save|load/git bundle); 24 o ops é o gate da IA — a IA nunca muda a VPS direto nem escreve SQL, só operação nomeada (`ssh vps "ops <op>"`); 25 sem agents inúteis (entregou, morreu); 26 relatório a cada 30 min e handoff a cada 6 h; 27 CI remoto só antes do hml, a pedido ou em tag (`workflow_dispatch` + `hml-*`/`v*`; VETADO `pull_request`, `push` em branch, `workflow_run`, cron sem justificativa); 28 microserviço autônomo (fila durável + 7 testes de resiliência); 29 build/teste na máquina dev/hml quando existe (ponte só no workspace de build, nunca prd) + higiene (`scripts/higiene.sh`).<!-- /herdado -->

Gate: `bash .claude/skills/schematize-shell/scripts/check-shell.sh .` — waiver rastreável
`# shell-ok: <motivo>`.
