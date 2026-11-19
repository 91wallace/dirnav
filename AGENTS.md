# Repository Guidelines

## Project Structure

`dirnav` is the main Python CLI implementation. Shell integration lives in `dirnav.sh` and `dirnav.ps1`; installation and removal scripts are `install.sh`, `install.ps1`, `uninstall.sh`, and `uninstall.ps1`. The npm entry points are in `bin/`. Tests are in `tests/`, with shell integration tests under `tests/shell/`. Release metadata and package recipes live in `packaging/` (`arch/` and `winget/`); CI workflows are in `.github/workflows/`.

## Build, Test, and Development

- `python -m pytest tests/ -v` runs the Python unit and state tests. `npm test` invokes pytest through the package script.
- `ruff check dirnav tests/` runs Python lint checks; `ruff format --check dirnav tests/` checks formatting.
- `bash ./tests/shell/test_bash.sh` runs Bash integration tests.
- `pwsh ./tests/shell/Dirnav.Tests.ps1` runs PowerShell integration tests where PowerShell 7 is available.
- Run the CLI locally with `python dirnav` or `./dirnav`; use `dn` after installing the shell integration.

## Coding Style

Keep the project dependency-free at runtime and compatible with its supported Python versions and operating systems. Follow the existing Python style and use Ruff for linting and formatting; use four spaces for Python indentation. Keep shell and PowerShell changes consistent with adjacent scripts, including cross-platform path and quoting behavior. Name Python tests `test_*.py` and group them by behavior.

## Testing Guidelines

Add or update focused tests in `tests/` for behavior changes. The pytest suite covers CLI behavior, search filtering, state transitions, and viewport rendering. Changes to shell integration should also run the relevant Bash or PowerShell integration suite. CI additionally checks Python formatting/lint and PowerShell syntax.

## Commits and Pull Requests

Recent history uses short, imperative, conventional-style subjects such as `feat(controls): ...`, `fix(windows): ...`, and `chore(packaging): ...`; use a type and optional scope when appropriate. A pull request should explain the user-visible change, note relevant platforms and tests run, and link related issues. Include terminal screenshots or sample output when they clarify a UI change. Keep packaging metadata and documentation aligned with behavior changes.

## Security and Configuration

Do not commit credentials, personal shell configuration, or generated release artifacts. Installer changes affect user shell profiles and `PATH`; keep edits scoped and preserve the corresponding uninstall behavior.
