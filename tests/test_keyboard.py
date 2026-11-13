from types import SimpleNamespace


def test_windows_function_key_codes_are_decoded(dirnav_module, monkeypatch):
    sequence = iter(("\x00", ";"))  # Windows Console F1 code 59.
    fake_console = SimpleNamespace(kbhit=lambda: True, getwch=lambda: next(sequence))
    monkeypatch.setattr(dirnav_module, "IS_WINDOWS", True)
    monkeypatch.setattr(dirnav_module, "msvcrt", fake_console, raising=False)

    assert dirnav_module.read_key(None, timeout=0) == "F1"


def test_windows_f5_f6_f8_codes_are_decoded(dirnav_module, monkeypatch):
    keys = []
    for code in ("?", "@", "B"):
        sequence = iter(("\xe0", code))
        fake_console = SimpleNamespace(
            kbhit=lambda: True, getwch=lambda keys=sequence: next(keys)
        )
        monkeypatch.setattr(dirnav_module, "IS_WINDOWS", True)
        monkeypatch.setattr(dirnav_module, "msvcrt", fake_console, raising=False)
        keys.append(dirnav_module.read_key(None, timeout=0))

    assert keys == ["F5", "F6", "F8"]


def test_posix_function_key_sequences_are_decoded(dirnav_module, monkeypatch):
    sequences = iter((b"\x1bOP", b"\x1b[15~", b"\x1b[17~", b"\x1b[19~"))
    pending = []

    def read_byte(_fd, _size):
        if not pending:
            pending.extend(bytes((byte,)) for byte in next(sequences))
        return pending.pop(0)

    def select_ready(_read, _write, _error, _timeout=None):
        return [1], [], []

    monkeypatch.setattr(dirnav_module, "IS_WINDOWS", False)
    monkeypatch.setattr(dirnav_module.os, "read", read_byte)
    monkeypatch.setattr(dirnav_module.select, "select", select_ready)

    assert [dirnav_module.read_key(1, timeout=0.1) for _ in range(4)] == [
        "F1",
        "F5",
        "F6",
        "F8",
    ]


def test_selected_file_enter_does_not_finish_directory_navigation(
    dirnav_module, tmp_path
):
    (tmp_path / "entry.txt").write_text("data", encoding="utf-8")
    state = dirnav_module.NavigatorState(str(tmp_path))
    state.selected_idx = state.filtered_dirs.index("entry.txt")

    state.handle_key("\n")

    assert not state.finished
    assert state.target_path is None
    assert state.status_message
