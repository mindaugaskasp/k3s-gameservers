#!/usr/bin/env python3
"""Run before each server start: a world that doesn't exist yet gets the seed in WORLD_SEED. The server has no
seed option; it loads a world whose metadata exists, or gives a new one a random seed (World.GetCreateWorld).
So this writes that metadata as World.SaveWorldFWLData does, and the server generates the world from it."""
import os
import random
import struct

WORLDS_DIR = "/config/worlds_local"
WORLD_METADATA_VERSION = 41
WORLD_GENERATOR_VERSION = 2


def to_int32(value):
    return (value + 2**31) % 2**32 - 2**31


def get_stable_hash_code(text):
    """Valheim's StringExtensionMethods.GetStableHashCode, which turns a seed name into the seed."""
    first = second = 5381
    index = 0
    while index < len(text) and text[index] != "\0":
        first = to_int32((to_int32(first << 5) + first) ^ ord(text[index]))
        if index == len(text) - 1 or text[index + 1] == "\0":
            break
        second = to_int32((to_int32(second << 5) + second) ^ ord(text[index + 1]))
        index += 2
    return to_int32(first + to_int32(second * 1566083941))


def encode_string(text):
    """As .NET's BinaryWriter writes a string: its UTF-8 length in 7-bit groups, then the bytes."""
    data = text.encode()
    length, prefix = len(data), bytearray()
    while True:
        prefix.append((length & 0x7F) | (0x80 if length > 0x7F else 0))
        length >>= 7
        if not length:
            return bytes(prefix) + data


def build_world_metadata(world_name, seed_name):
    unique_id = random.randint(1, 2**62)
    package = (
        struct.pack("<i", WORLD_METADATA_VERSION)
        + encode_string(world_name)
        + encode_string(seed_name)
        # seed, unique ID, generator version, no database yet, no starting keys, no player history
        + struct.pack("<iqi?ii", get_stable_hash_code(seed_name), unique_id, WORLD_GENERATOR_VERSION, False, 0, 0)
    )
    return struct.pack("<i", len(package)) + package


def main():
    seed_name = os.environ.get("WORLD_SEED", "")
    world_name = os.environ.get("WORLD_NAME", "")
    world_dir = f"{WORLDS_DIR}/{world_name}"
    if not seed_name or not world_name:
        return
    if os.path.exists(world_dir) or os.path.exists(f"{WORLDS_DIR}/{world_name}.fwl"):
        print(f"create-seeded-world: {world_name} already exists; its seed stays, WORLD_SEED only seeds a new world")
        return
    os.makedirs(world_dir)
    with open(f"{world_dir}/_main.0.fwl2", "wb") as metadata_file:
        metadata_file.write(build_world_metadata(world_name, seed_name))
    print(f"create-seeded-world: created {world_name} with seed {seed_name}")


main()
