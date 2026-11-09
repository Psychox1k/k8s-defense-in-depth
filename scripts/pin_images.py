#!/usr/bin/env python3
"""Pin container images in k8s manifests to immutable digests.

A tag such as `latest` can point to a different image tomorrow, which would silently change
the lab between two experiment runs. A digest (`repo@sha256:...`) always means the same image.

Usage:
    python3 scripts/pin_images.py           pin every image that is not pinned yet
    python3 scripts/pin_images.py --check   only list unpinned images, exit 1 if there are any

How it works: for each `image: repo:tag` line the script runs `docker pull`, reads the digest
Docker recorded for it and rewrites the line to `image: repo@sha256:...  # pinned from repo:tag`.
To upgrade an image later, put the new tag back into the manifest and run the script again.
"""
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IMAGE_LINE = re.compile(r"^(?P<prefix>\s*image:\s*)(?P<ref>[^\s#]+)(?P<rest>\s*#.*)?$")


def manifests() -> list:
    return sorted((ROOT / "k8s").rglob("*.yaml"))


def unpinned_refs() -> dict:
    """Return {image reference: [manifest paths]} for images without a digest."""
    found = {}
    for path in manifests():
        for line in path.read_text().splitlines():
            match = IMAGE_LINE.match(line)
            if match and "@sha256:" not in match.group("ref"):
                found.setdefault(match.group("ref"), []).append(path)
    return found


def resolve_digest(ref: str) -> str:
    print(f"  pulling {ref} ...", flush=True)
    subprocess.run(["docker", "pull", "--quiet", ref], check=True, stdout=subprocess.DEVNULL)
    out = subprocess.run(
        ["docker", "image", "inspect", "--format", "{{index .RepoDigests 0}}", ref],
        check=True, capture_output=True, text=True,
    ).stdout.strip()
    if "@sha256:" not in out:
        raise RuntimeError(f"no digest reported for {ref}: {out!r}")
    return out


def rewrite(path: Path, pinned: dict) -> None:
    lines = path.read_text().splitlines()
    for i, line in enumerate(lines):
        match = IMAGE_LINE.match(line)
        if match and match.group("ref") in pinned:
            ref = match.group("ref")
            lines[i] = f"{match.group('prefix')}{pinned[ref]}  # pinned from {ref} on {date.today()}"
    path.write_text("\n".join(lines) + "\n")


def main() -> int:
    refs = unpinned_refs()
    if not refs:
        print("All images are pinned to digests.")
        return 0
    if "--check" in sys.argv[1:]:
        print("Images not pinned to a digest:")
        for ref, paths in refs.items():
            print(f"  {ref}  ({', '.join(str(p.relative_to(ROOT)) for p in paths)})")
        return 1

    pinned = {}
    for ref in refs:
        try:
            pinned[ref] = resolve_digest(ref)
        except (subprocess.CalledProcessError, RuntimeError, FileNotFoundError) as err:
            print(f"Error: cannot pin {ref}: {err}", file=sys.stderr)
            print("Is Docker (OrbStack) running?", file=sys.stderr)
            return 1
    for path in manifests():
        rewrite(path, pinned)
    print("Pinned:")
    for ref, digest in pinned.items():
        print(f"  {ref} -> {digest}")
    print("Review with 'git diff', then run 'make waf-reload' and 'make attack'.")
    return 0


if __name__ == "__main__":
    sys.exit(main())