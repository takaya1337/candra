#!/bin/bash
# Puts the iPhone's permission prompts into the app from
# assets/samples/showcase-strings.json (keys ios.permission.<Info.plist
# key>): the English into ios/Runner/Info.plist, the Indonesian into
# ios/Runner/id.lproj/InfoPlist.strings, which iOS uses on a phone set to
# Indonesian. An Indonesian left empty is left out, and the phone shows
# the English. Run it after changing either; test/permission_strings_test
# fails while the app and the file disagree.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import json, re
texts = json.load(open('assets/samples/showcase-strings.json'))
prefix = 'ios.permission.'
lines = ['/* The permission prompts in Indonesian, made by',
         '   tool/permission_strings.sh from assets/samples/showcase-strings.json.',
         '   Do not edit here. */', '']
for key, value in texts.items():
    if not key.startswith(prefix):
        continue
    name = key[len(prefix):]
    # The prompt's own line only, so the file keeps its order.
    plist = open('ios/Runner/Info.plist').read()
    escaped = (value['en'].replace('&', '&amp;').replace('<', '&lt;')
               .replace('>', '&gt;'))
    pattern = re.compile(r'(<key>' + re.escape(name) + r'</key>\s*<string>)(.*?)(</string>)', re.S)
    if not pattern.search(plist):
        raise SystemExit(f'{name} is not in Info.plist')
    plist = pattern.sub(lambda m: m.group(1) + escaped + m.group(3), plist, count=1)
    open('ios/Runner/Info.plist', 'w').write(plist)
    if value['id'].strip():
        quoted = value['id'].replace('\\', '\\\\').replace('"', '\\"')
        lines.append(f'"{name}" = "{quoted}";')
    else:
        lines.append(f'/* {name}: not written yet; the English is shown. */')
open('ios/Runner/id.lproj/InfoPlist.strings', 'w').write('\n'.join(lines) + '\n')
print('Info.plist and id.lproj/InfoPlist.strings written.')
PY
