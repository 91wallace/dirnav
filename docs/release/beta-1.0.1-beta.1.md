# Beta controlada Windows — 1.0.1-beta.1

## Decisão de risco

O proprietário aprovou avançar para uma beta controlada Windows aceitando o risco residual de a homologação adversarial entre contas não ter sido executada. O registro F15 permanece intacto em `docs/audit/results/`; os resultados de autenticação bloqueada não são convertidos em testes aprovados.

**Escopo:** avaliação controlada do ZIP Windows por usuários autorizados, sem publicação automática e sem alegação de segurança cross-identity comprovada.

**Limitações:** a resistência do batch auxiliar contra uma segunda conta padrão continua desconhecida. A homologação adversarial real permanece obrigatória antes de aprovação definitiva de segurança e antes da versão estável Windows. A aceitação não cobre distribuição pública ampla, nem Linux/macOS.

## Artefato preparado

- `../../artifacts/beta/dirnav-1.0.1-beta.1-windows-x64.zip` (artefato local, fora do controle Git).
- `../../artifacts/beta/dirnav-1.0.1-beta.1.tgz` (pacote npm preparado para revisão interna; distribuição multiplataforma não aprovada).
- SHA-256: ver `../../artifacts/beta/SHA256SUMS.txt`.
- Conteúdo: `dirnav.exe`, `cc.cmd`, `dn.cmd`, `dirnav.cmd`, README e LICENSE.
- `dirnav.exe --version`: `dirnav 1.0.1-beta.1`.
- O wrapper `cc.cmd` foi executado por `cmd.exe` real; seleção com metacaracteres/Unicode e delayed expansion habilitada, cancelamento e limpeza passaram.

Esse ZIP foi construído localmente e não foi publicado. A distribuição via Winget é separada: o validador rejeitou aliases `.cmd`/`.bat`; o manifesto agora registra somente `dirnav.exe`. O fluxo Winget não dá suporte à navegação no CMD por alias, e o teste de instalação real pelo gerenciador não foi executado.

## Critérios de release

- Beta controlada: permitir somente compartilhamento direto do ZIP com grupo delimitado, com hash verificado e aviso explícito do risco F15.
- Não publicar automaticamente via GitHub Release, npm, AUR ou Winget. O workflow `workflow_dispatch` produz artefato de CI; jobs públicos requerem tag sem sufixo prerelease.
- Não anunciar segurança Windows plenamente homologada.
- Antes da versão estável: homologação adversarial real com segunda identidade padrão, regressões completas e validação do ciclo de instalação/atualização/remoção dos pacotes pertinentes.

## Matriz de prontidão

| Área | Estado | Evidência / limite |
|---|---|---|
| Funcionalidade Windows | **PASS para beta controlada** | Python 46 passed/1 skipped; CMD real validado; PowerShell 5.1 e 7, 16/16 cada; ZIP selecionou destino especial e cancelou sem mudar diretório. Skip long path: WinError 206. |
| Segurança Windows | **Risco aceito, não homologado** | Auditoria estática revisada; F15 cross-identity continua BLOCKED. Uso limitado à beta controlada. |
| ZIP Windows | **PASS local** | PyInstaller 6.22.3, execução `--version`, conteúdo e integração CMD real; hash acima. Não é assinatura Authenticode nem scan de distribuição. |
| Winget | **BLOCKED para distribuição beta** | Aliases `.cmd` e `.bat` rejeitados pelo `winget validate`; teste de instalação real não feito. Manifesto corrigido para aliases aceitos, mas URL/hash da beta publicada não existem. |
| npm | **PASS para empacotamento e ciclo Windows isolado; NO-GO multiplataforma** | Pacote local foi instalado, atualizado para beta e removido em prefixo isolado. A limpeza exige executar `dirnav --uninstall` antes de `npm uninstall`, porque npm 7+ não executa lifecycle de remoção. Bash/Zsh não testados. Sem publicação. |
| Arch/AUR | **BLOCKED** | `makepkg` indisponível; `sha256sums=('SKIP')`; URL da fonte/tag v1.0.0 respondeu 404. Sem build ou instalação local. |
| Bash/Zsh e Linux | **BLOCKED** | Bash, Zsh e makepkg indisponíveis neste host. |
| Publicação | **NOT PUBLISHED** | Nenhum registro público ou release foi atualizado. |

## Decisão

**GO limitado ao ZIP local para beta Windows controlada**, condicionado à distribuição direta e delimitada descrita acima. **NO-GO para Winget nesta beta, publicação pública ou distribuição Windows geral/estável.**

## Addendum F20 — publicação pública como pre-release

Em 2026-11-11, por autorização explícita do proprietário, a beta Windows x64 foi publicada como GitHub Pre-release em https://github.com/91wallace/dirnav/releases/tag/v1.0.1-beta.1. O ZIP aprovado não foi recriado; SHA-256, tag/commit, quality gate, assets e confirmação de download público estão registrados em `publication-v1.0.1-beta.1.md`. Nenhum outro pacote foi publicado. A publicação não altera os bloqueios Linux/macOS, F15 cross-identity, caminhos longos ou Windows estável.
