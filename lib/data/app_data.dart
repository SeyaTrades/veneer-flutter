enum RoomKind { blank, living, bedroom, kitchen, dining } // studio preset archetypes
enum PlaceZone { rug, floor, wall, decor, ceiling } // governs default elevation & z-ordering
enum ViewFace { front, side, back } // available drawn elevation sprites
enum StageMode { plan, wall } // top-down CAD blueprint vs orthographic wall elevation
enum WallFace { north, east, south, west } // compass wall target for elevation camera
enum UnitKind { metric, imperial } // display & snap system (storage always stays cm)
enum SwitchRule { ask, loadLast, keepItems, blank } // behavior when changing studio type

class StudioRef { // room template preset & default condo shell size in cm
  final String id;
  final String name;
  final RoomKind kind;
  final int wallHex;
  final int floorHex;
  final double defW; // default width west->east
  final double defD; // default depth north->south
  final double defH; // default ceiling height

  const StudioRef({
    required this.id,
    required this.name,
    required this.kind,
    required this.wallHex,
    required this.floorHex,
    this.defW = 400,
    this.defD = 400,
    this.defH = 260,
  });
}

class StoreRef { // single merchant price entry & external link
  final String id;
  final String store;
  final double regPrice;
  final double? salePrice;
  final String? promoTag;
  final String url;

  const StoreRef({
    required this.id,
    required this.store,
    required this.regPrice,
    this.salePrice,
    this.promoTag,
    required this.url,
  });

  double get bestPrice => salePrice ?? regPrice;
}

class ItemData { // catalog furniture spec driving both Top Plan & NESW Elevation
  final String id;
  final String name;
  final String cat;
  final List<RoomKind> rooms;
  final List<String> styles;
  final PlaceZone zone;
  final String shapeKey;
  final List<ViewFace> views;
  final double wCm; // width when facing south (rotDeg = 0)
  final double dCm; // front-to-back depth when facing south (rotDeg = 0)
  final double hCm; // vertical height
  final double defElev; // default bottom clearance off floor in cm
  final bool canFlip;
  final List<StoreRef> listings;

  const ItemData({
    required this.id,
    required this.name,
    required this.cat,
    required this.rooms,
    required this.styles,
    required this.zone,
    required this.shapeKey,
    required this.views,
    required this.wCm,
    required this.dCm,
    required this.hCm,
    this.defElev = 0,
    required this.canFlip,
    required this.listings,
  });

  double get minPrice {
    if (listings.isEmpty) return 0;
    return listings.map((e) => e.bestPrice).reduce((a, b) => a < b ? a : b);
  }

  double planW(int rotDeg) => (rotDeg % 180 == 0) ? wCm : dCm; // swaps footprint W/D on 90 or 270 turns

  double planD(int rotDeg) => (rotDeg % 180 == 0) ? dCm : wCm;

  int get spawnZ { // tie-breaker layer within identical depth planes
    switch (zone) {
      case PlaceZone.rug:
        return 0;
      case PlaceZone.wall:
        return 5;
      case PlaceZone.floor:
        return 10;
      case PlaceZone.ceiling:
        return 18;
      case PlaceZone.decor:
        return 20;
    }
  }
}

class StickerData { // single placed item stored in canonical room-space cm
  final String id;
  final String itemId;
  final double xCm; // west->east center in cm
  final double yCm; // north->south center in cm
  final double elevCm; // bottom height above floor in cm
  final int rotDeg; // 0=south, 90=west, 180=north, 270=east
  final bool flipX;
  final bool isLocked; // locks drag/delete & passes pointer through to pan view
  final int zIdx;

  const StickerData({
    required this.id,
    required this.itemId,
    required this.xCm,
    required this.yCm,
    this.elevCm = 0,
    this.rotDeg = 0,
    this.flipX = false,
    this.isLocked = false,
    this.zIdx = 10,
  });

  StickerData copyWith({
    String? id,
    String? itemId,
    double? xCm,
    double? yCm,
    double? elevCm,
    int? rotDeg,
    bool? flipX,
    bool? isLocked,
    int? zIdx,
  }) {
    return StickerData(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      xCm: xCm ?? this.xCm,
      yCm: yCm ?? this.yCm,
      elevCm: elevCm ?? this.elevCm,
      rotDeg: rotDeg ?? this.rotDeg,
      flipX: flipX ?? this.flipX,
      isLocked: isLocked ?? this.isLocked,
      zIdx: zIdx ?? this.zIdx,
    );
  }

  Map<String, dynamic> toMap() { // snake_case keys match future table columns firebase/supabase idk not sure
    return {
      'id': id,
      'item_id': itemId,
      'x_cm': xCm,
      'y_cm': yCm,
      'elev_cm': elevCm,
      'rot_deg': rotDeg,
      'flip_x': flipX,
      'is_locked': isLocked,
      'z_index': zIdx,
    };
  }

  factory StickerData.fromMap(Map<String, dynamic> m) {
    return StickerData(
      id: m['id'] as String,
      itemId: m['item_id'] as String,
      xCm: (m['x_cm'] as num).toDouble(), // num cast avoids web js int/double mismatch
      yCm: (m['y_cm'] as num).toDouble(),
      elevCm: (m['elev_cm'] as num?)?.toDouble() ?? 0,
      rotDeg: (m['rot_deg'] as num?)?.toInt() ?? 0,
      flipX: (m['flip_x'] as bool?) ?? false,
      isLocked: (m['is_locked'] as bool?) ?? false,
      zIdx: (m['z_index'] as num?)?.toInt() ?? 10,
    );
  }
}

class WallProj { // projects 3D cm item coordinates onto N, E, S, or W wall plane
  final double spanCm; // total horizontal width of viewed wall
  final double uCm; // horizontal center position left->right on viewed wall
  final double visW; // apparent horizontal width along viewed wall
  final double visH; // vertical height
  final double elevCm; // bottom height above floor
  final double depthCm; // perpendicular distance from viewed wall (drives depth filter & sort)
  final ViewFace face;
  final bool flipX;

  const WallProj({
    required this.spanCm,
    required this.uCm,
    required this.visW,
    required this.visH,
    required this.elevCm,
    required this.depthCm,
    required this.face,
    required this.flipX,
  });

  static WallProj of(StickerData s, ItemData item, RoomData room, WallFace wall) {
    final wallDeg = wall.index * 90; // north=0, east=90, south=180, west=270
    final rel = (s.rotDeg - wallDeg + 360) % 360; // relative item angle toward camera

    late final double span;
    late final double u;
    late final double depth;
    switch (wall) {
      case WallFace.north:
        span = room.roomW;
        u = s.xCm;
        depth = s.yCm;
      case WallFace.east:
        span = room.roomD;
        u = s.yCm;
        depth = room.roomW - s.xCm;
      case WallFace.south:
        span = room.roomW;
        u = room.roomW - s.xCm;
        depth = room.roomD - s.yCm;
      case WallFace.west:
        span = room.roomD;
        u = room.roomD - s.yCm;
        depth = s.xCm;
    }

    ViewFace face = ViewFace.front;
    bool flip = s.flipX;
    double visW = item.wCm;

    if (rel == 90) {
      face = item.views.contains(ViewFace.side) ? ViewFace.side : ViewFace.front;
      flip = !s.flipX; // side art natively faces right; rel 90 faces left
      visW = item.dCm;
    } else if (rel == 180) {
      face = item.views.contains(ViewFace.back) ? ViewFace.back : ViewFace.front;
      visW = item.wCm;
    } else if (rel == 270) {
      face = item.views.contains(ViewFace.side) ? ViewFace.side : ViewFace.front;
      flip = s.flipX;
      visW = item.dCm;
    }

    return WallProj(
      spanCm: span,
      uCm: u,
      visW: visW,
      visH: item.hCm,
      elevCm: s.elevCm,
      depthCm: depth,
      face: face,
      flipX: flip,
    );
  }
}

class RoomData { // saved room layout or community lookbook
  final String id;
  final String userId;
  final String studioId;
  final String title;
  final double roomW;
  final double roomD;
  final double ceilH;
  final double? budgetCap;
  final bool isPublic;
  final String? cloneFrom;
  final List<StickerData> stickers;
  final DateTime savedAt;

  const RoomData({
    required this.id,
    required this.userId,
    required this.studioId,
    required this.title,
    this.roomW = 400,
    this.roomD = 400,
    this.ceilH = 260,
    this.budgetCap,
    this.isPublic = false,
    this.cloneFrom,
    this.stickers = const [],
    required this.savedAt,
  });

  RoomData copyWith({
    String? id,
    String? userId,
    String? studioId,
    String? title,
    double? roomW,
    double? roomD,
    double? ceilH,
    double? budgetCap,
    bool clearCap = false,
    bool? isPublic,
    String? cloneFrom,
    List<StickerData>? stickers,
    DateTime? savedAt,
  }) {
    return RoomData(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      studioId: studioId ?? this.studioId,
      title: title ?? this.title,
      roomW: roomW ?? this.roomW,
      roomD: roomD ?? this.roomD,
      ceilH: ceilH ?? this.ceilH,
      budgetCap: clearCap ? null : (budgetCap ?? this.budgetCap),
      isPublic: isPublic ?? this.isPublic,
      cloneFrom: cloneFrom ?? this.cloneFrom,
      stickers: stickers ?? this.stickers,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'studio_id': studioId,
      'title': title,
      'room_w_cm': roomW,
      'room_d_cm': roomD,
      'ceil_h_cm': ceilH,
      'budget_limit': budgetCap,
      'is_public': isPublic,
      'cloned_from_room_id': cloneFrom,
      'placed_stickers': stickers.map((s) => s.toMap()).toList(),
      'updated_at': savedAt.toIso8601String(),
    };
  }

  factory RoomData.fromMap(Map<String, dynamic> m) {
    final rawStickers = (m['placed_stickers'] as List?) ?? [];
    return RoomData(
      id: m['id'] as String,
      userId: m['user_id'] as String,
      studioId: m['studio_id'] as String,
      title: m['title'] as String,
      roomW: (m['room_w_cm'] as num?)?.toDouble() ?? 400,
      roomD: (m['room_d_cm'] as num?)?.toDouble() ?? 400,
      ceilH: (m['ceil_h_cm'] as num?)?.toDouble() ?? 260,
      budgetCap: (m['budget_limit'] as num?)?.toDouble(),
      isPublic: (m['is_public'] as bool?) ?? false,
      cloneFrom: m['cloned_from_room_id'] as String?,
      stickers: rawStickers.map((e) => StickerData.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
      savedAt: DateTime.tryParse((m['updated_at'] as String?) ?? '') ?? DateTime.now(),
    );
  }
}

class PrefData { // persisted user planner settings
  final UnitKind unit;
  final bool snapOn;
  final bool showGrid;
  final SwitchRule switchRule;

  const PrefData({
    this.unit = UnitKind.metric,
    this.snapOn = true,
    this.showGrid = true,
    this.switchRule = SwitchRule.ask,
  });

  PrefData copyWith({
    UnitKind? unit,
    bool? snapOn,
    bool? showGrid,
    SwitchRule? switchRule,
  }) {
    return PrefData(
      unit: unit ?? this.unit,
      snapOn: snapOn ?? this.snapOn,
      showGrid: showGrid ?? this.showGrid,
      switchRule: switchRule ?? this.switchRule,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'unit': unit.name,
      'snap_on': snapOn,
      'show_grid': showGrid,
      'switch_rule': switchRule.name,
    };
  }

  factory PrefData.fromMap(Map<String, dynamic> m) {
    return PrefData(
      unit: UnitKind.values.firstWhere((e) => e.name == m['unit'], orElse: () => UnitKind.metric),
      snapOn: (m['snap_on'] as bool?) ?? true,
      showGrid: (m['show_grid'] as bool?) ?? true,
      switchRule: SwitchRule.values.firstWhere((e) => e.name == m['switch_rule'], orElse: () => SwitchRule.ask),
    );
  }
}

class UserData { // authenticated profile stub
  final String id;
  final String email;
  final String name;

  const UserData({
    required this.id,
    required this.email,
    required this.name,
  });

  Map<String, dynamic> toMap() => {'id': id, 'email': email, 'username': name};

  factory UserData.fromMap(Map<String, dynamic> m) {
    return UserData(
      id: m['id'] as String,
      email: m['email'] as String,
      name: m['username'] as String,
    );
  }
}