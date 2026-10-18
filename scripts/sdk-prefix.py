"""Read the installed SDK prefix without evaluating user configuration."""

import os
from pathlib import Path
import sys


def diagnostic(code, message):
    print(f"cedit: error[{code}]: {message}", file=sys.stderr)


def read_prefix(settings, tomllib):
    with settings.open("rb") as stream:
        config = tomllib.load(stream)
    if "sdk_prefix" not in config:
        return ""
    prefix = config["sdk_prefix"]
    if (
        not isinstance(prefix, str)
        or not prefix
        or any(character in prefix for character in "\0\r\n")
        or not os.path.isabs(prefix)
        or not os.path.isdir(prefix)
    ):
        raise ValueError(
            "sdk_prefix must be a non-empty absolute path to an existing SDK "
            "installation directory (without NUL or line breaks)"
        )
    return prefix


def main():
    if len(sys.argv) != 2:
        diagnostic("CEDIT0001", "usage: sdk-prefix.py CWHIP_CONFIG_DIRECTORY")
        return 2
    directory = Path(sys.argv[1])
    try:
        import tomllib
    except ModuleNotFoundError:
        diagnostic("CEDIT2001",
                   f"{directory}: reading sdk_prefix requires Python 3.11 or newer")
        return 1

    # An existing sdk.toml is authoritative; the legacy shared settings.toml is
    # consulted only when sdk.toml is absent. Nothing is ever written.
    for name in ("sdk.toml", "settings.toml"):
        settings = directory / name
        try:
            prefix = read_prefix(settings, tomllib)
        except FileNotFoundError:
            if settings.is_symlink():
                diagnostic("CEDIT2001", f"{settings}: cannot read sdk_prefix: dangling link")
                return 1
            continue
        except (OSError, ValueError) as error:
            diagnostic("CEDIT2001", f"{settings}: cannot read sdk_prefix: {error}")
            return 1
        sys.stdout.write(prefix)
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
