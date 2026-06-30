import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

  static Future<File> _customFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'keywords.json'));
  }

  Future<void> load() async {
    try {
      final custom = await _customFile();
      final raw = await custom.exists()
          ? await custom.readAsString()
          : await rootBundle.loadString('assets/keywords.json');
      _parseRaw(raw);
    } catch (_) {
      _rules = const [];
    }
  }

  void _parseRaw(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    _rules = list
        .map((e) => _Rule(
              (e['keyword'] as String).toLowerCase(),
              e['category'] as String,
              (e['weight'] as num).toInt(),
            ))
        .toList();
  }

  /// Returns the current rules as a JSON-serialisable list (for the editor).
  Future<List<Map<String, dynamic>>> loadRaw() async {
    try {
      final custom = await _customFile();
      final raw = await custom.exists()
          ? await custom.readAsString()
          : await rootBundle.loadString('assets/keywords.json');
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Persists the edited rule list to the app documents directory and
  /// reloads the in-memory rules so suggestions reflect the change immediately.
  Future<void> saveAndReload(List<Map<String, dynamic>> rules) async {
    final file = await _customFile();
    await file.writeAsString(jsonEncode(rules));
    _parseRaw(jsonEncode(rules));
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
