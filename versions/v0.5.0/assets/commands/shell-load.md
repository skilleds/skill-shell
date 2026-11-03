---
description: schematize-shell — carrega à força TODO o corpo normativo do piso de shell e passa a aplicá-lo nesta sessão.
---
Carregue **agora** o corpo normativo da skill `schematize-shell`. A partir daqui, nesta sessão, isto
**não é opcional**.

1. **Leia na íntegra, sem trabalhar de memória.** Caminho:
   `.claude/skills/schematize-shell/references/*.md` (projeto) ou
   `~/.claude/skills/schematize-shell/references/*.md` (global):
   - `piso.md` — strict mode **e o que ele não cobre** (`-e` não dispara em condição; `local x=$(cmd)`
     mascara status; job em background falha calado), exit code como contrato (**`2` = não deu para
     verificar**), `trap` em `EXIT INT TERM`, `mktemp` (symlink attack), **`eval` vetado**,
     idempotência.
   - `qualidade.md` — aspas e word splitting, `"$@"` vs `$*`, `while IFS= read -r`, nunca parsear
     `ls`; **`shellcheck` como gate** e como silenciar de forma rastreável; **bash vs POSIX** (dash,
     busybox, bash 3.2 do macOS).
   - `instalador.md` — o contrato do instalador que **se adapta e nunca culpa quem rodou**;
     `curl | bash` (o que a casa faz e o que não faz).
   - `stack-versoes.md` — anexo volátil: versões e ferramental, com data de verificação.
2. **Rode o gate no repo atual** antes de opinar sobre estilo:
   `bash .claude/skills/schematize-shell/scripts/check-shell.sh .`
3. **Aplique daqui em diante** a todo `.sh` que você escrever ou tocar, e diga qual piso está
   aplicando quando ele mudar o que você ia fazer.
