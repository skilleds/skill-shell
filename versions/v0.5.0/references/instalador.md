# O contrato do instalador — se adapta, e nunca culpa quem rodou

> Parte da skill **schematize-shell**. Instalador é a primeira coisa que o usuário roda e a que
> mais some da revisão. Este arquivo é o recorte da regra da casa **"prever macacos"**: software de
> massa **se adapta e nunca culpa o usuário**.

---

## 1. A regra

**O instalador descobre o ambiente e faz o certo sozinho.** Toda pergunta que ele faz é uma decisão
que ele não soube tomar; toda mensagem de erro que termina em "instale X e tente de novo" é trabalho
que ele empurrou para quem menos sabe fazê-lo.

Isso **não** significa adivinhar em silêncio: significa **detectar, decidir, dizer o que decidiu** —
e só parar quando parar é a única saída segura.

---

## 2. Detectar antes de exigir

- **Descubra o usuário real.** Rodando sob `sudo`, `$HOME` pode ser `/root` e `$USER` pode mentir:
  use `$SUDO_USER` quando existir e instale no `HOME` **dele**, não no do root. Arquivo do usuário
  criado com dono `root` é o bug que aparece três dias depois, como "permissão negada" em algo que
  nada tem a ver.
- **Descubra o gerenciador de pacotes** (`apt`/`dnf`/`pacman`/`apk`/`brew`) em vez de assumir
  `apt-get`. Não achou nenhum: diga **qual binário falta** e **como instalar em cada sistema comum**
  — não só "dependência ausente".
- **Descubra o shell e o arquivo de perfil certo** (`.bashrc`, `.zshrc`, `.profile`, `fish`) antes de
  escrever `PATH`. Escrever no arquivo errado é pior que não escrever: o usuário reinstala três
  vezes achando que falhou.
- **Descubra o que já existe.** Instalação anterior, versão antiga, arquivo de config do usuário:
  **preserve** o que é dele, atualize o que é seu, e diga qual dos dois aconteceu.
- **Descubra se tem permissão** — antes de fazer metade. Precisa de root e não tem? Diga **na
  primeira linha**, com o comando exato, e não depois de já ter criado três diretórios.

---

## 3. Falhar bem

- **Mensagem de erro = o que falhou · por quê · o que fazer agora.** Sem stack de shell, sem
  "erro inesperado", sem código sozinho.
- **Nunca culpe o usuário.** "Você não instalou o Node" é acusação e costuma ser mentira (ele pode
  ter Node noutro caminho, noutra versão, num gerenciador). "Preciso de Node ≥ 20; encontrei 18 em
  `/usr/bin/node`. Instale com `…` ou aponte `NODE_BIN`" é informação.
- **Falhe cedo e limpo:** valide tudo o que dá antes de escrever o primeiro byte. Instalador que
  aborta no meio deixa o sistema num estado que ninguém sabe descrever.
- **Reversível:** o que ele cria, ele sabe desfazer (`--uninstall`, ou pelo menos a lista do que foi
  escrito). Se não dá para desfazer, o cabeçalho avisa **antes**.
- **Idempotente** (`piso.md` §6): rodar de novo conserta, não duplica.

---

## 4. `curl | bash` — o que a casa faz e o que não faz

- **Publicar** um one-liner `curl … | bash` é aceitável para bootstrap **do lado de fora** (é a
  forma que o ecossistema usa), desde que: **HTTPS**, **URL sob domínio da casa**, o script seja
  **auditável no repo**, e a página diga **como baixar e ler antes** de executar.
- **VETADO usar `curl | bash` DENTRO de um script da casa** para trazer outra coisa: ali existe repo,
  versão e checksum, e o pipe joga fora os três. Baixe para arquivo temporário, **verifique
  checksum/assinatura**, e só então execute.
- **Todo script publicado assim tem `main "$@"` na última linha** (`qualidade.md` §4): download
  truncado não executa meio script.

---

## 5. Checklist do instalador

- [ ] Roda duas vezes seguidas e o resultado é o mesmo (idempotente).
- [ ] Sob `sudo`, escreve no `HOME` do **usuário real** e com o **dono certo**.
- [ ] Detecta gerenciador de pacotes e shell; não assume distribuição.
- [ ] Valida permissão e dependências **antes** de modificar qualquer coisa.
- [ ] Toda mensagem de erro diz **o que fazer agora**, e nenhuma culpa quem rodou.
- [ ] Preserva config do usuário; atualiza só o que é do pacote.
- [ ] Tem `--help` (sai `0`), `--dry-run` quando o efeito é grande, e caminho de desinstalação.
- [ ] `trap` limpa o temporário em `EXIT INT TERM`.
- [ ] Nenhum segredo em argumento de comando nem em log.
- [ ] Passa no `shellcheck --severity=warning` e no `scripts/check-shell.sh`.
