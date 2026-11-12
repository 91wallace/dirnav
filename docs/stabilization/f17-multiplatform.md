# Fase 17 — estabilização multiplataforma

Data: 2026-11-11
Branch de trabalho: `stabilization/multiplatform-f17`
Base: `4dd9ad43476b8dbd662ed3c0377987ee4de41ff4`

Esta linha é separada do piloto Windows. O piloto continua **PREPARED**, sem resultados externos. O ZIP beta aprovado foi preservado: `artifacts/beta/dirnav-1.0.1-beta.1-windows-x64.zip`, SHA-256 `9fecce9624d1a81d448fe7060fcbded7a13acccff1862816e19bae31dd322077`. Nenhum pacote foi publicado.

## Alterações desta fase

- `install.sh` e `uninstall.sh` agora se limitam ao usuário atual (`~/.local/bin` e blocos marcados nos perfis Bash/Zsh), recusam execução como root, não usam `sudo`, não modificam `/etc/profile.d` e não removem arquivos sem marcador de propriedade. Atalho é validado antes de escrita; fallback sem perfil preexistente escolhe `.zshrc` quando `$SHELL` indica Zsh.
- `tests/shell/test_installers.sh` cobre instalação isolada, repetição, atalho inválido sem gravação, fallback Zsh, integração com caminho contendo espaços/metacaracteres, cancelamento/erro e remoção delimitada. Foi executado em Git Bash no Windows.
- `tests/shell/test_zsh.zsh` e jobs CI Linux/macOS foram preparados; ainda não foram executados nesta sessão.
- PKGBUILD/.SRCINFO apontam para o commit de origem `4dd9ad43476b8dbd662ed3c0377987ee4de41ff4`, sem checksum `SKIP`; o SHA-256 do arquivo de origem é `38a5a14b3ae69c84358e961a4f93efa991e85e3c4dbb7a78f48992065bc62ef2`. O pacote não instala scripts em `/etc/profile.d`.
- O workflow não publica registros públicos em eventos de tag automaticamente. Publicação exige despacho manual explícito em tag estável correspondente e, para build estável, validação de receipt F15 com hash, identidade distinta e todas as tentativas reais de escrita aprovadas. O gate permanece fechado em `docs/security/windows-stable-release-approval.json`.
- O manifesto Winget continua rascunho: URL de release inexistente e hash zero são marcadores, não dados de pacote utilizável.

## Resultados e limites por plataforma

| Plataforma/critério | Estado | Evidência e limite |
|---|---|---|
| Git Bash no Windows | **PASS** | `bash -n`, `tests/shell/test_bash.sh` e `tests/shell/test_installers.sh`; Git Bash/MSYS não representa Linux/macOS. |
| Python/CMD regression | **PASS — 46 passed, 1 skipped** | `py -3 -m pytest -q -rs`; testes CMD usam `cmd.exe` real. Skip por WinError 206 ao criar o cenário >260 caracteres, antes da etapa CMD. |
| PowerShell 5.1 | **PASS — 16/16** | `powershell.exe -NoProfile -File tests/shell/Dirnav.Tests.ps1`, com diretórios/perfis temporários. |
| PowerShell 7 | **PASS — 16/16** | `pwsh.exe -NoProfile -File tests/shell/Dirnav.Tests.ps1`, com diretórios/perfis temporários. |
| Winget schema | **PASS estrutural** | `winget validate --manifest packaging/winget`; não comprova disponibilidade nem instalação. |
| Gate de publicação estável/F15 | **PASS — bloqueio fail-closed** | YAML dos workflows e AST PowerShell passaram; simulação local com receipt atual `BLOCKED` foi recusada antes de gravar output/publicar. |
| Bash Linux | **NOT TESTED** | Runner CI preparado, mas workflow remoto não executado nesta fase. |
| Zsh/macOS | **NOT TESTED** | Teste e runner preparados; `zsh` não está instalado localmente. |
| Linux/macOS em geral | **NOT HOMOLOGATED** | Sem execução real em host/runner nesta fase. |
| Arch build | **BLOCKED** | `makepkg` indisponível no host; job Arch CI preparado, não executado. Fonte e checksum foram baixados/calculados independentemente. |
| Winget | **BLOCKED** | `winget validate` valida estrutura local; `winget show --id 91wallace.dirnav --exact --source winget` não encontrou pacote. Asset estável e SHA real não existem. |
| Windows long paths | **FAIL / limitação reproduzida** | Com `LongPathsEnabled=0`, criação Python de caminho ~395 falhou; com prefixo Win32 estendido funcionou. CMD real rejeitou `cd /d \\?\C:\...` como UNC e manteve o diretório original. Configuração do sistema não foi alterada. |
| Piloto externo Windows | **NOT TESTED** | Nenhum resultado de avaliador externo recebido; permanece PREPARED. |
| F15 cross-identity | **BLOCKED / pendente para stable** | Nenhum teste adversarial real entre contas concluído; aceitação de risco da beta permanece restrita e inalterada. |
| ZIP beta aprovado | **PASS — preservado** | SHA-256 acima; não foi recriado nem modificado nesta fase. |
| Publicação | **NOT PUBLISHED** | Nenhum pacote enviado a npm, Winget, AUR ou release público. |

## Critérios de aprovação seguintes

1. Executar Bash/Linux e Bash/Zsh/macOS no CI ou em máquinas reais e anexar receipts completos.
2. Executar `makepkg` como usuário sem privilégios num ambiente Arch; comparar `.SRCINFO` gerado, instalar/remover em VM descartável e atualizar checksum/origem para um commit publicado que contenha as correções.
3. Só substituir placeholders Winget após existir release estável, ZIP publicado e SHA-256 conferido; validar e instalar/desinstalar em Windows limpo.
4. Resolver a limitação de caminho longo com desenho compatível com CMD ou declarar limites de suporte; testar com a política do Windows apropriada sem alterar a beta aprovada.
5. Receber os resultados externos do piloto, sem misturá-los com os testes locais.
6. Concluir a homologação adversarial F15 com segunda identidade padrão antes de aprovar segurança estável Windows.

**Decisão da Fase 17:** desenvolvimento e preparação multiplataforma em andamento. Não há homologação Linux/macOS, aprovação Arch/Winget, conclusão do piloto externo ou aprovação Windows estável.
