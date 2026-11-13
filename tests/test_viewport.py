import ctypes
import os
import re

import pytest


def strip_ansi(text):
    return re.sub(r"\x1b\[[0-9;]*[a-zA-Z]", "", text)


def test_viewport_invariant_when_scrolling_down_past_fifth_item(dirnav_module, tmp_path):
    """
    Testa especificamente o Bug Critico 0:
    Quando o usuario corre os diretorios para baixo (alem do 5o diretorio),
    aparece o indicador '↓ +X mais...' e '↑ +Y acima...'.
    O item selecionado NUNCA pode ser substituido ou ocultado pelo indicador inferior.
    """
    items = [f"folder_{i:02d}" for i in range(1, 21)]  # 20 pastas
    for item in items:
        (tmp_path / item).mkdir()
    max_lines = 8
    scroll_offset = 0

    for selected_idx in range(len(items)):
        lines, new_sel, scroll_offset = dirnav_module.build_ui_lines(
            current_path=str(tmp_path),
            items=items,
            selected_idx=selected_idx,
            scroll_offset=scroll_offset,
            max_lines=max_lines,
            term_columns=80,
            search_query="",
        )
        assert new_sel == selected_idx

        expected_folder_name = items[selected_idx]
        plain_lines = [strip_ansi(line) for line in lines]

        # Verifica se a pasta selecionada aparece na tela com o marcador '>'
        selected_lines = [
            line for line in plain_lines if f"> {expected_folder_name}/" in line
        ]
        assert len(selected_lines) == 1, (
            f"Falha no indice {selected_idx} ({expected_folder_name}): "
            f"item selecionado ficou invisivel! Linhas renderizadas:\n"
            + "\n".join(plain_lines)
        )


def test_viewport_invariant_scrolling_up_and_down_various_sizes(dirnav_module):
    """Garante a invariante em qualquer tamanho de terminal (max_lines de 3 a 12)."""
    items = [f"dir_{i:02d}" for i in range(15)]

    for max_lines in range(3, 12):
        scroll_offset = 0
        # Descendo ate o fim
        for idx in range(len(items)):
            sel, scroll_offset, avail, has_above, has_below = (
                dirnav_module.compute_viewport(
                    len(items), idx, scroll_offset, max_lines
                )
            )
            assert sel == idx
            assert scroll_offset <= sel < scroll_offset + avail, (
                f"Descendo: idx={idx} fora da janela [{scroll_offset}, {scroll_offset + avail}) com max_lines={max_lines}"
            )
            total_rendered = avail + (1 if has_above else 0) + (1 if has_below else 0)
            assert total_rendered <= max_lines

        # Subindo de volta ao topo
        for idx in reversed(range(len(items))):
            sel, scroll_offset, avail, has_above, has_below = (
                dirnav_module.compute_viewport(
                    len(items), idx, scroll_offset, max_lines
                )
            )
            assert sel == idx
            assert scroll_offset <= sel < scroll_offset + avail, (
                f"Subindo: idx={idx} fora da janela [{scroll_offset}, {scroll_offset + avail}) com max_lines={max_lines}"
            )


def test_viewport_empty_and_small_lists(dirnav_module):
    sel, off, avail, above, below = dirnav_module.compute_viewport(0, 0, 0, 8)
    assert (sel, off, above, below) == (0, 0, False, False)

    sel, off, avail, above, below = dirnav_module.compute_viewport(3, 2, 0, 8)
    assert (sel, off, avail, above, below) == (2, 0, 3, False, False)


def test_filesystem_control_characters_are_not_written_as_terminal_escapes(
    dirnav_module,
):
    lines, _, _ = dirnav_module.build_ui_lines(
        current_path="/tmp/\x1b[2J",
        items=["safe\x1b[31mNAME"],
        selected_idx=0,
        scroll_offset=0,
        max_lines=8,
        term_columns=80,
    )
    rendered = "\n".join(lines)
    assert "\x1b[2J" not in rendered
    assert "\x1b[31m" not in rendered
    assert "�" in rendered


def test_footer_stays_on_last_usable_row_without_overlapping_content(dirnav_module, tmp_path):
    (tmp_path / "folder").mkdir()
    (tmp_path / "readme.txt").write_text("read me", encoding="utf-8")
    lines, _, _ = dirnav_module.build_ui_lines(
        current_path=str(tmp_path),
        items=["folder", "readme.txt"],
        selected_idx=0,
        scroll_offset=0,
        max_lines=4,
        term_columns=80,
        footer_text=dirnav_module.build_footer(80),
    )

    layout = dirnav_module.layout_ui_lines(lines, terminal_rows=20)

    assert layout[-1].endswith("Esc:Voltar\033[0m")
    assert len(layout) == 19
    assert "folder/" in "\n".join(strip_ansi(line) for line in layout)
    assert "readme.txt" in "\n".join(strip_ansi(line) for line in layout)


def test_footer_truncates_in_narrow_terminal_and_updates_by_context(dirnav_module):
    navigation = dirnav_module.build_footer(14, "navigation")
    compact_navigation = dirnav_module.build_footer(40, "navigation")
    destination = dirnav_module.build_footer(14, "destination")
    help_footer = dirnav_module.build_footer(8, "help")

    assert len(navigation) <= 14
    assert len(destination) <= 14
    assert len(help_footer) <= 8
    assert navigation != destination
    assert navigation == "Del:Apagar"
    assert "F7:Exibir arq" in compact_navigation
    assert "F8:Arq ocultos" in compact_navigation
    assert "Del:Apagar" in compact_navigation
    full = dirnav_module.build_footer(120)
    for legend in (
        "F5:Cop",
        "F6:Mov",
        "F7:Exibir arquivos",
        "F8:Arquivos Ocultos",
        "Del:Apagar",
        "Esc:Voltar",
    ):
        assert legend in full
    file_mode = dirnav_module.build_footer(160, show_files=True)
    hidden_mode = dirnav_module.build_footer(180, show_files=True, show_hidden_files=True)
    assert "F7:Somente diretorios" in file_mode
    assert "F8:Ocultar arquivos do sistema" in hidden_mode


def test_unicode_cell_width_and_truncation_fit_terminal(dirnav_module):
    text = "中文文件abc"
    assert dirnav_module.terminal_cell_width("中文") == 4
    clipped = dirnav_module.truncate_text(text, 6)
    assert dirnav_module.terminal_cell_width(clipped) <= 6


def test_help_screen_lists_file_operations_and_existing_key_semantics(dirnav_module):
    lines = dirnav_module.build_help_lines(term_columns=120, terminal_rows=20)
    rendered = "\n".join(lines)

    assert "F5: copiar" in rendered
    assert "F6: mover" in rendered
    assert "F7: alternar entre arquivos e somente diretorios" in rendered
    assert "F8: exibir/ocultar arquivos ocultos ou do sistema" in rendered
    assert "Del: apagar" in rendered
    assert "Q nao encerra" in rendered
    assert "F1: mostrar/fechar ajuda" in rendered
    assert "Esc ou Ctrl+C: cancelar" in rendered


def test_small_terminal_layout_keeps_footer_and_bounds_rows(dirnav_module):
    lines = ["header", "one", "two", "footer"]
    for rows in range(1, 8):
        layout = dirnav_module.layout_ui_lines(lines, terminal_rows=rows)
        assert len(layout) <= max(1, rows - 1)
        assert layout[-1] == "footer"


def test_file_listing_preserves_directory_first_order(dirnav_module, tmp_path):
    (tmp_path / "z-directory").mkdir()
    (tmp_path / "a-directory").mkdir()
    (tmp_path / "a-file.txt").write_text("file", encoding="utf-8")

    assert dirnav_module.get_entries(str(tmp_path)) == [
        "a-directory",
        "z-directory",
    ]
    assert dirnav_module.get_entries(str(tmp_path), show_files=True) == [
        "a-directory",
        "z-directory",
        "a-file.txt",
    ]


def test_f8_lists_hidden_files_when_files_are_enabled_but_hides_hidden_directories(
    dirnav_module, tmp_path
):
    (tmp_path / "visible-directory").mkdir()
    (tmp_path / ".hidden-directory").mkdir()
    (tmp_path / "visible.txt").write_text("visible", encoding="utf-8")
    (tmp_path / ".hidden.txt").write_text("hidden", encoding="utf-8")

    assert dirnav_module.get_entries(str(tmp_path)) == ["visible-directory"]
    assert dirnav_module.get_entries(str(tmp_path), show_files=True) == [
        "visible-directory",
        "visible.txt",
    ]
    assert dirnav_module.get_entries(
        str(tmp_path), show_files=True, show_hidden_files=True
    ) == [
        "visible-directory",
        ".hidden.txt",
        "visible.txt",
    ]


@pytest.mark.skipif(os.name != "nt", reason="requires Windows hidden file attributes")
def test_f8_reads_windows_hidden_and_system_file_attributes(dirnav_module, tmp_path):
    hidden_file = tmp_path / "windows-hidden.txt"
    hidden_file.write_text("hidden", encoding="utf-8")
    kernel32 = ctypes.windll.kernel32
    kernel32.GetFileAttributesW.argtypes = (ctypes.c_wchar_p,)
    kernel32.GetFileAttributesW.restype = ctypes.c_uint32
    kernel32.SetFileAttributesW.argtypes = (ctypes.c_wchar_p, ctypes.c_uint32)
    kernel32.SetFileAttributesW.restype = ctypes.c_int
    original_attributes = kernel32.GetFileAttributesW(str(hidden_file))
    if original_attributes == 0xFFFFFFFF:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        for attribute in (0x2, 0x4):  # HIDDEN and SYSTEM
            if not kernel32.SetFileAttributesW(
                str(hidden_file), original_attributes | attribute
            ):
                raise ctypes.WinError(ctypes.get_last_error())
            assert "windows-hidden.txt" not in dirnav_module.get_entries(
                str(tmp_path), show_files=True
            )
            assert "windows-hidden.txt" in dirnav_module.get_entries(
                str(tmp_path), show_files=True, show_hidden_files=True
            )
    finally:
        if not kernel32.SetFileAttributesW(str(hidden_file), original_attributes):
            raise ctypes.WinError(ctypes.get_last_error())


def test_f7_and_f8_toggle_file_modes_and_preserve_selection(
    dirnav_module, tmp_path
):
    (tmp_path / "alpha").mkdir()
    (tmp_path / "visible.txt").write_text("visible", encoding="utf-8")
    (tmp_path / ".secret.txt").write_text("secret", encoding="utf-8")
    state = dirnav_module.NavigatorState(str(tmp_path))
    state.selected_idx = state.filtered_dirs.index("alpha")

    state.handle_key("F7")

    assert state.show_files
    assert "visible.txt" in state.filtered_dirs
    assert ".secret.txt" not in state.filtered_dirs
    assert state.filtered_dirs[state.selected_idx] == "alpha"
    assert "Arquivos exibidos" in state.status_message

    state.handle_key("F8")

    assert state.show_hidden_files
    assert ".secret.txt" in state.filtered_dirs
    assert state.filtered_dirs[state.selected_idx] == "alpha"
    assert "ocultos" in state.status_message

    state.handle_key("F7")

    assert not state.show_files
    assert state.filtered_dirs == ["alpha"]
