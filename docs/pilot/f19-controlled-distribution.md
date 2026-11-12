# Fase 19 — beta Windows controlada pronta para entrega

Estado: **READY_FOR_CONTROLLED_DISTRIBUTION**, condicionado à verificação de integridade no recebimento. Isto autoriza somente compartilhamento direto com avaliadores selecionados; não é publicação pública nem conclusão do piloto.

## Pasta final

`artifacts/controlled-delivery/dirnav-1.0.1-beta.1-windows-x64/`

Conteúdo: ZIP beta aprovado, `SHA256SUMS.txt`, aviso para avaliadores, instalação/remoção, guia completo, checklist e formulário voluntário de feedback.

## Integridade observada

- SHA-256 esperado: `9fecce9624d1a81d448fe7060fcbded7a13acccff1862816e19bae31dd322077`.
- Hash recalculado na origem `artifacts/beta/dirnav-1.0.1-beta.1-windows-x64.zip`: **igual**.
- Hash recalculado na cópia de entrega: **igual**.
- Hash listado no `SHA256SUMS.txt` de origem e no manifesto da pasta final: **igual**.
- O ZIP não foi recriado nem alterado. A cópia preserva os mesmos 7.551.830 bytes.

## Compartilhamento

1. Selecione manualmente apenas avaliadores Windows x64 autorizados.
2. Compartilhe a pasta final por canal direto e restrito; não envie a registro público.
3. Envie o valor SHA-256 acima também por um canal separado do pacote, para autenticar a soma recebida.
4. Peça ao avaliador que confira o hash antes de extrair/executar e use o checklist/formulário para devolver resultados voluntariamente.
5. Não atualize o estado do piloto até receber registros reais. Avaliadores que não executarem certo shell/cenário ficam como NOT TESTED.

## Limitações comunicadas

- Beta experimental somente Windows x64; não homologada para distribuição geral ou uso crítico.
- Caminhos longos: limite reproduzido no host de desenvolvimento; evitar caminhos profundos e reportar falhas.
- Homologação adversarial entre contas Windows não executada; segurança contra modificação por outra identidade padrão não está comprovada. A pendência F15 continua obrigatória para versão estável.
- Nenhum resultado externo foi recebido nesta fase; piloto permanece **PREPARED**.
- Linux/Arch, macOS/Zsh e Winget não estão incluídos neste piloto.

Sem publicação pública, instalação administrativa, merge ou push nesta fase.
