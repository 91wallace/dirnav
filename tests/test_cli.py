import io
import json
import os


def test_write_output_exclusively_to_cwd_file_without_stdout_leak(
    dirnav_module, tmp_path
):
    """
    Bug Critico 1:
    Quando --cwd-file e fornecido, a saida deve ir EXCLUSIVAMENTE para o arquivo,
    sem vazar nada em stdout (mesmo que stdout nao seja um TTY).
    """
    cwd_file = tmp_path / "cwd.tmp"
    fake_stdout = io.StringIO()

    target = str(tmp_path / "Pasta [2026]")
    dirnav_module.write_output(target, str(cwd_file), stdout_stream=fake_stdout)

    assert cwd_file.read_text(encoding="utf-8") == os.path.normpath(
        os.path.abspath(target)
    )
    assert fake_stdout.getvalue() == ""


def test_write_output_to_stdout_when_no_cwd_file(dirnav_module, tmp_path):
    fake_stdout = io.StringIO()
    target = str(tmp_path)
    dirnav_module.write_output(target, None, stdout_stream=fake_stdout)

    assert fake_stdout.getvalue().strip() == os.path.normpath(os.path.abspath(target))


def test_parse_args(dirnav_module, sample_tree):
    cwd_file, start_path, action = dirnav_module.parse_args(
        ["dirnav", "--cwd-file=/tmp/out", str(sample_tree)]
    )
    assert cwd_file == "/tmp/out"
    assert start_path == os.path.abspath(str(sample_tree))
    assert action is None

    cwd_file2, start_path2, action2 = dirnav_module.parse_args(
        ["dirnav", "--cwd-file", "/tmp/out2"]
    )
    assert cwd_file2 == "/tmp/out2"
    assert start_path2 is None
    assert action2 is None

    _, _, action_ver = dirnav_module.parse_args(["dirnav", "--version"])
    assert action_ver == "version"

    _, _, action_setup = dirnav_module.parse_args(["dirnav", "--setup"])
    assert action_setup == "setup"

    _, _, action_uninst = dirnav_module.parse_args(["dirnav", "--uninstall"])
    assert action_uninst == "uninstall"


def test_setup_and_uninstall_shell_integration_idempotent(
    dirnav_module, tmp_path, monkeypatch
):
    """Testa --setup e --uninstall para garantir provisionamento limpo para NPM, Winget e Pacman."""
    prof1 = tmp_path / "prof1.ps1"
    prof2 = tmp_path / "prof2.ps1"
    prof1.write_text("# Config do usuario\n$x = 1\n", encoding="utf-8")

    monkeypatch.setenv("DIRNAV_TEST_PROFILE", f"{prof1}{os.pathsep}{prof2}")

    # 1. Setup inicial
    updated = dirnav_module.setup_shell_integration("dn")
    assert len(updated) == 2
    assert "# Dirnav shell integration" in prof1.read_text(encoding="utf-8")
    assert "# Dirnav shell integration" in prof2.read_text(encoding="utf-8")

    # 2. Setup repetido (idempotente)
    dirnav_module.setup_shell_integration("dn")
    content1 = prof1.read_text(encoding="utf-8")
    assert content1.count("# Dirnav shell integration") == 1
    assert "$x = 1" in content1

    # 3. Uninstall
    cleaned = dirnav_module.uninstall_shell_integration()
    assert len(cleaned) == 2
    after1 = prof1.read_text(encoding="utf-8")
    assert "# Dirnav shell integration" not in after1
    assert "$x = 1" in after1


def test_packaging_manifests_integrity():
    """Valida que os manifestos de NPM (package.json), Winget e Arch Linux (PKGBUILD) existem e sao validos."""
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

    # 1. NPM package.json
    pkg_json_path = os.path.join(root, "package.json")
    assert os.path.isfile(pkg_json_path)
    with open(pkg_json_path, encoding="utf-8") as f:
        pkg = json.load(f)
    assert pkg["name"] == "dirnav"
    assert "dirnav" in pkg["bin"]
    assert os.path.isfile(os.path.join(root, pkg["bin"]["dirnav"]))
    assert os.path.isfile(os.path.join(root, "bin", "postinstall.js"))
    assert os.path.isfile(os.path.join(root, "bin", "preuninstall.js"))

    # 2. Arch Linux PKGBUILD & .SRCINFO
    pkgbuild_path = os.path.join(root, "packaging", "arch", "PKGBUILD")
    srcinfo_path = os.path.join(root, "packaging", "arch", ".SRCINFO")
    assert os.path.isfile(pkgbuild_path)
    assert os.path.isfile(srcinfo_path)
    with open(pkgbuild_path, encoding="utf-8") as f:
        pb_content = f.read()
    assert "pkgname=dirnav" in pb_content
    assert "/etc/profile.d/dirnav.sh" in pb_content

    # 3. Winget Manifests
    winget_dir = os.path.join(root, "packaging", "winget")
    for fname in (
        "91wallace.dirnav.yaml",
        "91wallace.dirnav.installer.yaml",
        "91wallace.dirnav.locale.pt-BR.yaml",
    ):
        fpath = os.path.join(winget_dir, fname)
        assert os.path.isfile(fpath)
        with open(fpath, encoding="utf-8") as f:
            assert "PackageIdentifier: 91wallace.dirnav" in f.read()
