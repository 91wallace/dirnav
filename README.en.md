# dirnav

Interactive directory navigation for the terminal, written in Python. dirnav displays a filterable list of directories inline and lets you change the current location of your shell session.

[Leia em português](README.md) | [Windows 1.0.1-beta.1 release](https://github.com/91wallace/dirnav/releases/tag/v1.0.1-beta.1)

> **Release status:** `1.0.1-beta.1` is an experimental Windows x64 beta for selected evaluators. It is not a stable release and is not approved for general distribution or critical environments.

## Features

- Inline directory browsing without a full-screen interface.
- Live filtering of files and directories as you type.
- Responsive bottom shortcut bar and help with `?` or `F1`.
- Enter to select, navigation between directory levels, and Esc to cancel.
- `F5` copies the selected item to a chosen destination, with verification and explicit conflict handling.
- `F6` moves the selected item; cross-volume moves copy and verify before removing the source.
- `F8` requires confirmation before deletion. Directory deletion is recursive and permanent.
- Shell integration for changing the current location in CMD and PowerShell.
- Python implementation using the standard library, with no external runtime dependencies for the application.

In the TUI evolution branch, `q` remains search text and `Esc` cancels the current navigation or operation. The new interface and file operations are **not included** in the published `1.0.1-beta.1` ZIP; they are under development and require review before any new release.

See [docs/development/tui-file-operations.md](docs/development/tui-file-operations.md) for design decisions, security details, and validation status.

## Compatibility and validation status

| Environment | Status |
| --- | --- |
| Windows x64, CMD | Included in the beta; locally tested in real `cmd.exe`. |
| Windows PowerShell 5.1 and PowerShell 7 | Within the beta scope; temporary integration is documented. |
| Linux and macOS | Not homologated. |
| Bash and Zsh | In stabilization; Git Bash tests on Windows do not constitute Linux/macOS homologation. |
| Arch/AUR, Winget, and npm | Not part of the published Windows beta; do not install these as approved packages. |

The beta is not intended for critical environments. The owner reported positive external feedback, but this repository does not contain detailed reports or published metrics.

## Install the Windows beta

Download only the ZIP and `SHA256SUMS.txt` from the [1.0.1-beta.1 release](https://github.com/91wallace/dirnav/releases/tag/v1.0.1-beta.1). Verify the hash before extracting or running it:

```powershell
$Zip = Join-Path $HOME 'Downloads\dirnav-1.0.1-beta.1-windows-x64.zip'
$Expected = '9fecce9624d1a81d448fe7060fcbded7a13acccff1862816e19bae31dd322077'
$Actual = (Get-FileHash -LiteralPath $Zip -Algorithm SHA256).Hash.ToLowerInvariant()
if ($Actual -ne $Expected) { throw 'SHA-256 mismatch; do not run the package.' }
```

Extract the archive to a dedicated folder under your user account, for example `%LOCALAPPDATA%\DirnavPilot\1.0.1-beta.1`. To start navigation in CMD, use `call` in the same session:

```cmd
call "%LOCALAPPDATA%\DirnavPilot\1.0.1-beta.1\cc.cmd"
```

The [evaluation guide](docs/pilot/windows-beta-evaluation.md) provides CMD, Windows PowerShell 5.1, and PowerShell 7 instructions, along with a checklist for selection, cancellation, and metacharacter testing.

### Uninstall the Windows beta

Close the test sessions and remove only the dedicated folder you created for extraction, for example `%LOCALAPPDATA%\DirnavPilot\1.0.1-beta.1`. Verify the path before deleting it. The ZIP beta does not install services or require profile or PATH changes.

## Security and path limitations

- F15 adversarial testing with a second standard Windows identity was not performed. It has not been proven that another standard account cannot alter the temporary helper batch.
- Windows has a known limitation with long paths. Avoid deeply nested directory trees.
- Linux and macOS have not been homologated.
- The stable Windows release remains **NO-GO** until adversarial testing and outstanding security criteria are complete.

See the [F15 risk acceptance](docs/security/release-risk-acceptance.md), [release report](docs/release/publication-v1.0.1-beta.1.md), and [test matrix](docs/audit/test-matrix.md) for scope and available evidence.

## Development

Python 3 and `pytest` are required to run the Python tests; Ruff is used for linting.

```powershell
py -3 -m pytest -q -rs
py -3 -m ruff check dirnav tests/
```

Shell and installer tests are in `tests/shell/`. Consult the audit documentation before interpreting simulated tests as validation of a native operating system.

## Security reports and feedback

Do not include tokens, credentials, full profiles, personal paths, or temporary file contents in issues. Review diagnostics and remove sensitive information before sharing. The [pilot feedback template](docs/pilot/feedback-template.md) describes useful results without automatic data collection. dirnav does not send telemetry.

## License

Distributed under the [MIT License](LICENSE).
