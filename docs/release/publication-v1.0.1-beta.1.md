# Publicação — dirnav 1.0.1-beta.1 Windows x64

Data: 2026-11-11
Repositório oficial: `https://github.com/91wallace/dirnav`
Release: https://github.com/91wallace/dirnav/releases/tag/v1.0.1-beta.1

## Tag e commit

- Tag anotada: `v1.0.1-beta.1`.
- Commit apontado pela tag: `1555484e81f2248d7780757e8f449bd808cdc41d`.
- A branch F17 não foi enviada nem movida. O commit de release foi preparado em worktree isolada a partir do HEAD base `4dd9ad43476b8dbd662ed3c0377987ee4de41ff4`; somente a tag foi enviada.
- O workflow `Release & Publish` concluiu com sucesso: https://github.com/91wallace/dirnav/actions/runs/43083041620. Quality Gate passou; build Windows e jobs npm/AUR/Winget foram `skipped`. Nenhum ZIP foi recriado por CI.

## Release e assets

- Release pública: **Pre-release=true**, Draft=false.
- Assets anexados (exatamente dois):
  - `dirnav-1.0.1-beta.1-windows-x64.zip` — 7.551.830 bytes; SHA-256 `9fecce9624d1a81d448fe7060fcbded7a13acccff1862816e19bae31dd322077`.
  - `SHA256SUMS.txt` — 102 bytes; SHA-256 do arquivo `920631efd9eeb834a33723d11dc102f217a831726cf390b888ecf29793229bdf`.
- Ambos foram baixados anonimamente da release pública; hash do ZIP baixado e o conteúdo do checksum conferem com a cópia local aprovada.
- O archive público automático da tag também foi baixado anonimamente; contém `dirnav` com `__version__ = "1.0.1-beta.1"`.
- Proveniência e diferença source-only de lint estão em `docs/release/source-provenance-v1.0.1-beta.1.md` no commit da tag. O ZIP não foi reconstruído e não há alegação de reprodutibilidade byte a byte.

## Verificações

- Antes da publicação: `SHA256SUMS.txt` da beta, ZIP original e ZIP de entrega tinham o mesmo SHA-256 esperado.
- Regressões na árvore exata do commit: Ruff check **PASS**; Pytest/CMD **46 passed, 1 skipped**; PowerShell 5.1 **16/16**; PowerShell 7 **16/16**; Bash/instaladores em Git Bash **PASS**.
- O skip Python/CMD é WinError 206 na criação de caminho >260 caracteres. O limite de long paths continua conhecido.
- `ruff format --check` reportou que 3 arquivos seriam reformatados. Não altera a lógica, não integra o quality gate do workflow de tag e não bloqueou os testes funcionais; fica registrado como pendência de estilo.
- Scanner estático dos arquivos preparados não encontrou tokens/credenciais, chaves privadas, email pessoal Gmail, caminhos locais do desenvolvedor, recibos de auditoria ou artefatos temporários. O ZIP aprovado foi examinado sem extraí-lo ao disco: sem caminho local do desenvolvedor, token/chave ou endereço de email. A atribuição de copyright do LICENSE foi preservada.

## Avisos preservados

- Beta experimental somente Windows x64; não homologada para distribuição geral ou uso crítico.
- Homologação adversarial F15 entre contas não foi realizada; não há comprovação de resistência contra outra identidade padrão.
- Caminhos longos têm limitação reproduzida e não estão aprovados.
- Linux/macOS não homologados; Arch, Winget, npm e AUR não foram publicados.
- O proprietário relatou feedback externo positivo; nenhum relatório detalhado ou métrica foi criado ou inferido.
- Versão estável permanece **NO-GO**.
