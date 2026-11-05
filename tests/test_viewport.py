import re


def strip_ansi(text):
    return re.sub(r"\x1b\[[0-9;]*[a-zA-Z]", "", text)


def test_viewport_invariant_when_scrolling_down_past_fifth_item(dirnav_module):
    """
    Testa especificamente o Bug Critico 0:
    Quando o usuario corre os diretorios para baixo (alem do 5o diretorio),
    aparece o indicador '↓ +X mais...' e '↑ +Y acima...'.
    O item selecionado NUNCA pode ser substituido ou ocultado pelo indicador inferior.
    """
    items = [f"folder_{i:02d}" for i in range(1, 21)]  # 20 pastas
    max_lines = 8
    scroll_offset = 0

    for selected_idx in range(len(items)):
        lines, new_sel, scroll_offset = dirnav_module.build_ui_lines(
            current_path="/root/test",
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
