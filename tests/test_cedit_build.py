"""Build the real editor target and require an unchanged second invocation."""

import argparse
from pathlib import Path
import subprocess
import tempfile

from program_runner import environment


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--cmake", required=True)
    parser.add_argument("--executable", type=Path, required=True)
    parser.add_argument("--compiler", type=Path, required=True)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="cedit build environment ") as directory:
        env = environment(Path(directory))
        command = [args.cmake, "--build", str(args.build), "--target", "cedit"]
        subprocess.run(command, check=True, env=env, timeout=80)
        assert args.executable.name == "cedit", args.executable
        outputs = (args.executable, args.compiler)
        before = [path.stat().st_mtime_ns for path in outputs]
        subprocess.run(command, check=True, env=env, timeout=80)
        after = [path.stat().st_mtime_ns for path in outputs]
        assert before == after, f"No-op cedit build rewrote outputs: {before} -> {after}"


if __name__ == "__main__":
    main()
