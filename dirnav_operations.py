"""Conservative filesystem operations used by the dirnav interactive UI.

This module uses only Python's standard library. It never invokes a shell.
"""

# DIRNAV_MANAGED_INSTALL

import ctypes
import errno
import hashlib
import os
import shutil
import stat
import sys
import tempfile


class OperationError(Exception):
    """A filesystem operation could not be completed safely."""


class OperationCancelled(OperationError):
    """The user cancelled an operation before it was committed."""


class SourceChangedError(OperationError):
    """The selected source changed after it was selected or confirmed."""


class PartialOperationError(OperationError):
    """An operation left a reported, recoverable partial result."""


def _is_junction(path):
    isjunction = getattr(os.path, "isjunction", None)
    if isjunction is not None:
        try:
            return bool(isjunction(path))
        except (OSError, ValueError):
            return False
    try:
        return bool(os.lstat(path).st_file_attributes & 0x400)
    except (AttributeError, OSError):
        return False


def _kind_from_stat(path, info):
    if stat.S_ISLNK(info.st_mode):
        return "symlink"
    if _is_junction(path):
        return "junction"
    if stat.S_ISDIR(info.st_mode):
        return "directory"
    if stat.S_ISREG(info.st_mode):
        return "file"
    return "special"


def inspect_entry(path):
    """Return a stable identity snapshot and type without following links."""
    absolute = os.path.abspath(os.fspath(path))
    try:
        info = os.lstat(absolute)
    except OSError as exc:
        raise OperationError(f"Nao foi possivel inspecionar {absolute!r}: {exc}") from exc
    kind = _kind_from_stat(absolute, info)
    if kind == "special":
        raise OperationError(f"Tipo de item nao suportado: {absolute!r}")
    return {
        "path": absolute,
        "kind": kind,
        "device": getattr(info, "st_dev", None),
        "inode": getattr(info, "st_ino", None),
        "mode": info.st_mode,
        "size": info.st_size,
        "mtime_ns": getattr(info, "st_mtime_ns", int(info.st_mtime * 1e9)),
        "ctime_ns": getattr(info, "st_ctime_ns", int(info.st_ctime * 1e9)),
    }


def _same_snapshot(expected, actual):
    return all(
        expected.get(key) == actual.get(key)
        for key in ("path", "kind", "device", "inode", "mode", "size", "mtime_ns", "ctime_ns")
    )


def validate_snapshot(path, expected):
    actual = inspect_entry(path)
    if not _same_snapshot(expected, actual):
        raise SourceChangedError(
            f"O item selecionado mudou antes da operacao: {os.fspath(path)!r}"
        )
    return actual


def _realpath(path):
    return os.path.normcase(os.path.realpath(os.path.abspath(path)))


def _is_same_or_descendant(path, parent):
    path_real = _realpath(path)
    parent_real = _realpath(parent)
    try:
        return os.path.commonpath((path_real, parent_real)) == parent_real
    except (ValueError, OSError):
        return False


def _ensure_directory(path):
    absolute = os.path.abspath(os.fspath(path))
    try:
        info = os.stat(absolute)
        if not stat.S_ISDIR(info.st_mode):
            raise OperationError(f"O destino nao e um diretorio: {absolute!r}")
        if not os.access(absolute, os.W_OK | os.X_OK):
            raise OperationError(f"O destino nao permite escrita: {absolute!r}")
    except OSError as exc:
        raise OperationError(f"O destino esta inacessivel: {absolute!r}: {exc}") from exc
    return absolute


def _validate_destination(target, destination_dir, expected_destination=None):
    destination_dir = _ensure_directory(
        destination_dir or os.path.dirname(target) or os.curdir
    )
    target_parent = os.path.dirname(os.path.abspath(target)) or os.path.abspath(os.curdir)
    if os.path.normcase(target_parent) != os.path.normcase(destination_dir):
        raise OperationError("O destino precisa ser filho direto da pasta selecionada")
    if expected_destination is not None:
        validate_snapshot(destination_dir, expected_destination)
    return destination_dir


def _validate_directory_identity(path, expected):
    actual = inspect_entry(path)
    if any(
        expected.get(key) != actual.get(key)
        for key in ("path", "kind", "device", "inode")
    ):
        raise SourceChangedError("A pasta de destino mudou durante a operacao")
    if actual["kind"] != "directory":
        raise OperationError("O destino deixou de ser um diretorio")


def _check_cancel(cancel):
    if cancel is not None and cancel():
        raise OperationCancelled("Operacao cancelada")


def _check_destination_for_source(source, destination_dir, source_kind):
    source_real = _realpath(source)
    destination_real = _realpath(destination_dir)
    try:
        if os.path.samefile(source, destination_dir):
            raise OperationError("A origem e o destino sao o mesmo diretorio")
    except OSError:
        pass
    if source_kind == "directory" and _is_same_or_descendant(
        destination_real, source_real
    ):
        raise OperationError("Nao e possivel copiar ou mover um diretorio para dentro dele mesmo")


def _copy_file(source, destination, progress, cancel):
    before = inspect_entry(source)
    if before["kind"] != "file":
        raise OperationError(f"O item nao e um arquivo regular: {source!r}")
    copied = 0
    try:
        with open(source, "rb") as source_stream, open(destination, "xb") as target_stream:
            while True:
                _check_cancel(cancel)
                block = source_stream.read(1024 * 1024)
                if not block:
                    break
                target_stream.write(block)
                copied += len(block)
                if progress is not None:
                    progress(source, copied, before["size"])
            target_stream.flush()
            os.fsync(target_stream.fileno())
        after = inspect_entry(source)
        if not _same_snapshot(before, after):
            raise SourceChangedError(f"A origem mudou durante a copia: {source!r}")
        shutil.copystat(source, destination, follow_symlinks=False)
    except Exception:
        try:
            os.unlink(destination)
        except OSError:
            pass
        raise


def _copy_to_stage(source, destination, progress, cancel):
    _check_cancel(cancel)
    source_info = inspect_entry(source)
    kind = source_info["kind"]
    if kind == "file":
        _copy_file(source, destination, progress, cancel)
        return
    if kind == "symlink":
        link_target = os.readlink(source)
        os.symlink(link_target, destination, target_is_directory=os.path.isdir(source))
        validate_snapshot(source, source_info)
        return
    if kind == "junction":
        raise OperationError(
            f"Copia de junction nao suportada; o link nao foi percorrido: {source!r}"
        )
    if kind != "directory":
        raise OperationError(f"Tipo de item nao suportado: {source!r}")

    os.mkdir(destination)
    before = source_info
    with os.scandir(source) as entries:
        children = sorted(entries, key=lambda entry: entry.name.casefold())
    for entry in children:
        _check_cancel(cancel)
        child_source = os.path.join(source, entry.name)
        child_destination = os.path.join(destination, entry.name)
        _copy_to_stage(child_source, child_destination, progress, cancel)
    after = inspect_entry(source)
    if not _same_snapshot(before, after):
        raise SourceChangedError(f"O diretorio de origem mudou durante a copia: {source!r}")
    shutil.copystat(source, destination, follow_symlinks=False)


def _digest_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _manifest(path):
    info = inspect_entry(path)
    if info["kind"] == "file":
        return ("file", _digest_file(path))
    if info["kind"] == "symlink":
        return ("symlink", os.readlink(path))
    if info["kind"] == "junction":
        return ("junction", os.readlink(path))
    if info["kind"] != "directory":
        return ("special",)
    with os.scandir(path) as entries:
        children = sorted(entries, key=lambda entry: entry.name.casefold())
    return (
        "directory",
        tuple(
            (entry.name, _manifest(os.path.join(path, entry.name)))
            for entry in children
        ),
    )


def _remove_path(path):
    info = os.lstat(path)
    kind = _kind_from_stat(path, info)
    if kind == "symlink":
        os.unlink(path)
    elif kind == "junction":
        os.rmdir(path)
    elif kind == "directory":
        shutil.rmtree(path)
    else:
        os.unlink(path)


def _rename_no_replace(source, target, source_info):
    """Rename atomically without clobbering a target where the OS exposes it."""
    if os.name == "nt":
        # MoveFileW/os.rename fails when the destination already exists.
        return os.rename(source, target)

    libc = ctypes.CDLL(None, use_errno=True)
    source_bytes = os.fsencode(source)
    target_bytes = os.fsencode(target)
    renameat2 = getattr(libc, "renameat2", None)
    unsupported = {errno.ENOSYS, errno.EINVAL, getattr(errno, "EOPNOTSUPP", errno.EINVAL)}
    if renameat2 is not None:
        renameat2.argtypes = (ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint)
        renameat2.restype = ctypes.c_int
        if renameat2(-100, source_bytes, -100, target_bytes, 1) == 0:
            return
        error = ctypes.get_errno()
        if error not in unsupported:
            raise OSError(error, os.strerror(error), target)

    # Darwin provides the same no-clobber guarantee through renamex_np.
    renamex_np = getattr(libc, "renamex_np", None)
    if renamex_np is not None:
        renamex_np.argtypes = (ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint)
        renamex_np.restype = ctypes.c_int
        if renamex_np(source_bytes, target_bytes, 0x00000004) == 0:  # RENAME_EXCL
            return
        error = ctypes.get_errno()
        if error not in unsupported:
            raise OSError(error, os.strerror(error), target)

    # Portable fallback for non-directory items: exclusive hard-link creation
    # cannot replace an existing name. Directory moves fail closed without a
    # native no-replace rename primitive.
    if source_info["kind"] == "directory":
        raise OperationError(
            "Este sistema nao oferece movimentacao atomica de diretorios sem substituicao"
        )
    os.link(source, target, follow_symlinks=False)
    try:
        linked_info = inspect_entry(target)
        if any(
            source_info.get(key) != linked_info.get(key)
            for key in ("kind", "device", "inode", "mode", "size", "mtime_ns")
        ):
            raise SourceChangedError("A origem mudou durante a movimentacao")
        current_source = inspect_entry(source)
        if any(
            source_info.get(key) != current_source.get(key)
            for key in ("kind", "device", "inode", "mode", "size", "mtime_ns")
        ):
            raise SourceChangedError("A origem mudou durante a movimentacao")
        os.unlink(source)
    except Exception as exc:
        try:
            os.unlink(target)
        except OSError as cleanup_error:
            raise PartialOperationError(
                f"Origem preservada, mas o link temporario permanece em {target!r}: {cleanup_error}"
            ) from exc
        raise


def _cleanup_stage(stage_dir):
    if not os.path.lexists(stage_dir):
        return
    try:
        _remove_path(stage_dir)
    except OSError as exc:
        raise PartialOperationError(
            f"Dados temporarios da operacao permanecem em {stage_dir!r}: {exc}"
        ) from exc


def unique_destination_path(destination_dir, source_name, label="copy"):
    stem, extension = os.path.splitext(source_name)
    if not stem:
        stem = source_name
        extension = ""
    number = 1
    while True:
        candidate_name = f"{stem} ({label} {number}){extension}"
        candidate = os.path.join(destination_dir, candidate_name)
        if not os.path.lexists(candidate):
            return candidate
        number += 1


def copy_entry(
    source,
    target,
    *,
    replace=False,
    expected_source=None,
    expected_target=None,
    destination_dir=None,
    expected_destination=None,
    progress=None,
    cancel=None,
):
    """Copy one file/tree into a sibling staging area, verify, then publish."""
    source = os.path.abspath(os.fspath(source))
    target = os.path.abspath(os.fspath(target))
    source_info = validate_snapshot(source, expected_source) if expected_source else inspect_entry(source)
    destination_dir = _validate_destination(target, destination_dir, expected_destination)
    _check_destination_for_source(source, destination_dir, source_info["kind"])
    if os.path.normcase(source) == os.path.normcase(target):
        raise OperationError("A origem e o destino sao o mesmo caminho")
    initial_target_exists = os.path.lexists(target)
    if initial_target_exists and not replace:
        raise FileExistsError(errno.EEXIST, "O destino ja existe", target)
    if expected_target is not None and not initial_target_exists:
        raise SourceChangedError(
            "O destino em conflito desapareceu depois da confirmacao"
        )
    if replace and expected_target is None:
        raise OperationError("A substituicao exige confirmar a identidade do destino")

    stage_dir = tempfile.mkdtemp(prefix=".dirnav-stage-", dir=destination_dir)
    staged = os.path.join(stage_dir, "payload")
    backup = os.path.join(stage_dir, "previous")
    moved_existing = False
    try:
        _copy_to_stage(source, staged, progress, cancel)
        _check_cancel(cancel)
        if _manifest(source) != _manifest(staged):
            raise OperationError("A verificacao da copia falhou; a origem foi preservada")
        validate_snapshot(source, source_info)
        if expected_destination is not None:
            _validate_directory_identity(destination_dir, expected_destination)

        target_exists = os.path.lexists(target)
        if expected_target is not None and not target_exists:
            raise SourceChangedError(
                "O destino em conflito desapareceu depois da confirmacao"
            )
        if target_exists:
            if not replace:
                raise FileExistsError(errno.EEXIST, "O destino ja existe", target)
            target_info = inspect_entry(target)
            if expected_target is None or not _same_snapshot(expected_target, target_info):
                raise SourceChangedError(
                    "O destino em conflito mudou depois da confirmacao"
                )
            os.replace(target, backup)
            moved_existing = True
        try:
            if os.path.lexists(target):
                raise FileExistsError(errno.EEXIST, "O destino mudou durante a copia", target)
            os.rename(staged, target)
        except Exception as publish_error:
            if moved_existing and os.path.lexists(backup):
                if os.path.lexists(target):
                    raise PartialOperationError(
                        f"O destino mudou durante a substituicao; item anterior preservado em {backup!r}"
                    ) from publish_error
                try:
                    os.replace(backup, target)
                    moved_existing = False
                except OSError as restore_error:
                    raise PartialOperationError(
                        f"Falha ao restaurar o destino; item anterior preservado em {backup!r}: {restore_error}"
                    ) from publish_error
            raise

        message = f"Copiado para {target}"
        if moved_existing:
            try:
                _remove_path(backup)
                moved_existing = False
            except OSError as exc:
                message += f"; item substituido permanece para recuperacao em {backup!r}: {exc}"
        return message
    finally:
        if moved_existing:
            # Preserve the backup if publication succeeded but cleanup failed.
            if os.path.lexists(backup) and os.path.lexists(target):
                pass
        else:
            _cleanup_stage(stage_dir)


def move_entry(
    source,
    target,
    *,
    expected_source=None,
    destination_dir=None,
    expected_destination=None,
    progress=None,
    cancel=None,
):
    """Move without replacing an existing target; cross-volume moves copy/verify first."""
    source = os.path.abspath(os.fspath(source))
    target = os.path.abspath(os.fspath(target))
    source_info = validate_snapshot(source, expected_source) if expected_source else inspect_entry(source)
    destination_dir = _validate_destination(target, destination_dir, expected_destination)
    _check_destination_for_source(source, destination_dir, source_info["kind"])
    if os.path.normcase(source) == os.path.normcase(target):
        raise OperationError("A origem e o destino sao o mesmo caminho")
    if os.path.lexists(target):
        raise FileExistsError(errno.EEXIST, "O destino ja existe", target)
    if expected_destination is not None:
        validate_snapshot(destination_dir, expected_destination)
    _check_cancel(cancel)

    try:
        _rename_no_replace(source, target, source_info)
        return f"Movido para {target}"
    except OSError as exc:
        if exc.errno != errno.EXDEV and getattr(exc, "winerror", None) not in (17, 18):
            raise

    copy_entry(
        source,
        target,
        expected_source=source_info,
        progress=progress,
        cancel=cancel,
    )
    try:
        try:
            _check_cancel(cancel)
        except OperationCancelled as exc:
            raise PartialOperationError(
                f"A copia verificada permanece em {target!r}; a origem foi preservada apos cancelamento"
            ) from exc
        validate_snapshot(source, source_info)
        _remove_path(source)
    except OSError as exc:
        raise PartialOperationError(
            f"Destino verificado em {target!r}, mas a limpeza da origem falhou em {source!r}: {exc}"
        ) from exc
    return f"Movido para {target} (copiado e verificado entre volumes)"


def deletion_summary(path):
    """Count descendants without following symlinks or junctions."""
    info = inspect_entry(path)
    if info["kind"] in ("file", "symlink", "junction"):
        return {"files": 1, "directories": 0, "links": int(info["kind"] != "file")}
    files = 0
    directories = 1
    links = 0
    with os.scandir(path) as entries:
        children = list(entries)
    for entry in children:
        child_path = os.path.join(path, entry.name)
        child = inspect_entry(child_path)
        if child["kind"] == "directory":
            child_summary = deletion_summary(child_path)
            files += child_summary["files"]
            directories += child_summary["directories"]
            links += child_summary["links"]
        elif child["kind"] in ("symlink", "junction"):
            files += 1
            links += 1
        else:
            files += 1
    return {"files": files, "directories": directories, "links": links}


def _protected_delete_paths(extra_exact=()):
    exact_paths = [
        os.path.abspath(os.curdir),
        os.path.abspath(os.path.expanduser("~")),
        os.path.abspath(sys.prefix),
        *(os.path.abspath(os.fspath(path)) for path in extra_exact),
    ]
    protected_roots = []
    if os.name == "nt":
        system_root = os.environ.get("SystemRoot") or os.environ.get("WINDIR")
        if system_root:
            protected_roots.append(os.path.abspath(system_root))
        for variable in ("ProgramFiles", "ProgramFiles(x86)", "ProgramW6432"):
            value = os.environ.get(variable)
            if value:
                protected_roots.append(os.path.abspath(value))
    return (
        {_realpath(path) for path in exact_paths if path},
        {_realpath(path) for path in protected_roots if path},
    )


def validate_delete_target(path, expected_source=None, protected_paths=()):
    path = os.path.abspath(os.fspath(path))
    info = validate_snapshot(path, expected_source) if expected_source else inspect_entry(path)
    if info["kind"] in ("symlink", "junction"):
        # Removing the link itself does not traverse its target.
        return info
    _drive, tail = os.path.splitdrive(os.path.abspath(path))
    if not tail or tail in (os.sep, os.altsep):
        raise OperationError("A exclusao da raiz do sistema de arquivos foi recusada")
    candidate = _realpath(path)
    exact_paths, protected_roots = _protected_delete_paths(protected_paths)
    blocked_by_root = False
    for root in protected_roots:
        try:
            if os.path.commonpath((candidate, root)) == root:
                blocked_by_root = True
                break
        except ValueError:
            continue
    if candidate in exact_paths or blocked_by_root:
        raise OperationError(f"A exclusao de um caminho protegido foi recusada: {path!r}")
    return info


def delete_entry(path, *, expected_source=None, protected_paths=()):
    """Permanently delete a path after revalidating its identity; links are not followed."""
    path = os.path.abspath(os.fspath(path))
    validate_delete_target(path, expected_source, protected_paths)
    _remove_path(path)
    return f"Excluido permanentemente: {path}"
