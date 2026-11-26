import 'package:flutter/material.dart';
import '../core/app_cfg.dart';
import '../data/app_ctrl.dart';
import '../data/app_data.dart';
import '../stage/info_sht.dart';
import '../stage/room_view.dart';

class StoreScrn extends StatefulWidget { // saved rooms gallery & shopping list launcher
  final AppCtrl ctrl;
  final VoidCallback onStudio;
  final VoidCallback onAuth;

  const StoreScrn({super.key, required this.ctrl, required this.onStudio, required this.onAuth});

  @override
  State<StoreScrn> createState() => _StoreScrnState();
}

class _StoreScrnState extends State<StoreScrn> {
  StageMode _cardView = StageMode.plan;

  double _roomCost(RoomData room) {
    double sum = 0;
    for (final s in room.stickers) {
      sum += widget.ctrl.itemById(s.itemId)?.minPrice ?? 0;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final ui = UiCfg.of(context);
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.ctrl,
        builder: (context, _) {
          if (widget.ctrl.inLoad) return const Center(child: CircularProgressIndicator());
          if (widget.ctrl.isGuest) return _buildGate(ui);
          if (widget.ctrl.savedRooms.isEmpty) return _buildEmpty(ui);
          return _buildList(context, ui);
        },
      ),
    );
  }

  Widget _buildGate(UiCfg ui) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(ui.pad * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bookmarks_outlined, size: 52, color: PalCfg.muted),
            const SizedBox(height: 12),
            const Text('Saved Rooms & Shopping Lists', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: PalCfg.ink)),
            const SizedBox(height: 6),
            const Text('Sign in to save a room and see its shopping list.', textAlign: TextAlign.center, style: TextStyle(color: PalCfg.muted)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton(onPressed: widget.onAuth, style: FilledButton.styleFrom(backgroundColor: PalCfg.accent), child: const Text('Sign In / Register')),
                OutlinedButton(onPressed: () => widget.ctrl.doDemo(), child: const Text('Use demo account')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(UiCfg ui) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(ui.pad * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.meeting_room_outlined, size: 52, color: PalCfg.muted),
            const SizedBox(height: 12),
            const Text('No saved rooms yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: PalCfg.ink)),
            const SizedBox(height: 6),
            const Text('Decorate a room in Studio and tap Save to keep it here.', textAlign: TextAlign.center, style: TextStyle(color: PalCfg.muted)),
            const SizedBox(height: 16),
            FilledButton(onPressed: widget.onStudio, style: FilledButton.styleFrom(backgroundColor: PalCfg.accent), child: const Text('Open Studio')),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, UiCfg ui) {
    final rooms = widget.ctrl.savedRooms;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(ui.pad, 12, ui.pad, 6),
          child: Wrap(
            spacing: 10,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Saved Rooms (${rooms.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: PalCfg.ink)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChoiceChip(label: const Text('Plan', style: TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact, selected: _cardView == StageMode.plan, onSelected: (_) => setState(() => _cardView = StageMode.plan)),
                  const SizedBox(width: 4),
                  ChoiceChip(label: const Text('Wall', style: TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact, selected: _cardView == StageMode.wall, onSelected: (_) => setState(() => _cardView = StageMode.wall)),
                ],
              ),
              if (widget.ctrl.curRoom.stickers.isNotEmpty)
                TextButton.icon(
                  onPressed: () => ShopSht.show(context, widget.ctrl.curRoom, widget.ctrl),
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('Draft List'),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final cols = box.maxWidth >= 680 ? 2 : 1;
              if (cols == 1) {
                return ListView.separated(
                  padding: EdgeInsets.all(ui.pad),
                  itemCount: rooms.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _buildCard(context, rooms[i]),
                );
              }
              return GridView.builder(
                padding: EdgeInsets.all(ui.pad),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.88),
                itemCount: rooms.length,
                itemBuilder: (context, i) => _buildCard(context, rooms[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, RoomData room) {
    final studio = widget.ctrl.studios.firstWhere((s) => s.id == room.studioId, orElse: () => widget.ctrl.curStudio);
    final unit = widget.ctrl.prefs.unit;
    final cost = _roomCost(room);
    final overCap = room.budgetCap != null && cost > room.budgetCap!;

    return Container(
      decoration: BoxDecoration(color: PalCfg.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: PalCfg.border)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.5,
            child: RoomView(room: room, studio: studio, findItem: widget.ctrl.itemById, mode: _cardView, unit: unit, readOnly: true),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(room.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                    if (room.isPublic)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0x1A2D6A4F), borderRadius: BorderRadius.circular(4)),
                        child: const Text('Public', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: PalCfg.accent)),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text('${studio.name} • ${UnitCfg.fmtRoom(room.roomW, room.roomD, unit)}', style: const TextStyle(fontSize: 11, color: PalCfg.muted)),
                Text('${room.stickers.length} items • Est. ${UiCfg.fmtPeso(cost)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: overCap ? PalCfg.warn : PalCfg.accent)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.tonalIcon(onPressed: () => _askLoad(context, room), icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Edit')),
                    OutlinedButton.icon(onPressed: () => ShopSht.show(context, room, widget.ctrl), icon: const Icon(Icons.shopping_bag_outlined, size: 16), label: const Text('Shop List')),
                    IconButton(tooltip: 'Delete Room', onPressed: () => _askDrop(context, room), icon: const Icon(Icons.delete_outline, color: PalCfg.warn, size: 20)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _askLoad(BuildContext context, RoomData room) async {
    if (!widget.ctrl.hasDraft) {
      widget.ctrl.loadRoom(room);
      widget.onStudio();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load Room?'),
        content: const Text('This will replace your unsaved changes in Studio.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Load')),
        ],
      ),
    );
    if (ok == true) {
      widget.ctrl.loadRoom(room);
      widget.onStudio();
    }
  }

  Future<void> _askDrop(BuildContext context, RoomData room) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Saved Room?'),
        content: Text('Remove "${room.title}" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: PalCfg.warn), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await widget.ctrl.dropSaved(room.id);
  }
}