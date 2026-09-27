#!/usr/bin/env python3
"""Run by the gameserver's preStop: asks the server over RCON to save and shut down, then waits for it to exit."""
import os
import socket
import struct
import subprocess
import sys
import time

# https://developer.valvesoftware.com/wiki/Source_RCON_Protocol
AUTH_REQUEST, AUTH_RESPONSE, COMMAND_REQUEST = 3, 2, 2
# The game saves on exit. Its shutdown counts whole minutes, and 1 is the shortest it accepts.
SHUTDOWN_COMMAND = "shutdown 1 The server is restarting; the world is being saved."
SERVER_PROCESS = "VRisingServer.exe"
EXIT_WAIT_SECONDS = 150


def send_packet(connection, request_id, packet_type, body):
    payload = struct.pack("<ii", request_id, packet_type) + body.encode() + b"\x00\x00"
    connection.sendall(struct.pack("<i", len(payload)) + payload)


def read_exactly(connection, byte_count):
    data = b""
    while len(data) < byte_count:
        chunk = connection.recv(byte_count - len(data))
        if not chunk:
            raise ConnectionError("RCON closed the connection")
        data += chunk
    return data


def read_packet(connection):
    size = struct.unpack("<i", read_exactly(connection, 4))[0]
    request_id, packet_type = struct.unpack("<ii", read_exactly(connection, 8))
    body = read_exactly(connection, size - 8)[:-2].decode(errors="replace")
    return request_id, packet_type, body


def request_shutdown(port, password):
    with socket.create_connection(("127.0.0.1", port), timeout=10) as connection:
        send_packet(connection, 1, AUTH_REQUEST, password)
        request_id, packet_type = 0, None
        while packet_type != AUTH_RESPONSE:
            request_id, packet_type, _ = read_packet(connection)
        if request_id == -1:
            raise PermissionError("RCON refused the password")
        send_packet(connection, 2, COMMAND_REQUEST, SHUTDOWN_COMMAND)
        return read_packet(connection)[2]


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
