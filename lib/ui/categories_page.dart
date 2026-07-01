import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database.dart';
import '../format.dart';
import '../main.dart' show repository;
import '../models/domain.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String get _currentKind =>
      _tab.index == 0 ? TxTypes.spending : TxTypes.earning;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh mục'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Chi tiêu'),
            Tab(text: 'Thu nhập'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _CategoryList(kind: TxTypes.spending),
          _CategoryList(kind: TxTypes.earning),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, _currentKind),
        icon: const Icon(Icons.add),
        label: Text(_tab.index == 0 ? 'Thêm chi tiêu' : 'Thêm thu nhập'),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, String kind) async {
    final labelCtrl = TextEditingController();
    final threshCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(kind == TxTypes.spending
            ? 'Thêm danh mục chi tiêu'
            : 'Thêm danh mục thu nhập'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Tên danh mục'),
              autofocus: true,
            ),
            if (kind == TxTypes.spending) ...[
              const SizedBox(height: 12),
              TextField(
                controller: threshCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Ngưỡng tự động sao (₫, tùy chọn)',
                  suffixText: '₫',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () async {
              final label = labelCtrl.text.trim();
              if (label.isEmpty) return;
              final threshold = int.tryParse(threshCtrl.text) ?? 0;
              await repository.addCategory(
                  label: label, kind: kind, threshold: threshold);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    labelCtrl.dispose();
    threshCtrl.dispose();
  }
}

// ── Category list ─────────────────────────────────────────────────────────────

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppCategory>>(
      stream: repository.watchActiveCategories(kind),
      builder: (context, snap) {
        final cats = snap.data ?? [];
        if (cats.isEmpty) {
          return Center(
            child: Text(
              kind == TxTypes.spending
                  ? 'Chưa có danh mục chi tiêu.'
                  : 'Chưa có danh mục thu nhập.',
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          children: [
            for (final cat in cats)
              Card(
                child: ListTile(
                  title: Text(cat.label),
                  subtitle: cat.threshold > 0
                      ? Text('Tự động sao > ${formatVnd(cat.threshold)}')
                      : const Text('Không tự động sao'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showEditDialog(context, cat),
                      ),
                      IconButton(
                        icon: const Icon(Icons.archive_outlined),
                        tooltip: 'Lưu trữ danh mục',
                        onPressed: () => _confirmArchive(context, cat),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showEditDialog(BuildContext context, AppCategory cat) async {
    final labelCtrl = TextEditingController(text: cat.label);
    final threshCtrl = TextEditingController(
        text: cat.threshold > 0 ? cat.threshold.toString() : '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa danh mục'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Tên danh mục'),
              autofocus: true,
            ),
            if (cat.kind == TxTypes.spending) ...[
              const SizedBox(height: 12),
              TextField(
                controller: threshCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Ngưỡng tự động sao (₫, để trống = tắt)',
                  suffixText: '₫',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Lưu')),
        ],
      ),
    );

    if (ok == true) {
      final label = labelCtrl.text.trim();
      if (label.isEmpty) return;
      final threshold = int.tryParse(threshCtrl.text) ?? 0;
      await repository.updateCategory(
        AppCategory(
          id: cat.id,
          label: label,
          kind: cat.kind,
          threshold: threshold,
          isDefault: cat.isDefault,
          archived: cat.archived,
          sortOrder: cat.sortOrder,
        ),
      );
    }
    labelCtrl.dispose();
    threshCtrl.dispose();
  }

  Future<void> _confirmArchive(BuildContext context, AppCategory cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Lưu trữ "${cat.label}"?'),
        content: const Text(
            'Danh mục sẽ ẩn khỏi lựa chọn nhưng giao dịch cũ vẫn giữ nguyên.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lưu trữ')),
        ],
      ),
    );
    if (ok == true) await repository.archiveCategory(cat.id);
  }
}
