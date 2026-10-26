"""Creates thumbnails for uploaded images. Run every minute by cron."""
import os
import re
import subprocess
from pathlib import Path

import yaml

# Same folder as the API, outside the deployed tree that scripts/deploy.sh replaces.
UPLOADS = Path(os.environ.get("UPLOAD_DIR", "/var/lib/tinyshop/uploads"))
THUMBS = UPLOADS / "thumbs"
FORMATS = {".png": "png", ".jpg": "jpeg", ".jpeg": "jpeg"}
SIZE = re.compile(r"\d{2,4}x\d{2,4}")


def load_options(image: Path) -> dict:
    """Reads optional per-image settings, keeping only values that pass validation."""
    options = {"size": "200x200"}
    sidecar = image.with_suffix(".yml")
    if sidecar.exists():
        loaded = yaml.safe_load(sidecar.read_text()) or {}
        if isinstance(loaded, dict) and SIZE.fullmatch(str(loaded.get("size", ""))):
            options["size"] = loaded["size"]
    return options


def make_thumbnail(image: Path) -> None:
    options = load_options(image)
    fmt = FORMATS[image.suffix.lower()]
    # Argument list, no shell. The explicit format prefix stops ImageMagick from guessing a decoder.
    subprocess.run(
        ["convert", f"{fmt}:{image}", "-resize", options["size"], str(THUMBS / image.name)],
        check=True,
        timeout=30,
    )


def main() -> None:
    THUMBS.mkdir(exist_ok=True)
    for image in UPLOADS.iterdir():
        if image.is_file() and image.suffix.lower() in FORMATS:
            # One broken upload must not stop thumbnails for everyone else.
            try:
                make_thumbnail(image)
            except (subprocess.SubprocessError, OSError, yaml.YAMLError) as error:
                print(f"thumbnail failed for {image.name}: {error}")


if __name__ == "__main__":
    main()
