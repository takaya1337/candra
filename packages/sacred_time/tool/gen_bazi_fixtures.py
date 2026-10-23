"""Writes test/bazi_oracle_fixtures.dart: charts worked out by two other
implementations, to hold this one against.

  lunar_python (6tail)  the four pillars of a Beijing clock time
  sxtwl (寿星天文历)      the instants of the twelve node terms

Neither is an authority; where one disagrees with this library the test
says why. Run with both installed:

  python3 -m venv venv && venv/bin/pip install lunar_python sxtwl
  venv/bin/python gen_bazi_fixtures.py > ../test/bazi_oracle_fixtures.dart
"""
import random
from datetime import datetime, timedelta

import sxtwl
from lunar_python import Solar
from lunar_python.util import LunarUtil

random.seed(8)
FIRST, LAST = 1900, 2100


def chart(t):
    solar = Solar.fromYmdHms(t.year, t.month, t.day, t.hour, t.minute, 0)
    eight = solar.getLunar().getEightChar()
    out = []
    # Sect 2: the hour before midnight keeps the day. Sect 1: it is
    # already the next day.
    for sect in (2, 1):
        eight.setSect(sect)
        out.append(eight.getYear() + eight.getMonth() + eight.getDay()
                   + eight.getTime())
    return out


def node_terms():
    """Every node term (節) as a Beijing clock time, from sxtwl."""
    found = []
    day = sxtwl.fromSolar(FIRST, 1, 1)
    while day.getSolarYear() <= LAST:
        # Odd indices are the nodes: 小寒 1, 立春 3, ...
        if day.hasJieQi() and day.getJieQi() % 2 == 1:
            t = sxtwl.JD2DD(day.getJieQiJD())
            second = int(t.s)
            found.append((day.getJieQi(), datetime(
                int(t.Y), int(t.M), int(t.D), int(t.h), int(t.m), second)))
        day = day.after(1)
    return found


terms = node_terms()
span = (datetime(LAST, 12, 31) - datetime(FIRST, 1, 1)).days

cases = {}


def add(kind, t):
    t = t.replace(second=0, microsecond=0)
    if FIRST <= t.year <= LAST:
        cases[(kind, t)] = chart(t)


# Anywhere.
for _ in range(3000):
    add('any', datetime(FIRST, 1, 1) + timedelta(
        days=random.randrange(span), minutes=random.randrange(1440)))
# Within two hours of a node term, clear of it by three minutes or more:
# closer than that the two libraries' own instants differ.
for _ in range(1500):
    _, at = random.choice(terms)
    off = random.randrange(3, 120) * random.choice((-1, 1))
    add('term', at + timedelta(minutes=off))
# The zi hour, both sides of midnight.
for _ in range(1500):
    day = datetime(FIRST, 1, 2) + timedelta(days=random.randrange(span - 2))
    add('zi', day + timedelta(hours=23, minutes=random.randrange(120)))
# Between the earliest lunar new year and the latest Lichun.
for _ in range(1000):
    year = random.randrange(FIRST, LAST + 1)
    add('newyear', datetime(year, 1, 20) + timedelta(
        minutes=random.randrange(32 * 1440)))

print('// Written by tool/gen_bazi_fixtures.py; do not edit by hand.')
print('//')
print('// Each chart: what kind of case it is, the Beijing clock time, the')
print('// four pillars by lunar_python with the hour before midnight kept')
print('// in the day (its sect 2), and with it given to the next (sect 1).')
print('const oracleCharts = <(String, int, int, int, int, int, String, String)>[')
for (kind, t), (keeps, next_day) in sorted(cases.items(), key=lambda c: c[0][1]):
    print(f"  ('{kind}', {t.year}, {t.month}, {t.day}, {t.hour}, {t.minute}, "
          f"'{keeps}', '{next_day}'),")
print('];')
print()
print('// Every node term from 1900 to 2100 by sxtwl: its index there (1 is')
print('// 小寒, 3 立春, ...) and its instant as a Beijing clock time.')
print('const oracleNodeTerms = <(int, int, int, int, int, int, int)>[')
for index, t in terms:
    print(f'  ({index}, {t.year}, {t.month}, {t.day}, {t.hour}, {t.minute}, '
          f'{t.second}),')
print('];')
print()
print('// The sixty pairs by lunar_python: the pair, its nayin (in simplified')
print('// characters, as that library writes it) and its void branches.')
print('const oracleCycle = <(String, String, String)>[')
for pair in LunarUtil.JIA_ZI:
    print(f"  ('{pair}', '{LunarUtil.NAYIN[pair]}', "
          f"'{LunarUtil.getXunKong(pair)}'),")
print('];')
