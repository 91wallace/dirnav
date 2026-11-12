# Aceitação de risco residual — beta controlada Windows

## Decisão

O proprietário decidiu aceitar o risco residual da homologação adversarial cross-identity não executada para avançar somente a uma beta Windows controlada. A decisão foi registrada para esta transição a pedido expresso do proprietário em 2026-11-11.

## Escopo aceito

- Compartilhamento delimitado do ZIP Windows beta com avaliadores autorizados.
- Execução em ambientes de teste/controlados, com verificação do SHA-256 publicado na documentação do artefato.
- Uso dos wrappers CMD existentes, com a limitação de que a proteção cross-identity do batch temporário não foi provada por token adversarial real.

## Fora do escopo

- Aprovação definitiva de segurança Windows ou versão estável.
- Distribuição pública ampla, publicação automática em GitHub Releases, npm, Winget ou AUR.
- Alegação de que outra conta padrão não pode ler, editar, substituir, renomear ou excluir o batch.
- Homologação Linux/macOS, Bash/Zsh, UNC ou caminhos longos não suportados pelo host.

## Evidência e limitação

F15 registrou falhas ao iniciar autenticação adversarial, antes da execução do script sob a segunda identidade. Por isso os resultados de leitura, edição, substituição, exclusão, renomeação, criação e mudança de DACL/owner são **BLOCKED/NOT TESTED**, não negações de acesso. Os documentos e receipts F15 permanecem preservados em `docs/audit/`.

## Saída da aceitação

Esta aceitação deixa de bloquear exclusivamente a beta controlada descrita acima. A homologação adversarial real continua obrigatória antes da aprovação definitiva de segurança e da versão estável Windows. Qualquer evidência de que a segunda identidade consegue alterar/substituir/remover o batch invalida o GO e exige correção antes de continuidade.
