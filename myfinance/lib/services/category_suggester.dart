import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/domain.dart';

class _Rule {
  final String keyword;
  final String category;
  final int weight;
  const _Rule(this.keyword, this.category, this.weight);
}

/// Lightweight, fully-offline weighted-keyword classifier.
/// It only *suggests* a category to pre-select in the form — it never files a
/// transaction silently, so a wrong guess can't quietly skew the charts.
class CategorySuggester {
  List<_Rule> _rules = const [];

  Future<void> load() async {
    try {
      final raw = await rootBundle.loadString('assets/keywords.json');
      final list = jsonDecode(raw) as List<dynamic>;
      _rules = list
          .map((e) => _Rule(
                (e['keyword'] as String).toLowerCase(),
                e['category'] as String,
                (e['weight'] as num).toInt(),
              ))
          .toList();
    } catch (_) {
      _rules = const [];
    }
  }

  /// Returns the best category id for [description] limited to the categories
  /// valid for [txType]. Falls back to that type's "Others".
  String suggest(String description, String txType) {
    final allowed = Categories.forType(txType).toSet();
    final text = description.toLowerCase();
    final scores = <String, int>{};
    for (final r in _rules) {
      if (!allowed.contains(r.category)) continue;
      if (text.contains(r.keyword)) {
        scores[r.category] = (scores[r.category] ?? 0) + r.weight;
      }
    }
    if (scores.isEmpty) return Categories.fallbackFor(txType);
    return scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
