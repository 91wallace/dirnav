"""Real cmd.exe integration tests for the generated Windows launchers."""

import os
import shutil
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pytest


@pytest.mark.parametrize(
    ("keys", "bad_temp", "folder_name", "expected_relative", "expected_status", "delayed_expansion"),
    [
        ("ENTER", False, "selected folder [2026]", "selected folder [2026]", 0, False),
        ("ESC", False, "selected folder [2026]", "", 0, False),
        ("ENTER", True, "selected folder [2026]", "", 1, False),
        ("ENTER", False, "selected & echo CMD_INJECTED_MARKER", "selected & echo CMD_INJECTED_MARKER", 0, False),
        ("ENTER", False, "selected ^ folder", "selected ^ folder", 0, False),
        ("ENTER", False, "selected ^ folder", "selected ^ folder", 0, True),
        ("ENTER", False, "selected %PATH% folder", "selected %PATH% folder", 0, False),
        ("ENTER", False, "selected !DIRNAV_TEST_KEYS! folder", "selected !DIRNAV_TEST_KEYS! folder", 0, True),
        ("ENTER", False, "selected (parentheses) folder", "selected (parentheses) folder", 0, False),
        ("ENTER", False, "seleção 中文 folder", "seleção 中文 folder", 0, False),
        ("ENTER", False, "mix & ^ %PATH% !X! (unicode ç) 中文", "mix & ^ %PATH% !X! (unicode ç) 中文", 0, True),
        ("ENTER", False, "mix & ^ %PATH% !X! (unicode ç) 中文", "mix & ^ %PATH% !X! (unicode ç) 中文", 0, False),
    ],
)
@pytest.mark.skipif(os.name != "nt", reason="requires real Windows cmd.exe")
def test_cmd_launcher_selection_cancel_and_error(
    tmp_path, keys, bad_temp, folder_name, expected_relative, expected_status, delayed_expansion
):
    cmd = shutil.which("cmd.exe")
    powershell = shutil.which("pwsh") or shutil.which("powershell.exe")
    python = shutil.which("python.exe")
    if not cmd or not powershell or not python:
        pytest.skip("cmd.exe, PowerShell, or Python 3 is unavailable")

    project_root = Path(__file__).resolve().parents[2]
    install_dir = tmp_path / "installed"
    profile = tmp_path / "isolated profile.ps1"
    start_dir = tmp_path / "start"
    target_dir = start_dir / folder_name
    target_dir.mkdir(parents=True)

    env = os.environ.copy()
    env["DIRNAV_INSTALL_DIR"] = str(install_dir)
    env["DIRNAV_TEST_PROFILE"] = str(profile)
    env["DIRNAV_SKIP_PATH"] = "1"
    isolated_temp = tmp_path / "isolated temp"
    isolated_temp.mkdir()
    env["TEMP"] = str(isolated_temp)
    env["PATH"] = str(Path(python).parent) + os.pathsep + env.get("PATH", "")
    subprocess.run(
        [powershell, "-NoProfile", "-File", str(project_root / "install.ps1"), "-Shortcut", "dn", "-NonInteractive"],
        env=env,
        check=True,
        capture_output=True,
        text=True,
    )

    env["DIRNAV_TEST_KEYS"] = keys
    profile_root = Path(env["USERPROFILE"])
    secure_dirs_before = set(profile_root.glob("dirnav-cmd-*"))
    if bad_temp:
        blocked_profile = tmp_path / "profile-is-a-file"
        blocked_profile.write_text("blocked", encoding="utf-8")
        env["USERPROFILE"] = str(blocked_profile)
    launcher = install_dir / "dirnav.cmd"
    cwd_record = tmp_path / "observed-cwd.txt"
    runner = tmp_path / "run-cmd-session.cmd"
    runner.write_text(
        f'@echo off\r\nchcp 65001 >nul\r\ncd /d "{start_dir}"\r\n'
        f'call "{launcher}"\r\n'
        'set "LAUNCHER_EXIT=%ERRORLEVEL%"\r\n'
        f'cd > "{cwd_record}"\r\n'
        'exit /b %LAUNCHER_EXIT%\r\n',
        encoding="utf-8",
    )
    result = subprocess.run(
        [cmd, "/d", "/q", *( ["/v:on"] if delayed_expansion else []), "/c", "call", str(runner)],
        check=False,
        env=env,
        capture_output=True,
        text=True,
        errors="replace",
    )

    assert result.returncode == expected_status, result.stdout + result.stderr
    expected_dir = start_dir / expected_relative if expected_relative else start_dir
    assert cwd_record.read_text(encoding="utf-8").strip() == str(expected_dir)
    assert "CMD_INJECTED_MARKER" not in result.stdout
    assert set(profile_root.glob("dirnav-cmd-*")) == secure_dirs_before


@pytest.mark.skipif(os.name != "nt", reason="requires real Windows cmd.exe")
def test_cmd_launcher_changes_drive_with_cd_d(tmp_path):
    cmd = shutil.which("cmd.exe")
    subst = shutil.which("subst.exe")
    powershell = shutil.which("pwsh") or shutil.which("powershell.exe")
    python = shutil.which("python.exe")
    if not cmd or not subst or not powershell or not python:
        pytest.skip("cmd.exe, subst.exe, PowerShell, or Python 3 is unavailable")

    drive = next(
        (f"{letter}:" for letter in "ZYXWVUTSRQPONMLKJIHGFED" if not os.path.exists(f"{letter}:\\")),
        None,
    )
    if not drive:
        pytest.skip("no unused drive letter is available for subst")

    root = tmp_path / "mapped-drive"
    start_dir = root / "start"
    target_dir = start_dir / "selected"
    target_dir.mkdir(parents=True)
    install_dir = tmp_path / "installed"
    profile = tmp_path / "isolated profile.ps1"
    env = os.environ.copy()
    env["DIRNAV_INSTALL_DIR"] = str(install_dir)
    env["DIRNAV_TEST_PROFILE"] = str(profile)
    env["DIRNAV_SKIP_PATH"] = "1"
    isolated_temp = tmp_path / "isolated temp"
    isolated_temp.mkdir()
    env["TEMP"] = str(isolated_temp)
    env["PATH"] = str(Path(python).parent) + os.pathsep + env.get("PATH", "")
    profile_root = Path(env["USERPROFILE"])
    secure_dirs_before = set(profile_root.glob("dirnav-cmd-*"))
    subprocess.run(
        [powershell, "-NoProfile", "-File", str(Path(__file__).resolve().parents[2] / "install.ps1"), "-Shortcut", "dn", "-NonInteractive"],
        env=env,
        check=True,
        capture_output=True,
        text=True,
    )

    subprocess.run([subst, drive, str(root)], check=True, capture_output=True)
    try:
        env["DIRNAV_TEST_KEYS"] = "ENTER"
        batch = tmp_path / "cross-drive.cmd"
        batch.write_text(
            f'@echo off\r\ncd /d "{Path.cwd()}"\r\n'
            f'call "{install_dir / "dirnav.cmd"}" "{drive}\\start"\r\n'
            "echo RESULT_CWD=%CD%\r\n",
            encoding="ascii",
        )
        result = subprocess.run(
            [cmd, "/d", "/q", "/c", "call", str(batch)],
            check=False,
            env=env,
            capture_output=True,
            text=True,
            errors="replace",
        )
        assert result.returncode == 0, result.stdout + result.stderr
        assert f"RESULT_CWD={drive}\\start\\selected" in result.stdout
    finally:
        subprocess.run([subst, drive, "/d"], check=False, capture_output=True)
    assert set(profile_root.glob("dirnav-cmd-*")) == secure_dirs_before


@pytest.mark.skipif(os.name != "nt", reason="requires real Windows cmd.exe")
def test_cmd_launcher_parallel_sessions_have_isolated_results(tmp_path):
    cmd = shutil.which("cmd.exe")
    powershell = shutil.which("pwsh") or shutil.which("powershell.exe")
    python = shutil.which("python.exe")
    if not cmd or not powershell or not python:
        pytest.skip("cmd.exe, PowerShell, or Python 3 is unavailable")

    install_dir = tmp_path / "installed"
    temp_dir = tmp_path / "isolated temp"
    temp_dir.mkdir()
    env = os.environ.copy()
    env.update(
        DIRNAV_INSTALL_DIR=str(install_dir),
        DIRNAV_TEST_PROFILE=str(tmp_path / "isolated profile.ps1"),
        DIRNAV_SKIP_PATH="1",
        TEMP=str(temp_dir),
        PATH=str(Path(python).parent) + os.pathsep + env.get("PATH", ""),
    )
    subprocess.run(
        [powershell, "-NoProfile", "-File", str(Path(__file__).resolve().parents[2] / "install.ps1"),
         "-Shortcut", "dn", "-NonInteractive"],
        env=env,
        check=True,
        capture_output=True,
        text=True,
    )

    launcher = install_dir / "dirnav.cmd"
    profile_root = Path(env["USERPROFILE"])
    secure_dirs_before = set(profile_root.glob("dirnav-cmd-*"))
    sessions = []
    for index in range(8):
        start_dir = tmp_path / f"session-{index}" / "start"
        target_dir = start_dir / f"selected-{index} & folder"
        target_dir.mkdir(parents=True)
        record = tmp_path / f"session-{index}-cwd.txt"
        runner = tmp_path / f"session-{index}.cmd"
        runner.write_text(
            f'@echo off\r\nchcp 65001 >nul\r\ncd /d "{start_dir}"\r\n'
            f'call "{launcher}"\r\ncd > "{record}"\r\n',
            encoding="utf-8",
        )
        sessions.append((runner, record, target_dir))

    def run_session(session):
        runner, record, expected = session
        return subprocess.run(
            [cmd, "/d", "/q", "/c", "call", str(runner)],
            env={**env, "DIRNAV_TEST_KEYS": "ENTER"},
            check=False,
            capture_output=True,
        ), record, expected

    with ThreadPoolExecutor(max_workers=len(sessions)) as pool:
        results = list(pool.map(run_session, sessions))

    for result, record, expected in results:
        assert result.returncode == 0, result.stdout + result.stderr
        assert record.read_text(encoding="utf-8").strip() == str(expected), (
            result.stdout.decode("utf-8", errors="replace")
            + result.stderr.decode("utf-8", errors="replace")
        )
    assert set(profile_root.glob("dirnav-cmd-*")) == secure_dirs_before


@pytest.mark.skipif(os.name != "nt", reason="requires Windows filesystem links")
def test_windows_junction_is_listed_as_directory(tmp_path, dirnav_module):
    cmd = shutil.which("cmd.exe")
    if not cmd:
        pytest.skip("cmd.exe is unavailable")
    root = tmp_path / "junction-root"
    target = tmp_path / "junction-target"
    junction = root / "junction entry"
    root.mkdir()
    target.mkdir()
    result = subprocess.run(
        [cmd, "/d", "/c", "mklink", "/J", str(junction), str(target)],
        check=False,
        capture_output=True,
        text=True,
        errors="replace",
    )
    if result.returncode != 0:
        pytest.skip("junction creation is unavailable: " + result.stdout + result.stderr)
    try:
        assert dirnav_module.get_directories(str(root)) == [junction.name]
    finally:
        os.rmdir(junction)


@pytest.mark.skipif(os.name != "nt", reason="requires Windows symbolic-link support")
def test_windows_directory_symlink_is_listed_when_permitted(tmp_path, dirnav_module):
    root = tmp_path / "symlink-root"
    target = tmp_path / "symlink-target"
    link = root / "symlink entry"
    root.mkdir()
    target.mkdir()
    try:
        os.symlink(target, link, target_is_directory=True)
    except OSError as exc:
        pytest.skip("directory symlink privilege is unavailable: " + str(exc))
    try:
        assert dirnav_module.get_directories(str(root)) == [link.name]
    finally:
        os.rmdir(link)


@pytest.mark.skipif(os.name != "nt", reason="requires real Windows CMD and filesystem links")
@pytest.mark.parametrize("link_kind", ["junction", "symlink"])
def test_cmd_launcher_navigates_through_directory_link(tmp_path, link_kind):
    cmd = shutil.which("cmd.exe")
    powershell = shutil.which("pwsh") or shutil.which("powershell.exe")
    python = shutil.which("python.exe")
    if not cmd or not powershell or not python:
        pytest.skip("cmd.exe, PowerShell, or Python 3 is unavailable")

    project_root = Path(__file__).resolve().parents[2]
    install_dir = tmp_path / "installed"
    start_dir = tmp_path / "start"
    link = start_dir / "linked folder"
    real_target = tmp_path / "real target"
    child = real_target / "child"
    start_dir.mkdir()
    child.mkdir(parents=True)
    if link_kind == "junction":
        linked = subprocess.run(
            [cmd, "/d", "/c", "mklink", "/J", str(link), str(real_target)],
            check=False,
            capture_output=True,
            text=True,
            errors="replace",
        )
        if linked.returncode:
            pytest.skip("junction creation unavailable: " + linked.stdout + linked.stderr)
    else:
        try:
            os.symlink(real_target, link, target_is_directory=True)
        except OSError as exc:
            pytest.skip("directory symlink privilege unavailable: " + str(exc))

    temp_dir = tmp_path / "isolated temp"
    temp_dir.mkdir()
    env = os.environ.copy()
    env.update(
        DIRNAV_INSTALL_DIR=str(install_dir),
        DIRNAV_TEST_PROFILE=str(tmp_path / "isolated profile.ps1"),
        DIRNAV_SKIP_PATH="1",
        TEMP=str(temp_dir),
        PATH=str(Path(python).parent) + os.pathsep + env.get("PATH", ""),
        DIRNAV_TEST_KEYS="TAB,ENTER",
    )
    subprocess.run(
        [powershell, "-NoProfile", "-File", str(project_root / "install.ps1"), "-Shortcut", "dn", "-NonInteractive"],
        env=env,
        check=True,
        capture_output=True,
        text=True,
    )
    record = tmp_path / "observed-cwd.txt"
    runner = tmp_path / "run-link-session.cmd"
    runner.write_text(
        f'@echo off\r\nchcp 65001 >nul\r\ncd /d "{start_dir}"\r\n'
        f'call "{install_dir / "dirnav.cmd"}"\r\n'
        f'cd > "{record}"\r\n',
        encoding="utf-8",
    )
    result = subprocess.run(
        [cmd, "/d", "/q", "/c", "call", str(runner)],
        env=env,
        check=False,
        capture_output=True,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    observed = Path(record.read_text(encoding="utf-8").strip())
    assert os.path.samefile(observed, child)
    assert set(Path(env["USERPROFILE"]).glob("dirnav-cmd-*")) == set()


@pytest.mark.skipif(os.name != "nt", reason="requires real Windows CMD")
def test_cmd_launcher_long_path_navigation_when_supported(tmp_path):
    cmd = shutil.which("cmd.exe")
    powershell = shutil.which("pwsh") or shutil.which("powershell.exe")
    python = shutil.which("python.exe")
    if not cmd or not powershell or not python:
        pytest.skip("cmd.exe, PowerShell, or Python 3 is unavailable")

    deep_start = tmp_path
    try:
        for index in range(12):
            deep_start = deep_start / f"level-{index:02d}-abcdefghij"
        target = deep_start / "selected"
        target.mkdir(parents=True)
    except OSError as exc:
        pytest.skip("filesystem cannot create the long path: " + str(exc))
    if len(str(target)) <= 260:
        pytest.skip("pytest temporary root did not produce a path over 260 characters")

    install_dir = tmp_path / "installed"
    temp_dir = tmp_path / "isolated temp"
    temp_dir.mkdir()
    env = os.environ.copy()
    env.update(
        DIRNAV_INSTALL_DIR=str(install_dir),
        DIRNAV_TEST_PROFILE=str(tmp_path / "isolated profile.ps1"),
        DIRNAV_SKIP_PATH="1",
        TEMP=str(temp_dir),
        PATH=str(Path(python).parent) + os.pathsep + env.get("PATH", ""),
        DIRNAV_TEST_KEYS="ENTER",
    )
    subprocess.run(
        [powershell, "-NoProfile", "-File", str(Path(__file__).resolve().parents[2] / "install.ps1"),
         "-Shortcut", "dn", "-NonInteractive"],
        env=env,
        check=True,
        capture_output=True,
        text=True,
    )
    record = tmp_path / "long-cwd.txt"
    runner = tmp_path / "run-long-session.cmd"
    runner.write_text(
        f'@echo off\r\nchcp 65001 >nul\r\ncall "{install_dir / "dirnav.cmd"}" "{deep_start}"\r\n'
        f'cd > "{record}"\r\n',
        encoding="utf-8",
    )
    result = subprocess.run(
        [cmd, "/d", "/q", "/c", "call", str(runner)],
        env=env,
        check=False,
        capture_output=True,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    observed = Path(record.read_text(encoding="utf-8").strip())
    assert os.path.samefile(observed, target)
    assert set(Path(env["USERPROFILE"]).glob("dirnav-cmd-*")) == set()
