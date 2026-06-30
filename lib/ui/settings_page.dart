import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart' show repository, suggester;
import '../models/domain.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final files = await repository.csv.export();
      await SharePlus.instance.share(ShareParams(files: files, subject: 'MyFinance — sao lưu CSV'));
    } catch (e) {
      _snack('Xuất CSV thất bại: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    setState(() => _busy = true);
    try {
      final r = await repository.csv.importMerge(path);
      _snack('Đã gộp ${r.added} giao dịch mới (bỏ qua ${r.skipped}).');
    } catch (e) {
      _snack('Nhập CSV thất bại: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const _SectionHeader('Sao lưu dữ liệu (CSV)'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Xuất CSV'),
                subtitle: const Text('Chia sẻ/lưu giao dịch và ví ra file CSV.'),
                onTap: _busy ? null : _export,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Nhập CSV (gộp)'),
                subtitle: const Text(
                    'Gộp theo id. Giao dịch nhập vào chỉ để xem lại lịch sử — '
                    'không tính vào số dư hay thống kê.'),
                onTap: _busy ? null : _import,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _SectionHeader('Danh mục gợi ý'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('Thư viện từ khoá'),
            subtitle: const Text(
                'Sửa từ khoá và danh mục gợi ý khi nhập mô tả.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KeywordEditorPage()),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _SectionHeader('Thông tin'),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('MyFinance'),
            subtitle: Text(
                'Phiên bản 1.0 · Hoàn toàn ngoại tuyến · Chỉ dùng VND.'),
          ),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}

// ---------------------------------------------------------------------------
// Keyword Library Editor (P4)
// ---------------------------------------------------------------------------

/// All valid category ids in one flat list for the dropdown.
const _allCategories = [
  ...Categories.spending,
  ...Categories.earning,
];

class KeywordEditorPage extends StatefulWidget {
  const KeywordEditorPage({super.key});

  @override
  State<KeywordEditorPage> createState() => _KeywordEditorPageState();
}

class _KeywordEditorPageState extends State<KeywordEditorPage> {
  List<Map<String, dynamic>> _rules = [];
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rules = await suggester.loadRaw();
    setState(() {
      _rules = rules;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await suggester.saveAndReload(_rules);
    setState(() => _dirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu thư viện từ khoá.')),
      );
    }
  }

  void _delete(int index) {
    setState(() {
      _rules.removeAt(index);
      _dirty = true;
    });
  }

  Future<void> _addRule() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _AddKeywordDialog(),
    );
    if (result != null) {
      setState(() {
        _rules.add(result);
        _dirty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Từ khoá gợi ý'),
        actions: [
          if (_dirty)
            TextButton(
              onPressed: _save,
              child: const Text('Lưu'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rules.isEmpty
              ? const Center(child: Text('Chưa có từ khoá nào.'))
              : ListView.builder(
                  itemCount: _rules.length,
                  itemBuilder: (context, i) {
                    final r = _rules[i];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          (r['weight'] as int? ?? 0).toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      title: Text(r['keyword'] as String? ?? ''),
                      subtitle:
                          Text(Categories.label(r['category'] as String?)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(i),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRule,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddKeywordDialog extends StatefulWidget {
  const _AddKeywordDialog();

  @override
  State<_AddKeywordDialog> createState() => _AddKeywordDialogState();
}

class _AddKeywordDialogState extends State<_AddKeywordDialog> {
  final _kwCtrl = TextEditingController();
  final _wCtrl = TextEditingController(text: '5');
  String _category = _allCategories.first;

  @override
  void dispose() {
    _kwCtrl.dispose();
    _wCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm từ khoá'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _kwCtrl,
            decoration: const InputDecoration(labelText: 'Từ khoá'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Danh mục'),
            items: [
              for (final c in _allCategories)
                DropdownMenuItem(value: c, child: Text(Categories.label(c))),
            ],
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _wCtrl,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Trọng số (1–10)'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ')),
        FilledButton(
          onPressed: () {
            final kw = _kwCtrl.text.trim();
            if (kw.isEmpty) return;
            final w = int.tryParse(_wCtrl.text) ?? 5;
            Navigator.pop(context, {
              'keyword': kw,
              'category': _category,
              'weight': w.clamp(1, 20),
            });
          },
          child: const Text('Thêm'),
        ),
      ],
    );
  }
}
