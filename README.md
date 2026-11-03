# schematize-shell

> **Script de shell é código de produção.** Ele roda como root no servidor, apaga diretório, decide
> deploy e é a primeira coisa que o usuário executa. Esta skill é o piso: strict mode **e o que ele
> não cobre**, quoting, `shellcheck` como gate que trava, `eval` vetado, exit code como contrato,
> `trap`/`mktemp`, idempotência, portabilidade — e o contrato do instalador que **se adapta e nunca
> culpa quem rodou**.

Pacote de **skill normativa para [Claude Code](https://claude.com/claude-code)**.
Parte do catálogo **schematize skills**.

## Por que ela existe

A vistoria de 2026-08-21 mediu o catálogo: **shell é a linguagem mais usada da casa** — instalador,
gate de CI, hook, ops, harness de teste — e era **a única sem skill, sem piso e sem gate**.
`shellcheck` sequer estava instalado. Uma linguagem sem piso não fica neutra: ela vira o lugar por
onde o piso das outras vaza.

## Instalar

### Pelo app schematize (recomendado)

```bash
schematize install shell    # requer o CLI schematize instalado
```

### Manual

```bash
git clone https://github.com/schematizeme/skill-shell.git /tmp/skill-shell
bash /tmp/skill-shell/install.sh .        # instala em .claude/ do projeto atual
```

## O que tem dentro

- **SKILL.md** — o contrato: 12 pisos inegociáveis + o mapa de references.
- **references/** — `piso` (strict mode e suas fugas, exit code, `trap`, `mktemp`, `eval`,
  idempotência), `qualidade` (aspas, `shellcheck`, bash vs POSIX, estrutura), `instalador` (o
  contrato do instalador), `stack-versoes` (anexo volátil com data de verificação).
- **scripts/** — `check-shell.sh`, o gate (com **waiver rastreável** `# shell-ok: <motivo>` e
  ignorando corpo de heredoc), e `check-shell.test.sh` (51 casos, com vermelho para cada regra).
- **assets/commands/** — `/shell-help`, `/shell-load`, `/shell-review`, `/shell-claude`,
  `/shell-cc`, `/shell-handoff`.
- **assets/CLAUDE.md** — regra sempre-on de shell para a raiz do repo.

## Comandos

| Comando | O que faz |
|---|---|
| `/shell-help` | lista os comandos |
| `/shell-load` | carrega o corpo normativo e passa a aplicá-lo |
| `/shell-review` | roda o gate + `shellcheck` e revisa o que a máquina não lê |
| `/shell-claude` | cria/mescla o `CLAUDE.md` sempre-on |
| `/shell-cc` · `/shell-handoff` | context compact / handoff no archive |

## Versão

**v0.4.0** — changelog em `CHANGELOG.md`.

## Regra de ouro

**Nenhum script tem o modo de falha por acidente.** Não é "todo script tem `set -euo pipefail`" — é
que, onde ele não tem, **está escrito por quê**.

MIT.
