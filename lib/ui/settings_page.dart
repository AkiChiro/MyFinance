import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../models/domain.dart';
import '../providers.dart';
import '../services/csv_service.dart';
import '../services/notification_service.dart';
import 'categories_page.dart';
import 'theme_customization_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
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
      final files = await ref.read(repositoryProvider).csv.export();
      await SharePlus.instance
          .share(ShareParams(files: files, subject: 'MyFinance — sao lưu CSV'));
    } catch (e) {
      _snack('Xuất CSV thất bại: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importMerge() async {
    final mode = await showDialog<CsvImportMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chọn chế độ nhập'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Chỉ lưu trữ'),
              subtitle: const Text('Không ảnh hưởng đến số dư ví.'),
              onTap: () => Navigator.pop(ctx, CsvImportMode.contextOnly),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Khôi phục số dư'),
              subtitle: const Text('Tính vào số dư — chỉ dùng cho ví trống.'),
              onTap: () => Navigator.pop(ctx, CsvImportMode.reconstructBalance),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
        ],
      ),
    );
    if (mode == null || !mounted) return;

    final picked = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    final path = picked?.files.single.path;
    if (path == null) return;

    setState(() => _busy = true);
    try {
      final r = await ref
          .read(repositoryProvider)
          .csv
          .importMerge(path, mode: mode);
      _snack('Đã gộp ${r.added} giao dịch mới (bỏ qua ${r.skipped}).');
    } on NonEmptyWalletReconstructError {
      _snack(
          'Ví đã có giao dịch ảnh hưởng số dư. Chọn "Chỉ lưu trữ" hoặc dùng ví trống.');
    } catch (e) {
      _snack('Nhập CSV thất bại: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importReplace() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thay thế toàn bộ dữ liệu?'),
        content: const Text(
          'Thao tác này sẽ XOÁ toàn bộ ví và giao dịch hiện tại, '
          'sau đó khôi phục từ hai file CSV (ví + giao dịch).\n\n'
          'Không thể hoàn tác. Hãy chắc chắn bạn có bản sao lưu.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    _snack('Chọn file ví (myfinance_wallets_...)');
    final wPicked = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    final wPath = wPicked?.files.single.path;
    if (wPath == null || !mounted) return;

    _snack('Chọn file giao dịch (myfinance_txns_...)');
    final tPicked = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    final tPath = tPicked?.files.single.path;
    if (tPath == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final r = await ref.read(repositoryProvider).csv.importReplace(wPath, tPath);
      _snack('Đã khôi phục ${r.added} giao dịch.');
    } catch (e) {
      _snack('Khôi phục thất bại: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleNotifToggle(bool v) async {
    ref.read(settingsProvider).notifEnabled = v;
    if (v) {
      final status = await Permission.notification.status;
      if (!mounted) return;
      if (status.isPermanentlyDenied) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cần quyền thông báo'),
            content: const Text(
              'Quyền thông báo đã bị từ chối vĩnh viễn. '
              'Vui lòng cấp quyền trong Cài đặt ứng dụng.',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Không phải bây giờ')),
              FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openAppSettings();
                  },
                  child: const Text('Mở cài đặt')),
            ],
          ),
        );
      } else {
        if (status.isDenied) {
          await Permission.notification.request();
        }
        if (await Permission.notification.isGranted) {
          await NotificationService.instance.showPersistentNotification();
        }
      }
    } else {
      await NotificationService.instance.cancelPersistentNotification();
    }
  }

  Future<void> _editCurrencySymbol() async {
    final settings = ref.read(settingsProvider);
    final ctrl = TextEditingController(text: settings.currencySymbol);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ký hiệu tiền tệ'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 8,
          decoration: const InputDecoration(
            labelText: 'Ký hiệu',
            hintText: '₫',
          ),
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
      final sym = ctrl.text.trim();
      if (sym.isNotEmpty) settings.currencySymbol = sym;
    }
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Notifications ──────────────────────────────────────────────────
        const _SectionHeader('Thông báo'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('Thông báo liên tục'),
                subtitle:
                    const Text('Giữ nút thêm nhanh trong thanh thông báo.'),
                value: settings.notifEnabled,
                onChanged: _handleNotifToggle,
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.battery_saver_outlined),
                title: Text('Lưu ý pin'),
                subtitle: Text(
                  'Nếu thông báo biến mất sau khi tắt màn hình, '
                  'hãy tắt "Tối ưu hoá pin" cho MyFinance trong '
                  'Cài đặt → Ứng dụng.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Currency ───────────────────────────────────────────────────────
        const _SectionHeader('Đơn vị tiền tệ'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.currency_exchange),
                title: const Text('Ký hiệu tiền tệ'),
                subtitle: Text('Ví dụ: 100.000 ${settings.currencySymbol}'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _editCurrencySymbol,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Auto-star ──────────────────────────────────────────────────────
        const _SectionHeader('Tự động đánh dấu sao'),
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.star_outline),
            title: const Text('Tự động sao theo ngưỡng'),
            subtitle: const Text(
                'Tự động đánh dấu sao cho khoản chi vượt ngưỡng danh mục.'),
            value: settings.autostarEnabled,
            onChanged: (v) => settings.autostarEnabled = v,
          ),
        ),
        const SizedBox(height: 16),

        // ── Categories ─────────────────────────────────────────────────────
        const _SectionHeader('Danh mục'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Quản lý danh mục'),
            subtitle: const Text(
                'Thêm, sửa, lưu trữ danh mục chi tiêu và thu nhập.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoriesPage()),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Theme ──────────────────────────────────────────────────────────
        const _SectionHeader('Giao diện'),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chế độ màu',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'system', label: Text('Hệ thống')),
                        ButtonSegment(value: 'light', label: Text('Sáng')),
                        ButtonSegment(value: 'dark', label: Text('Tối')),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (s) =>
                          settings.themeMode = s.first,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.tune_outlined),
                title: const Text('Tuỳ chỉnh nâng cao'),
                subtitle: const Text(
                    'Màu nền, màu chữ, ảnh nền, màu chủ đề.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ThemeCustomizationPage(),
                )),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── CSV Backup ─────────────────────────────────────────────────────
        const _SectionHeader('Sao lưu dữ liệu (CSV)'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Xuất CSV'),
                subtitle: const Text(
                    'Chia sẻ/lưu giao dịch và ví ra file CSV.'),
                onTap: _busy ? null : _export,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Nhập CSV (gộp)'),
                subtitle: const Text(
                    'Gộp theo id. Giao dịch nhập chỉ để xem lịch sử — '
                    'không tính vào số dư hay thống kê.'),
                onTap: _busy ? null : _importMerge,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.restore,
                    color: Theme.of(context).colorScheme.error),
                title: Text('Nhập CSV (thay thế toàn bộ)',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
                subtitle: const Text(
                    'Xoá toàn bộ dữ liệu hiện tại và khôi phục từ CSV. '
                    'Cần chọn hai file: ví rồi giao dịch.'),
                onTap: _busy ? null : _importReplace,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Keyword Library ────────────────────────────────────────────────
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

        // ── About ──────────────────────────────────────────────────────────
        const _SectionHeader('Thông tin'),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('MyFinance'),
            subtitle: Text(
                'Phiên bản 0.2 · Hoàn toàn ngoại tuyến · Chỉ dùng VND.'),
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
// Keyword Library Editor
// ---------------------------------------------------------------------------

class KeywordEditorPage extends ConsumerStatefulWidget {
  const KeywordEditorPage({super.key});

  @override
  ConsumerState<KeywordEditorPage> createState() => _KeywordEditorPageState();
}

class _KeywordEditorPageState extends ConsumerState<KeywordEditorPage> {
  List<Map<String, dynamic>> _rules = [];
  Map<String, String> _catLabels = {};
  List<AppCategory> _activeCategories = [];
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(repositoryProvider);
    final suggester = ref.read(suggesterProvider);
    final rules = await suggester.loadRaw();
    // allCategories includes archived — for rendering labels on existing rules.
    final allCats = await repo.allCategories();
    // allActiveCategories — for the picker in the add-rule dialog.
    final activeCats = await repo.allActiveCategories();
    setState(() {
      _rules = rules;
      _catLabels = {for (final c in allCats) c.id: c.label};
      _activeCategories = activeCats;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await ref.read(suggesterProvider).saveAndReload(_rules);
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
    if (_activeCategories.isEmpty) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AddKeywordDialog(categories: _activeCategories),
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
            TextButton(onPressed: _save, child: const Text('Lưu')),
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
                    final catId = r['category'] as String?;
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          (r['weight'] as int? ?? 0).toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      title: Text(r['keyword'] as String? ?? ''),
                      subtitle: Text(
                        catId == null
                            ? '—'
                            : (_catLabels[catId] ?? Categories.label(catId)),
                      ),
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
  const _AddKeywordDialog({required this.categories});
  final List<AppCategory> categories;

  @override
  State<_AddKeywordDialog> createState() => _AddKeywordDialogState();
}

class _AddKeywordDialogState extends State<_AddKeywordDialog> {
  final _kwCtrl = TextEditingController();
  final _wCtrl = TextEditingController(text: '5');
  late String _category;

  @override
  void initState() {
    super.initState();
    _category = widget.categories.isNotEmpty
        ? widget.categories.first.id
        : Categories.fallbackFor(TxTypes.spending);
  }

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
              for (final c in widget.categories)
                DropdownMenuItem(value: c.id, child: Text(c.label)),
            ],
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _wCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Trọng số (1–10)'),
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
