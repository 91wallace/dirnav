def test_get_directories_excludes_hidden_and_files(dirnav_module, sample_tree):
    dirs = dirnav_module.get_directories(str(sample_tree))
    assert ".hidden_folder" not in dirs
    assert "README.txt" not in dirs
    assert "alpha" in dirs
    assert "Configurações" in dirs
    assert "Pasta [2026]" in dirs


def test_filter_case_insensitive_and_substring(dirnav_module):
    dirs = ["Alpha", "beta", "project-one", "project-two", "quill"]
    assert dirnav_module.filter_directories(dirs, "proj") == [
        "project-one",
        "project-two",
    ]
    assert dirnav_module.filter_directories(dirs, "ALPHA") == ["Alpha"]
    assert dirnav_module.filter_directories(dirs, "q") == ["quill"]


def test_filter_accent_insensitive(dirnav_module):
    dirs = ["Configurações", "Documentação", "Imagens"]
    # Usuario digita sem acento ou cedilha e encontra a pasta acentuada
    assert dirnav_module.filter_directories(dirs, "configuracoes") == ["Configurações"]
    assert dirnav_module.filter_directories(dirs, "configurações") == ["Configurações"]
    assert dirnav_module.filter_directories(dirs, "documentacao") == ["Documentação"]


def test_filter_no_match(dirnav_module):
    dirs = ["alpha", "beta"]
    assert dirnav_module.filter_directories(dirs, "xyz") == []
