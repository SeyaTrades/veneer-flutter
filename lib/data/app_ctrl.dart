import 'package:flutter/foundation.dart';
import '../core/app_cfg.dart';
import 'app_data.dart';
import 'app_repo.dart';

class AppCtrl extends ChangeNotifier { // reactive state store for active room, catalog, prefs & mock auth
  final AuthRepo authRepo;
  final ItemRepo itemRepo;
  final RoomRepo roomRepo;
  final PrefRepo prefRepo;

  AppCtrl({
    required this.authRepo,
    required this.itemRepo,
    required this.roomRepo,
    required this.prefRepo,
  });

  List<StudioRef> studios = [];
  List<ItemData> items = [];
  List<RoomData> savedRooms = [];
  List<RoomData> lookbooks = [];

  UserData? curUser;
  PrefData prefs = const PrefData();
  StageMode stageMode = StageMode.plan;
  WallFace wallFace = WallFace.north;
  bool panMode = false; // forces drags to pan viewport instead of moving furniture
  String? curId;
  bool inLoad = true;
  bool inSave = false;
  bool hasDraft = false;

  RoomData curRoom = RoomData(
    id: 'draft_init',
    userId: 'guest',
    studioId: 'std_blank',
    title: 'Untitled Room',
    savedAt: DateTime.now(),
  );

  bool get isGuest => curUser == null;
  bool get isSaved => savedRooms.any((r) => r.id == curRoom.id);

  StudioRef get curStudio {
    if (studios.isEmpty) {
      return const StudioRef(id: 'std_blank', name: 'Blank Studio', kind: RoomKind.blank, wallHex: 0xFFF2EFE9, floorHex: 0xFFD9CFC1);
    }
    return studios.firstWhere((s) => s.id == curRoom.studioId, orElse: () => studios.first);
  }

  StickerData? get pickedSticker {
    if (curId == null) return null;
    return curRoom.stickers.where((s) => s.id == curId).firstOrNull;
  }

  ItemData? itemById(String id) => items.where((i) => i.id == id).firstOrNull;

  double get roomCost {
    double sum = 0;
    for (final s in curRoom.stickers) {
      sum += itemById(s.itemId)?.minPrice ?? 0;
    }
    return sum;
  }

  RoomData? latestRoom(String studioId) { // pulls user's most recent save for a studio type
    for (final r in savedRooms) {
      if (r.studioId == studioId) return r;
    }
    return null;
  }

  Future<void> initApp() async {
    inLoad = true;
    notifyListeners();

    studios = await itemRepo.pullStudios();
    items = await itemRepo.pullItems();
    prefs = await prefRepo.pullPrefs();
    curUser = await authRepo.curUser();
    lookbooks = await roomRepo.pullPublic();

    if (curUser != null) {
      savedRooms = await roomRepo.pullRooms(curUser!.id);
    }

    inLoad = false;
    notifyListeners();
  }

  void setMode(StageMode mode) {
    if (stageMode == mode) return;
    stageMode = mode;
    notifyListeners();
  }

  void setWall(WallFace wall) {
    if (wallFace == wall) return;
    wallFace = wall;
    notifyListeners();
  }

  void togglePan() {
    panMode = !panMode;
    notifyListeners();
  }

  Future<void> setPrefs(PrefData next) async {
    prefs = next;
    await prefRepo.pushPrefs(next);
    notifyListeners();
  }

  void pickSticker(String? id) {
    if (curId == id) return;
    curId = id;
    notifyListeners();
  }

  StickerData _clampItem(StickerData s, ItemData? item, RoomData room) { // binds rotated footprint inside room walls & ceiling
    if (item == null) return s;
    final halfW = item.planW(s.rotDeg) / 2;
    final halfD = item.planD(s.rotDeg) / 2;
    final minX = halfW;
    final maxX = room.roomW - halfW;
    final minY = halfD;
    final maxY = room.roomD - halfD;
    final maxElev = (room.ceilH - item.hCm).clamp(0.0, room.ceilH);

    final cx = minX >= maxX ? room.roomW / 2 : s.xCm.clamp(minX, maxX);
    final cy = minY >= maxY ? room.roomD / 2 : s.yCm.clamp(minY, maxY);
    final ce = s.elevCm.clamp(0.0, maxElev);
    return s.copyWith(xCm: cx, yCm: cy, elevCm: ce);
  }

  void setRoomDim(double wCm, double dCm, double hCm) {
    final cw = wCm.clamp(StageCfg.minRoom, StageCfg.maxRoom);
    final cd = dCm.clamp(StageCfg.minRoom, StageCfg.maxRoom);
    final ch = hCm.clamp(StageCfg.minCeil, StageCfg.maxCeil);
    final resized = curRoom.copyWith(roomW: cw, roomD: cd, ceilH: ch);
    final clamped = [
      for (final s in resized.stickers) _clampItem(s, itemById(s.itemId), resized),
    ];
    curRoom = resized.copyWith(stickers: clamped);
    hasDraft = true;
    notifyListeners();
  }

  void dropSticker(ItemData item) {
    final id = 'stk_${DateTime.now().microsecondsSinceEpoch}';
    final sameZone = curRoom.stickers.where((s) => s.zIdx >= item.spawnZ && s.zIdx < item.spawnZ + 9);
    final nextZ = sameZone.isEmpty ? item.spawnZ : sameZone.map((s) => s.zIdx).reduce((a, b) => a > b ? a : b) + 1;
    final offset = (curRoom.stickers.length % 5 - 2) * 20.0; // staggers repeated drops 20 cm apart
    final rawY = item.zone == PlaceZone.wall ? (item.dCm / 2) + 2 : (curRoom.roomD / 2) + offset;

    final raw = StickerData(
      id: id,
      itemId: item.id,
      xCm: UnitCfg.snapCm((curRoom.roomW / 2) + offset, prefs.unit, on: prefs.snapOn),
      yCm: UnitCfg.snapCm(rawY, prefs.unit, on: prefs.snapOn),
      elevCm: item.defElev,
      zIdx: nextZ,
    );
    curRoom = curRoom.copyWith(stickers: [...curRoom.stickers, _clampItem(raw, item, curRoom)]);
    curId = id;
    panMode = false; // auto-exits pan mode so user can immediately drag the dropped piece
    hasDraft = true;
    notifyListeners();
  }

  void moveItem(String id, double xCm, double yCm, {bool doSnap = true}) {
    final next = curRoom.stickers.map((s) {
      if (s.id != id || s.isLocked) return s;
      final sx = doSnap ? UnitCfg.snapCm(xCm, prefs.unit, on: prefs.snapOn) : xCm;
      final sy = doSnap ? UnitCfg.snapCm(yCm, prefs.unit, on: prefs.snapOn) : yCm;
      return _clampItem(s.copyWith(xCm: sx, yCm: sy), itemById(s.itemId), curRoom);
    }).toList();
    curRoom = curRoom.copyWith(stickers: next);
    hasDraft = true;
    notifyListeners();
  }

  void setCoords(String id, {double? xCm, double? yCm, double? elevCm}) {
    final next = curRoom.stickers.map((s) {
      if (s.id != id || s.isLocked) return s;
      return _clampItem(
        s.copyWith(xCm: xCm ?? s.xCm, yCm: yCm ?? s.yCm, elevCm: elevCm ?? s.elevCm),
        itemById(s.itemId),
        curRoom,
      );
    }).toList();
    curRoom = curRoom.copyWith(stickers: next);
    hasDraft = true;
    notifyListeners();
  }

  void nudgeItem(String id, double dxCm, double dyCm, {double dElev = 0}) {
    final s = curRoom.stickers.where((e) => e.id == id).firstOrNull;
    if (s == null || s.isLocked) return;
    setCoords(id, xCm: s.xCm + dxCm, yCm: s.yCm + dyCm, elevCm: s.elevCm + dElev);
  }

  void turnItem(String id) { // rotates 90 deg clockwise in Top Plan & updates NESW projection
    final next = curRoom.stickers.map((s) {
      if (s.id != id || s.isLocked) return s;
      final item = itemById(s.itemId);
      final nextDeg = (s.rotDeg + 90) % 360;
      return _clampItem(s.copyWith(rotDeg: nextDeg), item, curRoom);
    }).toList();
    curRoom = curRoom.copyWith(stickers: next);
    hasDraft = true;
    notifyListeners();
  }

  void toggleLock(String id) {
    final next = curRoom.stickers.map((s) => s.id == id ? s.copyWith(isLocked: !s.isLocked) : s).toList();
    curRoom = curRoom.copyWith(stickers: next);
    hasDraft = true;
    notifyListeners();
  }

  void copySticker(String id) {
    final src = curRoom.stickers.where((s) => s.id == id).firstOrNull;
    if (src == null) return;
    final item = itemById(src.itemId);
    final newId = 'stk_${DateTime.now().microsecondsSinceEpoch}';
    final topZ = curRoom.stickers.map((s) => s.zIdx).reduce((a, b) => a > b ? a : b) + 1;
    final shift = src.xCm > curRoom.roomW * 0.75 ? -25.0 : 25.0; // nudges inward if near east wall
    final dupe = _clampItem(src.copyWith(id: newId, xCm: src.xCm + shift, isLocked: false, zIdx: topZ), item, curRoom);
    curRoom = curRoom.copyWith(stickers: [...curRoom.stickers, dupe]);
    curId = newId;
    hasDraft = true;
    notifyListeners();
  }

  void shiftZ(String id, int delta) {
    final sorted = [...curRoom.stickers]..sort((a, b) => a.zIdx.compareTo(b.zIdx));
    final idx = sorted.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    final target = (idx + delta).clamp(0, sorted.length - 1);
    if (target == idx) return;

    final moved = sorted.removeAt(idx);
    sorted.insert(target, moved);
    final reindexed = [
      for (int i = 0; i < sorted.length; i++) sorted[i].copyWith(zIdx: i),
    ]; // re-indexing guarantees 1 step crosses 1 neighbor
    curRoom = curRoom.copyWith(stickers: reindexed);
    hasDraft = true;
    notifyListeners();
  }

  void cutSticker(String id) {
    final target = curRoom.stickers.where((s) => s.id == id).firstOrNull;
    if (target == null || target.isLocked) return; // locked items ignore delete
    final next = curRoom.stickers.where((s) => s.id != id).toList();
    curRoom = curRoom.copyWith(stickers: next);
    if (curId == id) curId = null;
    hasDraft = true;
    notifyListeners();
  }

  void setTitle(String title) {
    curRoom = curRoom.copyWith(title: title.trim().isEmpty ? 'Untitled Room' : title.trim());
    hasDraft = true;
    notifyListeners();
  }

  void setBudget(double? cap) {
    curRoom = curRoom.copyWith(budgetCap: cap, clearCap: cap == null);
    hasDraft = true;
    notifyListeners();
  }

  void setPublic(bool val) {
    curRoom = curRoom.copyWith(isPublic: val);
    hasDraft = true;
    notifyListeners();
  }

  String _uniqueTitle(String base, {String? ignoreId}) { // increments (2), (3) when matching an existing saved title
    final clean = base.trim().isEmpty ? 'Untitled Room' : base.trim();
    final taken = savedRooms.where((r) => r.id != ignoreId).map((r) => r.title.toLowerCase()).toSet();
    if (!taken.contains(clean.toLowerCase())) return clean;
    final stem = clean.replaceFirst(RegExp(r'\s*\(\d+\)$'), '');
    int n = 2;
    while (taken.contains('$stem ($n)'.toLowerCase())) {
      n++;
    }
    return '$stem ($n)';
  }

  void switchRoom(String studioId, {bool keepItems = false, RoomData? loadSaved}) {
    if (loadSaved != null) {
      loadRoom(loadSaved);
      return;
    }
    final st = studios.firstWhere((s) => s.id == studioId, orElse: () => curStudio);
    curId = null;
    if (keepItems) {
      final resized = curRoom.copyWith(studioId: studioId, roomW: st.defW, roomD: st.defD, ceilH: st.defH);
      final clamped = [
        for (final s in resized.stickers) _clampItem(s, itemById(s.itemId), resized),
      ];
      curRoom = resized.copyWith(stickers: clamped);
      hasDraft = true;
    } else {
      hasDraft = false;
      curRoom = RoomData(
        id: 'draft_${DateTime.now().millisecondsSinceEpoch}',
        userId: curUser?.id ?? 'guest',
        studioId: studioId,
        title: _uniqueTitle('Untitled Room'),
        roomW: st.defW,
        roomD: st.defD,
        ceilH: st.defH,
        savedAt: DateTime.now(),
      );
    }
    notifyListeners();
  }

  void newRoom({String studioId = 'std_blank'}) => switchRoom(studioId, keepItems: false);

  Future<bool> saveRoom({bool asNew = false}) async { // false bounces guest to auth; asNew forces a fresh copy
    if (isGuest) return false;
    inSave = true;
    notifyListeners();

    final makeNew = asNew || curRoom.id.startsWith('draft_') || !isSaved;
    final roomId = makeNew ? 'rm_${DateTime.now().millisecondsSinceEpoch}' : curRoom.id;
    final safeTitle = _uniqueTitle(curRoom.title, ignoreId: makeNew ? null : roomId);

    final saved = await roomRepo.pushRoom(curRoom.copyWith(id: roomId, userId: curUser!.id, title: safeTitle));
    curRoom = saved;
    hasDraft = false;
    savedRooms = await roomRepo.pullRooms(curUser!.id);
    lookbooks = await roomRepo.pullPublic();

    inSave = false;
    notifyListeners();
    return true;
  }

  void loadRoom(RoomData room) {
    curId = null;
    curRoom = room;
    hasDraft = false;
    notifyListeners();
  }

  void cloneRoom(RoomData room) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cloned = [
      for (int i = 0; i < room.stickers.length; i++) room.stickers[i].copyWith(id: 'stk_${now}_$i', isLocked: false),
    ];
    curId = null;
    curRoom = RoomData(
      id: 'draft_$now',
      userId: curUser?.id ?? 'guest',
      studioId: room.studioId,
      title: _uniqueTitle('${room.title} Remix'),
      roomW: room.roomW,
      roomD: room.roomD,
      ceilH: room.ceilH,
      budgetCap: room.budgetCap,
      isPublic: false,
      cloneFrom: room.id,
      stickers: cloned,
      savedAt: DateTime.now(),
    );
    hasDraft = true;
    notifyListeners();
  }

  Future<void> dropSaved(String roomId) async {
    await roomRepo.dropRoom(roomId);
    if (curUser != null) savedRooms = await roomRepo.pullRooms(curUser!.id);
    lookbooks = await roomRepo.pullPublic();
    notifyListeners();
  }

  Future<void> doLogin(String email, String pass) async {
    curUser = await authRepo.signIn(email, pass);
    savedRooms = await roomRepo.pullRooms(curUser!.id);
    notifyListeners();
  }

  Future<void> doSignup(String email, String pass, String name) async {
    curUser = await authRepo.signUp(email, pass, name);
    savedRooms = await roomRepo.pullRooms(curUser!.id);
    notifyListeners();
  }

  Future<void> doDemo() async {
    curUser = await authRepo.demoUser();
    savedRooms = await roomRepo.pullRooms(curUser!.id);
    notifyListeners();
  }

  Future<void> doLogout() async {
    await authRepo.signOut();
    curUser = null;
    savedRooms = [];
    notifyListeners();
  }
}