import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

/// Candra's sigil drawing itself, ported from the logo maker
/// (`LOGOMAKER/candra`: `sigil.go` for the dial, `trace.go` for the
/// tracing, `promo.go` for the name rising under it, `lunation.go` for the
/// great crescent's month), so the app, the web page and the store's
/// videos move alike. Everything is in the logo maker's design units, a
/// square 1000 across, y down.
///
/// The tracing (the owner's order, 23 October 2026):
///
///  1. The five moons, one at a time, clockwise from the new moon: each
///     traced round, then waxing to its phase.
///  2. The bead ring through the moons, at one even pace.
///  3. The inner ring, from the new moon's direction.
///  4. The great crescent: a full moon swelling from its centre, then a
///     shadow sliding in from two o'clock and eclipsing it to the crescent.
class SigilGeometry {
  SigilGeometry._();

  static const n = 5;

  /// Each small moon's lit fraction, counterclockwise from the apex.
  static const phases = [0.5, 0.25, 0.0, 1.0, 0.75];

  static const centre = Offset(500, 500);
  static const _module = 22.0;

  /// A small moon's radius.
  static const dot = 2.25 * _module;

  /// The ring line, and the thread through the moons (as heavy).
  static const w = 0.2 * _module;
  static const thread = w;

  // The dial walked inward from r_outer 433.6 as `Resolve` does for the
  // shipped config: no rim, the outer ring not drawn, a band of 3 modules
  // with the moons centred in it, the inner ring one moon's radius clear
  // of them, the great moon one module inside the inner ring.
  static const _bandOut = 433.6 + w / 2 - w;

  /// The moons' centres, and the thread's.
  static const rDots = _bandOut - 3 * _module / 2;
  static const _bandIn = rDots - dot - 2.25 * _module;

  /// The inner ring's centreline.
  static const rInner = _bandIn - w / 2;
  static const _inEdge = _bandIn - w;

  /// The outermost ink: the moons.
  static const rimOut = rDots + dot;

  /// The great moon, concentric with the dial.
  static const rMoon = _inEdge - _module;
  static const rShadow = rMoon * 0.92;
  static const _shadowOffset = 0.26 * rMoon - rMoon + rShadow;

  /// The crescent's back: toward the third moon, about seven o'clock.
  static final backAngle = dotAngle(3);
  static Offset get moon => centre;
  static final shadow = polar(moon, _shadowOffset, backAngle + math.pi);

  /// The horns.
  static final (Offset, Offset) cusps = () {
    const d = _shadowOffset;
    const a = (d * d + rMoon * rMoon - rShadow * rShadow) / (2 * d);
    final h = math.sqrt(math.max(rMoon * rMoon - a * a, 0));
    final foot = polar(moon, a, backAngle + math.pi);
    return (
      polar(foot, h, backAngle + math.pi / 2),
      polar(foot, h, backAngle - math.pi / 2),
    );
  }();

  /// The small moons are lit from the right.
  static const light = 0.0;

  /// The direction of moon [k], 1-based, counted counterclockwise from
  /// the apex at twelve o'clock.
  static double dotAngle(int k) => -math.pi / 2 - (k - 1) * 2 * math.pi / n;

  static Offset polar(Offset c, double r, double angle) =>
      Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));

  /// The crescent's thickness at its middle, a share of the moon's radius.
  static double get thick =>
      (rMoon - (rShadow - (moon - shadow).distance)) / rMoon;
}

typedef _G = SigilGeometry;

/// One stroke of the tracing, in seconds from its start.
class _Step {
  final double start, duration;
  const _Step(this.start, this.duration);
  double get end => start + duration;

  /// How far it has got at [t], eased in and out.
  double eased(double t) {
    if (duration <= 0) return t >= start ? 1 : 0;
    final x = ((t - start) / duration).clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  /// The same, at one pace.
  double linear(double t) {
    if (duration <= 0) return 1;
    return ((t - start) / duration).clamp(0.0, 1.0);
  }
}

class _TraceMoon {
  final Offset centre;
  final double from, lit, threadFrom, threadTo;
  final _Step ring, wax;
  late _Step thread;
  _TraceMoon({
    required this.centre,
    required this.from,
    required this.lit,
    required this.ring,
    required this.wax,
    required this.threadFrom,
    required this.threadTo,
  });
}

/// The tracing laid out in time, as `NewTrace` lays it out.
class SigilTrace {
  // The pace, in seconds: the app's own (owner, 23 October 2026), quicker
  // than the logo maker's (0.5, 0.45, 0.45, 0.08, 2.6, 0.25, 1.6, 1.3,
  // 0.35, 2.0) where it is only drawing lines, and as slow where the
  // moons fill and the great moon swells and is eclipsed.
  static const _lead = 0.3;
  static const _moon = 0.32;
  static const _wax = 0.36;
  static const _pause = 0.06;
  static const _ring = 1.2;
  static const _breath = 0.14;
  static const _inner = 0.85;
  static const _full = 1.5;
  static const _hold = 0.3;
  static const _eclipse = 1.6;

  /// Where the shadow comes from: two o'clock, between the half moon and
  /// the gibbous.
  static const _shadowFrom = -30 * math.pi / 180;

  final _moons = <_TraceMoon>[];
  late final double innerFrom;
  late final _Step _innerStep, _fullStep, _eclipseStep;

  /// When the sigil is whole.
  late final double done;
  late final Offset shadowFrom;

  SigilTrace() {
    const n = SigilGeometry.n;
    // From the new moon (the least lit), clockwise: on screen, y down,
    // clockwise is a growing angle, which is the previous moon.
    var start = 1;
    for (var k = 2; k <= n; k++) {
      if (_G.phases[k - 1] < _G.phases[start - 1]) start = k;
    }
    // From a moon's centre to where the thread meets its ring.
    final half = 2 * math.asin((_G.dot - _G.thread / 2) / (2 * _G.rDots));
    var t = _lead;
    for (var i = 0; i < n; i++) {
      final k = (start - 1 - i + n * 4) % n + 1;
      final a = SigilGeometry.dotAngle(start) + i * 2 * math.pi / n;
      final d = SigilGeometry.polar(_G.centre, _G.rDots, a);
      final arrives = SigilGeometry.polar(_G.centre, _G.rDots, a - half);
      final lit = _G.phases[k - 1];
      final ring = _Step(t, _moon);
      t += _moon;
      final wax = _Step(t, lit > 0 ? _wax : 0);
      if (lit > 0) t += _wax;
      t += _pause;
      _moons.add(
        _TraceMoon(
          centre: d,
          from: math.atan2(arrives.dy - d.dy, arrives.dx - d.dx),
          lit: lit,
          ring: ring,
          wax: wax,
          threadFrom: a + half,
          threadTo: a + 2 * math.pi / n - half,
        ),
      );
    }
    // The bead ring at one pace: the pen passes behind each moon in the
    // time its gap would take.
    t += _breath;
    for (final m in _moons) {
      m.thread = _Step(
        t + (m.threadFrom - _moons.first.threadFrom) / (2 * math.pi) * _ring,
        (m.threadTo - m.threadFrom) / (2 * math.pi) * _ring,
      );
    }
    t += _ring + _breath;
    innerFrom = SigilGeometry.dotAngle(start);
    _innerStep = _Step(t, _inner);
    t += _inner + _breath;
    _fullStep = _Step(t, _full);
    _eclipseStep = _Step(t + _full + _hold, _eclipse);
    done = _eclipseStep.end;
    shadowFrom = SigilGeometry.polar(
      _G.moon,
      _G.rMoon + _G.rShadow + _G.thread * 2,
      _shadowFrom,
    );
  }

  static final instance = SigilTrace();
}

/// An open arc about [c] from [a0], sweeping [sweep] (clockwise if
/// positive).
Path _arc(Offset c, double r, double a0, double sweep) {
  final box = Rect.fromCircle(center: c, radius: r);
  // A whole turn is laid as two halves: as one arc its ends are one point
  // and it can come out as nothing, and as an oval the phone's renderer
  // dropped the inner ring (23 October 2026).
  if (sweep.abs() >= 2 * math.pi - 1e-9) {
    return Path()
      ..addArc(box, a0, math.pi)
      ..arcTo(box, a0 + math.pi, math.pi, false);
  }
  return Path()..addArc(box, a0, sweep);
}

/// The lit part of a small moon of radius [r], lit fraction [f], lit from
/// [light]: the limb and the true terminator, half an ellipse, so the lit
/// area is exactly [f] of the disc.
Path _phase(Offset c, double r, double f, double light) {
  final u = Offset(math.cos(light), math.sin(light));
  final v = Offset(-u.dy, u.dx);
  final e = (1 - 2 * f) * r;
  Offset at(double phi) =>
      c + v * (r * math.cos(phi)) + u * (e * math.sin(phi));
  Offset d(double phi) => v * (-r * math.sin(phi)) + u * (e * math.cos(phi));
  final s = at(math.pi);
  final p = Path()..moveTo(s.dx, s.dy);
  p.arcTo(
    Rect.fromCircle(center: c, radius: r),
    light - math.pi / 2,
    math.pi,
    false,
  );
  const k = 0.5522847498307936;
  for (var i = 0; i < 2; i++) {
    final p0 = i * math.pi / 2, p1 = (i + 1) * math.pi / 2;
    final a = at(p0), z = at(p1), da = d(p0), dz = d(p1);
    final c1 = a + da * k, c2 = z - dz * k;
    p.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, z.dx, z.dy);
  }
  return p..close();
}

Path _disc(Offset c, double r) =>
    Path()..addOval(Rect.fromCircle(center: c, radius: r));

/// The great crescent: the moon less the shadow.
Path _crescent([Offset? shadow]) => Path.combine(
  PathOperation.difference,
  _disc(SigilGeometry.moon, SigilGeometry.rMoon),
  _disc(shadow ?? SigilGeometry.shadow, SigilGeometry.rShadow),
);

/// The lit moon at [age] of a month (0 new): the limb between two horns
/// [beta] from the light's axis, closed by a circular terminator through
/// its middle point, as `moonShape` draws it. Also the lit fraction.
(Path?, double) _moonShape(
  Offset c,
  double r,
  double age,
  double light,
  double beta,
) {
  final frac = age - age.floorToDouble();
  final e = r * math.cos(2 * math.pi * frac);
  final f = (1 - e / r) / 2;
  if (frac >= 0.5) light += math.pi;
  if (f < 0.0005) return (null, f);
  final u = Offset(math.cos(light), math.sin(light));
  final v = Offset(-u.dy, u.dx);
  Offset at(double along, double across) => c + u * along + v * across;
  final hp = at(r * math.cos(beta), r * math.sin(beta));
  final hm = at(r * math.cos(beta), -r * math.sin(beta));
  final m = at(e, 0);
  final p = Path()..moveTo(hm.dx, hm.dy);
  p.arcTo(Rect.fromCircle(center: c, radius: r), light - beta, 2 * beta, false);
  final ax = hp.dx, ay = hp.dy, bx = m.dx, by = m.dy, cx = hm.dx, cy = hm.dy;
  final d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by));
  if (d.abs() < 1e-9 * r * r) {
    p.lineTo(hm.dx, hm.dy);
  } else {
    final ox =
        ((ax * ax + ay * ay) * (by - cy) +
            (bx * bx + by * by) * (cy - ay) +
            (cx * cx + cy * cy) * (ay - by)) /
        d;
    final oy =
        ((ax * ax + ay * ay) * (cx - bx) +
            (bx * bx + by * by) * (ax - cx) +
            (cx * cx + cy * cy) * (bx - ax)) /
        d;
    final rr = math.sqrt((ax - ox) * (ax - ox) + (ay - oy) * (ay - oy));
    final t0 = math.atan2(ay - oy, ax - ox);
    final tm = math.atan2(by - oy, bx - ox);
    final t1 = math.atan2(cy - oy, cx - ox);
    double norm(double x) {
      x %= 2 * math.pi;
      return x < 0 ? x + 2 * math.pi : x;
    }

    var sweep = norm(t1 - t0);
    if (norm(tm - t0) > sweep) sweep -= 2 * math.pi;
    const steps = 96;
    for (var i = 1; i <= steps; i++) {
      final a = t0 + sweep * i / steps;
      p.lineTo(ox + rr * math.cos(a), oy + rr * math.sin(a));
    }
  }
  return (p..close(), f);
}

/// Paints the sigil at moment [t] (seconds of the tracing), and from
/// [SigilTrace.done] on, if [lunation] is given, the great crescent going
/// once through its month every [lunation] seconds.
void paintSigil(
  Canvas canvas,
  double t,
  Color ink, {
  bool tips = true,
  double? lunation,
}) {
  final tr = SigilTrace.instance;
  final stroke = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = _G.thread
    ..isAntiAlias = true;
  final fill = Paint()
    ..color = ink
    ..isAntiAlias = true;
  void tip(Offset p) {
    if (tips) canvas.drawCircle(p, _G.thread * 1.4, fill);
  }

  for (final m in tr._moons) {
    final r = _G.dot - _G.thread / 2;
    final q = m.ring.eased(t);
    if (q > 0) {
      canvas.drawPath(_arc(m.centre, r, m.from, 2 * math.pi * q), stroke);
      if (q < 1) {
        tip(SigilGeometry.polar(m.centre, r, m.from + 2 * math.pi * q));
      }
    }
    if (m.lit > 0) {
      final w = m.wax.eased(t);
      if (w > 0) {
        canvas.drawPath(
          _phase(m.centre, _G.dot, math.max(0.004, m.lit * w), _G.light),
          fill,
        );
      }
    }
    final s = m.thread.linear(t);
    if (s > 0) {
      final sweep = (m.threadTo - m.threadFrom) * s;
      canvas.drawPath(_arc(_G.centre, _G.rDots, m.threadFrom, sweep), stroke);
      if (s < 1) {
        tip(SigilGeometry.polar(_G.centre, _G.rDots, m.threadFrom + sweep));
      }
    }
  }
  final i = tr._innerStep.eased(t);
  if (i > 0) {
    canvas.drawPath(
      _arc(_G.centre, _G.rInner, tr.innerFrom, 2 * math.pi * i),
      stroke,
    );
    if (i < 1) {
      tip(
        SigilGeometry.polar(
          _G.centre,
          _G.rInner,
          tr.innerFrom + 2 * math.pi * i,
        ),
      );
    }
  }
  if (tr._fullStep.eased(t) <= 0) return;
  final e = tr._eclipseStep.eased(t);
  if (e >= 1) {
    if (lunation == null) {
      canvas.drawPath(_crescent(), fill);
    } else {
      _paintLunation(canvas, t - tr.done, lunation, ink);
    }
  } else if (e <= 0) {
    // The full moon, swelling out from its centre.
    final r = _G.rMoon * (1 - math.pow(1 - tr._fullStep.linear(t), 3));
    canvas.drawCircle(_G.moon, math.max(r, 0.01), fill);
  } else {
    // The shadow sliding in.
    final s = Offset.lerp(tr.shadowFrom, _G.shadow, e)!;
    canvas.drawPath(_crescent(s), fill);
  }
}

// How much the month slows at the sigil's own crescent, and over how
// much of it the horns draw in to the sigil's cusps.
const _dwell = 0.6;
const _near = 0.14;

/// The great crescent at moment [t] of a month [period] seconds long,
/// as `lunation` paints it: the sigil's own crescent at 0.
void _paintLunation(Canvas canvas, double t, double period, Color ink) {
  const r = _G.rMoon;
  final back = Offset(math.cos(_G.backAngle), math.sin(_G.backAngle));
  final cusp = _G.cusps.$1 - _G.moon;
  final beta0 = math.acos((cusp.dx * back.dx + cusp.dy * back.dy) / r);
  final e0 = r * (1 - _G.thick);
  final a0 = math.acos(e0 / r) / (2 * math.pi);
  final x = t / period;
  final age = a0 + x - _dwell * math.sin(2 * math.pi * x) / (2 * math.pi);
  var dist = (age - a0) % 1;
  if (dist > 0.5) dist = 1 - dist;
  var k = 1 - math.min(1.0, dist / _near);
  k = k * k * (3 - 2 * k);
  final beta = math.pi / 2 + (beta0 - math.pi / 2) * k;
  final (shape, f) = _moonShape(_G.moon, r, age, _G.backAngle, beta);
  // The earthshine: the dark of the moon faintly there while it is thin.
  final f0 = (1 - e0 / r) / 2;
  if (f < f0) {
    canvas.drawCircle(
      _G.moon,
      r,
      Paint()..color = ink.withValues(alpha: ink.a * 0.028 * (1 - f / f0)),
    );
  }
  if (shape != null) canvas.drawPath(shape, Paint()..color = ink);
}

/// The sigil tracing itself, the name rising under it once it is whole,
/// and, if [lunation] is set, its crescent then going round the month for
/// as long as it is shown.
///
/// [onDone] is called once the name has settled.
class SigilTracing extends StatefulWidget {
  final Color ink;
  final double? lunation;
  final VoidCallback? onDone;

  const SigilTracing({
    super.key,
    required this.ink,
    this.lunation,
    this.onDone,
  });

  /// The name's letters rise one after another, each over this long,
  /// [_stagger] apart; the word draws its spacing in over [_settle].
  static const _rise = 1.1;
  static const _stagger = 0.15;
  static const _settle = 2.2;

  /// How long from the start until the name has settled.
  static double get length => SigilTrace.instance.done + _settle;

  @override
  State<SigilTracing> createState() => _SigilTracingState();
}

class _SigilTracingState extends State<SigilTracing>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _seconds = ValueNotifier(0.0);
  bool _told = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _seconds.value = elapsed.inMicroseconds / 1e6;
      if (!_told && _seconds.value >= SigilTracing.length) {
        _told = true;
        widget.onDone?.call();
        if (widget.lunation == null) _ticker.stop();
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: _SigilPainter(
      seconds: _seconds,
      ink: widget.ink,
      lunation: widget.lunation,
    ),
  );
}

class _SigilPainter extends CustomPainter {
  final ValueNotifier<double> seconds;
  final Color ink;
  final double? lunation;

  _SigilPainter({
    required this.seconds,
    required this.ink,
    required this.lunation,
  }) : super(repaint: seconds);

  // In the store's search art the sigil is 0.32 of the height, the
  // name's capitals 0.02 and the gap between them 0.025: the same
  // proportions here, to the sigil.
  static const _cap = 0.02 / 0.32;
  static const _gap = 0.025 / 0.32;

  @override
  void paint(Canvas canvas, Size size) {
    final real = seconds.value;
    final t = real;
    final done = SigilTrace.instance.done;
    // The sigil and the name, as one block, centred.
    final across = math.min(size.width * 0.74, size.height * 0.62);
    final cap = across * _cap;
    final gap = across * _gap;
    final top = (size.height - (across + gap + cap * 1.4)) / 2;
    final scale = across / (2 * SigilGeometry.rimOut);
    canvas.save();
    canvas.translate(size.width / 2, top + across / 2);
    canvas.scale(scale);
    canvas.translate(-SigilGeometry.centre.dx, -SigilGeometry.centre.dy);
    paintSigil(canvas, t, ink, lunation: lunation);
    canvas.restore();

    // The name rises once the sigil is whole: the letters come up one by
    // one out of the dark while the word draws its spacing in.
    final since = real - done;
    if (since <= 0) return;
    final settle =
        1 - math.pow(1 - math.min(1.0, since / SigilTracing._settle), 3);
    final tracking = 1.35 - (1.35 - 0.72) * settle;
    // IBM Plex Mono's capitals are 0.698 of its size, its advance 0.6.
    final fontSize = cap / 0.698;
    final advance = fontSize * 0.6;
    const word = 'CANDRA';
    final width = word.length * advance + (word.length - 1) * tracking * cap;
    final baseline = top + across + gap + cap;
    for (var i = 0; i < word.length; i++) {
      final x = ((since - SigilTracing._stagger * i) / SigilTracing._rise)
          .clamp(0.0, 1.0);
      final q = 1 - math.pow(1 - x, 3);
      if (q <= 0) continue;
      final painter = TextPainter(
        text: TextSpan(
          text: word[i],
          style: TextStyle(
            fontFamily: SmType.family,
            package: SmType.package,
            fontWeight: FontWeight.w500,
            fontSize: fontSize,
            height: 1,
            color: ink.withValues(alpha: ink.a * math.min(0.999, q)),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final left = (size.width - width) / 2 + i * (advance + tracking * cap);
      final ascent = painter.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      );
      painter.paint(
        canvas,
        Offset(left, baseline - ascent + (1 - q) * 0.4 * cap),
      );
    }
  }

  @override
  bool shouldRepaint(_SigilPainter old) =>
      old.ink != ink || old.lunation != lunation;
}

/// The first time the app is ever opened, the sigil traces itself over
/// it, the name rises, and it gives way to the app.
class SigilOpening extends StatefulWidget {
  /// Whether it is still to be shown; set once from the phone's
  /// preferences, and false from the moment it has given way.
  static final showing = ValueNotifier(false);

  /// The sigil's night and its moonlight, whatever the app's colours.
  static const night = Color(0xFF0B1B2E);
  static const moonlight = Color(0xFFF4F1E8);

  const SigilOpening({super.key});

  @override
  State<SigilOpening> createState() => _SigilOpeningState();
}

class _SigilOpeningState extends State<SigilOpening> {
  bool _leaving = false;

  void _done() {
    // The name stays a moment, then it all fades into the app.
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _leaving = true);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _leaving ? 0 : 1,
    duration: const Duration(milliseconds: 700),
    curve: Curves.easeInOut,
    onEnd: () => SigilOpening.showing.value = false,
    // Nothing under it is touched while it is there.
    child: AbsorbPointer(
      child: ColoredBox(
        color: SigilOpening.night,
        child: SafeArea(
          child: SigilTracing(ink: SigilOpening.moonlight, onDone: _done),
        ),
      ),
    ),
  );
}
