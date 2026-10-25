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
        diagnostic("CEDIT0001", "usage: sdk-prefix.py SETTINGS_FILE_OR_CONFIG_DIRECTORY")
        return 2
    location = Path(sys.argv[1])
    try:
        import tomllib
    except ModuleNotFoundError:
        diagnostic("CEDIT2001",
                   f"{location}: reading sdk_prefix requires Python 3.11 or newer")
        return 1

    # An existing sdk.toml is authoritative; the legacy shared settings.toml is
    # consulted only when sdk.toml is absent. Nothing is ever written.
    settings_files = ([location / "sdk.toml", location / "settings.toml"]
                      if location.is_dir() else [location])
    for settings in settings_files:
        try:
            prefix = read_prefix(settings, tomllib)
        except FileNotFoundError:
            if settings.is_symlink():
                diagnostic("CEDIT2001", f"{settings}: cannot read sdk_prefix: dangling link")
                return 1
            if location.is_dir():
                continue
            diagnostic("CEDIT2001", f"{settings}: cannot read sdk_prefix: file not found")
            return 1
        except (OSError, ValueError) as error:
            diagnostic("CEDIT2001", f"{settings}: cannot read sdk_prefix: {error}")
            return 1
        sys.stdout.write(prefix)
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
