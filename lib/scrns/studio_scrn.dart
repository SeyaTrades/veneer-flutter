import 'package:flutter/material.dart';
import '../core/app_cfg.dart';
import '../data/app_ctrl.dart';
import '../data/app_data.dart';
import '../stage/info_sht.dart';
import '../stage/room_view.dart';
import '../stage/shape_draw.dart';

class StudioScrn extends StatefulWidget { // 3-breakpoint dual-view planner + 5-button beginner strip
  final AppCtrl ctrl;
  final VoidCallback? onAuth;

  const StudioScrn({super.key, required this.ctrl, this.onAuth});

  @override
  State<StudioScrn> createState() => _StudioScrnState();
}

class _StudioScrnState extends State<StudioScrn> {
  String _curCat = 'All';
  bool _roomOnly = false;
  bool _showTray = true;
  int _sideTab = 0; // desktop right sidebar: 0 = catalog, 1 = coordinates
  int _topLevel = 0; // top plan filter: 0 = all, 1 = floor only, 2 = upper only
  bool _fullDepth = false; // wall cut: false = half depth, true = full room

  List<ItemData> _shownItems() {
    final kind = widget.ctrl.curStudio.kind;
    return widget.ctrl.items.where((item) {
      final catOk = _curCat == 'All' || item.cat == _curCat;
      final roomOk = !_roomOnly || kind == RoomKind.blank || item.rooms.contains(kind);
      return catOk && roomOk;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ui = UiCfg.of(context);
    return ListenableBuilder(
      listenable: widget.ctrl,
      builder: (context, _) {
        if (widget.ctrl.inLoad) return const Center(child: CircularProgressIndicator());
        if (ui.isDesk) return _buildDesk(context, ui);

        if (ui.isWide) { // landscape phones use 2-column split without shrinking vertically
          return SafeArea(
            child: Row(
              children: [
                Expanded(flex: 3, child: _buildStage(context, ui, expand: true)),
                Container(width: 1, color: PalCfg.border),
                Expanded(flex: 2, child: _buildSide(context, ui)),
              ],
            ),
          );
        }

        final picked = widget.ctrl.pickedSticker;
        return SafeArea( // phone & portrait tablet stay stacked vertically
          child: Column(
            children: [
              if (_showTray) _buildStage(context, ui, expand: false) else Expanded(child: _buildStage(context, ui, expand: true)),
              if (picked != null) _buildBar(context, picked, ui),
              if (_showTray) Expanded(child: _buildTray(context, ui)) else _trayBar(ui),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesk(BuildContext context, UiCfg ui) {
    final picked = widget.ctrl.pickedSticker;
    return SafeArea(
      child: Column(
        children: [
          _buildHead(context, ui),
          _buildTool(context, ui),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: _buildBox(context, ui)),
                      if (picked != null)
                        Padding(
                          padding: EdgeInsets.fromLTRB(ui.pad, 0, ui.pad, 8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 540),
                            child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _buildBar(context, picked, ui)),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(width: 1, color: PalCfg.border),
                SizedBox(width: 320, child: _buildSide(context, ui)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSide(BuildContext context, UiCfg ui) {
    final picked = widget.ctrl.pickedSticker;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(ui.pad),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Catalog', style: TextStyle(fontSize: 12))),
                ButtonSegment(value: 1, label: Text('Properties', style: TextStyle(fontSize: 12))),
              ],
              selected: {_sideTab},
              onSelectionChanged: (v) => setState(() => _sideTab = v.first),
            ),
          ),
        ),
        Expanded(
          child: _sideTab == 1
              ? (picked == null
                  ? const Center(child: Text('Tap a piece of furniture to see its position.', textAlign: TextAlign.center, style: TextStyle(color: PalCfg.muted)))
                  : SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: ui.pad),
                      child: PropSht(ctrl: widget.ctrl, stickerId: picked.id, asCard: true),
                    ))
              : _buildTray(context, ui),
        ),
      ],
    );
  }

  Widget _buildStage(BuildContext context, UiCfg ui, {required bool expand}) {
    return Column(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        _buildHead(context, ui),
        _buildTool(context, ui),
        if (expand) Expanded(child: _buildBox(context, ui)) else SizedBox(height: ui.stageH, width: double.infinity, child: _buildBox(context, ui)),
      ],
    );
  }

  Widget _buildBox(BuildContext context, UiCfg ui) {
    return Padding(
      padding: EdgeInsets.fromLTRB(ui.pad, 4, ui.pad, 6),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: PalCfg.border)),
        clipBehavior: Clip.antiAlias,
        child: RoomView(
          room: widget.ctrl.curRoom,
          studio: widget.ctrl.curStudio,
          findItem: widget.ctrl.itemById,
          mode: widget.ctrl.stageMode,
          wall: widget.ctrl.wallFace,
          unit: widget.ctrl.prefs.unit,
          showGrid: widget.ctrl.prefs.showGrid,
          snapOn: widget.ctrl.prefs.snapOn,
          panMode: widget.ctrl.panMode,
          topLevel: _topLevel,
          fullDepth: _fullDepth,
          curId: widget.ctrl.curId,
          onPick: widget.ctrl.pickSticker,
          onMove: _stageMove,
          onLayers: () => _openList(context),
        ),
      ),
    );
  }

  void _stageMove(String id, double xCm, double yCm, double elevCm) {
    if (widget.ctrl.stageMode == StageMode.plan) {
      widget.ctrl.moveItem(id, xCm, yCm);
      return;
    }
    final u = widget.ctrl.prefs.unit;
    final snap = widget.ctrl.prefs.snapOn;
    widget.ctrl.setCoords(
      id,
      xCm: UnitCfg.snapCm(xCm, u, on: snap),
      yCm: UnitCfg.snapCm(yCm, u, on: snap),
      elevCm: UnitCfg.snapCm(elevCm, u, on: snap),
    );
  }

  Widget _buildHead(BuildContext context, UiCfg ui) {
    final room = widget.ctrl.curRoom;
    final cost = widget.ctrl.roomCost;
    final cap = room.budgetCap;
    final over = cap != null && cost > cap;

    return Padding(
      padding: EdgeInsets.fromLTRB(ui.pad, 6, ui.pad, 2),
      child: Row(
        children: [
          Expanded(
            child: Column( // sibling tap targets keep title save & budget cap clicks cleanly separated
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _trySave(context),
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(room.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: PalCfg.ink)),
                      ),
                      if (widget.ctrl.hasDraft) const Text(' •', style: TextStyle(fontSize: 16, color: PalCfg.accent)),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _openCap(context),
                  borderRadius: BorderRadius.circular(4),
                  child: Text(
                    cap == null ? 'Est. ${UiCfg.fmtPeso(cost)} • Set Budget' : 'Est. ${UiCfg.fmtPeso(cost)} / ${UiCfg.fmtPeso(cap)}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: over ? PalCfg.warn : PalCfg.accent),
                  ),
                ),
              ],
            ),
          ),
          IconButton(tooltip: 'Quick Settings', visualDensity: VisualDensity.compact, onPressed: () => _openPrefs(context), icon: const Icon(Icons.tune, size: 19)),
          OutlinedButton.icon(
            onPressed: () => _askNew(context),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: ui.isSlim ? 8 : 10, vertical: 6),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.note_add_outlined, size: 15),
            label: Text(ui.isSlim ? '' : 'New', style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: widget.ctrl.inSave ? null : () => _trySave(context),
            style: FilledButton.styleFrom(
              backgroundColor: PalCfg.accent,
              padding: EdgeInsets.symmetric(horizontal: ui.isSlim ? 10 : 12, vertical: 6),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.bookmark_outline, size: 15),
            label: Text(widget.ctrl.inSave ? '...' : 'Save', style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildTool(BuildContext context, UiCfg ui) {
    final room = widget.ctrl.curRoom;
    final unit = widget.ctrl.prefs.unit;
    final isPlan = widget.ctrl.stageMode == StageMode.plan;

    return Padding(
      padding: EdgeInsets.fromLTRB(ui.pad, 4, ui.pad, 4),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PopupMenuButton<String>(
              tooltip: 'Change Room Type',
              onSelected: (id) => _pickRoom(context, id),
              itemBuilder: (_) => [
                for (final st in widget.ctrl.studios)
                  PopupMenuItem(
                    value: st.id,
                    child: Row(
                      children: [
                        Icon(st.id == room.studioId ? Icons.check_circle : Icons.meeting_room_outlined, size: 16, color: st.id == room.studioId ? PalCfg.accent : PalCfg.muted),
                        const SizedBox(width: 8),
                        Text(st.name),
                      ],
                    ),
                  ),
              ],
              child: _pillBox(Icons.meeting_room_outlined, widget.ctrl.curStudio.name, hasArrow: true),
            ),
            InkWell(
              onTap: () => _openDim(context),
              borderRadius: BorderRadius.circular(16),
              child: _pillBox(Icons.square_foot, UnitCfg.fmtRoom(room.roomW, room.roomD, unit)),
            ),
            SegmentedButton<StageMode>(
              style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              segments: const [
                ButtonSegment(value: StageMode.plan, label: Text('Top Plan', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: StageMode.wall, label: Text('Wall', style: TextStyle(fontSize: 11))),
              ],
              selected: {widget.ctrl.stageMode},
              onSelectionChanged: (v) => widget.ctrl.setMode(v.first),
            ),
            if (isPlan)
              SegmentedButton<int>(
                style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                segments: const [
                  ButtonSegment(value: 0, label: Text('All', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: 1, label: Text('Floor', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: 2, label: Text('Upper', style: TextStyle(fontSize: 11))),
                ],
                selected: {_topLevel},
                onSelectionChanged: (v) => setState(() => _topLevel = v.first),
              )
            else ...[
              SegmentedButton<WallFace>(
                style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                segments: const [
                  ButtonSegment(value: WallFace.north, label: Text('N', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: WallFace.east, label: Text('E', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: WallFace.south, label: Text('S', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: WallFace.west, label: Text('W', style: TextStyle(fontSize: 11))),
                ],
                selected: {widget.ctrl.wallFace},
                onSelectionChanged: (v) => widget.ctrl.setWall(v.first),
              ),
              SegmentedButton<bool>(
                style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                segments: const [
                  ButtonSegment(value: false, label: Text('Half Depth', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: true, label: Text('Full', style: TextStyle(fontSize: 11))),
                ],
                selected: {_fullDepth},
                onSelectionChanged: (v) => setState(() => _fullDepth = v.first),
              ),
            ],
            FilterChip(
              label: Text(widget.ctrl.panMode ? 'Pan View' : 'Move Items', style: const TextStyle(fontSize: 11)),
              avatar: Icon(widget.ctrl.panMode ? Icons.pan_tool_outlined : Icons.touch_app_outlined, size: 14),
              visualDensity: VisualDensity.compact,
              selected: widget.ctrl.panMode,
              onSelected: (_) => widget.ctrl.togglePan(),
            ),
            if (!ui.isDesk && !ui.isWide)
              OutlinedButton.icon(
                onPressed: () => setState(() => _showTray = !_showTray),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(_showTray ? Icons.keyboard_arrow_down : Icons.add_box_outlined, size: 15),
                label: Text(_showTray ? 'Expand' : 'Catalog', style: const TextStyle(fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pillBox(IconData icon, String text, {bool hasArrow = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: PalCfg.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: PalCfg.border)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: PalCfg.accent),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: PalCfg.ink)),
          if (hasArrow) const Icon(Icons.arrow_drop_down, size: 16, color: PalCfg.muted),
        ],
      ),
    );
  }

  Widget _buildBar(BuildContext context, StickerData s, UiCfg ui) { // 5 uniform plain-word actions for non-natives
    final item = widget.ctrl.itemById(s.itemId);
    if (item == null) return const SizedBox.shrink();
    final unit = widget.ctrl.prefs.unit;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(ui.pad, 6, ui.pad, 6),
      decoration: const BoxDecoration(
        color: PalCfg.surface,
        border: Border(top: BorderSide(color: PalCfg.border), bottom: BorderSide(color: PalCfg.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.name} • ${UnitCfg.fmtItem(item.wCm, item.dCm, item.hCm, unit)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PalCfg.ink),
                ),
              ),
              if (!ui.isDesk)
                TextButton.icon(
                  onPressed: () => PropSht.show(context, widget.ctrl, s.id),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6)),
                  icon: const Icon(Icons.straighten, size: 15),
                  label: const Text('Position', style: TextStyle(fontSize: 11)),
                ),
              IconButton(visualDensity: VisualDensity.compact, tooltip: 'Deselect', onPressed: () => widget.ctrl.pickSticker(null), icon: const Icon(Icons.close, size: 17, color: PalCfg.muted)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _actBtn(Icons.rotate_right, 'Turn', s.isLocked ? null : () => widget.ctrl.turnItem(s.id)),
              _actBtn(s.isLocked ? Icons.lock : Icons.lock_open, s.isLocked ? 'Unlock' : 'Lock', () => widget.ctrl.toggleLock(s.id), amber: s.isLocked),
              _actBtn(Icons.copy_outlined, 'Copy', () => widget.ctrl.copySticker(s.id)),
              _actBtn(Icons.shopping_bag_outlined, 'Shop', () => InfoSht.show(context, item, unit: unit), accent: true),
              _actBtn(Icons.delete_outline, 'Delete', s.isLocked ? null : () => widget.ctrl.cutSticker(s.id), warn: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actBtn(IconData icon, String label, VoidCallback? onTap, {bool accent = false, bool warn = false, bool amber = false}) {
    final disabled = onTap == null;
    final fg = disabled
        ? PalCfg.border
        : accent
            ? Colors.white
            : warn
                ? PalCfg.warn
                : amber
                    ? PalCfg.locked
                    : PalCfg.ink;
    final bg = accent ? PalCfg.accent : (amber ? const Color(0x14D97706) : PalCfg.bg);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent ? PalCfg.accent : (amber ? PalCfg.locked : PalCfg.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: fg),
                const SizedBox(height: 2),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _trayBar(UiCfg ui) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: ui.pad, vertical: 8),
      decoration: const BoxDecoration(color: PalCfg.surface, border: Border(top: BorderSide(color: PalCfg.border))),
      child: FilledButton.tonalIcon(
        onPressed: () => setState(() => _showTray = true),
        icon: const Icon(Icons.keyboard_arrow_up, size: 18),
        label: Text('Open Furniture Catalog (${widget.ctrl.items.length})'),
      ),
    );
  }

  Widget _buildTray(BuildContext context, UiCfg ui) {
    final cats = ['All', ...{for (final i in widget.ctrl.items) i.cat}];
    final shown = _shownItems();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(ui.pad, 6, ui.pad, 2),
          child: Row(
            children: [
              PopupMenuButton<String>(
                tooltip: 'Filter Category',
                onSelected: (c) => setState(() => _curCat = c),
                itemBuilder: (_) => [for (final c in cats) PopupMenuItem(value: c, child: Text(c))],
                child: _pillBox(Icons.category_outlined, _curCat, hasArrow: true),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Room Fit', style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                selected: _roomOnly,
                onSelected: (v) => setState(() => _roomOnly = v),
              ),
              const Spacer(),
              Text('${shown.length} items', style: const TextStyle(fontSize: 11, color: PalCfg.muted)),
            ],
          ),
        ),
        Expanded(
          child: RepaintBoundary( // isolates 20-card grid from stage rebuilds
            child: LayoutBuilder(
              builder: (context, box) {
                if (shown.isEmpty) return const Center(child: Text('No items match this filter', style: TextStyle(color: PalCfg.muted)));
                return GridView.builder(
                  padding: EdgeInsets.all(ui.pad),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: ui.gridCols(box.maxWidth),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.86,
                  ),
                  itemCount: shown.length,
                  itemBuilder: (context, i) => _buildCard(context, shown[i]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, ItemData item) {
    return InkWell(
      onTap: () => widget.ctrl.dropSticker(item),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: PalCfg.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: PalCfg.border)),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () => InfoSht.show(context, item, unit: widget.ctrl.prefs.unit, onDrop: () => widget.ctrl.dropSticker(item)),
                  child: const Icon(Icons.info_outline, size: 15, color: PalCfg.muted),
                ),
              ],
            ),
            Expanded(child: ItemDraw(shapeKey: item.shapeKey)),
            const SizedBox(height: 4),
            Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
            Text(UiCfg.fmtPeso(item.minPrice), style: const TextStyle(fontSize: 10, color: PalCfg.accent, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRoom(BuildContext context, String nextId) async {
    if (nextId == widget.ctrl.curRoom.studioId) return;
    final rule = widget.ctrl.prefs.switchRule;
    final latest = widget.ctrl.latestRoom(nextId);

    if (rule == SwitchRule.keepItems) {
      widget.ctrl.switchRoom(nextId, keepItems: true);
      return;
    }
    if (rule == SwitchRule.blank) {
      widget.ctrl.switchRoom(nextId, keepItems: false);
      return;
    }
    if (rule == SwitchRule.loadLast) {
      widget.ctrl.switchRoom(nextId, loadSaved: latest);
      return;
    }

    final hasItems = widget.ctrl.curRoom.stickers.isNotEmpty;
    if (!hasItems && latest == null) {
      widget.ctrl.switchRoom(nextId);
      return;
    }

    final target = widget.ctrl.studios.firstWhere((s) => s.id == nextId, orElse: () => widget.ctrl.curStudio);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Switch to ${target.name}?'),
        content: Text(
          hasItems
              ? 'What would you like to do with the furniture in this room?'
              : 'You have a saved ${target.name} ("${latest!.title}"). Load it?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          if (hasItems) ...[
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.ctrl.switchRoom(nextId, keepItems: true);
              },
              child: const Text('Keep Furniture'),
            ),
            if (!widget.ctrl.isGuest)
              OutlinedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await widget.ctrl.saveRoom();
                  widget.ctrl.switchRoom(nextId, loadSaved: latest);
                },
                child: const Text('Save & Switch'),
              ),
          ],
          if (latest != null)
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.ctrl.switchRoom(nextId, loadSaved: latest);
              },
              child: Text('Load "${latest.title}"'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.ctrl.switchRoom(nextId, keepItems: false);
            },
            child: const Text('Start Empty'),
          ),
        ],
      ),
    );
  }

  Future<void> _askNew(BuildContext context) async {
    final empty = widget.ctrl.curRoom.stickers.isEmpty && !widget.ctrl.hasDraft;
    if (empty) {
      widget.ctrl.newRoom(studioId: widget.ctrl.curRoom.studioId);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Blank Room?'),
        content: const Text('Any changes you have not saved will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: PalCfg.warn), onPressed: () => Navigator.pop(ctx, true), child: const Text('Start empty')),
        ],
      ),
    );
    if (ok == true) widget.ctrl.newRoom(studioId: widget.ctrl.curRoom.studioId);
  }

  Future<void> _trySave(BuildContext context) async {
    if (widget.ctrl.isGuest) {
      if (widget.onAuth != null) {
        widget.onAuth!();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in required to save rooms')));
      }
      return;
    }
    await _openSave(context);
  }

  Future<void> _openSave(BuildContext context) async {
    String title = widget.ctrl.curRoom.title;
    bool pub = widget.ctrl.curRoom.isPublic;
    final canUpdate = widget.ctrl.isSaved;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(canUpdate ? 'Save Changes' : 'Save Room'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(initialValue: title, decoration: const InputDecoration(labelText: 'Room Name'), onChanged: (v) => title = v),
              const SizedBox(height: 12),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Share to Lookbooks', style: TextStyle(fontSize: 14)), value: pub, onChanged: (v) => setDlg(() => pub = v)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            if (canUpdate)
              OutlinedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  widget.ctrl.setTitle(title);
                  widget.ctrl.setPublic(pub);
                  final ok = await widget.ctrl.saveRoom(asNew: true);
                  if (context.mounted && ok) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved copy "${widget.ctrl.curRoom.title}"')));
                  }
                },
                child: const Text('Save as Copy'),
              ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                widget.ctrl.setTitle(title);
                widget.ctrl.setPublic(pub);
                final ok = await widget.ctrl.saveRoom(asNew: !canUpdate);
                if (context.mounted && ok) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved "${widget.ctrl.curRoom.title}"')));
                }
              },
              child: Text(canUpdate ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDim(BuildContext context) async {
    final unit = widget.ctrl.prefs.unit;
    final r = widget.ctrl.curRoom;
    String rawW = UnitCfg.toInput(r.roomW, unit).toStringAsFixed(0);
    String rawD = UnitCfg.toInput(r.roomD, unit).toStringAsFixed(0);
    String rawH = UnitCfg.toInput(r.ceilH, unit).toStringAsFixed(0);
    final uTag = UnitCfg.inputTag(unit);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Room Dimensions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(initialValue: rawW, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Width ($uTag)'), onChanged: (v) => rawW = v),
            const SizedBox(height: 8),
            TextFormField(initialValue: rawD, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Depth ($uTag)'), onChanged: (v) => rawD = v),
            const SizedBox(height: 8),
            TextFormField(initialValue: rawH, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Ceiling Height ($uTag)'), onChanged: (v) => rawH = v),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final w = double.tryParse(rawW.trim());
              final d = double.tryParse(rawD.trim());
              final h = double.tryParse(rawH.trim());
              if (w != null && d != null && h != null) {
                widget.ctrl.setRoomDim(UnitCfg.fromInput(w, unit), UnitCfg.fromInput(d, unit), UnitCfg.fromInput(h, unit));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPrefs(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      builder: (_) => ListenableBuilder(
        listenable: widget.ctrl,
        builder: (context, _) {
          final p = widget.ctrl.prefs;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Planner Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Measurement Units'),
                    trailing: SegmentedButton<UnitKind>(
                      segments: const [
                        ButtonSegment(value: UnitKind.metric, label: Text('Metric')),
                        ButtonSegment(value: UnitKind.imperial, label: Text('Imperial')),
                      ],
                      selected: {p.unit},
                      onSelectionChanged: (v) => widget.ctrl.setPrefs(p.copyWith(unit: v.first)),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Snap to Grid (${p.unit == UnitKind.metric ? "5 cm" : "2 in"})'),
                    value: p.snapOn,
                    onChanged: (v) => widget.ctrl.setPrefs(p.copyWith(snapOn: v)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Blueprint Grid'),
                    value: p.showGrid,
                    onChanged: (v) => widget.ctrl.setPrefs(p.copyWith(showGrid: v)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openCap(BuildContext context) async {
    String rawCap = widget.ctrl.curRoom.budgetCap?.toStringAsFixed(0) ?? '';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Room Budget Cap'),
        content: TextFormField(
          initialValue: rawCap,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Max Budget (₱)', hintText: 'e.g. 25000'),
          onChanged: (v) => rawCap = v,
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.ctrl.setBudget(null);
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(rawCap.trim());
              widget.ctrl.setBudget(parsed != null && parsed > 0 ? parsed : null);
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _openList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListenableBuilder(
        listenable: widget.ctrl,
        builder: (context, _) {
          final topDown = [...widget.ctrl.curRoom.stickers]..sort((a, b) => b.zIdx.compareTo(a.zIdx));
          if (topDown.isEmpty) return const SizedBox(height: 140, child: Center(child: Text('No items placed yet')));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: topDown.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = topDown[i];
              final item = widget.ctrl.itemById(s.itemId);
              return ListTile(
                selected: s.id == widget.ctrl.curId,
                leading: SizedBox(width: 40, height: 40, child: item == null ? null : ItemDraw(shapeKey: item.shapeKey)),
                title: Text(item?.name ?? s.itemId),
                subtitle: Text('${s.rotDeg}°${s.isLocked ? " • Locked" : ""}'),
                trailing: IconButton(
                  icon: Icon(s.isLocked ? Icons.lock : Icons.lock_open, size: 18, color: s.isLocked ? PalCfg.locked : PalCfg.muted),
                  onPressed: () => widget.ctrl.toggleLock(s.id),
                ),
                onTap: () {
                  widget.ctrl.pickSticker(s.id);
                  Navigator.pop(context);
                },
              );
            },
          );
        },
      ),
    );
  }
}