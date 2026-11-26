import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_data.dart';
import 'seed_data.dart';

abstract class AuthRepo { // auth contract for local mock or supabase swap
  Future<UserData?> curUser(); // returns null when running in guest mode
  Future<UserData> signIn(String email, String pass);
  Future<UserData> signUp(String email, String pass, String name);
  Future<UserData> demoUser();
  Future<void> signOut();
}

abstract class ItemRepo { // static studio templates & furniture catalog contract
  Future<List<StudioRef>> pullStudios();
  Future<List<ItemData>> pullItems();
}

abstract class RoomRepo { // room persistence & public lookbook feed contract
  Future<List<RoomData>> pullRooms(String userId);
  Future<List<RoomData>> pullPublic();
  Future<RoomData> pushRoom(RoomData room);
  Future<void> dropRoom(String roomId);
}

abstract class PrefRepo { // user planner settings contract
  Future<PrefData> pullPrefs();
  Future<void> pushPrefs(PrefData prefs);
}

class AuthDisk implements AuthRepo { // local mock auth backed by shared_preferences
  static const String _userKey = 'veneer_mock_user';

  @override
  Future<UserData?> curUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    return UserData.fromMap(Map<String, dynamic>.from(jsonDecode(raw) as Map));
  }

  @override
  Future<UserData> signIn(String email, String pass) async {
    // TODO(db): replace with supabase.auth.signInWithPassword
    final name = email.split('@').first;
    final user = UserData(id: 'usr_${email.hashCode.abs()}', email: email, name: name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toMap()));
    return user;
  }

  @override
  Future<UserData> signUp(String email, String pass, String name) async {
    // TODO(db): replace with supabase.auth.signUp + profile insert
    final user = UserData(id: 'usr_${email.hashCode.abs()}', email: email, name: name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toMap()));
    return user;
  }

  @override
  Future<UserData> demoUser() async => signIn('demo@veneer.app', 'demo1234');

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}

class ItemDisk implements ItemRepo { // serves local seed catalog until supabase tables exist
  @override
  Future<List<StudioRef>> pullStudios() async {
    // TODO(db): select studios from supabase
    return SeedData.studios;
  }

  @override
  Future<List<ItemData>> pullItems() async {
    // TODO(db): select catalog_items joined with store_listings
    return SeedData.items;
  }
}

class RoomDisk implements RoomRepo { // persists saved rooms & merges user public rooms into lookbooks
  static const String _roomsKey = 'veneer_saved_rooms_v2'; // v2 isolates real-cm schemas from v1 drafts

  Future<List<RoomData>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_roomsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => RoomData.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> _writeAll(List<RoomData> rooms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roomsKey, jsonEncode(rooms.map((e) => e.toMap()).toList()));
  }

  @override
  Future<List<RoomData>> pullRooms(String userId) async {
    // TODO(db): select saved_rooms where user_id = current user
    final all = await _readAll();
    return all.where((r) => r.userId == userId).toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  @override
  Future<List<RoomData>> pullPublic() async {
    // TODO(db): select saved_rooms where is_public = true
    final all = await _readAll();
    final userPublic = all.where((r) => r.isPublic).toList();
    return [...userPublic, ...SeedData.lookbooks];
  }

  @override
  Future<RoomData> pushRoom(RoomData room) async {
    // TODO(db): upsert saved_rooms and replace placed_stickers in supabase
    final all = await _readAll();
    final nextRoom = room.copyWith(savedAt: DateTime.now());
    final idx = all.indexWhere((r) => r.id == nextRoom.id);
    if (idx >= 0) {
      all[idx] = nextRoom;
    } else {
      all.add(nextRoom);
    }
    await _writeAll(all);
    return nextRoom;
  }

  @override
  Future<void> dropRoom(String roomId) async {
    final all = await _readAll();
    all.removeWhere((r) => r.id == roomId);
    await _writeAll(all);
  }
}

class PrefDisk implements PrefRepo { // stores unit, grid snap & room-switch preferences locally
  static const String _prefsKey = 'veneer_user_prefs';

  @override
  Future<PrefData> pullPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return const PrefData();
    return PrefData.fromMap(Map<String, dynamic>.from(jsonDecode(raw) as Map));
  }

  @override
  Future<void> pushPrefs(PrefData appPrefs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(appPrefs.toMap()));
  }
}