import 'dart:ui';
import 'package:flutter/material.dart';
import 'core/app_cfg.dart';
import 'data/app_ctrl.dart';
import 'data/app_repo.dart';
import 'scrns/nav_scrn.dart';

void main() {
  final ctrl = AppCtrl(
    authRepo: AuthDisk(),
    itemRepo: ItemDisk(),
    roomRepo: RoomDisk(),
    prefRepo: PrefDisk(),
  );
  ctrl.initApp();
  runApp(VeneerApp(ctrl: ctrl));
}

class VeneerApp extends StatelessWidget {
  final AppCtrl ctrl;

  const VeneerApp({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Veneer',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad}, // allows mouse drag on web lists
      ),
      theme: ThemeData(
        scaffoldBackgroundColor: PalCfg.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: PalCfg.accent),
        useMaterial3: true,
      ),
      home: NavScrn(ctrl: ctrl),
    );
  }
}