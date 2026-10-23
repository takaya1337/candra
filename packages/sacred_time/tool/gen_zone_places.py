"""Writes app/assets/bazi/zone_places.v1.json from the tz database's
zone.tab: for each time zone, the longitude of the city it is named for.

  python3 gen_zone_places.py /usr/share/zoneinfo > \
      ../../../app/assets/bazi/zone_places.v1.json
"""
import json
import re
import sys

root = sys.argv[1]
version = open(f'{root}/+VERSION').read().strip()
zones = {}
for line in open(f'{root}/zone.tab'):
    if line.startswith('#'):
        continue
    _, coordinates, zone = line.rstrip('\n').split('\t')[:3]
    # +DDMM+DDDMM or +DDMMSS+DDDMMSS; only the longitude is wanted.
    lon = re.match(r'[+-]\d+([+-])(\d{3})(\d{2})(\d{2})?$', coordinates)
    degrees = int(lon[2]) + int(lon[3]) / 60 + int(lon[4] or 0) / 3600
    zones[zone] = round(degrees * (-1 if lon[1] == '-' else 1), 1)

print(json.dumps({
    'schema': 1,
    'name': 'zone_places',
    'id': 'tz.v1',
    'source': f'IANA time zone database {version}, zone.tab (public domain)',
    'notes': 'Degrees east of Greenwich of the city each zone is named '
             'for, to a tenth of a degree. A zone covers far more than its '
             'city: the longitude is a starting point, to be put right for '
             'the actual place.',
    'longitudes': dict(sorted(zones.items())),
}, ensure_ascii=False, indent=1))
