"""Decode a Factorio blueprint string and extract build costs and foundation shapes.

Usage:
    python decode_blueprint.py <ship_name>

Example:
    python decode_blueprint.py hexaclysm

Reads data/blueprints/<ship_name>-string.lua and writes:
  - data/blueprints/<ship_name>-cost.lua
  - data/blueprints/<ship_name>-foundations.lua
"""

import argparse
import base64
import json
import re
import sys
import zlib
from collections import defaultdict
from pathlib import Path

BLUEPRINTS_DIR = Path(__file__).parent / "data" / "blueprints"


def read_blueprint_string(ship_name: str) -> str:
    """Read the raw Factorio blueprint string from the ship's Lua string file.

    Args:
        ship_name (str): The ship identifier, e.g. "hexaclysm".

    Returns:
        str: The raw blueprint string (starting with version prefix character).

    Raises:
        SystemExit: If the file is missing or the string cannot be extracted.
    """
    path = BLUEPRINTS_DIR / f"{ship_name}-string.lua"
    if not path.exists():
        print(f"Error: file not found: {path}", file=sys.stderr)
        sys.exit(1)
    text = path.read_text(encoding="utf-8")
    match = re.search(r'"(.*?)"', text, re.DOTALL)
    if not match:
        print(f"Error: could not extract string from {path}", file=sys.stderr)
        sys.exit(1)
    return match.group(1)


def decode_blueprint(bp_string: str) -> dict:
    """Decode a Factorio blueprint string into a Python dictionary.

    Factorio blueprint strings are: version_char + base64(zlib(json)).

    Args:
        bp_string (str): Raw Factorio blueprint string with version prefix.

    Returns:
        dict: Decoded blueprint data with keys like "blueprint" containing
              "entities" and "tiles" lists.
    """
    compressed = base64.b64decode(bp_string[1:])
    return json.loads(zlib.decompress(compressed))


def compute_costs(blueprint: dict) -> list[tuple[str, int]]:
    """Compute item build costs from a decoded blueprint.

    Counts all entities and tiles by name, ignoring quality. Results are
    sorted alphabetically by item name.

    Args:
        blueprint (dict): Decoded blueprint dict from decode_blueprint().

    Returns:
        list[tuple[str, int]]: Sorted list of (item_name, count) pairs.

    Example:
        [("assembling-machine-3", 2), ("space-platform-foundation", 1336)]
    """
    counts: defaultdict[str, int] = defaultdict(int)
    bp = blueprint.get("blueprint", blueprint)
    for entity in bp.get("entities", []):
        counts[entity["name"]] += 1
    for tile in bp.get("tiles", []):
        counts[tile["name"]] += 1
    counts.pop("space-platform-hub", None)
    return sorted(counts.items())


def compute_foundations(blueprint: dict) -> list[tuple[int, int, int]]:
    """Compute compressed row data for space-platform-foundation tiles.

    Groups foundation tiles by Y coordinate and computes the min and max X
    for each row, producing a compact run-length-like representation.

    Args:
        blueprint (dict): Decoded blueprint dict from decode_blueprint().

    Returns:
        list[tuple[int, int, int]]: List of (y, min_x, max_x) tuples sorted
            by y coordinate, where min_x and max_x are inclusive tile bounds.

    Example:
        [(-24, -1, 0), (-23, -2, 1), (-22, -5, 4)]
    """
    bp = blueprint.get("blueprint", blueprint)
    rows: defaultdict[int, list[int]] = defaultdict(list)
    for tile in bp.get("tiles", []):
        if tile["name"] == "space-platform-foundation":
            rows[int(tile["position"]["y"])].append(int(tile["position"]["x"]))
    return [(y, min(xs), max(xs)) for y, xs in sorted(rows.items())]


def format_costs(costs: list[tuple[str, int]]) -> str:
    """Format build costs as a minified single-line Lua return statement.

    Args:
        costs (list[tuple[str, int]]): Sorted (item_name, count) pairs.

    Returns:
        str: Minified Lua source, e.g. return {{"iron-plate",5},{"pipe",3}}
    """
    entries = ",".join(f'{{"{name}",{count}}}' for name, count in costs)
    return f"return {{{entries}}}"


def format_foundations(foundations: list[tuple[int, int, int]]) -> str:
    """Format foundation row data as a minified single-line Lua return statement.

    Args:
        foundations (list[tuple[int, int, int]]): Sorted (y, min_x, max_x) tuples.

    Returns:
        str: Minified Lua source, e.g. return {{-1,-5,4},{0,-6,5}}
    """
    entries = ",".join(f"{{{y},{min_x},{max_x}}}" for y, min_x, max_x in foundations)
    return f"return {{{entries}}}"


def main():
    """Parse arguments, decode the blueprint, and write cost and foundation files.

    Example:
        python decode_blueprint.py hexaclysm
    """
    parser = argparse.ArgumentParser(
        description="Decode a Factorio blueprint string into cost and foundation Lua data files."
    )
    parser.add_argument("ship_name", help='Ship name matching the string file, e.g. "hexaclysm"')
    args = parser.parse_args()

    bp_string = read_blueprint_string(args.ship_name)
    blueprint = decode_blueprint(bp_string)

    costs = compute_costs(blueprint)
    foundations = compute_foundations(blueprint)

    cost_path = BLUEPRINTS_DIR / f"{args.ship_name}-cost.lua"
    foundations_path = BLUEPRINTS_DIR / f"{args.ship_name}-foundations.lua"

    cost_path.write_text(format_costs(costs), encoding="utf-8")
    foundations_path.write_text(format_foundations(foundations), encoding="utf-8")

    print(f"Wrote {cost_path}")
    print(f"Wrote {foundations_path}")


if __name__ == "__main__":
    main()
