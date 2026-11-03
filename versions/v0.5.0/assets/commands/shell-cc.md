---
description: schematize-shell — context compact: grava o handoff no archive e roda /compact.
---
Antes de compactar, **grave o handoff** em `<projeto>/<projeto>_archive/context/` no par
o par **context + checklist** do padrão da `schematize-archive` (prefixo `AAAA-MM-DD-<slug>-`) (FEITO vs ABERTO), seguindo a
`schematize-archive`. Inclua: o que foi revisado/escrito de shell, os achados do
`scripts/check-shell.sh` que ficaram abertos, e as exceções de strict mode declaradas (com o motivo).
Só então rode `/compact`.
