import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_cfg.dart';
import '../data/app_data.dart';

class PlanDraw extends StatelessWidget { // top-down CAD room floor, metric/imperial grid & exterior walls
  final StudioRef studio;
  final RoomData room;
  final UnitKind unit;
  final bool showGrid;
  final WallFace wall;

  const PlanDraw({
    super.key,
    required this.studio,
    required this.room,
    required this.unit,
    required this.showGrid,
    required this.wall,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PlanDraw(studio: studio, room: room, unit: unit, showGrid: showGrid, wall: wall),
      size: Size.infinite,
    );
  }
}

class _PlanDraw extends CustomPainter {
  final StudioRef studio;
  final RoomData room;
  final UnitKind unit;
  final bool showGrid;
  final WallFace wall;

  _PlanDraw({required this.studio, required this.room, required this.unit, required this.showGrid, required this.wall});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final px = w / room.roomW;

    final floorTint = Color.lerp(Color(studio.floorHex), Colors.white, 0.72)!;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = floorTint);

    if (showGrid) {
      final minor = unit == UnitKind.metric ? 50.0 : 12.0 * UnitCfg.inRatio; // 50cm or 1ft minor grid
      final major = unit == UnitKind.metric ? 100.0 : 36.0 * UnitCfg.inRatio; // 1m or 3ft major grid
      final pMin = Paint()..color = const Color(0x14000000)..strokeWidth = 1;
      final pMaj = Paint()..color = const Color(0x2A000000)..strokeWidth = 1.2;

      for (double cm = minor; cm < room.roomW; cm += minor) {
        final isMaj = (cm % major).abs() < 0.5 || (major - (cm % major)).abs() < 0.5;
        canvas.drawLine(Offset(cm * px, 0), Offset(cm * px, h), isMaj ? pMaj : pMin);
      }
      for (double cm = minor; cm < room.roomD; cm += minor) {
        final isMaj = (cm % major).abs() < 0.5 || (major - (cm % major)).abs() < 0.5;
        canvas.drawLine(Offset(0, cm * px), Offset(w, cm * px), isMaj ? pMaj : pMin);
      }
    }

    canvas.drawRect(
      Rect.fromLTWH(-3, -3, w + 6, h + 6), // outer 6px stroke keeps inner room face strictly at 0..w
      Paint()..color = const Color(0xFF2D312E)..style = PaintingStyle.stroke..strokeWidth = 6,
    );

    _drawCue(canvas, w, h);
    _drawActive(canvas, w, h);
    _drawMarks(canvas, w, h);
  }

  void _drawCue(Canvas canvas, double w, double h) { // north wall window & backsplash ticks match WallDraw
    final winPaint = Paint()..color = const Color(0xFF60A5FA)..strokeWidth = 5;
    switch (studio.kind) {
      case RoomKind.living:
        canvas.drawLine(Offset(w * 0.66, -3), Offset(w * 0.88, -3), winPaint);
      case RoomKind.bedroom:
        canvas.drawLine(Offset(w * 0.12, -3), Offset(w * 0.32, -3), winPaint);
      case RoomKind.dining:
        canvas.drawLine(Offset(w * 0.36, -3), Offset(w * 0.64, -3), winPaint);
      case RoomKind.kitchen:
        canvas.drawLine(const Offset(0, -3), Offset(w, -3), Paint()..color = const Color(0xFF94A3B8)..strokeWidth = 4);
      case RoomKind.blank:
        break;
    }
  }

  void _drawActive(Canvas canvas, double w, double h) {
    final hi = Paint()..color = PalCfg.accent..strokeWidth = 4;
    switch (wall) {
      case WallFace.north:
        canvas.drawLine(const Offset(0, -3), Offset(w, -3), hi);
      case WallFace.east:
        canvas.drawLine(Offset(w + 3, 0), Offset(w + 3, h), hi);
      case WallFace.south:
        canvas.drawLine(Offset(0, h + 3), Offset(w, h + 3), hi);
      case WallFace.west:
        canvas.drawLine(const Offset(-3, 0), Offset(-3, h), hi);
    }
  }

  void _drawMarks(Canvas canvas, double w, double h) { // compass tags sit outside walls so furniture never hides them
    void mark(String ch, Offset pos, bool active) {
      final tp = TextPainter(
        text: TextSpan(text: ch, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: active ? PalCfg.accent : const Color(0x88000000))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    mark('N', Offset(w * 0.5, -13), wall == WallFace.north);
    mark('E', Offset(w + 13, h * 0.5), wall == WallFace.east);
    mark('S', Offset(w * 0.5, h + 13), wall == WallFace.south);
    mark('W', Offset(-13, h * 0.5), wall == WallFace.west);
  }

  @override
  bool shouldRepaint(covariant _PlanDraw old) =>
      old.studio.id != studio.id || old.room.roomW != room.roomW || old.room.roomD != room.roomD || old.unit != unit || old.showGrid != showGrid || old.wall != wall;
}

class FootDraw extends StatelessWidget { // procedural top-down CAD footprint facing south (+Y)
  final String shapeKey;
  final PlaceZone zone;
  final bool isUpper;

  const FootDraw({super.key, required this.shapeKey, required this.zone, this.isUpper = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FootDraw(shapeKey: shapeKey, zone: zone, isUpper: isUpper),
      size: Size.infinite,
    );
  }
}

class _FootDraw extends CustomPainter {
  final String shapeKey;
  final PlaceZone zone;
  final bool isUpper;

  _FootDraw({required this.shapeKey, required this.zone, required this.isUpper});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()..color = const Color(0xFF2D312E)..style = PaintingStyle.stroke..strokeWidth = 1.4;

    if (isUpper) { // dashed translucent CAD block keeps floor furniture underneath visible
      if (shapeKey == 'lamp_pendant') {
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.46, Paint()..color = const Color(0x38D7B176));
        _dashRing(canvas, Offset(w * 0.5, h * 0.5), w * 0.46, Paint()..color = const Color(0xAA8C6226)..style = PaintingStyle.stroke..strokeWidth = 1.4);
        canvas.drawLine(Offset(w * 0.38, h * 0.5), Offset(w * 0.62, h * 0.5), stroke);
        canvas.drawLine(Offset(w * 0.5, h * 0.38), Offset(w * 0.5, h * 0.62), stroke);
        return;
      }
      final r = Rect.fromLTWH(0, 0, w, h);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), Paint()..color = const Color(0x88E2E8F0));
      _dashRect(canvas, r, Paint()..color = PalCfg.ruler..style = PaintingStyle.stroke..strokeWidth = 1.4);
      return;
    }

    switch (shapeKey) {
      case 'sofa_love':
        _drawBox(canvas, Rect.fromLTWH(0, 0, w, h), const Color(0xFF9EA4A8), stroke, rad: 4);
        _drawBox(canvas, Rect.fromLTWH(0, 0, w, h * 0.26), const Color(0xFF7B8185), stroke, rad: 3);
        _drawBox(canvas, Rect.fromLTWH(0, 0, w * 0.14, h), const Color(0xFF7B8185), stroke, rad: 3);
        _drawBox(canvas, Rect.fromLTWH(w * 0.86, 0, w * 0.14, h), const Color(0xFF7B8185), stroke, rad: 3);
        canvas.drawLine(Offset(w * 0.5, h * 0.26), Offset(w * 0.5, h), stroke);
      case 'chair_lounge':
        _drawBox(canvas, Rect.fromLTWH(w * 0.08, 0, w * 0.84, h), const Color(0xFF33363A), stroke, rad: 6);
        _drawBox(canvas, Rect.fromLTWH(0, h * 0.08, w * 0.12, h * 0.84), const Color(0xFFD8B589), stroke, rad: 2);
        _drawBox(canvas, Rect.fromLTWH(w * 0.88, h * 0.08, w * 0.12, h * 0.84), const Color(0xFFD8B589), stroke, rad: 2);
      case 'chair_dining':
        _drawBox(canvas, Rect.fromLTWH(w * 0.06, h * 0.12, w * 0.88, h * 0.88), const Color(0xFFC89B6E), stroke, rad: 3);
        _drawBox(canvas, Rect.fromLTWH(0, 0, w, h * 0.20), const Color(0xFFF6F4EE), stroke, rad: 2);
      case 'bed_frame':
        _drawBox(canvas, Rect.fromLTWH(0, 0, w, h), const Color(0xFFF7F5F0), stroke, rad: 4);
        _drawBox(canvas, Rect.fromLTWH(0, 0, w, h * 0.08), const Color(0xFF474B50), stroke, rad: 2);
        _drawBox(canvas, Rect.fromLTWH(w * 0.08, h * 0.11, w * 0.38, h * 0.16), const Color(0xFFFFFFFF), stroke, rad: 4);
        _drawBox(canvas, Rect.fromLTWH(w * 0.54, h * 0.11, w * 0.38, h * 0.16), const Color(0xFFFFFFFF), stroke, rad: 4);
        canvas.drawLine(Offset(0, h * 0.34), Offset(w, h * 0.34), stroke);
      case 'table_dining':
      case 'island_kit':
        _drawBox(canvas, Rect.fromLTWH(0, 0, w, h), const Color(0xFFC89B6E), stroke, rad: 3);
        canvas.drawRect(Rect.fromLTWH(w * 0.06, h * 0.08, w * 0.88, h * 0.84), Paint()..color = const Color(0x22000000)..style = PaintingStyle.stroke);
      case 'table_coffee':
      case 'table_side':
        _drawBox(canvas, Rect.fromLTWH(0, 0, w, h), const Color(0xFF3E3A37), stroke, rad: 3);
      case 'tv_unit':
      case 'shelf_tall':
      case 'dresser_malm':
      case 'wardrobe_tall':
        _drawBox(canvas, Rect.fromLTWH(0, 0, w, h), const Color(0xFFF3F1EA), stroke, rad: 2);
        canvas.drawLine(Offset(w * 0.15, h * 0.82), Offset(w * 0.85, h * 0.82), stroke); // front face edge indicator
      case 'knox_base':
        _drawBox(canvas, Rect.fromLTWH(0, 0, w, h), const Color(0xFFD2A87C), stroke, rad: 2);
        _drawBox(canvas, Rect.fromLTWH(w * 0.58, h * 0.16, w * 0.32, h * 0.64), const Color(0xFFE2E8F0), stroke, rad: 3);
        canvas.drawCircle(Offset(w * 0.74, h * 0.24), w * 0.03, Paint()..color = const Color(0xFF475569));
      case 'lamp_floor':
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.48, Paint()..color = const Color(0xFFFFF8E1));
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.48, stroke);
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.16, Paint()..color = const Color(0xFF333333));
      case 'rug_rect':
        _drawBox(canvas, Rect.fromLTWH(0, 0, w, h), const Color(0xAAEAE5DA), Paint()..color = const Color(0x66000000)..style = PaintingStyle.stroke..strokeWidth = 1.2, rad: 2);
        canvas.drawRect(Rect.fromLTWH(w * 0.05, h * 0.06, w * 0.90, h * 0.88), Paint()..color = const Color(0x22000000)..style = PaintingStyle.stroke);
      case 'plant_tall':
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.34, Paint()..color = const Color(0xFF3E3A37));
        for (final off in [const Offset(0.32, 0.35), const Offset(0.68, 0.35), const Offset(0.35, 0.68), const Offset(0.65, 0.68), const Offset(0.5, 0.48)]) {
          canvas.drawCircle(Offset(w * off.dx, h * off.dy), w * 0.20, Paint()..color = const Color(0xFF52B788));
        }
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.48, Paint()..color = const Color(0x552D6A4F)..style = PaintingStyle.stroke);
      case 'wall_mirror':
        _drawBox(canvas, Rect.fromLTWH(0, 0, w, h), const Color(0xFF1F2421), stroke, rad: 1);
      default:
        _drawBox(canvas, Rect.fromLTWH(0, 0, w, h), const Color(0xFFCBD5E1), stroke);
    }
  }

  void _drawBox(Canvas canvas, Rect r, Color fill, Paint stroke, {double rad = 2}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(rad));
    canvas.drawRRect(rr, Paint()..color = fill);
    canvas.drawRRect(rr, stroke);
  }

  void _dashRect(Canvas canvas, Rect r, Paint p) {
    void seg(Offset a, Offset b) {
      final len = (b - a).distance;
      final dir = (b - a) / (len == 0 ? 1 : len);
      for (double d = 0; d < len; d += 8) {
        canvas.drawLine(a + dir * d, a + dir * math.min(d + 4.5, len), p);
      }
    }

    seg(r.topLeft, r.topRight);
    seg(r.topRight, r.bottomRight);
    seg(r.bottomRight, r.bottomLeft);
    seg(r.bottomLeft, r.topLeft);
  }

  void _dashRing(Canvas canvas, Offset c, double rad, Paint p) {
    for (int i = 0; i < 12; i++) {
      final a = (i * 2 * math.pi) / 12;
      canvas.drawArc(Rect.fromCircle(center: c, radius: rad), a, math.pi / 12, false, p);
    }
  }

  @override
  bool shouldRepaint(covariant _FootDraw old) => old.shapeKey != shapeKey || old.zone != zone || old.isUpper != isUpper;
}

class WallDraw extends StatelessWidget { // flat orthographic architectural elevation with 15% floor-depth lane
  static const double floorRatio = 0.85; // top 85% = true ceilH elevation
  static const double depthSpan = 0.12; // bottom 0.85h..0.97h separates back-wall items from foreground

  final StudioRef studio;
  final WallFace wall;

  const WallDraw({super.key, required this.studio, this.wall = WallFace.north});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WallDraw(studio: studio, wall: wall),
      size: Size.infinite,
    );
  }
}

class _WallDraw extends CustomPainter {
  final StudioRef studio;
  final WallFace wall;

  _WallDraw({required this.studio, required this.wall});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fy = h * WallDraw.floorRatio;

    final wallCol = Color(studio.wallHex);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, fy),
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [wallCol, _shiftCol(wallCol, -0.04)]).createShader(Rect.fromLTWH(0, 0, w, fy)),
    );

    final floorCol = Color(studio.floorHex);
    canvas.drawRect(
      Rect.fromLTWH(0, fy, w, h - fy),
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_shiftCol(floorCol, -0.08), floorCol]).createShader(Rect.fromLTWH(0, fy, w, h - fy)),
    );

    final laneLine = Paint()..color = const Color(0x16000000)..strokeWidth = 1;
    for (int i = 1; i <= 3; i++) {
      final ly = fy + (h - fy) * (i / 4);
      canvas.drawLine(Offset(0, ly), Offset(w, ly), laneLine);
    }

    if (wall == WallFace.north) {
      switch (studio.kind) {
        case RoomKind.living:
          _drawWin(canvas, Rect.fromLTWH(w * 0.66, fy * 0.16, w * 0.22, fy * 0.44));
        case RoomKind.bedroom:
          _drawWin(canvas, Rect.fromLTWH(w * 0.12, fy * 0.16, w * 0.20, fy * 0.42));
        case RoomKind.kitchen:
          final topY = fy * 0.65;
          canvas.drawRect(Rect.fromLTRB(0, topY, w, fy), Paint()..color = const Color(0x55FFFFFF));
        case RoomKind.dining:
          _drawWin(canvas, Rect.fromLTWH(w * 0.36, fy * 0.14, w * 0.28, fy * 0.46));
        case RoomKind.blank:
          break;
      }
    }

    if (studio.kind == RoomKind.bedroom) {
      final railY = fy * 0.68;
      canvas.drawLine(Offset(0, railY), Offset(w, railY), Paint()..color = const Color(0x22000000)..strokeWidth = 2);
    }

    final trimH = fy * 0.032;
    canvas.drawRect(Rect.fromLTWH(0, fy - trimH, w, trimH), Paint()..color = const Color(0xFFFDFCF9));
    canvas.drawLine(Offset(0, fy), Offset(w, fy), Paint()..color = const Color(0x44000000)..strokeWidth = 1.5);

    canvas.drawRect(
      Rect.fromLTWH(-2, -2, w + 4, h + 4),
      Paint()..color = const Color(0xFF2D312E)..style = PaintingStyle.stroke..strokeWidth = 4,
    );
  }

  void _drawWin(Canvas canvas, Rect rect) {
    final glass = Paint()
      ..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFD6EAF8), Color(0xFFF3F9FD)]).createShader(rect);
    canvas.drawRect(rect, glass);
    final frame = Paint()..color = const Color(0xFFFFFFFF)..style = PaintingStyle.stroke..strokeWidth = 4;
    canvas.drawRect(rect, frame);
    canvas.drawLine(Offset(rect.center.dx, rect.top), Offset(rect.center.dx, rect.bottom), frame);
    canvas.drawLine(Offset(rect.left, rect.center.dy), Offset(rect.right, rect.center.dy), frame);
  }

  Color _shiftCol(Color col, double delta) {
    final hsl = HSLColor.fromColor(col);
    return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
  }

  @override
  bool shouldRepaint(covariant _WallDraw old) => old.studio.id != studio.id || old.wall != wall;
}

class ItemDraw extends StatelessWidget { // procedural elevation sprites across front, side & back faces
  final String shapeKey;
  final ViewFace face;

  const ItemDraw({super.key, required this.shapeKey, this.face = ViewFace.front});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ItemDraw(shapeKey: shapeKey, face: face),
      size: Size.infinite,
    );
  }
}

class _ItemDraw extends CustomPainter {
  final String shapeKey;
  final ViewFace face;

  _ItemDraw({required this.shapeKey, required this.face});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    switch (shapeKey) {
      case 'sofa_love':
        _drawSofa(canvas, w, h);
      case 'chair_lounge':
        _drawLounge(canvas, w, h);
      case 'chair_dining':
        _drawChair(canvas, w, h);
      case 'bed_frame':
        _drawBed(canvas, w, h);
      case 'table_dining':
        _drawDTable(canvas, w, h);
      case 'table_coffee':
        _drawCTable(canvas, w, h);
      case 'table_side':
        _drawNStand(canvas, w, h);
      case 'tv_unit':
        _drawTv(canvas, w, h);
      case 'shelf_tall':
        _drawShelf(canvas, w, h);
      case 'dresser_malm':
        _drawDresser(canvas, w, h);
      case 'wardrobe_tall':
        _drawWardrobe(canvas, w, h);
      case 'knox_base':
        _drawKnoxBase(canvas, w, h);
      case 'knox_wall':
        _drawKnoxWall(canvas, w, h);
      case 'island_kit':
        _drawIsland(canvas, w, h);
      case 'lamp_floor':
        _drawLamp(canvas, w, h);
      case 'lamp_pendant':
        _drawPendant(canvas, w, h);
      case 'rug_rect':
        _drawRug(canvas, w, h);
      case 'plant_tall':
        _drawPlant(canvas, w, h);
      case 'wall_mirror':
        _drawMirror(canvas, w, h);
      case 'shelf_wall':
        _drawWallShf(canvas, w, h);
      default:
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF999999));
    }
  }

  void _drawShadow(Canvas canvas, double w, double h) {
    canvas.drawOval(Rect.fromLTWH(w * 0.06, h * 0.90, w * 0.88, h * 0.10), Paint()..color = const Color(0x28000000));
  }

  void _drawRect(Canvas canvas, Rect r, Color topCol, Color botCol, {double rad = 4}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(rad));
    final paint = Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [topCol, botCol]).createShader(r);
    canvas.drawRRect(rr, paint);
    canvas.drawRRect(rr, Paint()..color = const Color(0x26000000)..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  void _drawSofa(Canvas canvas, double w, double h) {
    _drawShadow(canvas, w, h);
    const fabLight = Color(0xFF8B9094);
    const fabMid = Color(0xFF73787C);
    const fabDark = Color(0xFF5A5E62);
    const legCol = Color(0xFF2D2B29);

    if (face == ViewFace.side) {
      _drawRect(canvas, Rect.fromLTWH(w * 0.12, h * 0.82, w * 0.10, h * 0.13), legCol, legCol, rad: 2);
      _drawRect(canvas, Rect.fromLTWH(w * 0.76, h * 0.82, w * 0.10, h * 0.13), legCol, legCol, rad: 2);
      _drawRect(canvas, Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.28, h * 0.76), fabLight, fabDark, rad: 6);
      _drawRect(canvas, Rect.fromLTWH(w * 0.24, h * 0.36, w * 0.68, h * 0.48), fabMid, fabDark, rad: 6);
      return;
    }
    if (face == ViewFace.back) {
      _drawRect(canvas, Rect.fromLTWH(w * 0.08, h * 0.82, w * 0.06, h * 0.13), legCol, legCol, rad: 2);
      _drawRect(canvas, Rect.fromLTWH(w * 0.86, h * 0.82, w * 0.06, h * 0.13), legCol, legCol, rad: 2);
      _drawRect(canvas, Rect.fromLTWH(w * 0.04, h * 0.08, w * 0.92, h * 0.76), fabMid, fabDark, rad: 6);
      canvas.drawLine(Offset(w * 0.5, h * 0.12), Offset(w * 0.5, h * 0.80), Paint()..color = const Color(0x28000000));
      return;
    }

    _drawRect(canvas, Rect.fromLTWH(w * 0.08, h * 0.82, w * 0.06, h * 0.13), legCol, legCol, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.86, h * 0.82, w * 0.06, h * 0.13), legCol, legCol, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.10, h * 0.08, w * 0.80, h * 0.56), fabLight, fabMid, rad: 6);
    _drawRect(canvas, Rect.fromLTWH(w * 0.16, h * 0.50, w * 0.34, h * 0.24), fabLight, fabMid, rad: 4);
    _drawRect(canvas, Rect.fromLTWH(w * 0.50, h * 0.50, w * 0.34, h * 0.24), fabLight, fabMid, rad: 4);
    _drawRect(canvas, Rect.fromLTWH(w * 0.14, h * 0.72, w * 0.72, h * 0.13), fabMid, fabDark, rad: 3);
    _drawRect(canvas, Rect.fromLTWH(w * 0.03, h * 0.34, w * 0.14, h * 0.50), fabLight, fabDark, rad: 5);
    _drawRect(canvas, Rect.fromLTWH(w * 0.83, h * 0.34, w * 0.14, h * 0.50), fabLight, fabDark, rad: 5);
  }

  void _drawLounge(Canvas canvas, double w, double h) {
    _drawShadow(canvas, w, h);
    const wood = Color(0xFFD8B589);
    const woodDark = Color(0xFFB58E5E);
    const cushTop = Color(0xFF33363A);
    const cushBot = Color(0xFF1F2124);

    if (face == ViewFace.side) {
      final woodLine = Paint()..color = woodDark..style = PaintingStyle.stroke..strokeWidth = w * 0.07..strokeCap = StrokeCap.round;
      final frame = Path()..moveTo(w * 0.14, h * 0.92)..lineTo(w * 0.84, h * 0.92)..lineTo(w * 0.84, h * 0.52)..quadraticBezierTo(w * 0.55, h * 0.44, w * 0.24, h * 0.62);
      canvas.drawPath(frame, woodLine);
      final cush = Paint()..color = cushBot..style = PaintingStyle.stroke..strokeWidth = w * 0.14..strokeCap = StrokeCap.round;
      final seat = Path()..moveTo(w * 0.22, h * 0.12)..lineTo(w * 0.34, h * 0.64)..lineTo(w * 0.84, h * 0.58);
      canvas.drawPath(seat, cush);
      return;
    }
    if (face == ViewFace.back) {
      _drawRect(canvas, Rect.fromLTWH(w * 0.08, h * 0.44, w * 0.10, h * 0.50), wood, woodDark, rad: 3);
      _drawRect(canvas, Rect.fromLTWH(w * 0.82, h * 0.44, w * 0.10, h * 0.50), wood, woodDark, rad: 3);
      _drawRect(canvas, Rect.fromLTWH(w * 0.18, h * 0.06, w * 0.64, h * 0.66), wood, woodDark, rad: 8);
      return;
    }

    _drawRect(canvas, Rect.fromLTWH(w * 0.08, h * 0.44, w * 0.10, h * 0.50), wood, woodDark, rad: 3);
    _drawRect(canvas, Rect.fromLTWH(w * 0.82, h * 0.44, w * 0.10, h * 0.50), wood, woodDark, rad: 3);
    _drawRect(canvas, Rect.fromLTWH(w * 0.18, h * 0.06, w * 0.64, h * 0.58), cushTop, cushBot, rad: 8);
    _drawRect(canvas, Rect.fromLTWH(w * 0.16, h * 0.58, w * 0.68, h * 0.16), cushTop, cushBot, rad: 5);
  }

  void _drawChair(Canvas canvas, double w, double h) {
    _drawShadow(canvas, w, h);
    const woodTop = Color(0xFFC89B6E);
    const woodBot = Color(0xFFA47548);
    const whiteTop = Color(0xFFF6F4EE);
    const whiteBot = Color(0xFFE1DDD2);

    if (face == ViewFace.side) {
      _drawRect(canvas, Rect.fromLTWH(w * 0.18, h * 0.06, w * 0.10, h * 0.88), whiteTop, whiteBot, rad: 2);
      _drawRect(canvas, Rect.fromLTWH(w * 0.74, h * 0.54, w * 0.10, h * 0.40), whiteTop, whiteBot, rad: 2);
      _drawRect(canvas, Rect.fromLTWH(w * 0.18, h * 0.50, w * 0.68, h * 0.08), woodTop, woodBot, rad: 2);
      return;
    }
    if (face == ViewFace.back) {
      _drawRect(canvas, Rect.fromLTWH(w * 0.18, h * 0.10, w * 0.10, h * 0.84), whiteTop, whiteBot, rad: 2);
      _drawRect(canvas, Rect.fromLTWH(w * 0.72, h * 0.10, w * 0.10, h * 0.84), whiteTop, whiteBot, rad: 2);
      _drawRect(canvas, Rect.fromLTWH(w * 0.46, h * 0.10, w * 0.08, h * 0.42), whiteTop, whiteBot, rad: 2);
      _drawRect(canvas, Rect.fromLTWH(w * 0.18, h * 0.05, w * 0.64, h * 0.09), woodTop, woodBot, rad: 3);
      _drawRect(canvas, Rect.fromLTWH(w * 0.16, h * 0.50, w * 0.68, h * 0.08), woodTop, woodBot, rad: 2);
      return;
    }

    _drawRect(canvas, Rect.fromLTWH(w * 0.18, h * 0.58, w * 0.10, h * 0.36), whiteTop, whiteBot, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.72, h * 0.58, w * 0.10, h * 0.36), whiteTop, whiteBot, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.22, h * 0.10, w * 0.08, h * 0.42), whiteTop, whiteBot, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.46, h * 0.10, w * 0.08, h * 0.42), whiteTop, whiteBot, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.70, h * 0.10, w * 0.08, h * 0.42), whiteTop, whiteBot, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.18, h * 0.05, w * 0.64, h * 0.09), woodTop, woodBot, rad: 3);
    _drawRect(canvas, Rect.fromLTWH(w * 0.14, h * 0.50, w * 0.72, h * 0.09), woodTop, woodBot, rad: 3);
  }

  void _drawBed(Canvas canvas, double w, double h) {
    _drawShadow(canvas, w, h);
    const frameTop = Color(0xFF565A60);
    const frameBot = Color(0xFF3E4247);
    const linenTop = Color(0xFFF8F7F4);
    const linenBot = Color(0xFFDFDDD6);

    if (face == ViewFace.side) {
      _drawRect(canvas, Rect.fromLTWH(w * 0.06, h * 0.84, w * 0.06, h * 0.11), frameBot, frameBot, rad: 2);
      _drawRect(canvas, Rect.fromLTWH(w * 0.88, h * 0.84, w * 0.06, h * 0.11), frameBot, frameBot, rad: 2);
      _drawRect(canvas, Rect.fromLTWH(w * 0.04, h * 0.06, w * 0.10, h * 0.80), frameTop, frameBot, rad: 4);
      _drawRect(canvas, Rect.fromLTWH(w * 0.16, h * 0.36, w * 0.18, h * 0.16), linenTop, linenBot, rad: 6);
      _drawRect(canvas, Rect.fromLTWH(w * 0.14, h * 0.48, w * 0.82, h * 0.24), linenTop, linenBot, rad: 5);
      _drawRect(canvas, Rect.fromLTWH(w * 0.14, h * 0.70, w * 0.82, h * 0.16), frameTop, frameBot, rad: 3);
      return;
    }
    if (face == ViewFace.back) {
      _drawRect(canvas, Rect.fromLTWH(w * 0.08, h * 0.84, w * 0.06, h * 0.11), frameBot, frameBot, rad: 2);
      _drawRect(canvas, Rect.fromLTWH(w * 0.86, h * 0.84, w * 0.06, h * 0.11), frameBot, frameBot, rad: 2);
      _drawRect(canvas, Rect.fromLTWH(w * 0.06, h * 0.06, w * 0.88, h * 0.82), frameTop, frameBot, rad: 6);
      return;
    }

    _drawRect(canvas, Rect.fromLTWH(w * 0.08, h * 0.84, w * 0.06, h * 0.11), frameBot, frameBot, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.86, h * 0.84, w * 0.06, h * 0.11), frameBot, frameBot, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.06, h * 0.06, w * 0.88, h * 0.62), frameTop, frameBot, rad: 6);
    _drawRect(canvas, Rect.fromLTWH(w * 0.14, h * 0.36, w * 0.33, h * 0.18), linenTop, linenBot, rad: 5);
    _drawRect(canvas, Rect.fromLTWH(w * 0.53, h * 0.36, w * 0.33, h * 0.18), linenTop, linenBot, rad: 5);
    _drawRect(canvas, Rect.fromLTWH(w * 0.08, h * 0.50, w * 0.84, h * 0.28), linenTop, linenBot, rad: 5);
    _drawRect(canvas, Rect.fromLTWH(w * 0.06, h * 0.76, w * 0.88, h * 0.12), frameTop, frameBot, rad: 3);
  }

  void _drawDTable(Canvas canvas, double w, double h) {
    _drawShadow(canvas, w, h);
    const woodTop = Color(0xFFC89B6E);
    const woodBot = Color(0xFFA47548);
    const whiteTop = Color(0xFFF6F4EE);
    const whiteBot = Color(0xFFDCD8CC);

    if (face == ViewFace.side) {
      _drawRect(canvas, Rect.fromLTWH(w * 0.10, h * 0.24, w * 0.09, h * 0.70), whiteTop, whiteBot, rad: 2);
      _drawRect(canvas, Rect.fromLTWH(w * 0.81, h * 0.24, w * 0.09, h * 0.70), whiteTop, whiteBot, rad: 2);
      _drawRect(canvas, Rect.fromLTWH(w * 0.10, h * 0.15, w * 0.80, h * 0.10), whiteTop, whiteBot, rad: 2);
      _drawRect(canvas, Rect.fromLTWH(w * 0.03, h * 0.06, w * 0.94, h * 0.10), woodTop, woodBot, rad: 3);
      return;
    }

    _drawRect(canvas, Rect.fromLTWH(w * 0.14, h * 0.24, w * 0.05, h * 0.66), whiteBot, const Color(0xFFC4BFB2), rad: 1);
    _drawRect(canvas, Rect.fromLTWH(w * 0.81, h * 0.24, w * 0.05, h * 0.66), whiteBot, const Color(0xFFC4BFB2), rad: 1);
    _drawRect(canvas, Rect.fromLTWH(w * 0.07, h * 0.24, w * 0.06, h * 0.70), whiteTop, whiteBot, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.87, h * 0.24, w * 0.06, h * 0.70), whiteTop, whiteBot, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.07, h * 0.15, w * 0.86, h * 0.10), whiteTop, whiteBot, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.02, h * 0.06, w * 0.96, h * 0.10), woodTop, woodBot, rad: 3);
  }

  void _drawCTable(Canvas canvas, double w, double h) {
    _drawShadow(canvas, w, h);
    const blkTop = Color(0xFF423C38);
    const blkBot = Color(0xFF282422);
    if (face == ViewFace.side) {
      _drawRect(canvas, Rect.fromLTWH(w * 0.08, h * 0.22, w * 0.14, h * 0.72), blkTop, blkBot, rad: 2);
      _drawRect(canvas, Rect.fromLTWH(w * 0.78, h * 0.22, w * 0.14, h * 0.72), blkTop, blkBot, rad: 2);
      _drawRect(canvas, Rect.fromLTWH(w * 0.18, h * 0.56, w * 0.64, h * 0.10), blkTop, blkBot, rad: 1);
      _drawRect(canvas, Rect.fromLTWH(w * 0.03, h * 0.06, w * 0.94, h * 0.18), blkTop, blkBot, rad: 2);
      return;
    }
    _drawRect(canvas, Rect.fromLTWH(w * 0.05, h * 0.22, w * 0.09, h * 0.72), blkTop, blkBot, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.86, h * 0.22, w * 0.09, h * 0.72), blkTop, blkBot, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.12, h * 0.56, w * 0.76, h * 0.10), blkTop, blkBot, rad: 1);
    _drawRect(canvas, Rect.fromLTWH(w * 0.02, h * 0.06, w * 0.96, h * 0.18), blkTop, blkBot, rad: 2);
  }

  void _drawNStand(Canvas canvas, double w, double h) {
    _drawShadow(canvas, w, h);
    const blkTop = Color(0xFF3A3D40);
    const blkBot = Color(0xFF222426);
    _drawRect(canvas, Rect.fromLTWH(w * 0.08, h * 0.14, w * 0.08, h * 0.80), blkTop, blkBot, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.84, h * 0.14, w * 0.08, h * 0.80), blkTop, blkBot, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.14, h * 0.56, w * 0.72, h * 0.07), blkTop, blkBot, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.04, h * 0.06, w * 0.92, h * 0.10), blkTop, blkBot, rad: 3);
  }

  void _drawTv(Canvas canvas, double w, double h) {
    _drawShadow(canvas, w, h);
    const whtTop = Color(0xFFFAF9F6);
    const whtBot = Color(0xFFE3E0D8);
    if (face == ViewFace.side || face == ViewFace.back) {
      _drawRect(canvas, Rect.fromLTWH(w * 0.04, h * 0.10, w * 0.92, h * 0.82), whtTop, whtBot, rad: 3);
      return;
    }
    _drawRect(canvas, Rect.fromLTWH(w * 0.02, h * 0.10, w * 0.96, h * 0.82), whtTop, whtBot, rad: 3);
    _drawRect(canvas, Rect.fromLTWH(w * 0.06, h * 0.24, w * 0.42, h * 0.48), const Color(0xFFC8C5BC), const Color(0xFFDDDAD1), rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.52, h * 0.24, w * 0.42, h * 0.48), const Color(0xFFC8C5BC), const Color(0xFFDDDAD1), rad: 2);
  }

  void _drawShelf(Canvas canvas, double w, double h) {
    _drawShadow(canvas, w, h);
    const whtTop = Color(0xFFFBFBFB);
    const whtBot = Color(0xFFE7E5DE);
    if (face == ViewFace.side || face == ViewFace.back) {
      _drawRect(canvas, Rect.fromLTWH(w * 0.06, h * 0.02, w * 0.88, h * 0.94), whtTop, whtBot, rad: 3);
      return;
    }
    _drawRect(canvas, Rect.fromLTWH(w * 0.06, h * 0.02, w * 0.88, h * 0.94), whtTop, whtBot, rad: 3);
    for (int i = 0; i < 4; i++) {
      final top = h * (0.06 + i * 0.21);
      _drawRect(canvas, Rect.fromLTWH(w * 0.12, top, w * 0.76, h * 0.17), const Color(0xFFDAD6CC), const Color(0xFFEFECE6), rad: 1);
    }
    _drawRect(canvas, Rect.fromLTWH(w * 0.16, h * 0.11, w * 0.10, h * 0.12), const Color(0xFF457B9D), const Color(0xFF2C536B), rad: 1);
    _drawRect(canvas, Rect.fromLTWH(w * 0.27, h * 0.13, w * 0.08, h * 0.10), const Color(0xFFE76F51), const Color(0xFFC55035), rad: 1);
  }

  void _drawDresser(Canvas canvas, double w, double h) {
    _drawShadow(canvas, w, h);
    const whtTop = Color(0xFFFAF9F6);
    const whtBot = Color(0xFFE4E1D8);
    _drawRect(canvas, Rect.fromLTWH(w * 0.05, h * 0.05, w * 0.90, h * 0.90), whtTop, whtBot, rad: 3);
    if (face == ViewFace.side) {
      for (int i = 0; i < 3; i++) {
        _drawRect(canvas, Rect.fromLTWH(w * 0.84, h * (0.12 + i * 0.26), w * 0.11, h * 0.22), const Color(0xFFFFFFFF), const Color(0xFFECEAE3), rad: 1);
      }
      return;
    }
    if (face == ViewFace.back) return;
    for (int i = 0; i < 3; i++) {
      _drawRect(canvas, Rect.fromLTWH(w * 0.10, h * (0.12 + i * 0.26), w * 0.80, h * 0.22), const Color(0xFFFFFFFF), const Color(0xFFECEAE3), rad: 2);
    }
  }

  void _drawWardrobe(Canvas canvas, double w, double h) {
    _drawShadow(canvas, w, h);
    const whtTop = Color(0xFFFDFCFA);
    const whtBot = Color(0xFFE6E3DB);
    if (face == ViewFace.side || face == ViewFace.back) {
      _drawRect(canvas, Rect.fromLTWH(w * 0.06, h * 0.03, w * 0.88, h * 0.92), whtTop, whtBot, rad: 3);
      return;
    }
    _drawRect(canvas, Rect.fromLTWH(w * 0.04, h * 0.03, w * 0.92, h * 0.92), whtTop, whtBot, rad: 3);
    _drawRect(canvas, Rect.fromLTWH(w * 0.08, h * 0.06, w * 0.26, h * 0.84), whtTop, whtBot, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.37, h * 0.06, w * 0.26, h * 0.84), whtTop, whtBot, rad: 2);
    final mirRect = Rect.fromLTWH(w * 0.66, h * 0.08, w * 0.26, h * 0.78);
    canvas.drawRect(mirRect, Paint()..shader = const LinearGradient(colors: [Color(0xFFCFE0EA), Color(0xFFEEF5F9)]).createShader(mirRect));
    canvas.drawRect(mirRect, Paint()..color = const Color(0x33000000)..style = PaintingStyle.stroke);
  }

  void _drawKnoxBase(Canvas canvas, double w, double h) {
    _drawShadow(canvas, w, h);
    const whtTop = Color(0xFFFAF9F6);
    const whtBot = Color(0xFFE4E1D8);
    const woodTop = Color(0xFFD2A87C);
    const woodBot = Color(0xFFB38456);

    if (face == ViewFace.side) {
      final tap = Path()..moveTo(w * 0.42, h * 0.22)..lineTo(w * 0.42, h * 0.06)..quadraticBezierTo(w * 0.50, h * 0.02, w * 0.58, h * 0.10);
      canvas.drawPath(tap, Paint()..color = const Color(0xFF7A8085)..style = PaintingStyle.stroke..strokeWidth = 3.5..strokeCap = StrokeCap.round);
      _drawRect(canvas, Rect.fromLTWH(w * 0.04, h * 0.22, w * 0.92, h * 0.09), woodTop, woodBot, rad: 2);
      _drawRect(canvas, Rect.fromLTWH(w * 0.06, h * 0.31, w * 0.86, h * 0.64), whtTop, whtBot, rad: 2);
      return;
    }
    if (face == ViewFace.back) {
      _drawRect(canvas, Rect.fromLTWH(w * 0.03, h * 0.22, w * 0.94, h * 0.09), woodTop, woodBot, rad: 2);
      _drawRect(canvas, Rect.fromLTWH(w * 0.05, h * 0.31, w * 0.90, h * 0.64), whtTop, whtBot, rad: 2);
      return;
    }

    final tap = Path()..moveTo(w * 0.74, h * 0.22)..lineTo(w * 0.74, h * 0.06)..quadraticBezierTo(w * 0.70, h * 0.02, w * 0.66, h * 0.10);
    canvas.drawPath(tap, Paint()..color = const Color(0xFF7A8085)..style = PaintingStyle.stroke..strokeWidth = 3.5..strokeCap = StrokeCap.round);
    _drawRect(canvas, Rect.fromLTWH(w * 0.03, h * 0.22, w * 0.94, h * 0.09), woodTop, woodBot, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.05, h * 0.31, w * 0.90, h * 0.64), whtTop, whtBot, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.09, h * 0.35, w * 0.26, h * 0.16), whtTop, const Color(0xFFECEAE3), rad: 1);
    _drawRect(canvas, Rect.fromLTWH(w * 0.09, h * 0.54, w * 0.26, h * 0.36), whtTop, const Color(0xFFECEAE3), rad: 1);
    _drawRect(canvas, Rect.fromLTWH(w * 0.38, h * 0.35, w * 0.26, h * 0.55), whtTop, const Color(0xFFECEAE3), rad: 1);
    _drawRect(canvas, Rect.fromLTWH(w * 0.67, h * 0.35, w * 0.24, h * 0.55), whtTop, const Color(0xFFECEAE3), rad: 1);
  }

  void _drawKnoxWall(Canvas canvas, double w, double h) {
    const whtTop = Color(0xFFFAF9F6);
    const whtBot = Color(0xFFE6E3DB);
    if (face == ViewFace.side) {
      _drawRect(canvas, Rect.fromLTWH(w * 0.06, h * 0.06, w * 0.88, h * 0.86), whtTop, whtBot, rad: 3);
      return;
    }
    _drawRect(canvas, Rect.fromLTWH(w * 0.03, h * 0.06, w * 0.94, h * 0.86), whtTop, whtBot, rad: 3);
    _drawRect(canvas, Rect.fromLTWH(w * 0.07, h * 0.12, w * 0.41, h * 0.74), whtTop, const Color(0xFFECEAE3), rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.52, h * 0.12, w * 0.41, h * 0.74), whtTop, const Color(0xFFECEAE3), rad: 2);
  }

  void _drawIsland(Canvas canvas, double w, double h) {
    _drawShadow(canvas, w, h);
    const blkTop = Color(0xFF333638);
    const blkBot = Color(0xFF1D1F21);
    const oakTop = Color(0xFFD5A97A);
    const oakBot = Color(0xFFB38456);
    _drawRect(canvas, Rect.fromLTWH(w * 0.06, h * 0.16, w * 0.09, h * 0.78), blkTop, blkBot, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.85, h * 0.16, w * 0.09, h * 0.78), blkTop, blkBot, rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.12, h * 0.44, w * 0.76, h * 0.07), blkTop, blkBot, rad: 1);
    _drawRect(canvas, Rect.fromLTWH(w * 0.12, h * 0.72, w * 0.76, h * 0.07), blkTop, blkBot, rad: 1);
    _drawRect(canvas, Rect.fromLTWH(w * 0.02, h * 0.06, w * 0.96, h * 0.12), oakTop, oakBot, rad: 3);
  }

  void _drawLamp(Canvas canvas, double w, double h) {
    _drawShadow(canvas, w, h);
    final glow = Paint()..shader = const RadialGradient(colors: [Color(0x55FFE082), Color(0x00FFE082)]).createShader(Rect.fromCircle(center: Offset(w * 0.5, h * 0.16), radius: w * 0.45));
    canvas.drawCircle(Offset(w * 0.5, h * 0.16), w * 0.45, glow);
    _drawRect(canvas, Rect.fromLTWH(w * 0.46, h * 0.24, w * 0.08, h * 0.68), const Color(0xFF333333), const Color(0xFF1A1A1A), rad: 2);
    _drawRect(canvas, Rect.fromLTWH(w * 0.18, h * 0.90, w * 0.64, h * 0.06), const Color(0xFF333333), const Color(0xFF1A1A1A), rad: 3);
    final shade = Path()..moveTo(w * 0.24, h * 0.04)..lineTo(w * 0.76, h * 0.04)..lineTo(w * 0.86, h * 0.26)..lineTo(w * 0.14, h * 0.26)..close();
    canvas.drawPath(shade, Paint()..color = const Color(0xFFFFF8E1));
    canvas.drawPath(shade, Paint()..color = const Color(0x33000000)..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  void _drawPendant(Canvas canvas, double w, double h) { // RoomView connects top wire from ceiling y=0 into socket ring
    final glow = Paint()..shader = const RadialGradient(colors: [Color(0x55FFD54F), Color(0x00FFD54F)]).createShader(Rect.fromCircle(center: Offset(w * 0.5, h * 0.68), radius: w * 0.48));
    canvas.drawCircle(Offset(w * 0.5, h * 0.68), w * 0.48, glow);
    _drawRect(canvas, Rect.fromLTWH(w * 0.44, h * 0.04, w * 0.12, h * 0.14), const Color(0xFF2B2B2B), const Color(0xFF181818), rad: 2);
    final dome = Path()..moveTo(w * 0.08, h * 0.80)..quadraticBezierTo(w * 0.5, h * 0.04, w * 0.92, h * 0.80)..close();
    canvas.drawPath(dome, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD7B176), Color(0xFFB3864A)]).createShader(Rect.fromLTWH(0, h * 0.14, w, h * 0.70)));
    canvas.drawPath(dome, Paint()..color = const Color(0x33000000)..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  void _drawRug(Canvas canvas, double w, double h) {
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFEAE5DA));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0x44000000)..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  void _drawPlant(Canvas canvas, double w, double h) {
    _drawShadow(canvas, w, h);
    for (final rx in [0.38, 0.50, 0.62]) {
      _drawRect(canvas, Rect.fromLTWH(w * rx - 2, h * 0.16, 4, h * 0.54), const Color(0xFF6B8E23), const Color(0xFF4F6B18), rad: 2);
    }
    for (final pos in [const Offset(0.32, 0.22), const Offset(0.54, 0.14), const Offset(0.68, 0.26), const Offset(0.42, 0.36), const Offset(0.60, 0.42)]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(w * pos.dx, h * pos.dy), width: w * 0.34, height: h * 0.14), Paint()..color = pos.dy < 0.3 ? const Color(0xFF52B788) : const Color(0xFF2D6A4F));
    }
    final pot = Path()..moveTo(w * 0.24, h * 0.64)..lineTo(w * 0.76, h * 0.64)..lineTo(w * 0.68, h * 0.95)..lineTo(w * 0.32, h * 0.95)..close();
    canvas.drawPath(pot, Paint()..color = const Color(0xFF3E3A37));
  }

  void _drawMirror(Canvas canvas, double w, double h) {
    _drawRect(canvas, Rect.fromLTWH(w * 0.06, h * 0.04, w * 0.88, h * 0.92), const Color(0xFF2B2D2F), const Color(0xFF18191A), rad: 4);
    final glassRect = Rect.fromLTWH(w * 0.14, h * 0.10, w * 0.72, h * 0.80);
    canvas.drawRect(glassRect, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFCFE0EA), Color(0xFFEEF5F9), Color(0xFFB8CDD9)]).createShader(glassRect));
    final sheen = Paint()..color = const Color(0x88FFFFFF)..strokeWidth = 4;
    canvas.drawLine(Offset(w * 0.26, h * 0.24), Offset(w * 0.46, h * 0.14), sheen);
    canvas.drawLine(Offset(w * 0.26, h * 0.34), Offset(w * 0.56, h * 0.18), sheen);
  }

  void _drawWallShf(Canvas canvas, double w, double h) {
    if (face == ViewFace.side) {
      _drawRect(canvas, Rect.fromLTWH(w * 0.28, h * 0.12, w * 0.34, h * 0.50), const Color(0xFF457B9D), const Color(0xFF2C536B), rad: 1);
      _drawRect(canvas, Rect.fromLTWH(w * 0.04, h * 0.62, w * 0.92, h * 0.24), const Color(0xFFFFFFFF), const Color(0xFFE1DDD2), rad: 2);
      return;
    }
    _drawRect(canvas, Rect.fromLTWH(w * 0.14, h * 0.12, w * 0.12, h * 0.50), const Color(0xFF457B9D), const Color(0xFF2C536B), rad: 1);
    _drawRect(canvas, Rect.fromLTWH(w * 0.27, h * 0.22, w * 0.10, h * 0.40), const Color(0xFFE76F51), const Color(0xFFC55035), rad: 1);
    _drawRect(canvas, Rect.fromLTWH(w * 0.02, h * 0.62, w * 0.96, h * 0.24), const Color(0xFFFFFFFF), const Color(0xFFE1DDD2), rad: 2);
  }

  @override
  bool shouldRepaint(covariant _ItemDraw old) => old.shapeKey != shapeKey || old.face != face;
}