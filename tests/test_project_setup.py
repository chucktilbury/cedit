"""Exercise the project shell and standalone output/install contract in isolation."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def run(command, *, cwd, env, input=None, success=True):
    result = subprocess.run(command, cwd=cwd, env=env, input=input, text=True,
                            capture_output=True, timeout=120)
    if success:
        assert result.returncode == 0, (command, result.stdout, result.stderr)
    else:
        assert result.returncode != 0, (command, result.stdout, result.stderr)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--sdk", type=Path, required=True)
    parser.add_argument("--cmake", required=True)
    parser.add_argument("--xvfb", required=True)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="cedit project ") as directory:
        work = Path(directory)
        source = work / "source with spaces"
        source.mkdir()
        for name in ("src", "cmake", "tests", "scripts"):
            shutil.copytree(args.source / name, source / name,
                            ignore=shutil.ignore_patterns("__pycache__"))
        for name in ("CMakeLists.txt", ".project_env"):
            shutil.copy2(args.source / name, source / name)
        home = work / "home"
        home.mkdir()
        (home / ".bashrc").write_text("export CEDIT_BASHRC_READ=yes\n")
        env = {key: value for key, value in os.environ.items()
               if key not in ("_PROJECT_NAME", "_PROJECT_LOC", "_BUILD_TYPE",
                              "CWHIP_BUILD_TYPE", "MAKEFLAGS", "MFLAGS", "MAKELEVEL",
                              "Cwhip_DIR", "CMAKE_PREFIX_PATH")}
        env.update(HOME=str(home), CWHIP_SDK=str(args.sdk))
        setup = str(source / "scripts/setup")
        state = (
            "printf 'STATE=%s|%s|%s|%s|%s|%s\\n' "
            '"$PWD" "$_PROJECT_LOC" "$_PROJECT_NAME" "$_BUILD_TYPE" '
            '"$CWHIP_BUILD_TYPE" "$CEDIT_BASHRC_READ"\n'
            '[[ "$PATH" == "$_PROJECT_LOC/bin:$_PROJECT_LOC/scripts:$CWHIP_SDK/bin:"* ]]'
            " || exit 31\n"
            "declare -F status add commit push all dbg || exit 32\n"
            '"$_PROJECT_LOC/scripts/setup" && exit 33\n'
            "exit 0\n"
        )
        for mode, cmake_mode in (("", "Debug"), ("release", "Release"),
                                 ("profile", "RelWithDebInfo")):
            command = [setup] + ([mode] if mode else [])
            result = run(command, cwd=work, env=env, input=state)
            expected = (f"STATE={source}/build|{source}|{source.name}|"
                        f"{mode or 'debug'}|{cmake_mode}|yes")
            assert expected in result.stdout, result
            assert f"CMAKE_BUILD_TYPE:STRING={cmake_mode}" in (
                source / "build/CMakeCache.txt").read_text()
            assert not (source / "bin").exists()
            assert not (source / "lib").exists()
            assert not (source / "share").exists()
        for arguments in (["invalid"], ["debug", "extra"]):
            result = run([setup, *arguments], cwd=work, env=env,
                         input="echo UNEXPECTED_SHELL\n", success=False)
            assert result.returncode == 2, result
            assert "cedit: error[CEDIT0001]:" in result.stderr, result
            assert "UNEXPECTED_SHELL" not in result.stdout
        bad_env = dict(env, CWHIP_SDK=str(work / "missing SDK"))
        result = run([setup], cwd=work, env=bad_env,
                     input="echo UNEXPECTED_SHELL\n", success=False)
        assert "project shell was not started" in result.stderr, result
        assert "cedit: error[CEDIT3001]:" in result.stderr, result
        assert "UNEXPECTED_SHELL" not in result.stdout
        run([setup, "debug"], cwd=work, env=env, input="exit\n")

        build = source / "build"
        cmake = [args.cmake, "--build", str(build)]
        run(cmake, cwd=work, env=env)
        outputs = [source / "bin/cedit", source / "bin/cedit.bin",
                   source / "share/cwhip/modules/sourceview/0.1.0/language-specs/cwhip.lang"]
        before = [path.stat().st_mtime_ns for path in outputs]
        run(cmake, cwd=work, env=env)
        assert before == [path.stat().st_mtime_ns for path in outputs]

        installed = work / "installed app"
        run([args.cmake, "--install", str(build), "--prefix", str(installed)],
            cwd=work, env=env)
        relocated = work / "relocated app"
        installed.rename(relocated)
        # Remove build outputs before running the installed, relocated application.
        run(cmake + ["--target", "clean"], cwd=work, env=env)
        assert all(not path.exists() for path in outputs), outputs
        run(["python3", str(source / "tests/test_smoke.py"),
             "--executable", str(relocated / "bin/cedit"), "--xvfb", args.xvfb,
             "--work", str(work / "relocated smoke")], cwd=work, env=env)
        run(cmake, cwd=work, env=env)
        assert all(path.exists() for path in outputs)

        private = work / "private outputs"
        run([args.cmake, "-S", str(source), "-B", str(build),
             f"-DCWHIP_BIN_DIR={private}/bin", f"-DCWHIP_LIB_DIR={private}/lib"],
            cwd=work, env=env)
        assert not private.exists()
        run(cmake, cwd=work, env=env)
        assert (private / "bin/cedit").is_file()
        assert (private / "bin/cedit.bin").is_file()
        assert (private / "share/cwhip/modules/sourceview/0.1.0/language-specs/cwhip.lang").is_file()
        run(["python3", str(source / "tests/test_smoke.py"),
             "--executable", str(private / "bin/cedit"), "--xvfb", args.xvfb,
             "--work", str(work / "override smoke")], cwd=work, env=env)


if __name__ == "__main__":
    main()
