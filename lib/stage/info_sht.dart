import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_cfg.dart';
import '../data/app_ctrl.dart';
import '../data/app_data.dart';
import 'shape_draw.dart';

class InfoSht extends StatelessWidget { // product dimensions, price comparison & external shop redirects
  final ItemData item;
  final UnitKind unit;
  final VoidCallback? onDrop;

  const InfoSht({super.key, required this.item, this.unit = UnitKind.metric, this.onDrop});

  static void show(BuildContext context, ItemData item, {UnitKind unit = UnitKind.metric, VoidCallback? onDrop}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PalCfg.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => InfoSht(item: item, unit: unit, onDrop: onDrop),
    );
  }

  Future<void> _openUrl(BuildContext context, String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open store link')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open store link')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...item.listings]..sort((a, b) => a.bestPrice.compareTo(b.bestPrice));
    final fallbackUrl = 'https://www.google.com/search?tbm=shop&q=${Uri.encodeComponent(item.name)}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: PalCfg.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: PalCfg.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: PalCfg.border)),
                  child: ItemDraw(shapeKey: item.shapeKey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: PalCfg.ink)),
                      const SizedBox(height: 3),
                      Text('${item.cat} • ${UnitCfg.fmtItem(item.wCm, item.dCm, item.hCm, unit)}', style: const TextStyle(fontSize: 12, color: PalCfg.muted)),
                      const SizedBox(height: 3),
                      Text('From ${UiCfg.fmtPeso(item.minPrice)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: PalCfg.accent)),
                    ],
                  ),
                ),
                if (onDrop != null)
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onDrop!();
                    },
                    child: const Text('Place'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Compare Stores', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: PalCfg.ink)),
            const SizedBox(height: 8),
            for (int i = 0; i < sorted.length; i++) _buildRow(context, sorted[i], i == 0),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openUrl(context, fallbackUrl),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Search More Stores Online'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, StoreRef ref, bool isBest) {
    final hasSale = ref.salePrice != null && ref.salePrice! < ref.regPrice;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isBest ? const Color(0x0D2D6A4F) : PalCfg.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isBest ? PalCfg.accent : PalCfg.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(ref.store, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: PalCfg.ink)),
                    if (isBest) _tagPill('BEST', PalCfg.accent),
                    if (ref.promoTag != null) _tagPill(ref.promoTag!, const Color(0xFFD97706)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(UiCfg.fmtPeso(ref.bestPrice), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: PalCfg.ink)),
                    if (hasSale) ...[
                      const SizedBox(width: 6),
                      Text(UiCfg.fmtPeso(ref.regPrice), style: const TextStyle(fontSize: 12, color: PalCfg.muted, decoration: TextDecoration.lineThrough)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          TextButton.icon(onPressed: () => _openUrl(context, ref.url), icon: const Icon(Icons.open_in_new, size: 16), label: const Text('Visit')),
        ],
      ),
    );
  }

  Widget _tagPill(String label, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}

class PropSht extends StatelessWidget { // AutoCAD exact coordinates, wall offsets & elevation inspector
  final AppCtrl ctrl;
  final String stickerId;
  final bool asCard;

  const PropSht({super.key, required this.ctrl, required this.stickerId, this.asCard = false});

  static void show(BuildContext context, AppCtrl ctrl, String stickerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PalCfg.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: PropSht(ctrl: ctrl, stickerId: stickerId))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final s = ctrl.curRoom.stickers.where((e) => e.id == stickerId).firstOrNull;
        if (s == null) return const SizedBox.shrink();
        final item = ctrl.itemById(s.itemId);
        if (item == null) return const SizedBox.shrink();

        final unit = ctrl.prefs.unit;
        final step = UnitCfg.nudgeCm(unit);
        final pw = item.planW(s.rotDeg);
        final pd = item.planD(s.rotDeg);
        final leftGap = (s.xCm - pw / 2).clamp(0.0, ctrl.curRoom.roomW);
        final topGap = (s.yCm - pd / 2).clamp(0.0, ctrl.curRoom.roomD);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: PalCfg.ink)),
                      Text('${UnitCfg.fmtItem(item.wCm, item.dCm, item.hCm, unit)} • ${s.rotDeg}°', style: const TextStyle(fontSize: 12, color: PalCfg.muted)),
                    ],
                  ),
                ),
                if (s.isLocked)
                  Chip(label: const Text('Locked', style: TextStyle(fontSize: 11, color: Colors.white)), backgroundColor: PalCfg.locked, visualDensity: VisualDensity.compact),
              ],
            ),
            const SizedBox(height: 10),
            _numRow(
              context,
              label: 'From West Wall',
              valText: UnitCfg.fmtGap(leftGap, unit),
              locked: s.isLocked,
              onDec: () => ctrl.nudgeItem(s.id, -step, 0),
              onInc: () => ctrl.nudgeItem(s.id, step, 0),
              onEdit: () => _editGap(context, 'Distance from West Wall', leftGap, (v) => ctrl.setCoords(s.id, xCm: v + pw / 2)),
            ),
            _numRow(
              context,
              label: 'From North Wall',
              valText: UnitCfg.fmtGap(topGap, unit),
              locked: s.isLocked,
              onDec: () => ctrl.nudgeItem(s.id, 0, -step),
              onInc: () => ctrl.nudgeItem(s.id, 0, step),
              onEdit: () => _editGap(context, 'Distance from North Wall', topGap, (v) => ctrl.setCoords(s.id, yCm: v + pd / 2)),
            ),
            _numRow(
              context,
              label: 'Floor Height (Elev)',
              valText: UnitCfg.fmtGap(s.elevCm, unit),
              locked: s.isLocked,
              onDec: () => ctrl.nudgeItem(s.id, 0, 0, dElev: -step * 5),
              onInc: () => ctrl.nudgeItem(s.id, 0, 0, dElev: step * 5),
              onEdit: () => _editGap(context, 'Height Above Floor', s.elevCm, (v) => ctrl.setCoords(s.id, elevCm: v)),
            ),
            if (!asCard) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: s.isLocked ? null : () => ctrl.setCoords(s.id, elevCm: 0),
                    icon: const Icon(Icons.vertical_align_bottom, size: 16),
                    label: const Text('Drop to Floor'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => ctrl.toggleLock(s.id),
                    icon: Icon(s.isLocked ? Icons.lock_open : Icons.lock_outline, size: 16),
                    label: Text(s.isLocked ? 'Unlock' : 'Lock'),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _numRow(
    BuildContext context, {
    required String label,
    required String valText,
    required bool locked,
    required VoidCallback onDec,
    required VoidCallback onInc,
    required VoidCallback onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          IconButton(visualDensity: VisualDensity.compact, onPressed: locked ? null : onDec, icon: const Icon(Icons.remove_circle_outline, size: 18)),
          InkWell(
            onTap: locked ? null : onEdit,
            child: Container(
              constraints: const BoxConstraints(minWidth: 68),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: PalCfg.bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: PalCfg.border)),
              alignment: Alignment.center,
              child: Text(valText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PalCfg.ink)),
            ),
          ),
          IconButton(visualDensity: VisualDensity.compact, onPressed: locked ? null : onInc, icon: const Icon(Icons.add_circle_outline, size: 18)),
        ],
      ),
    );
  }

  Future<void> _editGap(BuildContext context, String title, double curCm, void Function(double cm) onApply) async {
    final unit = ctrl.prefs.unit;
    String raw = UnitCfg.toInput(curCm, unit).toStringAsFixed(unit == UnitKind.metric ? 0 : 1);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: raw,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Value (${UnitCfg.inputTag(unit)})'),
          onChanged: (v) => raw = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(raw.trim());
              if (val != null && val >= 0) onApply(UnitCfg.fromInput(val, unit));
              Navigator.pop(ctx);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }
}

class ShopSht extends StatelessWidget { // grouped Item xQty shopping list shared by Explore & Storage
  final RoomData room;
  final AppCtrl ctrl;

  const ShopSht({super.key, required this.room, required this.ctrl});

  static void show(BuildContext context, RoomData room, AppCtrl ctrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PalCfg.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => ShopSht(room: room, ctrl: ctrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final s in room.stickers) {
      counts[s.itemId] = (counts[s.itemId] ?? 0) + 1;
    }

    final rows = <({ItemData item, int qty})>[];
    double mixTotal = 0;
    double ikeaTotal = 0;
    bool allIkea = true;

    for (final entry in counts.entries) {
      final item = ctrl.itemById(entry.key);
      if (item == null) continue;
      rows.add((item: item, qty: entry.value));
      mixTotal += item.minPrice * entry.value;
      final ikeaRef = item.listings.where((l) => l.store == 'IKEA PH');
      if (ikeaRef.isNotEmpty) {
        ikeaTotal += ikeaRef.first.bestPrice * entry.value;
      } else {
        allIkea = false;
      }
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.78),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: PalCfg.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 12),
              Text('${room.title} — Shopping List', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: PalCfg.ink)),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No items placed in this room yet.', style: TextStyle(color: PalCfg.muted))))
              else ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0x0D2D6A4F), borderRadius: BorderRadius.circular(10), border: Border.all(color: PalCfg.accent)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Lowest total across stores', style: TextStyle(fontSize: 11, color: PalCfg.muted)),
                          Text(UiCfg.fmtPeso(mixTotal), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: PalCfg.accent)),
                        ],
                      ),
                      if (allIkea)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('All from IKEA PH', style: TextStyle(fontSize: 11, color: PalCfg.muted)),
                            Text(UiCfg.fmtPeso(ikeaTotal), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: PalCfg.ink)),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final r = rows[i];
                      final bestRef = [...r.item.listings]..sort((a, b) => a.bestPrice.compareTo(b.bestPrice));
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(width: 44, height: 44, padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: PalCfg.bg, borderRadius: BorderRadius.circular(8)), child: ItemDraw(shapeKey: r.item.shapeKey)),
                        title: Text('${r.item.name} ×${r.qty}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text('${UiCfg.fmtPeso(r.item.minPrice)} each • Best at ${bestRef.first.store}', style: const TextStyle(fontSize: 12, color: PalCfg.muted)),
                        trailing: Text(UiCfg.fmtPeso(r.item.minPrice * r.qty), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        onTap: () => InfoSht.show(context, r.item, unit: ctrl.prefs.unit),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}