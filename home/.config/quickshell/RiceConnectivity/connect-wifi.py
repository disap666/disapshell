#!/usr/bin/python3
"""Receive a Wi-Fi password over stdin and pass it to NetworkManager privately."""
import subprocess
import sys
password = sys.stdin.readline().rstrip("\n")
if "\r" in password or "\n" in password:
    raise SystemExit("Invalid password")
result = subprocess.run(["nmcli", "--passwd-file", "/dev/stdin", "--wait", "25", "dev", "wifi", "connect", sys.argv[1]], input="802-11-wireless-security.psk:" + password + "\n", text=True)
raise SystemExit(result.returncode)
