"""Fatia uma tira horizontal de N quadros gerada por IA (sem grade exata) em frames
alinhados pelos pés, reduz para a resolução do jogo e atualiza o manifesto sprite8.

  python tools/art/slice_strip.py SRC.png --frames 16 --scale 0.2 --anim idle --dir s \
      --fps 10 --out assets/art/chars/fire_mage --prefix fire_mage \
      --manifest assets/data/sprites_fire_mage.json

Cada quadro é recortado nas divisões iguais da tira; o centro dos pés (faixa inferior do
recorte) vira o x do pivô e a linha mais baixa vira o y. Alfa binário (art bible §8).
"""
import argparse, json, os
from PIL import Image

p = argparse.ArgumentParser()
p.add_argument("src"); p.add_argument("--frames", type=int, required=True)
p.add_argument("--scale", type=float, required=True); p.add_argument("--anim", required=True)
p.add_argument("--dir", required=True); p.add_argument("--fps", type=float, default=10.0)
p.add_argument("--out", required=True); p.add_argument("--prefix", required=True)
p.add_argument("--manifest", required=True)
p.add_argument("--feet_band", type=float, default=0.12, help="fração inferior usada para achar os pés")
p.add_argument("--cell", type=int, nargs=2, default=[64, 64]); p.add_argument("--pivot", type=int, nargs=2, default=[32, 60])
a = p.parse_args()

src = Image.open(a.src).convert("RGBA")
W, H = src.size
step = W / a.frames
solid = lambda im: im.split()[3].point(lambda v: 255 if v > 128 else 0)
full = solid(src).getbbox()
band_top = int(full[3] - (full[3] - full[1]) * a.feet_band)
os.makedirs(a.out, exist_ok=True)
rel = a.out.replace("\\", "/").split("assets/art/", 1)[1].rstrip("/")


def _drop_edge_bits(im):
    """Apaga manchas que tocam a borda lateral do recorte (pedaços do quadro vizinho)."""
    px, w, h = im.load(), im.width, im.height
    seen = set()
    for x0 in (0, w - 1):
        for y0 in range(h):
            if px[x0, y0][3] == 0 or (x0, y0) in seen:
                continue
            stack, comp = [(x0, y0)], []
            seen.add((x0, y0))
            while stack:
                x, y = stack.pop()
                comp.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and px[nx, ny][3]:
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            if len(comp) < w * h * 0.05:  # o corpo principal nunca é tão pequeno
                for x, y in comp:
                    px[x, y] = (0, 0, 0, 0)


paths = []
for i in range(a.frames):
    x0, x1 = round(i * step), round((i + 1) * step)
    crop = src.crop((x0, 0, x1, H))
    feet = solid(crop.crop((0, band_top, x1 - x0, H))).getbbox()
    fx, fy = (feet[0] + feet[2]) / 2.0, band_top + feet[3]
    small = crop.resize((max(1, round(crop.width * a.scale)), max(1, round(H * a.scale))), Image.BOX)
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            r, g, b, al = px[x, y]
            px[x, y] = (r, g, b, 255 if al > 127 else 0)
    _drop_edge_bits(small)
    cell = Image.new("RGBA", tuple(a.cell))
    cell.alpha_composite(small, (round(a.pivot[0] - fx * a.scale), round(a.pivot[1] - fy * a.scale)))
    name = "%s_%s_%s_%02d.png" % (a.prefix, a.anim, a.dir, i)
    cell.save(os.path.join(a.out, name))
    paths.append("%s/%s" % (rel, name))

m = json.load(open(a.manifest, encoding="utf-8")) if os.path.exists(a.manifest) else {"anims": {}, "dirs": {}, "mirror": {}}
m["pivot"] = list(a.pivot)
m["anims"].setdefault(a.anim, {"dirs": {}, "mirror": {}})
m["anims"][a.anim]["fps"] = a.fps
m["anims"][a.anim]["dirs"][a.dir] = paths
if a.anim == "idle":
    m["dirs"][a.dir] = paths[0]
json.dump(m, open(a.manifest, "w", encoding="utf-8"), indent="\t", ensure_ascii=False)
print("slice_strip: %d frames -> %s (%s)" % (a.frames, a.out, a.manifest))
