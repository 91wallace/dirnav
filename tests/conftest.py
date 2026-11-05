import importlib.machinery
import importlib.util
import os

import pytest


@pytest.fixture(scope="session")
def dirnav_module():
    """Carrega o script 'dirnav' (sem extensao .py) como modulo Python."""
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    script_path = os.path.join(root_dir, "dirnav")
    loader = importlib.machinery.SourceFileLoader("dirnav_mod", script_path)
    spec = importlib.util.spec_from_loader(loader.name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


@pytest.fixture
def sample_tree(tmp_path):
    """Cria uma arvore de diretorios para testes de navegacao, filtro e caracteres especiais."""
    dirs = [
        "alpha",
        "beta",
        "Configurações",
        "Documentos",
        "Pasta [2026]",
        "project-one",
        "project-two",
        "quill",
        ".hidden_folder",
    ]
    for d in dirs:
        p = tmp_path / d
        p.mkdir()

    # Subpastas dentro de project-one
    (tmp_path / "project-one" / "src").mkdir()
    (tmp_path / "project-one" / "tests").mkdir()

    # Arquivo comum (nao deve aparecer na lista de diretorios)
    (tmp_path / "README.txt").write_text("hello", encoding="utf-8")

    return tmp_path
