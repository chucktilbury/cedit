"""Exercise the actual launcher/application and bundled syntax resources."""

import argparse
from pathlib import Path
import tempfile

from gtk_support import headless
from program_runner import environment, invoke


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--executable", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--xvfb", required=True)
    args = parser.parse_args()
    args.work.mkdir(parents=True, exist_ok=True)
    for custom in (False, True):
        with tempfile.TemporaryDirectory(dir=args.work, prefix="smoke-") as directory:
            work = Path(directory)
            for name in ("editor-a.cw", "editor-b.cw"):
                (work / name).write_text('start { print("ok") }\n')
            if custom:
                (work / "cwhip-shortcuts.conf").write_text(
                    "<Control><Alt>s=save\n<Control><Alt>s=open\n")
            with headless(args.xvfb, work, environment(work)) as env:
                result = invoke([str(args.executable.resolve()), "--test",
                                 "editor-a.cw", "editor-b.cw", "editor-a.cw"],
                                work, env)
                assert result.returncode == 0 and result.stdout == "true" and not result.stderr, result


if __name__ == "__main__":
    main()
