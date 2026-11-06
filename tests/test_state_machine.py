import os


def test_enter_goes_directly_to_selected_directory(dirnav_module, sample_tree):
    """
    Novo requisito do usuario:
    Quando o usuario apertar Enter, o dirnav deve ir direto para o diretorio
    que o usuario estiver selecionado, evitando ter que entrar para depois se manter.
    """
    state = dirnav_module.NavigatorState(str(sample_tree))
    # Seleciona a segunda pasta da lista ('beta')
    state.handle_key("DOWN")
    selected_folder = state.filtered_dirs[state.selected_idx]
    assert selected_folder == "beta"

    state.handle_key("\n")

    assert state.finished is True
    assert state.cancelled is False
    assert state.target_path == os.path.join(
        os.path.abspath(str(sample_tree)), selected_folder
    )


def test_backspace_confirms_current_directory_when_search_is_empty(
    dirnav_module, sample_tree
):
    """
    Novo requisito do usuario:
    Em vez de Enter para se manter no diretorio atual, o usuario deve usar Backspace.
    """
    state = dirnav_module.NavigatorState(str(sample_tree))
    state.handle_key("\b")

    assert state.finished is True
    assert state.cancelled is False
    assert state.target_path == os.path.abspath(str(sample_tree))


def test_q_key_is_typed_into_search_and_enter_goes_to_filtered_dir(
    dirnav_module, sample_tree
):
    """
    O teclado fica liberado (incluindo 'q') para escrever o nome da pasta,
    e Enter vai direto para a pasta filtrada selecionada.
    """
    state = dirnav_module.NavigatorState(str(sample_tree))
    state.handle_key("q")

    assert state.finished is False
    assert state.search_query == "q"
    assert state.filtered_dirs == ["quill"]

    # Pressionar Enter vai para a pasta selecionada ('quill')
    state.handle_key("\n")
    assert state.finished is True
    assert state.target_path == os.path.join(os.path.abspath(str(sample_tree)), "quill")


def test_backspace_edits_search_first_then_confirms_current_dir_when_empty(
    dirnav_module, sample_tree
):
    """
    Quando ha texto digitado na pesquisa, Backspace apaga os caracteres;
    quando o filtro fica vazio, um novo Backspace confirma o diretorio atual.
    """
    state = dirnav_module.NavigatorState(str(sample_tree))
    initial_path = state.current_path

    for ch in "pr":
        state.handle_key(ch)
    assert state.search_query == "pr"
    assert state.filtered_dirs == ["project-one", "project-two"]

    # Apaga 'r' -> resta 'p'
    state.handle_key("\b")
    assert state.search_query == "p"
    assert state.finished is False

    # Apaga 'p' -> filtro fica vazio, mas ainda nao sai
    state.handle_key("\b")
    assert state.search_query == ""
    assert state.finished is False

    # Agora com filtro vazio, Backspace confirma o diretorio atual!
    state.handle_key("\b")
    assert state.finished is True
    assert state.cancelled is False
    assert state.target_path == initial_path


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


def test_esc_exits_immediately_without_any_changes(dirnav_module, sample_tree):
    """
    Novo requisito do usuario:
    O botao ESC sera para o usuario sair sem nenhuma alteracao (mesmo se tiver digitado filtro).
    """
    state = dirnav_module.NavigatorState(str(sample_tree))
    state.handle_key("a")
    state.handle_key("l")
    assert state.search_query == "al"

    # Primeiro ESC ja cancela e sai imediatamente sem nenhuma alteracao
    state.handle_key("ESC")
    assert state.finished is True
    assert state.cancelled is True
    assert state.target_path is None


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


def test_go_back_multiple_directories_and_press_backspace(dirnav_module, tmp_path):
    """
    Quando o usuario esta em um diretorio profundo, volta 1 ou mais diretorios
    para tras (LEFT) e aciona Backspace para se manter naquele diretorio,
    o target_path e o arquivo --cwd-file devem refletir o diretorio ancestral.
    """
    deep_path = tmp_path / "nivel1" / "nivel2" / "nivel3"
    deep_path.mkdir(parents=True)

    state = dirnav_module.NavigatorState(str(deep_path))
    assert state.current_path == os.path.abspath(str(deep_path))

    # Volta 2 diretorios para tras (nivel3 -> nivel2 -> nivel1)
    state.handle_key("LEFT")
    assert state.current_path == os.path.abspath(str(tmp_path / "nivel1" / "nivel2"))

    state.handle_key("LEFT")
    expected_ancestor = os.path.abspath(str(tmp_path / "nivel1"))
    assert state.current_path == expected_ancestor

    # Aciona Backspace para se manter em nivel1
    state.handle_key("\b")
    assert state.finished is True
    assert state.cancelled is False
    assert state.target_path == expected_ancestor

    # Grava no --cwd-file e verifica o conteudo exato
    cwd_file = tmp_path / "out_cwd.tmp"
    dirnav_module.write_output(state.target_path, str(cwd_file))
    assert cwd_file.read_text(encoding="utf-8") == os.path.normpath(expected_ancestor)
