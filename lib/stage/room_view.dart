import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_cfg.dart';
import '../data/app_data.dart';
import 'shape_draw.dart';

class RoomView extends StatefulWidget { // synchronized Top Plan + NESW Wall stage with 60fps local drag
  final RoomData room;
  final StudioRef studio;
  final ItemData? Function(String id) findItem;
  final StageMode mode;
  final WallFace wall;
  final UnitKind unit;
  final bool showGrid;
  final bool snapOn;
  final bool panMode;
  final int topLevel; // 0 = all layers, 1 = floor only, 2 = upper wall/ceiling
  final bool fullDepth; // false = half depth cut, true = whole room depth
  final String? curId;
  final bool readOnly;
  final void Function(String? id)? onPick;
  final void Function(String id, double xCm, double yCm, double elevCm)? onMove;
  final VoidCallback? onLayers;

  const RoomView({
    super.key,
    required this.room,
    required this.studio,
    required this.findItem,
    this.mode = StageMode.plan,
    this.wall = WallFace.north,
    this.unit = UnitKind.metric,
    this.showGrid = true,
    this.snapOn = true,
    this.panMode = false,
    this.topLevel = 0,
    this.fullDepth = false,
    this.curId,
    this.readOnly = false,
    this.onPick,
    this.onMove,
    this.onLayers,
  });

  @override
  State<RoomView> createState() => _RoomViewState();
}

class _RoomViewState extends State<RoomView> {
  final TransformationController _viewCtrl = TransformationController();
  String? _dragId; // isolated local drag state avoids rebuilding catalog 60x/sec
  double _dragX = 0;
  double _dragY = 0;
  double _dragElev = 0;
  double _rawX = 0;
  double _rawY = 0;
  double _rawElev = 0;

  @override
  void dispose() {
    _viewCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RoomView old) {
    super.didUpdateWidget(old);
    if (old.room.id != widget.room.id) _dragId = null; // clears stale drag state on room swap
    if (old.mode != widget.mode || old.wall != widget.wall || old.room.id != widget.room.id) {
      _viewCtrl.value = Matrix4.identity();
    }
  }

  void _fitView() => _viewCtrl.value = Matrix4.identity();

  void _zoomBy(double factor, double vw, double vh) { // zooms smoothly around viewport center
    final curS = _viewCtrl.value.getMaxScaleOnAxis();
    final nextS = (curS * factor).clamp(StageCfg.minZoom, StageCfg.maxZoom);
    final val = _viewCtrl.value.getTranslation();
    final cx = vw / 2;
    final cy = vh / 2;
    final rx = (cx - val.x) / curS;
    final ry = (cy - val.y) / curS;
    _viewCtrl.value = Matrix4.diagonal3Values(nextS, nextS, 1.0)..setTranslationRaw(cx - rx * nextS, cy - ry * nextS, 0.0);
  }

  StickerData _localClamp(StickerData s, ItemData item, double xCm, double yCm, double elevCm, {bool snapElev = false}) {
    final sx = UnitCfg.snapCm(xCm, widget.unit, on: widget.snapOn);
    final sy = UnitCfg.snapCm(yCm, widget.unit, on: widget.snapOn);
    final se = snapElev ? UnitCfg.snapCm(elevCm, widget.unit, on: widget.snapOn) : elevCm;
    final hw = item.planW(s.rotDeg) / 2;
    final hd = item.planD(s.rotDeg) / 2;
    final minX = hw;
    final maxX = widget.room.roomW - hw;
    final minY = hd;
    final maxY = widget.room.roomD - hd;
    final maxE = (widget.room.ceilH - item.hCm).clamp(0.0, widget.room.ceilH);
    return s.copyWith(
      xCm: minX >= maxX ? widget.room.roomW / 2 : sx.clamp(minX, maxX),
      yCm: minY >= maxY ? widget.room.roomD / 2 : sy.clamp(minY, maxY),
      elevCm: se.clamp(0.0, maxE),
    );
  }

  void _commitDrag(String id) {
    if (_dragId != id) return;
    final x = _dragX;
    final y = _dragY;
    final e = _dragElev;
    setState(() => _dragId = null);
    widget.onMove?.call(id, x, y, e);
  }

  bool _isUpper(StickerData s, ItemData item) => item.zone == PlaceZone.wall || item.zone == PlaceZone.ceiling || s.elevCm >= 90;

  double _wallFloor(double depthCm, double rh) { // maps perpendicular depth across 0.85h..0.97h floor lane
    final maxDepth = (widget.wall == WallFace.north || widget.wall == WallFace.south) ? widget.room.roomD : widget.room.roomW;
    final norm = (depthCm / (maxDepth == 0 ? 1 : maxDepth)).clamp(0.0, 1.0);
    return (rh * WallDraw.floorRatio) + (rh * WallDraw.depthSpan * norm);
  }

  void _pickPlan(StickerData cur, double xCm, double yCm, List<StickerData> sorted) {
    final hits = <StickerData>[];
    for (final st in sorted.reversed) {
      final item = widget.findItem(st.itemId);
      if (item == null) continue;
      final hw = item.planW(st.rotDeg) / 2;
      final hd = item.planD(st.rotDeg) / 2;
      if (xCm >= st.xCm - hw && xCm <= st.xCm + hw && yCm >= st.yCm - hd && yCm <= st.yCm + hd) hits.add(st);
    }
    if (hits.length <= 1) {
      widget.onPick?.call(null);
      return;
    }
    final curIdx = hits.indexWhere((h) => h.id == cur.id);
    widget.onPick?.call(hits[(curIdx + 1) % hits.length].id);
  }

  void _pickWall(StickerData cur, double tapX, double tapY, double pxPerCm, double rh, List<StickerData> ordered) {
    final hits = <StickerData>[];
    for (final st in ordered.reversed) {
      final item = widget.findItem(st.itemId);
      if (item == null) continue;
      if (_wallRect(st, item, pxPerCm, rh).contains(Offset(tapX, tapY))) hits.add(st);
    }
    if (hits.length <= 1) {
      widget.onPick?.call(null);
      return;
    }
    final curIdx = hits.indexWhere((h) => h.id == cur.id);
    widget.onPick?.call(hits[(curIdx + 1) % hits.length].id);
  }

  Rect _wallRect(StickerData s, ItemData item, double pxPerCm, double rh) { // orthographic 1:1 cm box on depth-lane floorY
    final proj = WallProj.of(s, item, widget.room, widget.wall);
    final itemW = math.max(8.0, proj.visW * pxPerCm);
    final left = (proj.uCm * pxPerCm) - (itemW / 2);
    final yFloor = _wallFloor(proj.depthCm, rh);

    if (item.zone == PlaceZone.rug) {
      final rugH = math.max(12.0, item.planD(s.rotDeg) * pxPerCm * 0.11);
      return Rect.fromLTWH(left, yFloor - rugH * 0.65, itemW, rugH);
    }
    final itemH = math.max(8.0, proj.visH * pxPerCm);
    final bottomY = yFloor - (proj.elevCm * pxPerCm);
    return Rect.fromLTWH(left, bottomY - itemH, itemW, itemH);
  }

  List<StickerData> _liveList() {
    return [
      for (final s in widget.room.stickers)
        if (s.id == _dragId) s.copyWith(xCm: _dragX, yCm: _dragY, elevCm: _dragElev) else s,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isPlan = widget.mode == StageMode.plan;
    final wallSpan = (widget.wall == WallFace.north || widget.wall == WallFace.south) ? widget.room.roomW : widget.room.roomD;
    final totalElevCm = widget.room.ceilH / WallDraw.floorRatio;
    final canvasAspect = isPlan ? (widget.room.roomW / widget.room.roomD) : (wallSpan / totalElevCm);

    final live = _liveList();
    final sortedPlan = _filterPlan(live);
    final sortedWall = _filterWall(live);

    return ClipRect(
      child: Container(
        color: const Color(0xFFE7E4DC),
        child: LayoutBuilder(
          builder: (context, box) {
            final vw = box.maxWidth;
            final vh = box.maxHeight;
            if (vw <= 0 || vh <= 0) return const SizedBox.shrink();

            Widget stageCore = Center(
              child: Padding(
                padding: EdgeInsets.all(widget.readOnly ? 8 : 22),
                child: AspectRatio(
                  aspectRatio: canvasAspect,
                  child: LayoutBuilder(
                    builder: (ctx, cBox) {
                      final rw = cBox.maxWidth;
                      final rh = cBox.maxHeight;
                      final pxPerCm = isPlan ? (rw / widget.room.roomW) : (rw / wallSpan);
                      final visibleList = isPlan ? sortedPlan : sortedWall;
                      final picked = widget.curId == null ? null : visibleList.where((s) => s.id == widget.curId).firstOrNull; // hides rulers when selected item is filtered out

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: widget.readOnly
                                  ? (isPlan
                                      ? PlanDraw(studio: widget.studio, room: widget.room, unit: widget.unit, showGrid: false, wall: widget.wall)
                                      : WallDraw(studio: widget.studio, wall: widget.wall))
                                  : GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => widget.onPick?.call(null),
                                      child: isPlan
                                          ? PlanDraw(studio: widget.studio, room: widget.room, unit: widget.unit, showGrid: widget.showGrid, wall: widget.wall)
                                          : WallDraw(studio: widget.studio, wall: widget.wall),
                                    ),
                            ),
                          ),
                          if (isPlan)
                            for (final s in sortedPlan) _buildPlanItem(s, pxPerCm, sortedPlan)
                          else
                            for (final s in sortedWall) ..._wallNodes(s, pxPerCm, rh, sortedWall),
                          if (!widget.readOnly && picked != null)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _RuleDraw(
                                    room: widget.room,
                                    allItems: live,
                                    findItem: widget.findItem,
                                    sticker: picked,
                                    item: widget.findItem(picked.itemId),
                                    mode: widget.mode,
                                    wall: widget.wall,
                                    unit: widget.unit,
                                    pxPerCm: pxPerCm,
                                    rw: rw,
                                    rh: rh,
                                    yFloorOf: (d) => _wallFloor(d, rh),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );

            if (widget.readOnly) return stageCore;

            return Stack(
              children: [
                InteractiveViewer(
                  transformationController: _viewCtrl,
                  constrained: true, // keeps canvas natively centered at 1.0x
                  minScale: StageCfg.minZoom,
                  maxScale: StageCfg.maxZoom,
                  boundaryMargin: const EdgeInsets.all(160),
                  child: SizedBox(width: vw, height: vh, child: stageCore),
                ),
                _buildHud(vw, vh, live.length, sortedWall.length),
              ],
            );
          },
        ),
      ),
    );
  }

  List<StickerData> _filterPlan(List<StickerData> src) {
    final out = <StickerData>[];
    for (final s in src) {
      final item = widget.findItem(s.itemId);
      if (item == null) continue;
      final upper = _isUpper(s, item);
      if (widget.topLevel == 1 && upper) continue;
      if (widget.topLevel == 2 && !upper) continue;
      out.add(s);
    }
    out.sort((a, b) {
      final ia = widget.findItem(a.itemId);
      final ib = widget.findItem(b.itemId);
      final la = ia == null ? 1 : (ia.zone == PlaceZone.rug ? 0 : (_isUpper(a, ia) ? 2 : 1));
      final lb = ib == null ? 1 : (ib.zone == PlaceZone.rug ? 0 : (_isUpper(b, ib) ? 2 : 1));
      final cmp = la.compareTo(lb);
      return cmp != 0 ? cmp : a.zIdx.compareTo(b.zIdx);
    });
    return out;
  }

  List<StickerData> _filterWall(List<StickerData> src) {
    final maxDepth = (widget.wall == WallFace.north || widget.wall == WallFace.south) ? widget.room.roomD : widget.room.roomW;
    final cutoff = (widget.readOnly || widget.fullDepth) ? maxDepth + 1 : maxDepth * 0.55;
    final out = <StickerData>[];
    for (final s in src) {
      final item = widget.findItem(s.itemId);
      if (item == null) continue;
      if (WallProj.of(s, item, widget.room, widget.wall).depthCm <= cutoff) out.add(s);
    }
    out.sort((a, b) {
      final ia = widget.findItem(a.itemId)!;
      final ib = widget.findItem(b.itemId)!;
      if (ia.zone == PlaceZone.rug && ib.zone != PlaceZone.rug) return -1;
      if (ib.zone == PlaceZone.rug && ia.zone != PlaceZone.rug) return 1;
      final cmp = WallProj.of(a, ia, widget.room, widget.wall).depthCm.compareTo(WallProj.of(b, ib, widget.room, widget.wall).depthCm);
      return cmp != 0 ? cmp : a.zIdx.compareTo(b.zIdx);
    });
    return out;
  }

  Widget _buildHud(double vw, double vh, int total, int shownWall) {
    final hiddenCount = widget.mode == StageMode.wall ? (total - shownWall) : 0;
    return Positioned(
      left: 8,
      right: 8,
      top: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (widget.onLayers != null) _hudBtn('Items ($total)', widget.onLayers!),
              if (hiddenCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: PalCfg.border)),
                  child: Text('$hiddenCount behind cut', style: const TextStyle(fontSize: 10, color: PalCfg.muted)),
                ),
              ],
            ],
          ),
          Row(
            children: [
              _hudBtn('-', () => _zoomBy(0.85, vw, vh)),
              const SizedBox(width: 4),
              _hudBtn('Fit', _fitView),
              const SizedBox(width: 4),
              _hudBtn('+', () => _zoomBy(1.18, vw, vh)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hudBtn(String label, VoidCallback onTap) {
    return Material(
      color: const Color(0xE6FFFFFF),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: PalCfg.border)),
          child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: PalCfg.ink)),
        ),
      ),
    );
  }

  Widget _buildPlanItem(StickerData s, double pxPerCm, List<StickerData> sorted) {
    final item = widget.findItem(s.itemId);
    if (item == null) return const SizedBox.shrink();

    final itemW = math.max(10.0, item.planW(s.rotDeg) * pxPerCm);
    final itemH = math.max(10.0, item.planD(s.rotDeg) * pxPerCm);
    final left = (s.xCm * pxPerCm) - (itemW / 2);
    final top = (s.yCm * pxPerCm) - (itemH / 2);
    final upper = _isUpper(s, item);
    final isPicked = !widget.readOnly && s.id == widget.curId;
    final canDrag = isPicked && !s.isLocked && !widget.panMode;

    Widget art = RepaintBoundary(
      child: RotatedBox(
        quarterTurns: s.rotDeg ~/ 90,
        child: Transform.scale(scaleX: s.flipX ? -1.0 : 1.0, scaleY: 1.0, child: FootDraw(shapeKey: item.shapeKey, zone: item.zone, isUpper: upper)),
      ),
    );

    if (upper && !widget.readOnly && s.elevCm > 0) {
      art = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: art),
          Positioned(
            left: 2,
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(3)),
              child: Text('↑${UnitCfg.fmtGap(s.elevCm, widget.unit)}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: PalCfg.ruler)),
            ),
          ),
        ],
      );
    }

    art = _wrapPick(art, isPicked, s.isLocked);
    if (widget.readOnly) return Positioned(left: left, top: top, width: itemW, height: itemH, child: art);

    return Positioned(
      left: left,
      top: top,
      width: itemW,
      height: itemH,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          if (!isPicked) {
            widget.onPick?.call(s.id);
          } else {
            _pickPlan(s, (left + d.localPosition.dx) / pxPerCm, (top + d.localPosition.dy) / pxPerCm, sorted);
          }
        },
        onPanStart: canDrag
            ? (_) {
                _rawX = s.xCm;
                _rawY = s.yCm;
                _rawElev = s.elevCm;
                setState(() {
                  _dragId = s.id;
                  _dragX = s.xCm;
                  _dragY = s.yCm;
                  _dragElev = s.elevCm;
                });
              }
            : null,
        onPanUpdate: canDrag
            ? (d) {
                _rawX += d.delta.dx / pxPerCm;
                _rawY += d.delta.dy / pxPerCm;
                final next = _localClamp(s, item, _rawX, _rawY, _rawElev);
                setState(() {
                  _dragX = next.xCm;
                  _dragY = next.yCm;
                });
              }
            : null,
        onPanEnd: canDrag ? (_) => _commitDrag(s.id) : null,
        onPanCancel: canDrag ? () => _commitDrag(s.id) : null,
        child: art,
      ),
    );
  }

  List<Widget> _wallNodes(StickerData s, double pxPerCm, double rh, List<StickerData> ordered) {
    final item = widget.findItem(s.itemId);
    if (item == null) return const [];

    final rect = _wallRect(s, item, pxPerCm, rh);
    final proj = WallProj.of(s, item, widget.room, widget.wall);
    final maxDepth = (widget.wall == WallFace.north || widget.wall == WallFace.south) ? widget.room.roomD : widget.room.roomW;
    final isFar = !widget.readOnly && widget.fullDepth && proj.depthCm > maxDepth * 0.55;
    final isPicked = !widget.readOnly && s.id == widget.curId;
    final canDrag = isPicked && !s.isLocked && !widget.panMode;

    Widget art = RepaintBoundary(
      child: Transform.scale(scaleX: proj.flipX ? -1.0 : 1.0, scaleY: 1.0, child: ItemDraw(shapeKey: item.shapeKey, face: proj.face)),
    );

    if (isFar && !isPicked) art = Opacity(opacity: 0.58, child: art);
    art = _wrapPick(art, isPicked, s.isLocked);

    final nodes = <Widget>[];
    if (item.zone == PlaceZone.ceiling) {
      nodes.add(
        Positioned(
          left: rect.center.dx - 7,
          top: 0,
          width: 14,
          height: math.max(2.0, rect.top + rect.height * 0.10),
          child: IgnorePointer(
            child: Opacity(opacity: (isFar && !isPicked) ? 0.58 : 1.0, child: CustomPaint(painter: _CordDraw())),
          ),
        ),
      );
    }

    if (widget.readOnly) {
      nodes.add(Positioned.fromRect(rect: rect, child: art));
      return nodes;
    }

    nodes.add(
      Positioned.fromRect(
        rect: rect,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            if (!isPicked) {
              widget.onPick?.call(s.id);
            } else {
              _pickWall(s, rect.left + d.localPosition.dx, rect.top + d.localPosition.dy, pxPerCm, rh, ordered);
            }
          },
          onPanStart: canDrag
              ? (_) {
                  _rawX = s.xCm;
                  _rawY = s.yCm;
                  _rawElev = s.elevCm;
                  setState(() {
                    _dragId = s.id;
                    _dragX = s.xCm;
                    _dragY = s.yCm;
                    _dragElev = s.elevCm;
                  });
                }
              : null,
          onPanUpdate: canDrag
              ? (d) {
                  final du = d.delta.dx / pxPerCm;
                  switch (widget.wall) {
                    case WallFace.north:
                      _rawX += du;
                    case WallFace.east:
                      _rawY += du;
                    case WallFace.south:
                      _rawX -= du;
                    case WallFace.west:
                      _rawY -= du;
                  }
                  if (item.zone == PlaceZone.wall || item.zone == PlaceZone.ceiling || item.zone == PlaceZone.decor) {
                    _rawElev -= d.delta.dy / pxPerCm;
                  }
                  final next = _localClamp(s, item, _rawX, _rawY, _rawElev, snapElev: true);
                  setState(() {
                    _dragX = next.xCm;
                    _dragY = next.yCm;
                    _dragElev = next.elevCm;
                  });
                }
              : null,
          onPanEnd: canDrag ? (_) => _commitDrag(s.id) : null,
          onPanCancel: canDrag ? () => _commitDrag(s.id) : null,
          child: art,
        ),
      ),
    );
    return nodes;
  }

  Widget _wrapPick(Widget child, bool isPicked, bool isLocked) {
    if (!isPicked && !isLocked) return child;
    final borderCol = isLocked ? PalCfg.locked : PalCfg.accent;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: isPicked
              ? Container(
                  decoration: BoxDecoration(
                    color: isLocked ? const Color(0x14D97706) : const Color(0x142D6A4F),
                    border: Border.all(color: borderCol, width: 2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: child,
                )
              : child,
        ),
        if (isLocked)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: PalCfg.locked, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
              child: const Icon(Icons.lock, size: 9, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

class _CordDraw extends CustomPainter { // ceiling canopy mount & suspension wire
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - 6, 0, 12, 4), const Radius.circular(1)), Paint()..color = const Color(0xFF2B2B2B));
    canvas.drawLine(Offset(cx, 3), Offset(cx, size.height), Paint()..color = const Color(0xFF2B2B2B)..strokeWidth = 2.4);
  }

  @override
  bool shouldRepaint(covariant _CordDraw old) => false;
}

class _RuleDraw extends CustomPainter { // blue wall rulers & green closest-neighbor clearance lines
  final RoomData room;
  final List<StickerData> allItems;
  final ItemData? Function(String id) findItem;
  final StickerData sticker;
  final ItemData? item;
  final StageMode mode;
  final WallFace wall;
  final UnitKind unit;
  final double pxPerCm;
  final double rw;
  final double rh;
  final double Function(double depthCm) yFloorOf;

  _RuleDraw({
    required this.room,
    required this.allItems,
    required this.findItem,
    required this.sticker,
    required this.item,
    required this.mode,
    required this.wall,
    required this.unit,
    required this.pxPerCm,
    required this.rw,
    required this.rh,
    required this.yFloorOf,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final it = item;
    if (it == null) return;
    final wallLine = Paint()..color = PalCfg.ruler..strokeWidth = 1.2;
    final nearLine = Paint()..color = PalCfg.accent..strokeWidth = 1.6;

    if (mode == StageMode.plan) {
      final pw = it.planW(sticker.rotDeg);
      final pd = it.planD(sticker.rotDeg);
      final aL = sticker.xCm - pw / 2;
      final aR = sticker.xCm + pw / 2;
      final aT = sticker.yCm - pd / 2;
      final aB = sticker.yCm + pd / 2;

      double? nearL, nearR, nearT, nearB;
      double midLY = sticker.yCm, midRY = sticker.yCm, midTX = sticker.xCm, midBX = sticker.xCm;

      for (final other in allItems) {
        if (other.id == sticker.id) continue;
        final oi = findItem(other.itemId);
        if (oi == null || oi.zone == PlaceZone.rug || it.zone == PlaceZone.rug) continue;
        final ow = oi.planW(other.rotDeg);
        final od = oi.planD(other.rotDeg);
        final bL = other.xCm - ow / 2;
        final bR = other.xCm + ow / 2;
        final bT = other.yCm - od / 2;
        final bB = other.yCm + od / 2;

        if (bB > aT && bT < aB) {
          final yMid = (math.max(aT, bT) + math.min(aB, bB)) / 2;
          if (bR <= aL && aL - bR >= 1 && (nearL == null || aL - bR < nearL)) {
            nearL = aL - bR;
            midLY = yMid;
          } else if (bL >= aR && bL - aR >= 1 && (nearR == null || bL - aR < nearR)) {
            nearR = bL - aR;
            midRY = yMid;
          }
        }
        if (bR > aL && bL < aR) {
          final xMid = (math.max(aL, bL) + math.min(aR, bR)) / 2;
          if (bB <= aT && aT - bB >= 1 && (nearT == null || aT - bB < nearT)) {
            nearT = aT - bB;
            midTX = xMid;
          } else if (bT >= aB && bT - aB >= 1 && (nearB == null || bT - aB < nearB)) {
            nearB = bT - aB;
            midBX = xMid;
          }
        }
      }

      final cx = sticker.xCm * pxPerCm;
      final cy = sticker.yCm * pxPerCm;
      final lx = aL * pxPerCm;
      final rx = aR * pxPerCm;
      final ty = aT * pxPerCm;
      final by = aB * pxPerCm;

      if (aL > 4) {
        final wy = nearL != null ? cy - 11 : cy;
        canvas.drawLine(Offset(0, wy), Offset(lx, wy), wallLine);
        _tag(canvas, UnitCfg.fmtGap(aL, unit), Offset(lx / 2, wy), PalCfg.ruler);
      }
      if (nearL != null) {
        final ny = (midLY * pxPerCm - cy).abs() < 12 ? cy + 11 : midLY * pxPerCm;
        final bx = (aL - nearL) * pxPerCm;
        canvas.drawLine(Offset(bx, ny), Offset(lx, ny), nearLine);
        _tag(canvas, UnitCfg.fmtGap(nearL, unit), Offset((bx + lx) / 2, ny), PalCfg.accent);
      }

      final rightWall = room.roomW - aR;
      if (rightWall > 4) {
        final wy = nearR != null ? cy - 11 : cy;
        canvas.drawLine(Offset(rx, wy), Offset(rw, wy), wallLine);
        _tag(canvas, UnitCfg.fmtGap(rightWall, unit), Offset((rx + rw) / 2, wy), PalCfg.ruler);
      }
      if (nearR != null) {
        final ny = (midRY * pxPerCm - cy).abs() < 12 ? cy + 11 : midRY * pxPerCm;
        final bx = (aR + nearR) * pxPerCm;
        canvas.drawLine(Offset(rx, ny), Offset(bx, ny), nearLine);
        _tag(canvas, UnitCfg.fmtGap(nearR, unit), Offset((rx + bx) / 2, ny), PalCfg.accent);
      }

      if (aT > 4) {
        final wx = nearT != null ? cx - 18 : cx;
        canvas.drawLine(Offset(wx, 0), Offset(wx, ty), wallLine);
        _tag(canvas, UnitCfg.fmtGap(aT, unit), Offset(wx, ty / 2), PalCfg.ruler);
      }
      if (nearT != null) {
        final nx = (midTX * pxPerCm - cx).abs() < 18 ? cx + 18 : midTX * pxPerCm;
        final byEdge = (aT - nearT) * pxPerCm;
        canvas.drawLine(Offset(nx, byEdge), Offset(nx, ty), nearLine);
        _tag(canvas, UnitCfg.fmtGap(nearT, unit), Offset(nx, (byEdge + ty) / 2), PalCfg.accent);
      }

      final botWall = room.roomD - aB;
      if (botWall > 4) {
        final wx = nearB != null ? cx - 18 : cx;
        canvas.drawLine(Offset(wx, by), Offset(wx, rh), wallLine);
        _tag(canvas, UnitCfg.fmtGap(botWall, unit), Offset(wx, (by + rh) / 2), PalCfg.ruler);
      }
      if (nearB != null) {
        final nx = (midBX * pxPerCm - cx).abs() < 18 ? cx + 18 : midBX * pxPerCm;
        final tyEdge = (aB + nearB) * pxPerCm;
        canvas.drawLine(Offset(nx, by), Offset(nx, tyEdge), nearLine);
        _tag(canvas, UnitCfg.fmtGap(nearB, unit), Offset(nx, (by + tyEdge) / 2), PalCfg.accent);
      }
      return;
    }

    final proj = WallProj.of(sticker, it, room, wall);
    final fy = yFloorOf(proj.depthCm);
    final leftCm = proj.uCm - proj.visW / 2;
    final rightCm = proj.spanCm - (proj.uCm + proj.visW / 2);
    final midY = fy - (proj.elevCm + proj.visH / 2) * pxPerCm;
    final lx = leftCm * pxPerCm;
    final rx = (proj.uCm + proj.visW / 2) * pxPerCm;

    if (leftCm > 4) {
      canvas.drawLine(Offset(0, midY), Offset(lx, midY), wallLine);
      _tag(canvas, UnitCfg.fmtGap(leftCm, unit), Offset(lx / 2, midY), PalCfg.ruler);
    }
    if (rightCm > 4) {
      canvas.drawLine(Offset(rx, midY), Offset(rw, midY), wallLine);
      _tag(canvas, UnitCfg.fmtGap(rightCm, unit), Offset((rx + rw) / 2, midY), PalCfg.ruler);
    }
    if (proj.elevCm > 2) {
      final bx = proj.uCm * pxPerCm;
      final botY = fy - proj.elevCm * pxPerCm;
      canvas.drawLine(Offset(bx, botY), Offset(bx, fy), wallLine);
      _tag(canvas, UnitCfg.fmtGap(proj.elevCm, unit), Offset(bx, (botY + fy) / 2), PalCfg.ruler);
    }
  }

  void _tag(Canvas canvas, String text, Offset center, Color col) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: col)),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = Rect.fromCenter(center: center, width: tp.width + 8, height: tp.height + 4);
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), Paint()..color = const Color(0xEEFFFFFF));
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = 0.8);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _RuleDraw old) =>
      old.sticker != sticker || old.mode != mode || old.wall != wall || old.unit != unit || old.rw != rw || old.rh != rh;
}