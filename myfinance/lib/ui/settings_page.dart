import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart' show repository;

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
      await Share.shareXFiles(files, subject: 'MyFinance — sao lưu CSV');
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
        const _SectionHeader('Thông tin'),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('MyFinance'),
            subtitle: Text(
                'Phiên bản 1.0 (P1) · Hoàn toàn ngoại tuyến · Chỉ dùng VND.'),
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
