#!/usr/bin/env python3
"""Run by the gameserver's preStop: asks the server over RCON to save and shut down, then waits for it to exit."""
import os
import socket
import subprocess
import sys
import time

sys.path.insert(0, "/etc/game-hooks")  # rcon_client.py ships with the shared hook scripts
import rcon_client

# The game saves on exit. Its shutdown counts whole minutes, and 1 is the shortest it accepts.
SHUTDOWN_COMMAND = "shutdown 1 The server is restarting; the world is being saved."
SERVER_PROCESS = "VRisingServer.exe"
EXIT_WAIT_SECONDS = 150


def request_shutdown(port, password):
    with socket.create_connection(("127.0.0.1", port), timeout=10) as connection:
        rcon_client.login(connection, password)
        return rcon_client.run_command(connection, SHUTDOWN_COMMAND)


def is_server_running():
    return subprocess.run(["pgrep", "-f", SERVER_PROCESS], stdout=subprocess.DEVNULL).returncode == 0


def main():
    if not is_server_running():
        return
    try:
        # The same settings the image writes into ServerHostSettings.json.
        print(request_shutdown(int(os.environ["HOST_SETTINGS_Rcon__Port"]), os.environ["HOST_SETTINGS_Rcon__Password"]))
    except (OSError, KeyError, ValueError) as error:
        # Still starting, or RCON is off: SIGTERM follows and stops the server unsaved.
        print(f"save-and-stop: {error}", file=sys.stderr)
        return
    deadline = time.monotonic() + EXIT_WAIT_SECONDS
    while is_server_running() and time.monotonic() < deadline:
        time.sleep(2)


main()
