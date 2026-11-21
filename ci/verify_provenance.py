#!/usr/bin/env python3
import hashlib, json, pathlib
root=pathlib.Path(__file__).resolve().parents[1]
data=json.loads((root/'SOURCE_PROVENANCE.json').read_text())
errors=[]
for entry in data['files']:
    path=root/entry['path']
    if not path.is_file(): errors.append(f'missing: {entry["path"]}'); continue
    raw=path.read_bytes()
    if len(raw)!=entry['bytes']: errors.append(f'size mismatch: {entry["path"]}')
    if hashlib.sha256(raw).hexdigest()!=entry['sha256']: errors.append(f'SHA-256 mismatch: {entry["path"]}')
if errors: raise SystemExit('\n'.join(errors))
print(f'PASS: {len(data["files"])} upstream files match fixed-commit SHA-256 provenance')
