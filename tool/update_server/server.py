"""Compatibility entry point; prefer `uv run vocechat-update-server`."""
from vocechat_update.server import ReleaseStore, UpdateServer, main, validate_release

if __name__ == "__main__":
    main()
