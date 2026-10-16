"""Creates thumbnails for uploaded images. Run every minute by cron."""
import subprocess
from pathlib import Path

import yaml

UPLOADS = Path(__file__).resolve().parent.parent / "uploads"
THUMBS = UPLOADS / "thumbs"


def load_options(image: Path) -> dict:
    """Reads optional per-image settings from a .yml file uploaded next to the image."""
    sidecar = image.with_suffix(".yml")
    if sidecar.exists():
        return yaml.load(sidecar.read_text(), Loader=yaml.Loader)
    return {"size": "200x200"}


def make_thumbnail(image: Path) -> None:
    options = load_options(image)
    subprocess.run(
        f"convert {image} -resize {options['size']} {THUMBS / image.name}",
        shell=True,
        check=True,
    )


def main() -> None:
    THUMBS.mkdir(exist_ok=True)
    for image in UPLOADS.iterdir():
        if image.suffix.lower() in {".png", ".jpg", ".jpeg"}:
            make_thumbnail(image)


if __name__ == "__main__":
    main()
