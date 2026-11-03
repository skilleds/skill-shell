---
description: Mapa da skill schematize-shell (o piso de shell da casa — script de shell é código de produção).
---
**schematize-shell** — o piso de shell da casa.

| Comando | O que faz |
|---|---|
| `/shell-help` | esta lista |
| `/shell-load` | carrega à força TODO o corpo normativo (piso, qualidade, instalador) e passa a aplicá-lo |
| `/shell-review` | revisa `.sh` contra o piso: roda `scripts/check-shell.sh` + `shellcheck` e lê o que a máquina não lê (idempotência, lógica, mensagem de erro) |
| `/shell-claude` | cria ou mescla o `CLAUDE.md` sempre-on de shell na raiz do repo |
| `/shell-cc` · `/shell-handoff` | context compact / handoff no archive |

Pareia com: `schematize-engineering` (o piso comum e o `ops.md`), `schematize-infra` (o que o script
provisiona), `schematize-qa` (teste de script com `bats`), `schematize-pentest` (injeção de comando
como achado).
