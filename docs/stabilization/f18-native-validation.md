# Fase 18 — homologação nativa e integração

Data: 2026-11-11
Branch: `stabilization/multiplatform-f17`
HEAD: `4dd9ad43476b8dbd662ed3c0377987ee4de41ff4`
Estado geral: **BLOCKED para homologação nativa Linux/Arch**; testes locais Windows/Git Bash são evidência separada.

## Preservação

- ZIP beta `artifacts/beta/dirnav-1.0.1-beta.1-windows-x64.zip`: SHA-256 `9fecce9624d1a81d448fe7060fcbded7a13acccff1862816e19bae31dd322077`, conferido nesta fase. Nenhum rebuild ou alteração foi feito.
- `artifacts/beta/SHA256SUMS.txt`, recibos F15, aceitação de risco e estado do piloto foram preservados. O piloto continua **PREPARED**, sem resultados externos.
- A aprovação F15 para versão estável permanece **BLOCKED**; o arquivo `docs/security/windows-stable-release-approval.json` continua fechado.
- Nenhum pacote foi publicado e nenhum merge foi executado.

## Auditoria Git e proposta de commits

- Branch atual: `stabilization/multiplatform-f17`.
- `HEAD`, `main`, `origin/main` e `origin/HEAD` coincidem no commit `4dd9ad4`.
- Working tree: 21 arquivos rastreados modificados e novos documentos/scripts em `docs/` e `tests/`; nada staged. Só existe este worktree.
- As alterações não commitadas são herdadas de F15/F16/F17; a Fase 18 não alterou código de produção.

Separação recomendada, sem executar commits nesta fase:

1. **F15 — segurança/harness:** `dirnav` (helper Win32 da F12), `tests/security/`, receipts `docs/audit/results/`, documentação F15 em `docs/audit/`, `docs/security/release-risk-acceptance.md`, e hunks relacionados dos testes CMD/Python. Preservar os receipts BLOCKED sem reescrita.
2. **F16 — beta/piloto:** documentação `docs/pilot/`, `docs/release/`, artefatos e hashes beta, ajustes de npm/PowerShell e os hunks do README/workflow que tratam do ZIP beta e publicação delimitada.
3. **F17 — multiplataforma:** `install.sh`, `uninstall.sh`, `dirnav.sh`, packaging Arch/Winget, `tests/shell/test_installers.sh`, `test_zsh.zsh`, mudanças de CI, changelog e `docs/stabilization/f17-multiplatform.md`; incluir os hunks F17 mistos de README, workflow de release e `tests/test_cli.py` por staging interativo.
4. **F18 — validação:** este relatório e a atualização correspondente da matriz.

`README.md`, `.github/workflows/release.yml`, `tests/test_cli.py`, `tests/shell/Dirnav.Tests.ps1` e `dirnav` contêm trabalho de fases diferentes ou preexistente. Não devem ser adicionados integralmente a um único commit sem revisão por hunks. Não usei reset, clean ou staging em massa.

## Ambientes nativos

| Ambiente | Resultado | Evidência/limite |
|---|---|---|
| Oracle Linux via `ssh oracle-vm` | **BLOCKED** | `ssh -o BatchMode=yes -o ConnectTimeout=8 oracle-vm ...` falhou antes de autenticação: `Could not resolve hostname oracle-vm`. Nenhuma transferência, comando remoto ou alteração foi feita. |
| WSL/Linux local | **BLOCKED** | `wsl.exe --status` e `--list --quiet` informaram que o Subsistema do Windows para Linux não está instalado. Nenhuma instalação foi tentada. |
| Arch Linux | **BLOCKED** | Sem `makepkg`, Docker, Podman ou distro WSL. Oracle Linux não foi tratado como substituto de Arch. |
| macOS | **NOT TESTED** | Nenhum host/runner macOS executado nesta fase. |
| Zsh | **NOT TESTED** | `zsh` não disponível neste host. |
| Git Bash | **PASS — apenas Git Bash/MSYS no Windows** | Bash syntax, `test_bash.sh` e `test_installers.sh` executados em HOME temporário. Não equivale a Linux/macOS. |

## Arch, Windows e pacote beta

- `PKGBUILD` passou `bash -n`; `.SRCINFO` e recipe referem o mesmo commit/archive e SHA-256 `38a5a14b3ae69c84358e961a4f93efa991e85e3c4dbb7a78f48992065bc62ef2`. O arquivo baixado foi re-hashado e contém `dirnav`, `dirnav.sh`, `LICENSE` e `README.md` no diretório esperado.
- Isto valida a integridade e estrutura de origem, **não** substitui `makepkg`, instalação, atualização ou remoção em Arch. Nenhum pacote Arch foi construído.
- Winget schema local: **PASS estrutural**; disponibilidade do pacote continua **BLOCKED** (nenhum pacote/release asset/hash real).
- Limite de caminho longo CMD permanece conforme F17: criação comum >260 chars falha no host; CMD rejeita prefixo `\\?\`. Nenhuma configuração Windows ou beta foi alterada nesta fase.

## Regressões locais e estado

Os testes locais desta fase: Python/CMD **46 passed, 1 skipped**, Bash em Git Bash, instaladores Bash com HOME isolado, validação estrutural Winget, sintaxe Bash/PKGBUILD, consistência de checksum Arch, `git diff --check`. O skip é WinError 206 ao criar o cenário longo; não representa aprovação de long paths. PowerShell não foi modificado nesta fase; seus resultados F17 permanecem evidência histórica, não uma execução F18.

## Decisão por plataforma

- **Windows beta delimitada:** GO previamente aprovado para compartilhamento direto; F18 não altera essa decisão. O piloto externo continua PREPARED.
- **Windows stable:** **NO-GO** até homologação adversarial F15 real e regressões obrigatórias.
- **Git Bash/Windows:** testes disponíveis passaram; isso não confere certificação Linux.
- **Linux/Oracle:** **BLOCKED** até alias SSH resolvível e execução em Oracle Linux real.
- **Arch/AUR:** **BLOCKED** até build/instalação/remoção em Arch real.
- **macOS/Zsh:** **NOT TESTED**.
- **Winget:** **BLOCKED** até asset publicado com SHA verificável e instalação/remoção reais.

## Próxima retomada

Disponibilizar o alias/host `oracle-vm` no SSH config ou DNS e um ambiente Arch real (ou runner aprovado); executar e persistir os receipts antes de marcar qualquer homologação nativa como PASS. Para integração Git, revisar hunks mistos e criar commits pequenos F15 → F16 → F17 → F18 sem incluir artefatos temporários ou usar comandos destrutivos.
