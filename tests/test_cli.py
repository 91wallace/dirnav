import io
import json
import os
import re

import pytest


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


def test_write_output_reports_a_cwd_file_error(dirnav_module, tmp_path):
    target = tmp_path / "target"
    target.mkdir()
    assert not dirnav_module.write_output(str(target), str(tmp_path))


def test_cmd_output_refuses_to_replace_existing_batch(dirnav_module, monkeypatch):
    if os.name != "nt":
        pytest.skip("secure CMD directory requires Windows")
    nonce = dirnav_module.create_secure_cmd_temp_directory()
    directory = os.path.join(os.environ["USERPROFILE"], "dirnav-cmd-" + nonce)
    cwd_file = os.path.join(directory, "result.cmd")
    original = b"@echo off\r\necho DO_NOT_EXECUTE\r\n"
    with open(cwd_file, "xb") as batch:
        batch.write(original)
    try:
        assert not dirnav_module.write_output(str(directory), cwd_file, cmd_escape=True)
        with open(cwd_file, "rb") as batch:
            assert batch.read() == original
    finally:
        os.remove(cwd_file)
        os.rmdir(directory)


@pytest.mark.skipif(os.name != "nt", reason="secure CMD directory requires Windows APIs")
def test_secure_cmd_directory_and_batch_have_protected_dacls(dirnav_module):
    user_sid = dirnav_module._windows_current_user_sid(
        dirnav_module._win32_security_api()[0],
        dirnav_module._win32_security_api()[1],
        dirnav_module._win32_security_api()[3],
    )
    token = dirnav_module.create_secure_cmd_temp_directory()
    directory = os.path.join(os.environ["USERPROFILE"], "dirnav-cmd-" + token)
    batch_path = os.path.join(directory, "result.cmd")
    try:
        directory_aces = dirnav_module._windows_verify_artifact(
            *dirnav_module._win32_security_api()[:2],
            directory,
            user_sid,
            [
                (user_sid, 0x001F01FF, 0x03),
                ("S-1-5-18", 0x001F01FF, 0x03),
                ("S-1-5-32-544", 0x001F01FF, 0x03),
            ],
            True,
        )
        assert len(directory_aces) == 3
        assert dirnav_module.write_output(str(directory), batch_path, cmd_escape=True)
        file_aces = dirnav_module._windows_verify_artifact(
            *dirnav_module._win32_security_api()[:2],
            batch_path,
            user_sid,
            [
                (user_sid, 0x001F01FF, 0),
                ("S-1-5-18", 0x001F01FF, 0),
                ("S-1-5-32-544", 0x001F01FF, 0),
            ],
            False,
        )
        assert len(file_aces) == 3
    finally:
        if os.path.exists(batch_path):
            os.remove(batch_path)
        if os.path.isdir(directory):
            os.rmdir(directory)


@pytest.mark.skipif(os.name != "nt", reason="secure CMD directory requires Windows APIs")
def test_secure_cmd_directory_fails_closed_for_untrusted_parent(dirnav_module, tmp_path, monkeypatch):
    monkeypatch.setenv("USERPROFILE", str(tmp_path))
    with pytest.raises(OSError):
        dirnav_module.create_secure_cmd_temp_directory()
    assert not list(tmp_path.glob("dirnav-cmd-*"))


@pytest.mark.skipif(os.name != "nt", reason="secure CMD directory requires Windows APIs")
def test_secure_cmd_directory_fails_closed_when_descriptor_creation_fails(
    dirnav_module, monkeypatch
):
    monkeypatch.setattr(
        dirnav_module,
        "_windows_security_descriptor",
        lambda *_args: (_ for _ in ()).throw(OSError("injected descriptor failure")),
    )
    before = set(os.listdir(os.environ["USERPROFILE"]))
    with pytest.raises(OSError, match="injected descriptor failure"):
        dirnav_module.create_secure_cmd_temp_directory()
    assert set(os.listdir(os.environ["USERPROFILE"])) == before


def test_cmd_cwd_file_builds_quoted_batch_script(dirnav_module, tmp_path, monkeypatch):
    cwd_file = tmp_path / "cmd-cwd.tmp"
    target = tmp_path / "folder & ^ %PATH% !NAME! (unicode ç) 中文"
    captured = {}
    monkeypatch.setattr(
        dirnav_module,
        "_write_secure_cmd_batch",
        lambda path, script: captured.update(path=path, script=script),
    )
    monkeypatch.setenv("DIRNAV_CMD_CODEPAGE", "850")
    assert dirnav_module.write_output(str(target), str(cwd_file), cmd_escape=True)
    script = captured["script"]
    assert 'if "!DIRNAV_DELAYED_' in script
    assert 'setlocal DisableDelayedExpansion\r\nendlocal & cd /d "' in script
    assert "folder & ^ %%PATH%% !NAME! (unicode ç) 中文\"" in script
    assert "folder & ^^ %%PATH%% ^!NAME^! (unicode ç) 中文\"" in script
    assert "chcp 850 >nul" in script


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

    cmd_cwd_file, _, _ = dirnav_module.parse_args(
        ["dirnav", "--cmd-cwd-file", "/tmp/cmd-out"]
    )
    assert cmd_cwd_file == "/tmp/cmd-out"

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


def test_generated_posix_integration_preserves_command_status(dirnav_module):
    block = dirnav_module.get_posix_integration_block("dn")
    assert "command dirnav --cwd-file=\"$tmp\" \"$@\" || dirnav_status=$?" in block
    assert 'return "$dirnav_status"' in block


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
    assert "dirnav_operations.py" in pkg["files"]
    assert os.path.isfile(os.path.join(root, "dirnav_operations.py"))
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
    with open(srcinfo_path, encoding="utf-8") as f:
        srcinfo_content = f.read()
    assert "pkgname=dirnav" in pb_content
    assert "/etc/profile.d/dirnav.sh" not in pb_content
    pkgver = re.search(r"(?m)^pkgver=([0-9.]+)$", pb_content)
    commit = re.search(r"(?m)^_sourcecommit=([0-9a-f]{40})$", pb_content)
    checksum = re.search(r"(?m)^sha256sums=\('([0-9a-f]{64})'\)$", pb_content)
    assert pkgver and commit and checksum
    assert f"source = dirnav-{pkgver.group(1)}.tar.gz::https://github.com/91wallace/dirnav/archive/{commit.group(1)}.tar.gz" in srcinfo_content
    assert f"sha256sums = {checksum.group(1)}" in srcinfo_content
    assert "SKIP" not in srcinfo_content

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
