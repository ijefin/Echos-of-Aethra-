"""Fatia uma spritesheet exportada pelo Aseprite (JSON array + frameTags) em PNGs
por frame e gera o manifesto "sprite8" lido por PlayerAvatar._setup_dir8.

Tags no formato <anim>_<dir> (ex.: idle_s, walk_e). Direções faltantes:
"w" espelha "e" e as diagonais caem na direção mais próxima (feito no avatar).

Uso:
  python legacy/2d/tools/art/slice_aseprite_tags.py <sheet.json> <prefixo> <saida_art_rel> <manifesto.json>
  ex.: ... legacy/2d/assets/art/chars/mage/spr_mage_sheet.json mage chars/mage/frames sprites_mage.json
"""
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    sheet_json, prefix, out_rel, manifest_name = sys.argv[1:5]
    data = json.loads(Path(sheet_json).read_text(encoding="utf-8"))
    frames = data["frames"]
    sheet = Image.open(Path(sheet_json).parent / data["meta"]["image"]).convert("RGBA")
    out_dir = ROOT / "legacy/2d/assets/art" / out_rel
    out_dir.mkdir(parents=True, exist_ok=True)

    anims: dict = {}
    bottom = 0
    for tag in data["meta"]["frameTags"]:
        anim, d = tag["name"].rsplit("_", 1)
        paths = []
        durations = []
        for i in range(tag["from"], tag["to"] + 1):
            f = frames[i]
            r = f["frame"]
            img = sheet.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"]))
            bbox = img.getbbox()
            if bbox:
                bottom = max(bottom, bbox[3])
            name = f"{prefix}_{anim}_{d}_{i - tag['from']:02d}.png"
            img.save(out_dir / name)
            paths.append(f"{out_rel}/{name}")
            durations.append(f["duration"])
        a = anims.setdefault(anim, {"dirs": {}, "mirror": {}, "fps": 0.0})
        a["dirs"][d] = paths
        a["fps"] = round(1000.0 / (sum(durations) / len(durations)), 2)

    for a in anims.values():
        if "e" in a["dirs"] and "w" not in a["dirs"]:
            a["mirror"]["w"] = "e"

    w = frames[0]["frame"]["w"]
    first = anims.get("idle", next(iter(anims.values())))
    manifest = {
        "anims": anims,
        "dirs": {k: v[0] for k, v in first["dirs"].items()},
        "mirror": dict(first["mirror"]),
        # Pivô nos pés: centro horizontal, linha abaixo do pixel opaco mais baixo.
        "pivot": [w / 2, bottom],
    }
    out = ROOT / "assets/data" / manifest_name
    out.write_text(json.dumps(manifest, indent="\t"), encoding="utf-8")
    print(f"{sum(len(p) for a in anims.values() for p in a['dirs'].values())} frames -> {out_dir}")
    print(f"manifesto -> {out}  pivot={manifest['pivot']}")


if __name__ == "__main__":
    main()
