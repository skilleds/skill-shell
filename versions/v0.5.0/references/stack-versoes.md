# Anexo volátil — versões e ferramental (shell)

> Parte da skill **schematize-shell**. **Fonte volátil:** tudo aqui tem prazo de validade e é
> atualizado **à parte** do corpo normativo — que não crava número (o lint do catálogo, regra
> `anexo-volatil`, reprova quando crava).
>
> **Verificado em: 2026-10-14.** Cadência: revisão trimestral e antes de cada release da skill.

## Interpretadores

- **bash** — o alvo da casa. **bash 5.3** existe (jul/2025), mas a linha comum nas distros é a **5.2.x** (é a do Debian 13);
  não use recurso exclusivo da 5.3 (ex.: `${ cmd; }`, `GLOBSORT`) sem declarar a versão mínima. O **macOS ainda entrega bash 3.2** por licença (GPLv3), e é por isso que
  `declare -A`, `${var,,}` e `mapfile` não podem ser assumidos em script que roda lá.
- **dash** — o `/bin/sh` do Debian/Ubuntu. É o que executa seu script quando o shebang é
  `#!/bin/sh`; sem array, sem `[[ ]]`, sem `local` padronizado.
- **busybox ash** — o `sh` do Alpine, mais restrito ainda. Alvo obrigatório de teste para script que
  entra em imagem `FROM alpine`.

## Ferramental

| Ferramenta | Papel | Nota |
|---|---|---|
| **`shellcheck`** | análise estática | **o gate**; piso `--severity=warning`. versão fixada no CI <!-- reverificar --> |
| `shfmt` | formatação | `-i 2 -ci -bn`; roda com `--diff` no CI |
| `bats-core` | teste de script | quando o script tem lógica de verdade (parsing, decisão) |
| `checkbashisms` | bashismo sob shebang `sh` | complementa o `shellcheck --shell=sh` |

**Instalação do `shellcheck`** (pode faltar na máquina de dev): pacote da distro
(`apt install shellcheck`), binário estático do release oficial, ou imagem
`koalaman/shellcheck-alpine` no CI. O binário estático é o caminho mais previsível para CI e para
máquina de dev sem root.

## Regra que NÃO é volátil

O **piso** (`piso.md`) e o **gate** (`scripts/check-shell.sh`) valem independente da versão. Número
de versão muda; "nenhum script tem o modo de falha por acidente" não.
