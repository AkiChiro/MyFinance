import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

/// Renders the user's custom image for [slotId] if one is set (see
/// `AppSettings.iconPath`/`setIconPath` and `ThemeCustomizationPage`'s
/// "Biểu tượng" section), otherwise falls back to [fallback].
///
/// [color] only tints the fallback `Icon` — a user-picked image is assumed
/// to be full-color already, so it is never recolored.
class AppIcon extends ConsumerWidget {
  const AppIcon(this.slotId, {super.key, required this.fallback, this.size = 24, this.color});

  final String slotId;
  final IconData fallback;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(settingsProvider).iconPath(slotId);
    if (path == null) return Icon(fallback, size: size, color: color);
    return Image.file(
      File(path),
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(fallback, size: size, color: color),
    );
  }
}
