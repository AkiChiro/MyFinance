import 'package:flutter/material.dart';

/// Per-category accent colors, shared between the Thống kê pie charts and
/// the Giao dịch tile icons. Only the 7 default seeded category ids are
/// covered; user-created categories (UUID ids) fall back to grey.
const spendColors = <String, Color>{
  'necessities': Color(0xFFFF7043),
  'food': Color(0xFFFFCA28),
  'hobbies': Color(0xFF7E57C2),
  'others': Color(0xFF78909C),
};
const earnColors = <String, Color>{
  'provided': Color(0xFF66BB6A),
  'self_earned': Color(0xFF42A5F5),
  'others_earn': Color(0xFF78909C),
};

Color spendColor(String? cat) => spendColors[cat] ?? const Color(0xFF78909C);
Color earnColor(String? cat) => earnColors[cat] ?? const Color(0xFF78909C);
