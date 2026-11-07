"""Check active 3D boundaries and migration references without reading archives."""
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
TEXT = {'.gd', '.tscn', '.tres', '.json', '.gdshader', '.gdshaderinc', '.sh', '.ps1', '.yaml', '.service'}
errors = []
checked = 0
for directory in ['src', 'tests', 'tools', 'server', 'assets/world', 'data/world']:
    for path in (ROOT / directory).rglob('*'):
        relative = path.relative_to(ROOT).as_posix()
        if relative.startswith('tools/studio/') or not path.is_file():
            continue
        if path.suffix not in TEXT and path.name not in ['Dockerfile', 'Dockerfile.dockerignore']:
            continue
        text = path.read_text(encoding='utf-8-sig')
        checked += 1
        if 'prototypes/pixel3d/' in text or 'res://legacy/' in text:
            errors.append(f'{relative}: references inactive runtime path')
        if relative.startswith('src/world/') and 'res://src/game/' in text:
            errors.append(f'{relative}: reusable world depends on game')
        for resource in re.findall(r'(?:load|preload)\("(res://[^"\n]+)"\)', text):
            if not (ROOT / resource.removeprefix('res://')).exists():
                errors.append(f'{relative}: missing resource {resource}')

for directory in ['legacy', 'tools/studio']:
    if not (ROOT / directory / '.gdignore').exists():
        errors.append(f'{directory}: missing .gdignore')
if 'run/main_scene="res://src/game/pixel3d_demo.tscn"' not in (ROOT / 'project.godot').read_text():
    errors.append('project.godot: default scene must be the 3D game')
if len((ROOT / 'AGENTS.md').read_bytes()) > 6000:
    errors.append('AGENTS.md: exceeds 6000-byte orientation budget; move detail to references')
settings = json.loads((ROOT / '.claude/settings.json').read_text(encoding='utf-8-sig'))
if settings.get('hooks') or settings.get('statusLine'):
    errors.append('.claude/settings.json: studio automation is active again')

for message in errors:
    print(f'FAIL {message}')
print(f'STRUCTURE: {checked} files checked, {len(errors)} errors')
sys.exit(bool(errors))
