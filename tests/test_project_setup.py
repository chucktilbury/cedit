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
               if not key.startswith(("CMAKE_", "CWHIP_", "Cwhip_", "_PROJECT_")) and
               key not in ("_BUILD_TYPE",
                           "MAKEFLAGS", "MFLAGS", "MAKELEVEL")}
        xdg_config = home / "xdg"
        xdg_config.mkdir()
        env.update(HOME=str(home), XDG_CONFIG_HOME=str(xdg_config),
                   CWHIP_SDK=str(args.sdk))
        setup = str(source / "scripts/setup")
        state = (
            "printf 'STATE=%s|%s|%s|%s|%s|%s\\n' "
            '"$PWD" "$_PROJECT_LOC" "$_PROJECT_NAME" "$_BUILD_TYPE" '
            '"$CWHIP_BUILD_TYPE" "$CEDIT_BASHRC_READ"\n'
            '[[ "$PATH" == "$_PROJECT_LOC/bin:$_PROJECT_LOC/scripts:$CWHIP_SDK/bin:"* ]]'
            " || exit 31\n"
            "declare -F build rebuild status add commit push all dbg || exit 32\n"
            '"$_PROJECT_LOC/scripts/setup" && exit 33\n'
            "exit 0\n"
        )
        for mode in ("", "release", "profile"):
            command = [setup] + ([mode] if mode else [])
            result = run(command, cwd=work, env=env, input=state)
            cache = (source / "build/CMakeCache.txt").read_text()
            cmake_mode = next(
                line.split("=", 1)[1] for line in cache.splitlines()
                if line.startswith("CMAKE_BUILD_TYPE:")
            )
            if not mode:
                assert cmake_mode == "", (
                    f"parent CMAKE_BUILD_TYPE leaked into the isolated setup: {cmake_mode!r}")
            shell_mode = {
                "Debug": "debug",
                "Release": "release",
                "RelWithDebInfo": "profile",
                "": "default",
            }.get(cmake_mode, cmake_mode.lower())
            expected = (f"STATE={source}/build|{source}|{source.name}|"
                        f"{shell_mode}|{cmake_mode}|yes")
            assert expected in result.stdout, result
            assert f"CMAKE_BUILD_TYPE:STRING={cmake_mode}" in cache
            assert not (source / "bin").exists()
            assert not (source / "lib").exists()
            assert not (source / "share").exists()
        marker = source / "build/active-shell-marker"
        marker.touch()
        for arguments in (["invalid"], ["debug", "extra"], ["debug", "release"],
                          ["debug", "debug"], ["--clean", "--clean"],
                          ["--clean", "invalid"]):
            result = run([setup, *arguments], cwd=work, env=env,
                         input="echo UNEXPECTED_SHELL\n", success=False)
            assert result.returncode == 2, result
            assert "Usage:" in result.stderr, result
            assert "UNEXPECTED_SHELL" not in result.stdout
            assert marker.exists()
        bad_env = dict(env, CWHIP_SDK=str(work / "missing SDK"))
        result = run([setup], cwd=work, env=bad_env,
                     input="echo UNEXPECTED_SHELL\n", success=False)
        assert "project shell was not started" in result.stderr, result
        assert "CMake configuration failed" in result.stderr, result
        assert "UNEXPECTED_SHELL" not in result.stdout
        # Both argument orders clean every default generated tree, not sources.
        for arguments in (["--clean", "debug"], ["debug", "--clean"]):
            sentinels = [source / name / "stale-output"
                         for name in ("bin", "build", "lib", "doc/out", "share")]
            for path in sentinels:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("old generated output\n")
            result = run([setup, *arguments], cwd=work, env=env, input=state)
            assert all(not path.exists() for path in sentinels)
            assert (source / "src/cedit.cw").is_file()
            assert "|debug|Debug|yes" in result.stdout, result

        marker.touch()
        result = run([setup, "--clean", "invalid"], cwd=work,
                     env=dict(env, _PROJECT_NAME="already active"), success=False)
        assert result.returncode == 1, result
        assert "already active" in result.stderr, result
        assert marker.exists()

        build = source / "build"
        cmake = [args.cmake, "--build", str(build)]
        result = run([setup, "--clean"], cwd=work, env=env,
                     input="cd / && build cedit && printf 'BUILD_RETURNED\\n'\nexit $?\n")
        assert "BUILD_RETURNED" in result.stdout, result
        assert not marker.exists()
        outputs = [source / "bin/cedit", source / "bin/cedit.bin",
                   source / "share/cwhip/modules/sourceview/0.1.0/language-specs/cwhip.lang"]
        before = [path.stat().st_mtime_ns for path in outputs]
        result = run([setup], cwd=work, env=env,
                     input="build && printf 'BUILD_RETURNED\\n'\nexit $?\n")
        assert "BUILD_RETURNED" in result.stdout, result
        assert before == [path.stat().st_mtime_ns for path in outputs]
        result = run([setup], cwd=work, env=env,
                     input="rebuild cedit && printf 'REBUILD_RETURNED\\n'\nexit $?\n")
        assert "REBUILD_RETURNED" in result.stdout, result
        assert before != [path.stat().st_mtime_ns for path in outputs]
        result = run([setup], cwd=work, env=env,
                     input="build no-such-target\nresult=$?\n"
                           "printf 'FAILED_BUILD_RETURNED\\n'\nexit \"$result\"\n",
                     success=False)
        assert "FAILED_BUILD_RETURNED" in result.stdout, result
        result = run([setup], cwd=work, env=env,
                     input="rebuild && printf 'REBUILD_DEFAULT_RETURNED\\n'\nexit $?\n")
        assert "REBUILD_DEFAULT_RETURNED" in result.stdout, result

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

        cache = (build / "CMakeCache.txt").read_text()
        install_prefix = next(
            line.split("=", 1)[1] for line in cache.splitlines()
            if line.startswith("CMAKE_INSTALL_PREFIX:")
        )
        default_stage = work / "default install stage"
        run([args.cmake, "--install", str(build)], cwd=work,
            env=dict(env, DESTDIR=str(default_stage)))
        staged_app = default_stage / install_prefix.lstrip("/")
        assert (staged_app / "bin/cedit").is_file()
        assert (staged_app / "bin/cedit.bin").is_file()
        run(["python3", str(source / "tests/test_smoke.py"),
             "--executable", str(staged_app / "bin/cedit"),
             "--xvfb", args.xvfb,
             "--work", str(work / "default staged smoke")], cwd=work, env=env)


if __name__ == "__main__":
    main()
