#!/usr/bin/env python3
import socket
import os
import sys

def main():
    xdg = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    sock_path = f"{xdg}/hypr/{sig}/.socket2.sock"

    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(sock_path)
        f = s.makefile("r", buffering=1, encoding="utf-8", errors="replace")
        for line in f:
            sys.stdout.write(line)
            sys.stdout.flush()
    except Exception as e:
        sys.stderr.write(f"hypr-events error: {e}\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
