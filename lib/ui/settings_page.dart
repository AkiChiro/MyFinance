import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/domain.dart';
import '../providers.dart';
import '../services/notification_service.dart';
import 'categories_page.dart';
import 'theme_customization_page.dart';
import 'widgets/icon_slots.dart';

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
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final settings = ref.read(settingsProvider);
      final suggester = ref.read(suggesterProvider);
      final file = await ref.read(repositoryProvider).csv.exportAll(
            settingsEntries: settings.exportEntries(kIconSlots),
            keywordRules: await suggester.loadRaw(),
          );
      await SharePlus.instance
          .share(ShareParams(files: [file], subject: l10n.settingsCsvShareSubject));
    } catch (e) {
      _snack(l10n.settingsExportFailed(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.settingsCsvImportConfirmTitle),
        content: Text(l10n.settingsCsvImportConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.settingsCsvImportConfirmAction),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    // FileType.custom + allowedExtensions asks Android's document picker to
    // filter by MIME type. Cloud-provider-listed files (e.g. Google Drive)
    // often don't report the exact MIME type expected, so they show up
    // greyed out and unselectable even with the right extension. FileType.any
    // skips that filter; the extension is checked here instead.
    final picked = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = picked?.files.single.path;
    if (path == null) return;
    if (!path.toLowerCase().endsWith('.csv')) {
      _snack(l10n.settingsCsvWrongFileType);
      return;
    }

    setState(() => _busy = true);
    try {
      final r = await ref.read(repositoryProvider).csv.importAll(path);
      _snack(l10n.csvImportResult(
          r.walletsAdded, r.walletsSkipped, r.txnsAdded, r.txnsUpdated));
    } catch (e) {
      _snack(l10n.settingsImportFailed(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleNotifToggle(bool v) async {
    final l10n = AppLocalizations.of(context)!;
    ref.read(settingsProvider).notifEnabled = v;
    if (v) {
      final status = await Permission.notification.status;
      if (!mounted) return;
      if (status.isPermanentlyDenied) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.settingsNotifPermTitle),
            content: Text(l10n.settingsNotifPermBody),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.settingsNotNow)),
              FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openAppSettings();
                  },
                  child: Text(l10n.settingsOpenSettings)),
            ],
          ),
        );
      } else {
        if (status.isDenied) {
          await Permission.notification.request();
        }
        if (await Permission.notification.isGranted) {
          await NotificationService.instance
              .showPersistentNotification(locale: ref.read(settingsProvider).locale);
        }
      }
    } else {
      await NotificationService.instance.cancelPersistentNotification();
    }
  }

  Future<void> _openListenerSettings() async {
    await ref.read(captureServiceProvider).permissions.requestListenerAccess();
  }

  Future<void> _showSeenPackages() async {
    final l10n = AppLocalizations.of(context)!;
    final packages =
        await ref.read(captureServiceProvider).seenPackages();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsSeenPackagesTitle),
        content: packages.isEmpty
            ? Text(l10n.settingsNoPackagesSeen)
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsPackagesHint,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    for (final pkg in packages)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: SelectableText(
                          pkg,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                  ],
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  Future<void> _editCurrencySymbol() async {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.read(settingsProvider);
    final ctrl = TextEditingController(text: settings.currencySymbol);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsCurrencySymbolTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 8,
          decoration: InputDecoration(
            labelText: l10n.settingsCurrencySymbolFieldLabel,
            hintText: '₫',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.commonSave)),
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
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Notifications ──────────────────────────────────────────────────
        _SectionHeader(l10n.settingsSectionNotifications),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: Text(l10n.settingsNotifTitle),
                subtitle: Text(l10n.settingsNotifSubtitle),
                value: settings.notifEnabled,
                onChanged: _handleNotifToggle,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.battery_saver_outlined),
                title: Text(l10n.settingsBatteryTitle),
                subtitle: Text(l10n.settingsBatteryBody),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Language ───────────────────────────────────────────────────────
        _SectionHeader(l10n.settingsSectionLanguage),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'vi', label: Text('Tiếng Việt')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {settings.locale},
              onSelectionChanged: (s) async {
                settings.locale = s.first;
                if (settings.notifEnabled) {
                  await NotificationService.instance
                      .showPersistentNotification(locale: s.first);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Currency ───────────────────────────────────────────────────────
        _SectionHeader(l10n.settingsSectionCurrency),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.currency_exchange),
                title: Text(l10n.settingsCurrencySymbolTitle),
                subtitle: Text(l10n.currencyExampleLabel(settings.currencySymbol)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _editCurrencySymbol,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Auto-star ──────────────────────────────────────────────────────
        _SectionHeader(l10n.settingsSectionAutostar),
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.star_outline),
            title: Text(l10n.settingsAutostarTitle),
            subtitle: Text(l10n.settingsAutostarSubtitle),
            value: settings.autostarEnabled,
            onChanged: (v) => settings.autostarEnabled = v,
          ),
        ),
        const SizedBox(height: 16),

        // ── Categories ─────────────────────────────────────────────────────
        _SectionHeader(l10n.settingsSectionCategories),
        Card(
          child: ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(l10n.settingsManageCategoriesTitle),
            subtitle: Text(l10n.settingsManageCategoriesSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoriesPage()),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Theme ──────────────────────────────────────────────────────────
        _SectionHeader(l10n.settingsSectionTheme),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.settingsColorModeLabel,
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                            value: 'system', label: Text(l10n.settingsThemeSystem)),
                        ButtonSegment(value: 'light', label: Text(l10n.settingsThemeLight)),
                        ButtonSegment(value: 'dark', label: Text(l10n.settingsThemeDark)),
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
                title: Text(l10n.settingsAdvancedThemeTitle),
                subtitle: Text(l10n.settingsAdvancedThemeSubtitle),
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
        _SectionHeader(l10n.settingsSectionCsv),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: Text(l10n.settingsCsvExportTitle),
                subtitle: Text(l10n.settingsCsvExportSubtitle),
                onTap: _busy ? null : _export,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download),
                title: Text(l10n.settingsCsvImportTitle),
                subtitle: Text(l10n.settingsCsvImportSubtitle),
                onTap: _busy ? null : _import,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Keyword Library ────────────────────────────────────────────────
        _SectionHeader(l10n.settingsSectionKeywords),
        Card(
          child: ListTile(
            leading: const Icon(Icons.label_outline),
            title: Text(l10n.settingsKeywordLibraryTitle),
            subtitle: Text(l10n.settingsKeywordLibrarySubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KeywordEditorPage()),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── About ──────────────────────────────────────────────────────────
        _SectionHeader(l10n.settingsSectionAbout),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('MyFinance'),
            subtitle: Text(l10n.settingsAboutSubtitle),
          ),
        ),
        const SizedBox(height: 16),

        // ── Developer ─────────────────────────────────────────────────────
        _SectionHeader(l10n.settingsSectionDeveloper),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(l10n.settingsListenerPermTitle),
                subtitle: Text(l10n.settingsListenerPermSubtitle),
                trailing: const Icon(Icons.open_in_new_outlined),
                onTap: _openListenerSettings,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.explore_outlined),
                title: Text(l10n.settingsSeenPackagesTitle),
                subtitle: Text(l10n.settingsSeenPackagesSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showSeenPackages,
              ),
            ],
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
        SnackBar(content: Text(AppLocalizations.of(context)!.keywordEditorSaved)),
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.keywordEditorTitle),
        actions: [
          if (_dirty)
            TextButton(onPressed: _save, child: Text(l10n.commonSave)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rules.isEmpty
              ? Center(child: Text(l10n.keywordEditorEmpty))
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
                            : (_catLabels[catId] ?? Categories.label(l10n, catId)),
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
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.keywordEditorAddTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _kwCtrl,
            decoration: InputDecoration(labelText: l10n.keywordEditorKeywordField),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: InputDecoration(labelText: l10n.fieldCategory),
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
            decoration: InputDecoration(labelText: l10n.keywordEditorWeightField),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel)),
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
          child: Text(l10n.commonAdd),
        ),
      ],
    );
  }
}
