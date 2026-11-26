import 'package:flutter/material.dart';
import '../core/app_cfg.dart';
import '../data/app_ctrl.dart';
import '../data/app_data.dart';
import '../stage/info_sht.dart';
import '../stage/room_view.dart';
import '../stage/shape_draw.dart';

class ExploreScrn extends StatefulWidget { // searchable catalog + community lookbook feed
  final AppCtrl ctrl;
  final VoidCallback onStudio;

  const ExploreScrn({super.key, required this.ctrl, required this.onStudio});

  @override
  State<ExploreScrn> createState() => _ExploreScrnState();
}

class _ExploreScrnState extends State<ExploreScrn> {
  int _tabMode = 0; // 0 = catalog, 1 = lookbooks
  StageMode _bookView = StageMode.wall;
  String _curStyle = 'All';
  String _query = '';

  List<ItemData> _shownItems() {
    final q = _query.trim().toLowerCase();
    return widget.ctrl.items.where((item) {
      final styleOk = _curStyle == 'All' || item.styles.contains(_curStyle);
      final qOk = q.isEmpty || item.name.toLowerCase().contains(q) || item.cat.toLowerCase().contains(q);
      return styleOk && qOk;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ui = UiCfg.of(context);
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.ctrl,
        builder: (context, _) {
          if (widget.ctrl.inLoad) return const Center(child: CircularProgressIndicator());
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(ui.pad, 10, ui.pad, 6),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Discover', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: PalCfg.ink)),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Catalog', style: TextStyle(fontSize: 12))),
                        ButtonSegment(value: 1, label: Text('Lookbooks', style: TextStyle(fontSize: 12))),
                      ],
                      selected: {_tabMode},
                      onSelectionChanged: (v) => setState(() => _tabMode = v.first),
                    ),
                  ],
                ),
              ),
              Expanded(child: _tabMode == 0 ? _buildCat(context, ui) : _buildBooks(context, ui)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCat(BuildContext context, UiCfg ui) {
    final styles = ['All', ...{for (final i in widget.ctrl.items) ...i.styles}];
    final shown = _shownItems();
    final unit = widget.ctrl.prefs.unit;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: ui.pad, vertical: 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search furniture or category...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: PalCfg.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: PalCfg.border)),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: ui.pad, vertical: 4),
          child: SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final st in styles)
                  ChoiceChip(
                    label: Text(st, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    selected: _curStyle == st,
                    onSelected: (_) => setState(() => _curStyle = st),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              if (shown.isEmpty) return const Center(child: Text('No matching furniture found', style: TextStyle(color: PalCfg.muted)));
              final cols = (box.maxWidth / 160).floor().clamp(2, 5);
              return GridView.builder(
                padding: EdgeInsets.all(ui.pad),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.82),
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final item = shown[i];
                  return InkWell(
                    onTap: () => InfoSht.show(
                      context,
                      item,
                      unit: unit,
                      onDrop: () {
                        widget.ctrl.dropSticker(item);
                        widget.onStudio();
                      },
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: PalCfg.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: PalCfg.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Center(child: ItemDraw(shapeKey: item.shapeKey))),
                          const SizedBox(height: 8),
                          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          Text(UnitCfg.fmtItem(item.wCm, item.dCm, item.hCm, unit), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: PalCfg.muted)),
                          const SizedBox(height: 3),
                          Text('From ${UiCfg.fmtPeso(item.minPrice)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PalCfg.accent)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBooks(BuildContext context, UiCfg ui) {
    final books = widget.ctrl.lookbooks;
    if (books.isEmpty) return const Center(child: Text('No community lookbooks yet', style: TextStyle(color: PalCfg.muted)));

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: ui.pad, vertical: 2),
          child: Row(
            children: [
              const Text('Preview:', style: TextStyle(fontSize: 12, color: PalCfg.muted)),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('North Wall', style: TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact, selected: _bookView == StageMode.wall, onSelected: (_) => setState(() => _bookView = StageMode.wall)),
              const SizedBox(width: 6),
              ChoiceChip(label: const Text('Top Plan', style: TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact, selected: _bookView == StageMode.plan, onSelected: (_) => setState(() => _bookView = StageMode.plan)),
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
                  itemCount: books.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _bookCard(context, books[i]),
                );
              }
              return GridView.builder(
                padding: EdgeInsets.all(ui.pad),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.88),
                itemCount: books.length,
                itemBuilder: (context, i) => _bookCard(context, books[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _bookCard(BuildContext context, RoomData room) {
    final studio = widget.ctrl.studios.firstWhere((s) => s.id == room.studioId, orElse: () => widget.ctrl.curStudio);
    final unit = widget.ctrl.prefs.unit;
    double est = 0;
    for (final s in room.stickers) {
      est += widget.ctrl.itemById(s.itemId)?.minPrice ?? 0;
    }

    return Container(
      decoration: BoxDecoration(color: PalCfg.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: PalCfg.border)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.5,
            child: RoomView(room: room, studio: studio, findItem: widget.ctrl.itemById, mode: _bookView, unit: unit, readOnly: true),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('${studio.name} • ${UnitCfg.fmtRoom(room.roomW, room.roomD, unit)}', style: const TextStyle(fontSize: 11, color: PalCfg.muted)),
                Text('${room.stickers.length} items • Est. ${UiCfg.fmtPeso(est)}', style: const TextStyle(fontSize: 12, color: PalCfg.accent, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        widget.ctrl.cloneRoom(room);
                        widget.onStudio();
                      },
                      style: FilledButton.styleFrom(backgroundColor: PalCfg.accent),
                      icon: const Icon(Icons.copy_all_outlined, size: 16),
                      label: const Text('Remix'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => ShopSht.show(context, room, widget.ctrl),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                      label: const Text('Shop Look'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}