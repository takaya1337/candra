"""Writes app/assets/stars/galaxies.tsv: the galaxies the star map can
show and find, from OpenNGC (Mattia Verga, CC BY-SA 4.0):
`database_files/NGC.csv` and `addendum.csv` (the Magellanic Clouds and
other objects outside NGC and IC).

  python3 -I gen_galaxies.py NGC.csv addendum.csv > \
      ../assets/stars/galaxies.tsv

Kept: every object of type G (a galaxy) of visual magnitude 10 or
brighter (B less 0.8 where only B is given), and every Messier galaxy.

Columns: name (the first common name, else the Messier, NGC or IC
designation), designations, J2000 right ascension and declination in
degrees, visual magnitude, major and minor axis in arc minutes,
position angle in degrees, constellation; brightest first.
"""
import csv
import sys


def degrees(text, hours):
    sign = -1 if text.startswith('-') else 1
    parts = [float(p) for p in text.lstrip('+-').split(':')]
    value = parts[0] + parts[1] / 60 + parts[2] / 3600
    return sign * value * (15 if hours else 1)


def designation(name):
    for prefix in ('NGC', 'IC'):
        if name.startswith(prefix):
            return f'{prefix} {int(name[len(prefix):].rstrip("ABCDEFGHIJKLMNOPQRSTUVWXYZ") or 0)}'
    return name


out = []
for path in sys.argv[1:3]:
    for r in csv.DictReader(open(path, encoding='utf-8'), delimiter=';'):
        if r['Type'] != 'G':
            continue
        v, b = r['V-Mag'], r['B-Mag']
        mag = float(v) if v else (float(b) - 0.8 if b else 99.0)
        messier = r['M'].lstrip('0')
        if mag > 10 and not messier:
            continue
        names = [n for n in r['Common names'].split(',') if n]
        ids = ([f'M {messier}'] if messier else []) + [designation(r['Name'])]
        out.append((
            mag,
            names[0] if names else ids[0],
            ' · '.join(ids),
            degrees(r['RA'], True),
            degrees(r['Dec'], False),
            r['MajAx'] or '',
            r['MinAx'] or '',
            r['PosAng'] or '',
            r['Const'],
        ))
out.sort()
print('name\tdesignations\tra\tdec\tmag\tmajor\tminor\tangle\tcon')
for mag, name, ids, ra, dec, major, minor, angle, con in out:
    print(f'{name}\t{ids}\t{ra:.5f}\t{dec:.5f}\t{mag:.2f}\t{major}\t{minor}\t{angle}\t{con}')
print(f'{len(out)} galaxies', file=sys.stderr)
