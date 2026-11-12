# Arquitetura do dirnav

## Inventário inspecionado

- `dirnav`: CLI e núcleo Python em um único arquivo, sem dependências externas de runtime.
- `dirnav.ps1`: função `dn`, alias `cc`/`dirnav`, invocação do Python e mudança do diretório com `Set-Location -LiteralPath`.
- `dirnav.sh`: função de shell que cria um arquivo temporário, invoca `dirnav`, valida o caminho e usa `builtin cd`.
- `install.ps1` / `uninstall.ps1`: instalação Windows, criação dos launchers CMD, ajuste opcional de PATH e edição isolada de perfis PowerShell.
- `install.sh` / `uninstall.sh`: distribuição POSIX e edição de perfis Bash/Zsh; podem gravar em `/usr/local/bin` e `/etc/profile.d`.
- `bin/dirnav-cli.js`: trampoline npm que localiza Python 3 e inicia o núcleo. Os hooks npm chamam `--setup` e `--uninstall`.
- `packaging/arch` e `packaging/winget`: metadados de distribuição.
- `tests`: testes Python de CLI, filtro, estado e viewport; integração Bash e PowerShell. Foi adicionado `tests/shell/test_cmd.py` para `cmd.exe` real.

## Fluxo de execução

1. A UI enumera subdiretórios do caminho inicial e mantém seleção, filtro e viewport em `NavigatorState`.
2. Enter confirma a subpasta selecionada; Backspace confirma o diretório atual; Esc/Ctrl+C cancela.
3. O núcleo grava o destino em `--cwd-file` ou em stdout. A UI é enviada a stderr.
4. O wrapper que está rodando na sessão do usuário lê o destino e muda o diretório. Um processo Python filho não consegue alterar o diretório do shell pai.

PowerShell e Bash/Zsh usam funções de shell para manter o processo pai. CMD usa launchers batch gerados pelo `install.ps1`; Python cria um nonce criptográfico e um diretório exclusivo sob `%USERPROFILE%` com DACL protegida fornecida a `CreateDirectoryW` no ato da criação. O Python valida o parent, owner, bit de proteção e allowlist de ACEs; cria `result.cmd` com `CreateFileW(CREATE_NEW)` e DACL explícita protegida, grava e verifica novamente. O launcher executa esse batch na mesma instância CMD; ele detecta delayed expansion, aplica escaping literal e usa `cd /d`. O launcher limpa arquivo e diretório em retorno normal. A validação adversarial com uma segunda identidade continua pendente.

## Alternativas avaliadas para CMD

| Mecanismo | Diretório da sessão pai | Caminho literal/metacaracteres | Compatibilidade/risco | Decisão |
|---|---|---|---|---|
| Batch auxiliar chamado pela sessão | Sim: `cd /d` ocorre na instância original | Sim, com script estático por destino e escaping verificado nos dois estados de delayed expansion | Requer diretório temporário protegido contra gravação por outros principals; mantém dependências atuais | Manter, condicionado à DACL restritiva |
| Caminho em variável e `cd /d "%VAR%"` | Sim | Não robusto: expansão e parsing de `%`, `!`, `^`, `&` dependem do contexto; reproduziu falhas anteriores | Complexidade de parser e risco de injeção | Rejeitada |
| Comando inline via `call` | Sim | Dupla reinterpretação do CMD e escaping frágil | Mais risco de injeção e de delayed expansion que batch literal | Rejeitada |
| Python/PowerShell filho ou `cmd /c` | Não | Não aplicável | Processo filho não pode alterar o CWD do CMD pai | Rejeitada |
| `pushd`/mapeamento temporário | Sim | Continua exigindo entrega segura do caminho ao parser; adiciona estado de drive/mapeamento | Não resolve transporte; UNC altera semântica | Sem superioridade demonstrada |

Nenhuma alternativa testada elimina a necessidade de um comando executado no `cmd.exe` pai. O batch auxiliar continua sendo o mecanismo mais simples já validado funcionalmente; a homologação remanescente é a prova adversarial efetiva com outra identidade padrão.

## Hardening CMD implementado na Fase 12

Em `dirnav`, `create_secure_cmd_temp_directory()` obtém o SID do token, valida `%USERPROFILE%` e usa `CreateDirectoryW` com `SECURITY_ATTRIBUTES` e descriptor SDDL `O:<user>G:SYD:P(A;OICI;FA;;;<user>)(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)`. A DACL é protegida (`D:P`) desde a criação; somente usuário, SYSTEM e Administrators têm ACE explícita, com herança para descendentes. A inclusão de Administrators é para administração/recuperação; administradores podem tomar posse por privilégio. O diretório não é criado sob `%TEMP%`, cuja ACL não é modificada.

`_write_secure_cmd_batch()` valida o nonce e a ACL do diretório, chama `CreateFileW(CREATE_NEW)` com DACL protegida equivalente, sem compartilhamento, grava e faz flush; em seguida verifica owner, DACL, ACEs, flags e tipo do artefato antes de permitir o fluxo do launcher. Colisão, falha de segurança ou falha de validação aborta fechado. Testes locais verificaram DACL, proprietário, criação exclusiva e recusas de parent/API inseguros. Ainda falta comprovação adversarial de edição/substituição sob uma segunda identidade autorizada. Logo, a proteção ACL foi demonstrada estruturalmente neste host, mas resistência cross-identity e homologação Windows completa ainda não estão aprovadas.

## Harness adversarial externo preparado na Fase 15

`tests/security/Prepare-DirnavAdversarial.ps1` cria staging exclusivo em `%ProgramFiles%` com DACL explícita. Ele usa o Python existente e os helpers de segurança Fase 12 com `USERPROFILE` apontado temporariamente para uma raiz isolada. A raiz compartilhada permite apenas leitura/execução à conta padrão; o subdiretório e batches usam as DACLs protegidas exatas do transporte real. Os artefatos são descartáveis e as ACLs de produção não são alteradas.

`Invoke-DirnavAdversary.ps1` só prossegue sob SID designado e token não administrativo. Ele executa as tentativas reais e `AccessCheck` com o token corrente, reporta separadamente ancestrais, DACL do diretório e DACL de cada batch. `Test-DirnavOwnerRegression.ps1` repete Python/CMD/PowerShell; `Complete-DirnavAdversarial.ps1` salva JSON e aciona `Remove-DirnavAdversarialArtifacts.ps1`. A limpeza recusa caminhos/reparse points/itens desconhecidos, restaura descriptor apenas nos artefatos identificados e nunca remove contas ou perfis.

Os scripts passaram pelo parser PowerShell 7 e o módulo C#/smoke test de AccessCheck compilou e executou. Nenhum deles foi executado como segunda identidade nesta auditoria. O resultado da Fase 15 continua **BLOCKED/NOT TESTED** até execução manual autorizada.

### Revisão estrutural do harness (2026-11-08)

`Read-DirnavAuditManifest` valida a localização do manifesto antes de lê-lo; a validação comum confere schema, GUID, SID distintos, checkout esperado, caminhos derivados, lista exata de artefatos, hash/SDDL e ausência de reparse points no caminho. `Complete-DirnavAdversarial.ps1` constrói o relatório com variáveis inicializadas, cria a evidência com `CreateNew`, relê e valida a evidência, e só então chama `Remove-DirnavAdversarialArtifacts.ps1`. Não há cleanup em `finally`. O cleanup também valida manifesto, marcador e evidência final correspondente antes de remover conteúdo conhecido.

O rollback de preparação verifica que o diretório é o staging gerado para o `RunId`, valida o marcador se existir e só remove nomes reconhecidos; ocorrências inesperadas param a limpeza. Foram executados 14 testes de integridade do harness no Windows PowerShell 5.1 e PowerShell 7. Os scripts operacionais não foram invocados, portanto o estado permanece **PREPARED_FOR_EXTERNAL_REVIEW**, com a segurança cross-identity **BLOCKED/NOT TESTED**.

Na retomada de 2026-11-11, a preparação real com DACL protegida passou em dois runs e a limpeza foi concluída com receipts. A tentativa de executar o script pela conta padrão foi bloqueada/falhou antes do script (PS5.1 `0xC0000142`; PS7 Access denied `0x80131509`); nenhuma operação adversarial foi realizada. A comparação de DACL do cleanup foi ajustada para aceitar somente a flag `AI` mantendo ACEs/owner/proteção exatos; 16 testes do harness passaram em cada PowerShell. Regressões funcionais finais: Python 46/1 skip, CMD 18/1 skip, PS5.1 16/16 e PS7 16/16. Homologação global continua **BLOCKED**.

## Limites da auditoria

O host desta auditoria é Windows. `cmd.exe`, Windows PowerShell 5.1 e PowerShell 7 foram executados. Bash e Zsh não estão instalados, e `wsl.exe` confirmou ausência do WSL. Junctions e symlinks de diretório foram navegados em integração CMD real. Nenhum share UNC estava mapeado; teste por segunda identidade, criação de caminho acima de 260 (WinError 206), remoção concorrente, interrupção forçada, Windows Terminal/conhost com teclado físico e instaladores reais de sistema não foram homologados. Os testes de instalação PowerShell usaram diretório e perfil temporários.
