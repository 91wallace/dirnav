# Unreleased — estabilização e evolução da TUI

- Removido o atalho F8; arquivos ocultos/do sistema passam a ser incluídos somente com `--all` ou `-a`.
- Redimensionamento da TUI consulta as dimensões atuais do TTY para evitar layout duplicado após mudanças de viewport.
- Adicionadas cópia verificada, movimentação com fallback seguro entre volumes e exclusão recursiva confirmada, sem invocar shell.
- Operações de arquivo adicionadas à instalação Python, PowerShell, Bash e ao manifesto npm; nova versão ainda não publicada. A receita Arch permanece vinculada à origem anterior e precisa ser atualizada junto com o próximo commit/release.
- Testes de filesystem, operações, navegação, layout e integração dos shells foram ampliados; homologação nativa Linux/macOS e junctions depende dos resultados por ambiente.
- A evolução integrada de comandos, criação, snippets, visualizador Markdown e editor foi removida; a árvore aprimorada e navegação/arquivos foram mantidos.
- As barras persistentes de atalhos foram removidas da TUI; `--help` e `-h` listam os controles disponíveis.

## Fase 17 — estabilização multiplataforma

- Restringidos os instaladores POSIX ao usuário atual, com blocos de perfil marcados e remoção limitada a arquivos gerenciados.
- Preparados testes Bash/Zsh e CI Linux/macOS; homologação real dessas plataformas continua pendente.
- Corrigida a origem/checksum do recipe Arch e removida a instalação automática em `/etc/profile.d`.
- Publicação pública agora exige despacho manual explícito em tag estável correspondente.
- Investigada a limitação de caminhos longos do CMD; o host atual não suporta o caminho testado.

# Changelog

## 1.0.1-beta.1 — beta controlada (preparação)

- Mantém a navegação CMD por wrapper que aplica `cd /d` na sessão chamadora e usa os artefatos temporários protegidos da Fase 12.
- Impede publicação de versões beta pelo workflow de release; o disparo manual gera somente artefatos de CI.
- Valida a versão de release antes de usá-la, passa entradas do evento por variáveis de ambiente e sincroniza a versão do CLI Python antes de empacotar/publicar npm.
- Ajusta o manifesto Winget para usar apenas aliases executáveis aceitos pelo validador; wrappers CMD continuam distribuídos no ZIP para execução manual.
- Documenta a remoção manual da integração antes de `npm uninstall`, pois npm 7+ não executa lifecycle scripts de desinstalação.
- Aceita, apenas para esta beta controlada Windows, o risco residual da homologação adversarial entre contas não executada. Essa aceitação não comprova isolamento contra outra identidade e não libera a versão estável.

## 1.0.0

- Versão estável anterior. Consulte o histórico Git para alterações anteriores.
