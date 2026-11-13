# TUI and file operations evolution

## Checkpoint and preservation

- Work started on 2026-11-12 in `C:\Users\criarte\projects\dirnav-ui-evolution`, branch `feature/tui-file-operations`, based on `stabilization/multiplatform-f17` at `2006802ddda2b198c6f806613a3820909f517e65`.
- The originally supplied `C:\Users\criarte\projects\dirnav` directory had Git objects but no usable `HEAD`, config, or working files. It was preserved without changes; work is isolated in the sibling checkout.
- The published tag `v1.0.1-beta.1` and ZIP were not changed or rebuilt. The new feature is unreleased and this branch has not been pushed.
- Python baseline before implementation: 46 passed, 1 skipped (Windows long-path creation failed with WinError 206).

## Implementation

- `dirnav` now lists directories and regular files, keeps existing Enter/Esc/Ctrl+C behavior, and keeps `q` as search text. F1 or `?` opens help.
- A bottom shortcut bar is reserved on each screen, adapted to narrow terminals, and redrawn through the existing render loop. Text clipping counts wide Unicode cells. Windows Console function keys and ANSI terminal sequences are decoded.
- F5 copies to a user-selected destination. The UI shows source/destination, requires confirmation, offers explicit replacement or a numbered name on conflict, and keeps the original. Copies stage in the destination, hash-verify content, and are removed from staging on ordinary errors/cancellation.
- F6 moves without intentional overwrite. Same-volume moves use the filesystem rename operation. On EXDEV/Windows cross-device errors it copies, verifies, then removes the source. If source removal fails, both recoverable copies remain and the error identifies them.
- Same-volume move uses no-replace semantics: Windows `os.rename`, Linux `renameat2(RENAME_NOREPLACE)`, Darwin `renamex_np(RENAME_EXCL)`, or exclusive hard-link/unlink fallback for non-directories. Directory moves fail closed if the OS has no native no-replace primitive.
- F8 always asks for confirmation and announces permanent deletion. Recursive deletion does not traverse symlinks or Windows junctions. Filesystem roots, the current directory, home, Python prefix, Windows system/program roots, and the navigator's current path are protected.
- Filesystem code lives in `dirnav_operations.py` and uses the Python standard library only. Shell commands are not constructed from file paths. Operation state, source identity, selected destination identity, conflict identity, and cancellation are checked before mutation where practical.
- PowerShell and POSIX installers now install/remove the managed module; the npm manifest includes it. The Arch recipe remains pinned to a source commit predating this module, so it is intentionally not changed into a broken recipe and must be updated with the eventual release commit and checksum. No package was built or published.

## Validation evidence

| Check | Result | Evidence |
|---|---|---|
| Python compile and Ruff | PASS | `py -3 -m compileall -q dirnav dirnav_operations.py tests`; `py -3 -m ruff check dirnav dirnav_operations.py tests/` reported “All checks passed”. |
| Focused operations, UI, and viewport tests | PASS | 39 passed, 1 skipped after no-replace move validation was added. |
| Windows PowerShell 5.1 integration suite | PASS | `tests/shell/Dirnav.Tests.ps1`: 19 passed, 0 failed, including F5 Unicode/ampersand copy and session location preservation. |
| PowerShell 7 integration suite | PASS | Same script: 19 passed, 0 failed. |
| Git Bash on Windows installer and Bash tests | PASS | `test_installers.sh` verified isolated install/remove and F5 copy to a path containing `&`/Unicode; `test_bash.sh` verified shell navigation, cancellation/status propagation. This is Git Bash/MSYS on Windows, not native Linux. |
| Real Windows CMD integration | PASS | Full `py -3 -m pytest -q -rs` run included the actual `cmd.exe` F5 copy case with a path containing `&` and Unicode; the test passed and verified source preservation and the calling session. |
| Full Python suite | PASS | `py -3 -m pytest -q -rs`: 86 passed, 2 skipped, 0 failed, 65.82s. |
| Junction deletion | BLOCKED on host | The Windows test attempted disposable junction creation but the host could not create one; it skipped rather than claiming coverage. |
| Windows long paths | BLOCKED on host | Existing test skipped because creating the path failed with WinError 206. |
| Linux/macOS/Zsh/Arch | NOT TESTED / BLOCKED | No native Linux/macOS, Zsh, or Arch/makepkg environment is available. Git Bash is not substituted for these platforms. The Arch source pin predates this unreleased module, so the package needs a release source revision containing the module before it can be built. |
| npm package dry-run | NOT TESTED | npm CLI is unavailable on this host. The Python manifest test confirms `dirnav_operations.py` is listed in `package.json`; no package archive was generated. |
| Cross-volume move | Unit simulation PASS; real volume NOT TESTED | EXDEV is simulated to test copy/verify/remove and preservation on cleanup failure. No second volume was available for native integration. |

## Known constraints and residual risks

- Copy replacement and recursive deletion still have unavoidable cross-platform check/use windows for path-based standard-library APIs. Snapshot checks narrow the window, but do not eliminate races against a hostile process that can modify the same parent directory.
- The no-replace move paths are unit-covered on this Windows host, but Linux `renameat2` and Darwin `renamex_np` were not executed here. On filesystems that reject those primitives, directory moves fail closed; file/link fallback depends on hard-link support.
- A cross-volume move is explicitly not atomic. On failure, dirnav retains and reports the verified destination and/or original instead of claiming success.
- F8 is permanent deletion; no platform trash API is used. Confirmation is mandatory.
- Recursive copying of junctions is rejected. Symlinks are copied as links and not traversed. Junction deletion test could not be completed on this host.
- Progress is available for file copies. Directory enumeration/hash verification may take time without per-entry progress; cancellation is checked between entries and copy blocks.
- Windows long-path behavior and native Linux/macOS behavior remain unverified. No stable release or publication approval is implied by this feature branch.

## Release state

This is an implementation checkpoint for review. It does not modify the approved `1.0.1-beta.1` artifact or tag. Do not publish a new release until the full suite passes, the package source is updated to include `dirnav_operations.py`, and native-platform/package checks required for the release scope have been completed.
