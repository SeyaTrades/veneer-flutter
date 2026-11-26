import 'package:flutter/material.dart';
import '../data/app_data.dart';

class StageCfg { // world-space room limits & viewport zoom bounds
  static const double minRoom = 200; // 2.0 m min wall span in cm
  static const double maxRoom = 1000; // 10.0 m max wall span in cm
  static const double minCeil = 220; // 2.2 m min ceiling height in cm
  static const double maxCeil = 400; // 4.0 m max ceiling height in cm
  static const double minZoom = 0.7;
  static const double maxZoom = 3.5;
}

class UnitCfg { // canonical cm storage with micro-to-macro display & unit-matched snap
  static const double inRatio = 2.54; // exact cm per inch conversion factor
  static const double snapMet = 5.0; // 5 cm default metric grid step
  static const double snapImp = 2.0 * inRatio; // 2 in (~5.08 cm) imperial grid step

  static double snapCm(double cm, UnitKind unit, {bool on = true}) { // falls back to 1 cm fine resolution when snap is off
    if (!on) return cm.roundToDouble();
    final step = unit == UnitKind.metric ? snapMet : snapImp;
    return (cm / step).round() * step;
  }

  static double nudgeCm(UnitKind unit) => unit == UnitKind.metric ? 1.0 : inRatio; // 1 cm or 1 in micro nudge

  static double toInput(double cm, UnitKind unit) => unit == UnitKind.metric ? cm : cm / inRatio;

  static double fromInput(double val, UnitKind unit) => unit == UnitKind.metric ? val : val * inRatio;

  static String inputTag(UnitKind unit) => unit == UnitKind.metric ? 'cm' : 'in';

  static String fmtGap(double cm, UnitKind unit) { // auto-scales cm->m or in->ft'in" for wall & object gaps
    if (unit == UnitKind.metric) {
      if (cm.abs() < 100) return '${cm.round()} cm';
      return '${(cm / 100).toStringAsFixed(2)} m';
    }
    final totalIn = (cm / inRatio).round();
    if (totalIn.abs() < 12) return '$totalIn"';
    final ft = totalIn ~/ 12;
    final rem = totalIn.abs() % 12;
    return rem == 0 ? "$ft'" : "$ft' $rem\"";
  }

  static String fmtItem(double w, double d, double h, UnitKind unit) { // retail W x D x H spec in cm or whole inches
    if (unit == UnitKind.metric) {
      return '${w.round()} × ${d.round()} × ${h.round()} cm';
    }
    return '${(w / inRatio).round()}" × ${(d / inRatio).round()}" × ${(h / inRatio).round()}"';
  }

  static String fmtRoom(double w, double d, UnitKind unit) { // macro room dimensions & floor area badge
    if (unit == UnitKind.metric) {
      final sqm = (w * d) / 10000;
      return '${(w / 100).toStringAsFixed(1)} × ${(d / 100).toStringAsFixed(1)} m (${sqm.toStringAsFixed(1)} m²)';
    }
    final sqft = (w * d) / 929.0304;
    return '${fmtGap(w, unit)} × ${fmtGap(d, unit)} (${sqft.round()} sq ft)';
  }
}

class UiCfg { // 3-tier responsive breakpoints & shared php formatter
  final double sw;
  final double sh;
  final bool isWide;
  final bool isDesk;
  final bool isTab;
  final bool isSlim;
  final double pad;

  const UiCfg._({
    required this.sw,
    required this.sh,
    required this.isWide,
    required this.isDesk,
    required this.isTab,
    required this.isSlim,
    required this.pad,
  });

  factory UiCfg.of(BuildContext context) { // keeps portrait tablets stacked vertically so stage stays wide
    final sz = MediaQuery.sizeOf(context);
    final pad = (sz.width * 0.03).clamp(8.0, 20.0);
    final land = sz.width > sz.height;
    return UiCfg._(
      sw: sz.width,
      sh: sz.height,
      isWide: land && sz.width >= 640,
      isDesk: land && sz.width >= 900, // 3-zone desktop workspace threshold
      isTab: !land && sz.width >= 600,
      isSlim: sz.width < 420,
      pad: pad,
    );
  }

  double get stageH => isWide ? (sh * 0.78).clamp(260.0, 680.0) : (sh * 0.46).clamp(240.0, 500.0);

  int gridCols(double panelW) => (panelW / 96).floor().clamp(3, 6);

  static String fmtPeso(double val) { // formats php totals with thousands commas
    final s = val.toStringAsFixed(0);
    return '₱${s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';
  }
}

class PalCfg { // color palette
  static const Color bg = Color(0xFFF6F4EF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1F2421);
  static const Color muted = Color(0xFF6F736E);
  static const Color accent = Color(0xFF2D6A4F);
  static const Color border = Color(0xFFE0DDD5);
  static const Color good = Color(0xFF2E7D32);
  static const Color warn = Color(0xFFC62828);
  static const Color ruler = Color(0xFF1D4ED8);
  static const Color locked = Color(0xFFD97706);
}