# dirnav

Interactive directory and file navigation for the terminal, written in Python. The maintained code version is `1.0.0` and shares one core across Windows, Ubuntu, and Arch Linux; shell integrations and packages are platform-specific.

[Leia em português](README.md)

## Features

- Inline browsing with live filtering and a directory tree.
- Copy, move, and delete operations with confirmation and safeguards.
- Shell integration for CMD and PowerShell on Windows and Bash/Zsh on POSIX systems.
- Python implementation with no external runtime dependencies.

## Requirements

- Python 3.
- Windows: CMD, Windows PowerShell 5.1, or PowerShell 7.
- Ubuntu/Arch Linux: Bash or Zsh to change the current shell session's directory.

## Installation

### Windows

From a repository checkout, run in PowerShell:

```powershell
.\install.ps1
```

The installer configures launchers and the current user's shell profile. Restart the shell or reload the profile.

### Ubuntu

From a repository checkout, run:

```bash
bash ./install.sh
```

Installation is per-user under `~/.local/bin`; start a new shell or reload the Bash/Zsh profile.

### Arch Linux

```bash
cd packaging/arch
makepkg -si
dirnav --setup
```

The package does not modify personal profiles automatically. Run `dirnav --uninstall` to remove the integration before removing the package.

## Usage

```text
dirnav --help
dirnav --all
dirnav -a /path/to/folder
```

The configured shell command (`dn` by default) lets the selection update the current session's directory. `Enter` confirms a directory, `Tab` or `→` enters it, and `Esc` cancels. `F5`, `F6`, and `Del` start copy, move, and delete operations; run `dirnav --help` for all shortcuts.

## Development and tests

```bash
python -m pytest tests/ -v
ruff check dirnav dirnav_operations.py tests/
ruff format --check dirnav dirnav_operations.py tests/
bash ./tests/shell/test_bash.sh
bash ./tests/shell/test_installers.sh
```

PowerShell integration tests are in `tests/shell/Dirnav.Tests.ps1`. The CMD tests require Windows; the Zsh tests require Zsh.

## History

Documents under `docs/pilot/`, `docs/release/`, and `docs/security/` preserve the record of the earlier Windows `1.0.1-beta.1` distribution. That is not the current code version.

## License

MIT. See [LICENSE](LICENSE).
