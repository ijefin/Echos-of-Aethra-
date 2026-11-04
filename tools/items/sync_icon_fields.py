"""Grava o campo "icon" em assets/data/items.json para todo item que tem PNG em
assets/items/icons/<id>.png (e ainda não tem "icon"). Preserva ordem, tab e CRLF.
Uso: python tools/items/sync_icon_fields.py [raiz_do_projeto]
Chamado por tools/bake_item_icons.sh depois do gerador de ícones."""
import json
import os
import sys

root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..")
items_path = os.path.join(root, "assets", "data", "items.json")
icon_dir = os.path.join(root, "assets", "items", "icons")

with open(items_path, "rb") as f:
    data = json.loads(f.read().decode("utf-8"))
added = []
for item_id, item in data["items"].items():
    if "icon" not in item and os.path.exists(os.path.join(icon_dir, item_id + ".png")):
        item["icon"] = "res://assets/items/icons/%s.png" % item_id
        added.append(item_id)
if added:
    text = json.dumps(data, indent="\t", ensure_ascii=False).replace("\n", "\r\n") + "\r\n"
    with open(items_path, "wb") as f:
        f.write(text.encode("utf-8"))
print("sync_icon_fields: icon em %d item(ns)%s" % (len(added), (": " + ", ".join(added)) if added else ""))
