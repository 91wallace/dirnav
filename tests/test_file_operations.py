import errno
import os
import shutil
import subprocess

import pytest

import dirnav_operations as ops


def test_copy_file_preserves_unicode_and_special_characters(
    dirnav_module, tmp_path
):
    source = tmp_path / "origem & ç.txt"
    source.write_text("conteudo Unicode: ç 漢字", encoding="utf-8")
    target_dir = tmp_path / "destino !"
    target_dir.mkdir()

    result = ops.copy_entry(source, target_dir / source.name)

    assert "Copiado para" in result
    assert (target_dir / source.name).read_bytes() == source.read_bytes()
    assert source.exists()


def test_copy_directory_is_recursive_and_verifies_content(dirnav_module, tmp_path):
    source = tmp_path / "árvore"
    (source / "sub").mkdir(parents=True)
    (source / "sub" / "a.txt").write_text("A" * 4096, encoding="utf-8")
    (source / "b.txt").write_text("B", encoding="utf-8")
    target_dir = tmp_path / "dest"
    target_dir.mkdir()

    ops.copy_entry(source, target_dir / source.name)

    assert (target_dir / source.name / "sub" / "a.txt").read_text() == "A" * 4096
    assert (target_dir / source.name / "b.txt").read_text() == "B"
    assert source.exists()


def test_copy_conflict_fails_without_overwriting(dirnav_module, tmp_path):
    source = tmp_path / "source.txt"
    target = tmp_path / "target.txt"
    source.write_text("new", encoding="utf-8")
    target.write_text("keep", encoding="utf-8")

    with pytest.raises(FileExistsError):
        ops.copy_entry(source, target)

    assert source.read_text() == "new"
    assert target.read_text() == "keep"


def test_copy_replace_requires_confirmed_destination_identity(
    dirnav_module, tmp_path
):
    source = tmp_path / "source.txt"
    target = tmp_path / "target.txt"
    source.write_text("new", encoding="utf-8")
    target.write_text("old", encoding="utf-8")
    snapshot = ops.inspect_entry(target)
    target.write_text("changed after confirmation", encoding="utf-8")

    with pytest.raises(ops.SourceChangedError):
        ops.copy_entry(
            source,
            target,
            replace=True,
            expected_target=snapshot,
        )

    assert source.read_text() == "new"
    assert target.read_text() == "changed after confirmation"


def test_copy_replace_is_explicit_and_preserves_original_on_success(
    dirnav_module, tmp_path
):
    source = tmp_path / "source.txt"
    target = tmp_path / "target.txt"
    source.write_text("new", encoding="utf-8")
    target.write_text("old", encoding="utf-8")

    ops.copy_entry(
        source,
        target,
        replace=True,
        expected_target=ops.inspect_entry(target),
    )

    assert source.read_text() == "new"
    assert target.read_text() == "new"
    assert not list(tmp_path.glob(".dirnav-stage-*"))


def test_copy_into_self_or_descendant_is_rejected(dirnav_module, tmp_path):
    source = tmp_path / "tree"
    child = source / "child"
    child.mkdir(parents=True)

    with pytest.raises(ops.OperationError, match="dele mesmo"):
        ops.copy_entry(source, child / source.name)

    assert source.is_dir()
    assert list(source.iterdir()) == [child]


def test_target_must_be_direct_child_to_prevent_path_traversal(
    dirnav_module, tmp_path
):
    source = tmp_path / "source.txt"
    destination = tmp_path / "destination"
    destination.mkdir()
    source.write_text("safe", encoding="utf-8")
    escaped_target = destination.parent / "outside.txt"

    with pytest.raises(ops.OperationError, match="filho direto"):
        ops.copy_entry(source, escaped_target, destination_dir=destination)

    assert source.read_text(encoding="utf-8") == "safe"
    assert not escaped_target.exists()


def test_destination_snapshot_prevents_using_a_changed_selection(dirnav_module, tmp_path):
    source = tmp_path / "source.txt"
    destination = tmp_path / "destination"
    destination.mkdir()
    source.write_text("safe", encoding="utf-8")
    snapshot = ops.inspect_entry(destination)
    original_destination = tmp_path / "destination-original"
    destination.rename(original_destination)
    destination.mkdir()

    with pytest.raises(ops.SourceChangedError, match="mudou"):
        ops.copy_entry(
            source,
            destination / source.name,
            destination_dir=destination,
            expected_destination=snapshot,
        )

    assert source.read_text(encoding="utf-8") == "safe"
    assert not (destination / source.name).exists()
    assert original_destination.is_dir()


def test_cancelled_copy_keeps_source_and_removes_staging(dirnav_module, tmp_path):
    source = tmp_path / "large.bin"
    source.write_bytes(b"x" * (3 * 1024 * 1024))
    target_dir = tmp_path / "dest"
    target_dir.mkdir()
    cancellation = {"requested": False}

    def progress(_path, copied, _total):
        if copied:
            cancellation["requested"] = True

    with pytest.raises(ops.OperationCancelled):
        ops.copy_entry(
            source,
            target_dir / source.name,
            progress=progress,
            cancel=lambda: cancellation["requested"],
        )

    assert source.stat().st_size == 3 * 1024 * 1024
    assert not (target_dir / source.name).exists()
    assert not list(target_dir.iterdir())


def test_copy_write_failure_preserves_source_and_cleans_partial_stage(
    dirnav_module, tmp_path, monkeypatch
):
    source = tmp_path / "source.txt"
    target_dir = tmp_path / "dest"
    source.write_text("original", encoding="utf-8")
    target_dir.mkdir()
    original_copy_file = ops._copy_file

    def partial_write_then_fail(source_path, target_path, progress, cancel):
        with open(target_path, "xb") as stream:
            stream.write(b"partial")
        raise OSError("simulated disk-full failure")

    monkeypatch.setattr(ops, "_copy_file", partial_write_then_fail)
    with pytest.raises(OSError, match="disk-full"):
        ops.copy_entry(source, target_dir / source.name)

    assert source.read_text(encoding="utf-8") == "original"
    assert not list(target_dir.iterdir())
    monkeypatch.setattr(ops, "_copy_file", original_copy_file)


def test_stale_source_snapshot_blocks_copy_and_move(dirnav_module, tmp_path):
    source = tmp_path / "source.txt"
    target_dir = tmp_path / "dest"
    target_dir.mkdir()
    source.write_text("before", encoding="utf-8")
    snapshot = ops.inspect_entry(source)
    source.write_text("after changed", encoding="utf-8")

    with pytest.raises(ops.SourceChangedError):
        ops.copy_entry(
            source, target_dir / source.name, expected_source=snapshot
        )
    with pytest.raises(ops.SourceChangedError):
        ops.move_entry(
            source, target_dir / source.name, expected_source=snapshot
        )

    assert source.read_text() == "after changed"
    assert not list(target_dir.iterdir())


def test_source_change_during_copy_discards_stage_and_preserves_changed_source(
    dirnav_module, tmp_path
):
    source = tmp_path / "source.bin"
    target_dir = tmp_path / "dest"
    target_dir.mkdir()
    source.write_bytes(b"a" * (2 * 1024 * 1024))
    changed = {"done": False}

    def mutate_source(_path, copied, _total):
        if copied and not changed["done"]:
            source.write_bytes(b"changed source")
            changed["done"] = True

    with pytest.raises(ops.SourceChangedError):
        ops.copy_entry(
            source,
            target_dir / source.name,
            progress=mutate_source,
        )

    assert source.read_bytes() == b"changed source"
    assert not (target_dir / source.name).exists()
    assert not list(target_dir.iterdir())


def test_move_same_volume_never_overwrites_destination(dirnav_module, tmp_path):
    source = tmp_path / "source.txt"
    target = tmp_path / "target.txt"
    source.write_text("source", encoding="utf-8")
    target.write_text("target", encoding="utf-8")

    with pytest.raises(FileExistsError):
        ops.move_entry(source, target)

    assert source.read_text() == "source"
    assert target.read_text() == "target"


def test_no_replace_rename_primitive_preserves_existing_target(dirnav_module, tmp_path):
    source = tmp_path / "source.txt"
    target = tmp_path / "target.txt"
    source.write_text("source", encoding="utf-8")
    target.write_text("target", encoding="utf-8")
    source_snapshot = ops.inspect_entry(source)

    with pytest.raises(FileExistsError):
        ops._rename_no_replace(source, target, source_snapshot)

    assert source.read_text(encoding="utf-8") == "source"
    assert target.read_text(encoding="utf-8") == "target"


def test_move_failure_preserves_source_and_absent_destination(
    dirnav_module, tmp_path, monkeypatch
):
    source = tmp_path / "source.txt"
    target = tmp_path / "target.txt"
    source.write_text("preserve", encoding="utf-8")

    def deny_rename(_source, _target, _source_info):
        raise PermissionError("simulated permission failure")

    monkeypatch.setattr(ops, "_rename_no_replace", deny_rename)
    with pytest.raises(PermissionError, match="permission"):
        ops.move_entry(source, target)

    assert source.read_text(encoding="utf-8") == "preserve"
    assert not target.exists()


def test_cross_volume_move_copies_verifies_then_removes_source(
    dirnav_module, tmp_path, monkeypatch
):
    source = tmp_path / "source.txt"
    target_dir = tmp_path / "dest"
    target_dir.mkdir()
    source.write_text("cross volume", encoding="utf-8")
    original_rename = ops._rename_no_replace

    def cross_volume_once(src, dst, source_info):
        if os.path.abspath(src) == os.path.abspath(source):
            raise OSError(errno.EXDEV, "different volume")
        return original_rename(src, dst, source_info)

    monkeypatch.setattr(ops, "_rename_no_replace", cross_volume_once)
    result = ops.move_entry(source, target_dir / source.name)

    assert "copiado e verificado" in result
    assert not source.exists()
    assert (target_dir / source.name).read_text() == "cross volume"


def test_cross_volume_move_cleanup_failure_keeps_verified_destination_and_source(
    dirnav_module, tmp_path, monkeypatch
):
    source = tmp_path / "source.txt"
    target_dir = tmp_path / "dest"
    target_dir.mkdir()
    source.write_text("recoverable", encoding="utf-8")
    original_rename = ops._rename_no_replace
    original_remove = ops._remove_path

    def cross_volume_once(src, dst, source_info):
        if os.path.abspath(src) == os.path.abspath(source):
            raise OSError(errno.EXDEV, "different volume")
        return original_rename(src, dst, source_info)

    def fail_source_removal(path):
        if os.path.abspath(path) == os.path.abspath(source):
            raise PermissionError("simulated cleanup failure")
        return original_remove(path)

    monkeypatch.setattr(ops, "_rename_no_replace", cross_volume_once)
    monkeypatch.setattr(ops, "_remove_path", fail_source_removal)

    with pytest.raises(ops.PartialOperationError, match="Destino verificado"):
        ops.move_entry(source, target_dir / source.name)

    assert source.read_text() == "recoverable"
    assert (target_dir / source.name).read_text() == "recoverable"


def test_delete_recurses_without_following_symlink(dirnav_module, tmp_path):
    outside = tmp_path / "outside"
    outside.mkdir()
    protected_file = outside / "keep.txt"
    protected_file.write_text("safe", encoding="utf-8")
    source = tmp_path / "tree"
    source.mkdir()
    link = source / "outside-link"
    try:
        os.symlink(outside, link, target_is_directory=True)
    except (OSError, NotImplementedError):
        pytest.skip("Host does not allow creating test symlinks")

    summary = ops.deletion_summary(source)
    ops.delete_entry(source)

    assert summary["links"] == 1
    assert not source.exists()
    assert protected_file.read_text() == "safe"


def test_delete_refuses_root_current_directory_and_critical_windows_roots(
    dirnav_module, tmp_path, monkeypatch
):
    current = tmp_path / "current"
    current.mkdir()
    with pytest.raises(ops.OperationError, match="protegido"):
        ops.validate_delete_target(current, protected_paths=(current,))

    if os.name == "nt":
        windows = os.environ.get("SystemRoot") or os.environ.get("WINDIR")
        if windows:
            with pytest.raises(ops.OperationError, match="protegido"):
                ops.validate_delete_target(windows)


def test_symlink_target_is_not_used_as_delete_target(dirnav_module, tmp_path):
    outside = tmp_path / "outside"
    outside.mkdir()
    payload = outside / "keep.txt"
    payload.write_text("safe", encoding="utf-8")
    link = tmp_path / "link"
    try:
        os.symlink(outside, link, target_is_directory=True)
    except (OSError, NotImplementedError):
        pytest.skip("Host does not allow creating test symlinks")

    snapshot = ops.inspect_entry(link)
    ops.delete_entry(link, expected_source=snapshot)

    assert not os.path.lexists(link)
    assert payload.read_text() == "safe"


def test_copy_preserves_symlink_without_copying_its_target(dirnav_module, tmp_path):
    target = tmp_path / "outside"
    target.mkdir()
    (target / "keep.txt").write_text("safe", encoding="utf-8")
    link = tmp_path / "link"
    destination = tmp_path / "dest"
    destination.mkdir()
    try:
        os.symlink(target, link, target_is_directory=True)
    except (OSError, NotImplementedError):
        pytest.skip("Host does not allow creating test symlinks")

    ops.copy_entry(link, destination / link.name)

    assert os.path.islink(destination / link.name)
    assert os.readlink(destination / link.name) == os.readlink(link)
    assert (target / "keep.txt").read_text(encoding="utf-8") == "safe"


@pytest.mark.skipif(os.name != "nt", reason="requires native Windows junctions")
def test_recursive_delete_does_not_follow_windows_junction(tmp_path):
    powershell = shutil.which("pwsh") or shutil.which("powershell.exe")
    if not powershell or not hasattr(os.path, "isjunction"):
        pytest.skip("PowerShell or native junction detection is unavailable")
    target = tmp_path / "junction-target"
    target.mkdir()
    sentinel = target / "keep.txt"
    sentinel.write_text("safe", encoding="utf-8")
    tree = tmp_path / "tree"
    tree.mkdir()
    junction = tree / "junction"
    script = "New-Item -ItemType Junction -Path $args[0] -Target $args[1] | Out-Null"
    result = subprocess.run(
        [powershell, "-NoProfile", "-Command", script, str(junction), str(target)],
        check=False,
        capture_output=True,
        text=True,
        timeout=20,
    )
    if result.returncode != 0 or not os.path.isjunction(junction):
        pytest.skip("Host could not create a disposable directory junction")

    assert ops.deletion_summary(tree)["links"] == 1
    ops.delete_entry(tree)

    assert not os.path.lexists(tree)
    assert sentinel.read_text(encoding="utf-8") == "safe"


def test_inaccessible_destination_fails_before_copy(dirnav_module, tmp_path, monkeypatch):
    source = tmp_path / "source.txt"
    target_dir = tmp_path / "dest"
    source.write_text("safe", encoding="utf-8")
    target_dir.mkdir()
    original_access = ops.os.access

    def deny_destination(path, mode):
        if os.path.abspath(path) == os.path.abspath(target_dir):
            return False
        return original_access(path, mode)

    monkeypatch.setattr(ops.os, "access", deny_destination)
    with pytest.raises(ops.OperationError, match="nao permite escrita"):
        ops.copy_entry(source, target_dir / source.name)
    assert source.read_text() == "safe"


def test_delete_confirmation_can_be_cancelled_without_changes(
    dirnav_module, tmp_path
):
    (tmp_path / "alpha").mkdir()
    item = tmp_path / "payload.txt"
    item.write_text("keep", encoding="utf-8")
    state = dirnav_module.NavigatorState(str(tmp_path))
    state.handle_key("F7")
    state.selected_idx = state.filtered_dirs.index("payload.txt")
    operation = dirnav_module.FileOperationController(state, "delete")
    assert "permanente" in " ".join(operation.screen_lines(80, 24)).lower()

    operation.handle_key("ESC")

    assert operation.done
    assert item.read_text() == "keep"


def test_copy_interaction_requires_destination_then_confirmation(
    dirnav_module, tmp_path
):
    source = tmp_path / "payload.txt"
    source.write_text("copy", encoding="utf-8")
    (tmp_path / "destination").mkdir()
    state = dirnav_module.NavigatorState(str(tmp_path))
    state.handle_key("F7")
    state.selected_idx = state.filtered_dirs.index(source.name)
    operation = dirnav_module.FileOperationController(state, "copy")

    operation.destination_navigator.handle_key("RIGHT")
    operation.handle_key("\n")
    assert operation.phase == "confirm"
    assert not (tmp_path / "payload (copy 1).txt").exists()
    operation.handle_key("ESC")

    assert operation.done
    assert source.read_text() == "copy"
    assert not list(tmp_path.glob("payload (copy*"))


def test_all_argument_exposes_hidden_files_in_destination_picker(
    dirnav_module, tmp_path
):
    source = tmp_path / "source.txt"
    source.write_text("copy", encoding="utf-8")
    (tmp_path / ".hidden-target").write_text("hidden", encoding="utf-8")
    state = dirnav_module.NavigatorState(str(tmp_path), show_all=True)
    state.selected_idx = state.filtered_dirs.index(source.name)
    operation = dirnav_module.FileOperationController(state, "copy")

    assert operation.destination_navigator.show_files
    assert operation.destination_navigator.show_hidden_files
    assert ".hidden-target" in operation.destination_navigator.filtered_dirs
