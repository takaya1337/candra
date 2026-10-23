"""Writes app/assets/places/world.bin: the countries' outlines for the
place map, from Natural Earth's 1:50m Admin 0 countries (public domain),
simplified for a phone (Douglas-Peucker, 0.03°) and kept in hundredths
of a degree.

  python3 -I gen_world_map.py ne_50m_admin_0_countries.geojson > \
      ../assets/places/world.bin

Format, little-endian: a uint32 count of rings; then for each ring a
uint16 count of points and the points as int16 pairs, longitude then
latitude, in hundredths of a degree.
"""
import json
import struct
import sys

TOLERANCE = 0.03


def simplify(points):
    if len(points) < 4:
        return points
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        a, b = stack.pop()
        (x1, y1), (x2, y2) = points[a], points[b]
        dx, dy = x2 - x1, y2 - y1
        length = (dx * dx + dy * dy) ** 0.5
        far, index = 0.0, None
        for i in range(a + 1, b):
            x, y = points[i]
            if length == 0:
                d = ((x - x1) ** 2 + (y - y1) ** 2) ** 0.5
            else:
                d = abs(dy * x - dx * y + x2 * y1 - y2 * x1) / length
            if d > far:
                far, index = d, i
        if index is not None and far > TOLERANCE:
            keep[index] = True
            stack += [(a, index), (index, b)]
    return [p for p, k in zip(points, keep) if k]


data = json.load(open(sys.argv[1], encoding='utf-8'))
rings = []
for feature in data['features']:
    g = feature['geometry']
    polygons = g['coordinates'] if g['type'] == 'MultiPolygon' else [g['coordinates']]
    for polygon in polygons:
        for ring in polygon[:1]:  # the outer edge; lakes are not drawn
            small = simplify([tuple(p[:2]) for p in ring])
            if len(small) >= 4:
                rings.append(small)

out = bytearray(struct.pack('<I', len(rings)))
points = 0
for ring in rings:
    out += struct.pack('<H', len(ring))
    for x, y in ring:
        out += struct.pack('<hh', round(x * 100), round(y * 100))
    points += len(ring)
sys.stdout.buffer.write(bytes(out))
print(f'{len(rings)} rings, {points} points', file=sys.stderr)
