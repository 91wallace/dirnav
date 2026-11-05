import io
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

    assert cwd_file.read_text(encoding="utf-8") == target
    assert fake_stdout.getvalue() == ""


def test_write_output_to_stdout_when_no_cwd_file(dirnav_module, tmp_path):
    fake_stdout = io.StringIO()
    target = str(tmp_path)
    dirnav_module.write_output(target, None, stdout_stream=fake_stdout)

    assert fake_stdout.getvalue().strip() == target


def test_parse_args(dirnav_module, sample_tree):
    cwd_file, start_path = dirnav_module.parse_args(
        ["dirnav", "--cwd-file=/tmp/out", str(sample_tree)]
    )
    assert cwd_file == "/tmp/out"
    assert start_path == os.path.abspath(str(sample_tree))

    cwd_file2, start_path2 = dirnav_module.parse_args(
        ["dirnav", "--cwd-file", "/tmp/out2"]
    )
    assert cwd_file2 == "/tmp/out2"
    assert start_path2 is None
