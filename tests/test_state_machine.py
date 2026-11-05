import os


def test_enter_confirms_current_directory_instead_of_q(dirnav_module, sample_tree):
    """
    Requisito do usuario:
    Em vez de apertar 'q' para se manter no diretorio atual, deve alterar para Enter.
    """
    state = dirnav_module.NavigatorState(str(sample_tree))
    state.handle_key("\n")

    assert state.finished is True
    assert state.cancelled is False
    assert state.target_path == os.path.abspath(str(sample_tree))


def test_q_key_is_typed_into_search_and_does_not_exit(dirnav_module, sample_tree):
    """
    Requisito do usuario:
    O teclado fica liberado (incluindo 'q') para escrever o nome da pasta e resumir a lista.
    """
    state = dirnav_module.NavigatorState(str(sample_tree))
    state.handle_key("q")

    assert state.finished is False
    assert state.search_query == "q"
    assert state.filtered_dirs == ["quill"]

    # Pressionar Enter com filtro ativo seleciona a pasta filtrada
    state.handle_key("\n")
    assert state.finished is True
    assert state.target_path == os.path.join(os.path.abspath(str(sample_tree)), "quill")


def test_backspace_edits_search_without_going_up_directory(dirnav_module, sample_tree):
    """
    Bug Critico 2:
    Backspace deve apagar letra do filtro e NUNCA subir de diretorio.
    """
    state = dirnav_module.NavigatorState(str(sample_tree))
    initial_path = state.current_path

    for ch in "proj":
        state.handle_key(ch)
    assert state.search_query == "proj"
    assert state.filtered_dirs == ["project-one", "project-two"]

    state.handle_key("\b")
    assert state.search_query == "pro"
    assert state.current_path == initial_path

    # Mesmo se o filtro estiver vazio, Backspace nao deve subir para o diretorio pai
    for _ in range(5):
        state.handle_key("\b")
    assert state.search_query == ""
    assert state.current_path == initial_path


def test_right_and_left_arrows_navigate_hierarchy_and_clear_filter(
    dirnav_module, sample_tree
):
    state = dirnav_module.NavigatorState(str(sample_tree))

    # Filtra para 'project-one'
    for ch in "project-one":
        state.handle_key(ch)
    assert state.filtered_dirs == ["project-one"]

    # Seta Direita entra na pasta e limpa o filtro
    state.handle_key("RIGHT")
    assert state.current_path == os.path.join(
        os.path.abspath(str(sample_tree)), "project-one"
    )
    assert state.search_query == ""
    assert state.filtered_dirs == ["src", "tests"]

    # Seta Esquerda volta para a pasta pai
    state.handle_key("LEFT")
    assert state.current_path == os.path.abspath(str(sample_tree))


def test_esc_clears_search_first_then_cancels_on_second_press(
    dirnav_module, sample_tree
):
    state = dirnav_module.NavigatorState(str(sample_tree))
    state.handle_key("a")
    state.handle_key("l")
    assert state.search_query == "al"

    # Primeiro ESC limpa a pesquisa mas continua aberto
    state.handle_key("ESC")
    assert state.search_query == ""
    assert state.finished is False
    assert state.cancelled is False

    # Segundo ESC cancela e sai
    state.handle_key("ESC")
    assert state.finished is True
    assert state.cancelled is True


def test_navigation_keys_up_down_home_end_page(dirnav_module, sample_tree):
    state = dirnav_module.NavigatorState(str(sample_tree))
    total = len(state.filtered_dirs)
    assert total > 3

    state.handle_key("DOWN")
    assert state.selected_idx == 1

    state.handle_key("END")
    assert state.selected_idx == total - 1

    state.handle_key("HOME")
    assert state.selected_idx == 0

    state.handle_key("PAGEDOWN")
    assert state.selected_idx > 0

    state.handle_key("PAGEUP")
    assert state.selected_idx == 0

    state.handle_key("UP")
    assert state.selected_idx == 0
