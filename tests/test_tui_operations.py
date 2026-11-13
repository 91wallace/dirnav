import os
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DIRNAV_SCRIPT = PROJECT_ROOT / "dirnav"


def run_tui(tmp_path, keys):
    environment = os.environ.copy()
    environment["DIRNAV_TEST_KEYS"] = ",".join(keys)
    return subprocess.run(
        [sys.executable, str(DIRNAV_SCRIPT), str(tmp_path)],
        check=False,
        cwd=tmp_path,
        env=environment,
        capture_output=True,
        text=True,
        timeout=20,
    )


def test_tui_copies_selected_file_after_destination_and_confirmation(tmp_path):
    destination = tmp_path / "destino ç &"
    destination.mkdir()
    source = tmp_path / "origem !.txt"
    source.write_text("conteudo", encoding="utf-8")

    result = run_tui(
        tmp_path,
        ["F7", "o", "r", "i", "g", "e", "m", "F5", "RIGHT", "ENTER", "ENTER", "ESC"],
    )

    assert result.returncode == 0, result.stderr
    assert (destination / source.name).read_text(encoding="utf-8") == "conteudo"
    assert source.read_text(encoding="utf-8") == "conteudo"


def test_tui_moves_item_without_closing_after_operation(tmp_path):
    destination = tmp_path / "target"
    destination.mkdir()
    source = tmp_path / "move-me.txt"
    source.write_text("move", encoding="utf-8")

    result = run_tui(
        tmp_path,
        ["F7", "m", "o", "v", "e", "-", "m", "e", "F6", "RIGHT", "ENTER", "ENTER", "ESC"],
    )

    assert result.returncode == 0, result.stderr
    assert not source.exists()
    assert (destination / source.name).read_text(encoding="utf-8") == "move"


def test_tui_delete_escape_cancels_and_enter_confirms(tmp_path):
    source = tmp_path / "delete-me.txt"
    source.write_text("keep until confirmed", encoding="utf-8")

    cancelled = run_tui(tmp_path, ["F7", "d", "e", "l", "e", "t", "e", "-", "m", "e", "DELETE", "ESC"])
    assert cancelled.returncode == 0, cancelled.stderr
    assert source.read_text(encoding="utf-8") == "keep until confirmed"

    confirmed = run_tui(
        tmp_path, ["F7", "d", "e", "l", "e", "t", "e", "-", "m", "e", "DELETE", "ENTER", "ESC"]
    )
    assert confirmed.returncode == 0, confirmed.stderr
    assert not source.exists()


def test_tui_conflict_requires_explicit_replace_or_rename(tmp_path):
    source = tmp_path / "item.txt"
    source.write_text("source", encoding="utf-8")
    destination = tmp_path / "destination"
    destination.mkdir()
    existing = destination / source.name
    existing.write_text("existing", encoding="utf-8")

    cancelled = run_tui(
        tmp_path,
        ["F7", "i", "t", "e", "m", ".", "t", "x", "t", "F5", "RIGHT", "ENTER", "ESC"],
    )
    assert cancelled.returncode == 0, cancelled.stderr
    assert existing.read_text(encoding="utf-8") == "existing"

    renamed = run_tui(
        tmp_path,
        ["F7", "i", "t", "e", "m", ".", "t", "x", "t", "F5", "RIGHT", "ENTER", "R", "ENTER", "ESC"],
    )
    assert renamed.returncode == 0, renamed.stderr
    assert existing.read_text(encoding="utf-8") == "existing"
    assert (destination / "item (copy 1).txt").read_text(encoding="utf-8") == "source"


def test_tui_help_does_not_change_q_or_escape_navigation_semantics(tmp_path):
    (tmp_path / "quill").mkdir()
    result = run_tui(tmp_path, ["F1", "ESC"])

    assert result.returncode == 0
    assert "F5: copiar" in result.stderr


def test_question_mark_remains_search_text_not_help_shortcut(tmp_path):
    (tmp_path / "question-folder").mkdir()
    result = run_tui(tmp_path, ["?", "ESC"])

    assert result.returncode == 0
    assert "Ajuda do dirnav" not in result.stderr
