"""Shared distribution destination, independent of the development checkout."""
import os
from pathlib import Path

DEFAULT_LATEST_BUILDS = Path.home() / "sw Dropbox/takano masahiro/Dropbox-shared/sw_app/Latest Builds"

def latest_builds_dir():
    value = os.environ.get("SW_APP_LATEST_BUILDS")
    return Path(value).expanduser().resolve() if value else DEFAULT_LATEST_BUILDS

if __name__ == "__main__":
    print(latest_builds_dir())
