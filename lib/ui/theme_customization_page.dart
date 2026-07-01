import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../main.dart' show settings;

// Preset palette used in all color pickers
const _palette = <Color>[
  // Reds / Pinks / Purples
  Color(0xFFEF5350), Color(0xFFEC407A), Color(0xFFAB47BC),
  Color(0xFF7E57C2), Color(0xFF5C6BC0), Color(0xFF42A5F5),
  // Blues / Teals / Greens
  Color(0xFF26C6DA), Color(0xFF26A69A), Color(0xFF66BB6A),
  Color(0xFF9CCC65), Color(0xFFFFEE58), Color(0xFFFFA726),
  // Oranges / Browns / Greys
  Color(0xFFFF7043), Color(0xFF8D6E63), Color(0xFF78909C),
  // Light backgrounds
  Color(0xFFFFFFFF), Color(0xFFF5F5F5), Color(0xFFFFFDF5),
  Color(0xFFF3E5F5), Color(0xFFE3F2FD), Color(0xFFE8F5E9),
  Color(0xFFFFF8E1), Color(0xFFE0F7FA), Color(0xFFFCE4EC),
  // Dark backgrounds
  Color(0xFF212121), Color(0xFF1C1B1F), Color(0xFF263238),
  Color(0xFF1A1A2E), Color(0xFF0D0D0D),
  // Neutrals
  Color(0xFF000000), Color(0xFF9E9E9E),
];

class ThemeCustomizationPage extends StatelessWidget {
  const ThemeCustomizationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Tuỳ chỉnh giao diện'),
          actions: [
            TextButton(
              onPressed: () => _resetAll(context),
              child: const Text('Đặt lại'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Colors ────────────────────────────────────────────────────────
            _sectionHeader(context, 'Màu sắc'),
            Card(
              child: Column(
                children: [
                  _ColorPickerTile(
                    icon: Icons.palette_outlined,
                    title: 'Màu chủ đề',
                    subtitle:
                        'Ảnh hưởng tới nút, thanh tiêu đề và toàn bộ bảng màu.',
                    color: Color(settings.themeSeedColor),
                    nullable: false,
                    onChanged: (c) {
                      if (c != null) {
                        // ignore: deprecated_member_use
                        settings.themeSeedColor = c.value;
                      }
                    },
                  ),
                  const Divider(height: 1),
                  _ColorPickerTile(
                    icon: Icons.format_paint_outlined,
                    title: 'Màu nền ứng dụng',
                    subtitle: 'Màu nền của màn hình. '
                        '"Tự động" dùng màu mặc định theo chế độ sáng/tối.',
                    color: settings.scaffoldBgColor,
                    nullable: true,
                    onChanged: (c) => settings.scaffoldBgColor = c,
                  ),
                  const Divider(height: 1),
                  _ColorPickerTile(
                    icon: Icons.font_download_outlined,
                    title: 'Màu chữ',
                    subtitle:
                        '"Tự động" theo chế độ sáng/tối. Cẩn thận khi chọn '
                        'màu tương phản thấp.',
                    color: settings.fontColor,
                    nullable: true,
                    onChanged: (c) => settings.fontColor = c,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Background image ──────────────────────────────────────────────
            _sectionHeader(context, 'Ảnh nền'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.image_outlined),
                    title: const Text('Chọn ảnh nền'),
                    subtitle: const Text(
                        'Ảnh hiển thị phía sau toàn bộ màn hình.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pickImage(context),
                  ),
                  if (settings.bgImagePath != null) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(settings.bgImagePath!),
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(
                              height: 40,
                              child: Center(
                                  child: Text('Không tìm thấy ảnh'))),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error),
                      title: Text('Xoá ảnh nền',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                      onTap: () => settings.bgImagePath = null,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Note ──────────────────────────────────────────────────────────
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Khi dùng ảnh nền, nền ứng dụng sẽ tự động trong suốt '
                        'để hiện ảnh phía sau.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _pickImage(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    final path = picked?.files.single.path;
    if (path != null) settings.bgImagePath = path;
  }

  Future<void> _resetAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đặt lại giao diện?'),
        content: const Text(
            'Màu chủ đề, màu nền, màu chữ và ảnh nền sẽ trở về mặc định.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Đặt lại')),
        ],
      ),
    );
    if (ok != true) return;
    settings.themeSeedColor = 0xFFFFC107;
    settings.scaffoldBgColor = null;
    settings.fontColor = null;
    settings.bgImagePath = null;
  }
}

// ── Color picker tile + dialog ────────────────────────────────────────────────

class _ColorPickerTile extends StatelessWidget {
  const _ColorPickerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.nullable,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;
  final bool nullable;
  final ValueChanged<Color?> onChanged;

  @override
  Widget build(BuildContext context) {
    final displayColor = color ?? Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: GestureDetector(
        onTap: () => _open(context),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: displayColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
              width: 1.5,
            ),
          ),
          child: color == null
              ? Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: displayColor.computeLuminance() > 0.5
                      ? Colors.black54
                      : Colors.white70,
                )
              : null,
        ),
      ),
      onTap: () => _open(context),
    );
  }

  Future<void> _open(BuildContext context) async {
    final result = await showDialog<Color?>(
      context: context,
      builder: (_) => _ColorPickerDialog(
        title: title,
        initial: color ?? Theme.of(context).colorScheme.primary,
        nullable: nullable,
      ),
    );
    if (result == null) return; // cancelled
    // Color(0x00000000) is the "Auto/clear" sentinel from the dialog.
    if (result == const Color(0x00000000)) {
      onChanged(null);
    } else {
      onChanged(result);
    }
  }
}

// ── Color picker dialog ───────────────────────────────────────────────────────

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({
    required this.title,
    required this.initial,
    required this.nullable,
  });

  final String title;
  final Color initial;
  final bool nullable;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _selected;
  final _hexCtrl = TextEditingController();
  bool _hexError = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    _hexCtrl.text = _toHex(_selected);
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  String _toHex(Color c) {
    // ignore: deprecated_member_use
    final hex = (c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
    return hex;
  }

  void _applyHex(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (cleaned.length == 6) {
      final v = int.tryParse('FF$cleaned', radix: 16);
      if (v != null) {
        setState(() {
          _selected = Color(v);
          _hexError = false;
        });
        return;
      }
    }
    if (cleaned.isNotEmpty) setState(() => _hexError = true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Live preview
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _selected,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.outline, width: 2),
                ),
              ),
              const SizedBox(height: 14),
              // Preset grid
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  for (final c in _palette)
                    GestureDetector(
                      onTap: () => setState(() {
                        _selected = c;
                        _hexCtrl.text = _toHex(c);
                        _hexError = false;
                      }),
                      child: Container(
                        width: 34,
                        height: 34,
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c == _selected
                                ? scheme.primary
                                : scheme.outlineVariant,
                            width: c == _selected ? 3 : 1,
                          ),
                        ),
                        child: c == _selected
                            ? Icon(
                                Icons.check,
                                size: 16,
                                color: c.computeLuminance() > 0.5
                                    ? Colors.black
                                    : Colors.white,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              // Hex input
              TextField(
                controller: _hexCtrl,
                decoration: InputDecoration(
                  labelText: 'Mã màu Hex',
                  prefixText: '#',
                  hintText: 'FF5722',
                  errorText: _hexError ? 'Mã không hợp lệ (cần 6 ký tự)' : null,
                ),
                onChanged: _applyHex,
                onSubmitted: _applyHex,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.nullable)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const Color(0x00000000)), // sentinel
            child: const Text('Tự động'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
