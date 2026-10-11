#!/usr/bin/env python3
"""Center-screen message to everyone online, through the ValheimRcon plugin in this pod."""
import argparse
import os
import socket
import sys
import time

import rcon_client

# The HUD fades a center message after about 4 seconds and the game's RPC takes
# no duration, so a longer fade time means resending before it fades.
REFRESH_SECONDS = 3


def read_arguments():
    parser = argparse.ArgumentParser(description="Center-screen message to everyone online.")
    parser.add_argument("--size", type=int, help="text size; the game default is about 24")
    parser.add_argument("--fadetime", type=float, help="keep the message on screen this many seconds")
    parser.add_argument("message", nargs="+")
    return parser.parse_args()


def show_message(connection, text):
    return rcon_client.run_command(connection, "showMessage " + text)


def main():
    arguments = read_arguments()
    message = " ".join(arguments.message).strip()
    if arguments.size:
        message = "<size=" + str(arguments.size) + ">" + message + "</size>"
    connection = socket.create_connection(("127.0.0.1", int(os.environ["VALHEIM_RCON_PORT"])), timeout=10)
    try:
        rcon_client.login(connection, os.environ["VALHEIM_RCON_PASSWORD"])
    except PermissionError as error:
        sys.exit(str(error))
    print(show_message(connection, message))
    fade_deadline = time.monotonic() + (arguments.fadetime or 0)
    while time.monotonic() < fade_deadline - REFRESH_SECONDS:
        time.sleep(REFRESH_SECONDS)
        show_message(connection, message)


main()
