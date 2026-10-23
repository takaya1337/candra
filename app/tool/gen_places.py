"""Writes app/assets/places/places.tsv, the named places a place can be
picked by, and app/assets/places/kecamatan.bin, the kecamatan's
outlines for the map, offline.

  python3 -I gen_places.py wilayah_level_1_2.sql kec/ cities15000.txt \
      countryInfo.txt admin1CodesASCII.txt ../assets/places/kecamatan.bin \
      > ../assets/places/places.tsv

Indonesia, to the kecamatan:
  * kabupaten and kota, their official names and coordinates, and the
    provinces' names, from cahyadsn/wilayah `db/wilayah_level_1_2.sql`
    (Kepmendagri No 300.2.2-2138 Tahun 2025, as its header states; MIT);
  * kecamatan, their official names and outlines, from
    cahyadsn/wilayah_boundaries `db/kec/*.sql` (Kepmendagri No
    300.2.2-2430 Tahun 2025, as its description states; MIT), each in the
    kabupaten or kota its code is under, placed at a point inside it: the
    file's own where that is inside, else the point farthest from its
    edges.
Everywhere else: GeoNames' towns of 15,000 people or more, with their
first-level division and country (CC BY 4.0).

Columns: name, the area it is in, ISO country code, latitude, longitude
(to a hundredth of a degree), and a rank to break ties (the population
where known). Indonesian places first, then the world by population.
"""
import glob
import heapq
import json
import math
import os
import re
import struct
import sys

level12, kec_dir, cities, country_info, admin1, kec_bin = sys.argv[1:7]

# --- Indonesia: provinces and kabupaten/kota from the decree's table.
provinces = {}
regencies = []  # (code, name, lat, lon, population, rings)
row = re.compile(
    r"^\('([\d.]+)','([^']*)','([^']*)',\s*([-\d.]+|NULL),\s*([-\d.]+|NULL),"
    r"\s*[-\d.]+,\s*[-\d.NUL]+,\s*[-\d.NUL]+,\s*([-\d.]+|NULL),\s*'(.*)',\s*[-\d]+\)[,;]?\s*$")
for line in open(level12, encoding='utf-8'):
    m = row.match(line)
    if not m:
        continue
    code, name, _, lat, lon, population, path = m.groups()
    if '.' not in code:
        provinces[code] = name
        continue
    rings = []
    try:
        shape = json.loads(path)
    except ValueError:
        shape = []

    def collect(node):
        if node and isinstance(node[0], (int, float)):
            return
        if node and isinstance(node[0], list) and node[0] and \
                isinstance(node[0][0], (int, float)):
            rings.append([(p[1], p[0]) for p in node])  # (lon, lat)
            return
        for child in node:
            collect(child)
    collect(shape)
    regencies.append((code, name, float(lat), float(lon),
                      0 if population == 'NULL' else int(float(population)),
                      rings))

# Short forms the government uses for the special regions.
province_names = {
    code: (name.replace('Daerah Khusus Ibukota ', 'DKI ')
           .replace('Daerah Istimewa ', 'DI '))
    for code, name in provinces.items()
}


def inside(rings, x, y):
    hit = False
    for ring in rings:
        for (x1, y1), (x2, y2) in zip(ring, ring[1:] + ring[:1]):
            if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
                hit = not hit
    return hit


boxes = []
for r in regencies:
    pts = [p for ring in r[5] for p in ring]
    if pts:
        boxes.append((min(p[0] for p in pts), max(p[0] for p in pts),
                      min(p[1] for p in pts), max(p[1] for p in pts), r))


def extent(rings):
    return sum(abs(sum(x1 * y2 - x2 * y1 for (x1, y1), (x2, y2)
                       in zip(ring, ring[1:] + ring[:1]))) / 2 for ring in rings)


def regency_of(lat, lon):
    # Some outlines still take in a kota carved out of them (Kabupaten
    # Tangerang holds Kota Tangerang Selatan): the smallest that holds the
    # point is its own.
    holding = [r for w, e, s, n, r in boxes
               if w <= lon <= e and s <= lat <= n and inside(r[5], lon, lat)]
    if holding:
        return min(holding, key=lambda r: extent(r[5]))
    # Off every boundary (a coast, an islet): the nearest seat.
    return min(regencies, key=lambda r: (r[2] - lat) ** 2 + (r[3] - lon) ** 2)


out = []
for code, name, lat, lon, population, _ in regencies:
    out.append((name, province_names[code.split('.')[0]], 'ID', lat, lon,
                population, 0, None))

regency_names = {r[0]: r[1] for r in regencies}


def polylabel(rings, precision=0.0005):
    """The point inside [rings] farthest from their edges (Mapbox's
    polylabel), as (lon, lat)."""
    def edge_distance(x, y):
        best = float('inf')
        for ring in rings:
            for (ax, ay), (bx, by) in zip(ring, ring[1:] + ring[:1]):
                dx, dy = bx - ax, by - ay
                t = 0.0
                if dx or dy:
                    t = max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) /
                                     (dx * dx + dy * dy)))
                px, py = ax + t * dx - x, ay + t * dy - y
                best = min(best, px * px + py * py)
        d = math.sqrt(best)
        return d if inside(rings, x, y) else -d

    xs = [p[0] for ring in rings for p in ring]
    ys = [p[1] for ring in rings for p in ring]
    w, e, s_, n = min(xs), max(xs), min(ys), max(ys)
    size = max(e - w, n - s_)
    if size == 0:
        return xs[0], ys[0]
    h = size / 2
    cells = []

    def push(x, y, h):
        d = edge_distance(x, y)
        heapq.heappush(cells, (-(d + h * math.sqrt(2)), d, x, y, h))

    x = w
    while x < e:
        y = s_
        while y < n:
            push(x + h, y + h, h)
            y += size
        x += size
    best = (edge_distance((w + e) / 2, (s_ + n) / 2), (w + e) / 2, (s_ + n) / 2)
    while cells:
        bound, d, x, y, h = heapq.heappop(cells)
        if d > best[0]:
            best = (d, x, y)
        if -bound - best[0] <= precision:
            continue
        h /= 2
        for ox in (-h, h):
            for oy in (-h, h):
                push(x + ox, y + oy, h)
    return best[1], best[2]


kec_row = re.compile(
    r"^\s*\('([\d.]+)','((?:[^']|'')*)',\s*([-\d.]+|NULL),\s*([-\d.]+|NULL),"
    r"\s*'(.*)'\)[,;]?\s*$")
kecamatan = []  # (code, name, lat, lon, rings)
moved = 0
for path in sorted(glob.glob(os.path.join(kec_dir, '*.sql'))):
    for line in open(path, encoding='utf-8'):
        m = kec_row.match(line)
        if not m:
            continue
        code, name, lat, lon, shape = m.groups()
        name = name.replace("''", "'")
        rings = []

        def collect(node):
            if node and isinstance(node[0], list) and node[0] and \
                    isinstance(node[0][0], (int, float)):
                rings.append([(p[1], p[0]) for p in node])  # (lon, lat)
                return
            for child in node:
                collect(child)
        collect(json.loads(shape))
        # A ring closed on itself repeats its first point: once is enough.
        rings = [r[:-1] if len(r) > 1 and r[0] == r[-1] else r for r in rings]
        rings = [r for r in rings if len(r) >= 3]
        lat = None if lat == 'NULL' else float(lat)
        lon = None if lon == 'NULL' else float(lon)
        if lat is None or not inside(rings, lon, lat):
            lon, lat = polylabel(rings)
            moved += 1
        kecamatan.append((code, name, lat, lon, rings))

for code, name, lat, lon, _ in kecamatan:
    regency = '.'.join(code.split('.')[:2])
    area = f"{regency_names[regency]}, {province_names[code.split('.')[0]]}"
    out.append((name, 'Kecamatan · ' + area, 'ID', lat, lon, 0, 1, code))
print(f'{len(kecamatan)} kecamatan, {moved} moved inside', file=sys.stderr)

# --- The world.
countries = {}
for line in open(country_info, encoding='utf-8'):
    if line.startswith('#'):
        continue
    f = line.rstrip('\n').split('\t')
    countries[f[0]] = f[4]
divisions = {}
for line in open(admin1, encoding='utf-8'):
    f = line.rstrip('\n').split('\t')
    divisions[f[0]] = f[1]
for line in open(cities, encoding='utf-8'):
    f = line.rstrip('\n').split('\t')
    cc = f[8]
    if cc == 'ID':
        continue
    division = divisions.get(f'{cc}.{f[10]}', '')
    country = countries.get(cc, cc)
    area = f'{division}, {country}' if division and division != f[1] else country
    out.append((f[1], area, cc, float(f[4]), float(f[5]), int(f[14] or 0), 2,
                None))

out.sort(key=lambda p: (p[6], -p[5], p[0]))
print('name\tarea\tcountry\tlat\tlon\trank')
for name, area, cc, lat, lon, population, _, _ in out:
    clean = lambda s: s.replace('\t', ' ').replace('\n', ' ')
    print(f'{clean(name)}\t{clean(area)}\t{cc}\t{lat:.2f}\t{lon:.2f}\t{population}')
print(f'{len(out)} places', file=sys.stderr)

# --- The kecamatan's outlines, each with the row it is in the file:
# a count, then for each its row, its rings, and for each ring its
# points, the first in ten-thousandths of a degree (longitude, latitude,
# 32 bits) and each after as the step from the one before (16 bits).
rows = {p[7]: i for i, p in enumerate(out) if p[7]}
blob = bytearray(struct.pack('<I', len(kecamatan)))
for code, _, _, _, rings in kecamatan:
    blob += struct.pack('<IH', rows[code], len(rings))
    for ring in rings:
        q = [(round(x * 1e4), round(y * 1e4)) for x, y in ring]
        blob += struct.pack('<Hii', len(q), *q[0])
        for (x0, y0), (x1, y1) in zip(q, q[1:]):
            dx, dy = x1 - x0, y1 - y0
            assert -32768 <= dx < 32768 and -32768 <= dy < 32768, code
            blob += struct.pack('<hh', dx, dy)
open(kec_bin, 'wb').write(blob)
print(f'{len(blob)} bytes of outlines', file=sys.stderr)
