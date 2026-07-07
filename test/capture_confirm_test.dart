import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/data/database.dart';
import 'package:myfinance/models/domain.dart';
import 'package:myfinance/repositories/finance_repository.dart';
import 'package:myfinance/services/bank/bank_notification_parser.dart';

AppDatabase _openDb() => AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late FinanceRepository repo;

  setUp(() {
    db = _openDb();
    repo = FinanceRepository(db);
  });

  tearDown(() => db.close());

  Future<String> seedWallet({
    String name = 'Test Wallet',
    String? packageName,
  }) =>
      repo.addWallet(
          name: name, initialBalance: 1000000, packageName: packageName);

  Future<NotificationCapture> seedCapture({
    ParseStatus parseStatus = ParseStatus.parsed,
    int? amount = 50000,
    CaptureDirection? direction = CaptureDirection.expense,
    String packageName = 'com.ocb.app',
    String rawText = 'Số tiền: -50.000 VND',
  }) async {
    final c = await repo.insertCapture(
      packageName: packageName,
      rawText: rawText,
      capturedAt: DateTime(2026, 7, 7, 15, 0),
      amount: amount,
      direction: direction,
      parseStatus: parseStatus,
    );
    return c!;
  }

  // ── confirm parsed capture ───────────────────────────────────────────────────

  group('confirm parsed capture', () {
    test('creates one bankNotification transaction with correct fields', () async {
      final walletId = await seedWallet();
      final capture = await seedCapture();

      await repo.confirmCapture(
        capture.id,
        walletId: walletId,
        amount: 50000,
        direction: CaptureDirection.expense,
      );

      final txns = await db.watchTxns().first;
      expect(txns, hasLength(1));
      final txn = txns.first;
      expect(txn.source, SourceType.bankNotification);
      expect(txn.affectsBalance, isTrue);
      expect(txn.type, TxTypes.spending);
      expect(txn.walletId, walletId);
      expect(txn.amount, 50000);
    });

    test('income direction produces earning transaction', () async {
      final walletId = await seedWallet();
      final capture = await seedCapture(
        direction: CaptureDirection.income,
        amount: 200000,
      );

      await repo.confirmCapture(
        capture.id,
        walletId: walletId,
        amount: 200000,
        direction: CaptureDirection.income,
      );

      final txns = await db.watchTxns().first;
      expect(txns.first.type, TxTypes.earning);
    });

    test('transaction timestamp equals capturedAt, not review time', () async {
      final walletId = await seedWallet();
      final capture = await seedCapture();
      final capturedAt = DateTime(2026, 7, 7, 15, 0);

      await repo.confirmCapture(
        capture.id,
        walletId: walletId,
        amount: 50000,
        direction: CaptureDirection.expense,
      );

      final txns = await db.watchTxns().first;
      expect(txns.first.timestamp, capturedAt);
    });

    test('explicit timestamp overrides capturedAt', () async {
      final walletId = await seedWallet();
      final capture = await seedCapture();
      final override = DateTime(2026, 7, 5, 10, 30);

      await repo.confirmCapture(
        capture.id,
        walletId: walletId,
        amount: 50000,
        direction: CaptureDirection.expense,
        timestamp: override,
      );

      final txns = await db.watchTxns().first;
      expect(txns.first.timestamp, override);
    });

    test('capture status becomes confirmed', () async {
      final walletId = await seedWallet();
      final capture = await seedCapture();

      await repo.confirmCapture(
        capture.id,
        walletId: walletId,
        amount: 50000,
        direction: CaptureDirection.expense,
      );

      final all =
          await (db.select(db.notificationCaptures)).get();
      expect(all.first.status, CaptureStatus.confirmed);
    });
  });

  // ── wallet override ──────────────────────────────────────────────────────────

  group('wallet override', () {
    test('confirms to a different wallet than suggestedWalletId', () async {
      final suggestedId = await seedWallet(name: 'Suggested');
      final overrideId = await seedWallet(name: 'Override');

      // Seed capture — suggestedWalletId will be null since no wallet has
      // the packageName linked yet, but that doesn't affect the override test.
      final capture = await seedCapture();

      await repo.confirmCapture(
        capture.id,
        walletId: overrideId,
        amount: 50000,
        direction: CaptureDirection.expense,
      );

      final txns = await db.watchTxns().first;
      expect(txns.first.walletId, overrideId);
      expect(txns.first.walletId, isNot(suggestedId));
    });
  });

  // ── dismiss ──────────────────────────────────────────────────────────────────

  group('dismiss', () {
    test('creates no transaction and marks capture dismissed', () async {
      final capture = await seedCapture();

      await repo.dismissCapture(capture.id);

      final txns = await db.watchTxns().first;
      expect(txns, isEmpty);

      final all =
          await (db.select(db.notificationCaptures)).get();
      expect(all.first.status, CaptureStatus.dismissed);
    });
  });

  // ── unparsed flow ────────────────────────────────────────────────────────────

  group('unparsed flow', () {
    test('manually-entered amount/direction confirms correctly', () async {
      final walletId = await seedWallet();
      final capture = await seedCapture(
        parseStatus: ParseStatus.unparsed,
        amount: null,
        direction: null,
        packageName: 'com.unknown.bank',
        rawText: 'Giao dịch thành công 100.000 VND',
      );

      await repo.confirmCapture(
        capture.id,
        walletId: walletId,
        amount: 100000,
        direction: CaptureDirection.income,
      );

      final txns = await db.watchTxns().first;
      expect(txns.first.type, TxTypes.earning);
      expect(txns.first.amount, 100000);
      expect(txns.first.source, SourceType.bankNotification);
    });
  });

  // ── uniqueness guard ─────────────────────────────────────────────────────────

  group('uniqueness guard', () {
    test('walletByPackageName returns the linked wallet', () async {
      await seedWallet(packageName: BankPackages.ocb);
      final found = await repo.walletByPackageName(BankPackages.ocb);
      expect(found, isNotNull);
      expect(found!.packageName, BankPackages.ocb);
    });

    test('walletByPackageName returns null when no wallet is linked', () async {
      await seedWallet();
      final found = await repo.walletByPackageName(BankPackages.mb);
      expect(found, isNull);
    });

    test('reassignWalletBankLink atomically moves link to new wallet', () async {
      final id1 =
          await seedWallet(name: 'Old', packageName: BankPackages.ocb);
      final id2 = await seedWallet(name: 'New');

      await repo.reassignWalletBankLink(BankPackages.ocb, id2);

      final holder =
          await repo.walletByPackageName(BankPackages.ocb);
      expect(holder?.id, id2);

      final wallets = await repo.allWallets();
      final old = wallets.firstWhere((w) => w.id == id1);
      expect(old.packageName, isNull);
    });

    test('self-link edit: reassigning to same wallet is no-op on data', () async {
      final id1 =
          await seedWallet(name: 'Mine', packageName: BankPackages.mb);

      // Simulates UI "edit link → same bank" path when self-exclusion fires.
      await repo.reassignWalletBankLink(BankPackages.mb, id1);

      final holder =
          await repo.walletByPackageName(BankPackages.mb);
      expect(holder?.id, id1);
    });
  });

  // ── reactivity ───────────────────────────────────────────────────────────────

  group('reactivity', () {
    test('pendingCaptureCount is 0 initially', () async {
      expect(await repo.pendingCaptureCount().first, 0);
    });

    test('pendingCaptureCount increments on insert', () async {
      await seedCapture();
      expect(await repo.pendingCaptureCount().first, 1);
    });

    test('pendingCaptureCount decrements on confirm', () async {
      final walletId = await seedWallet();
      final capture = await seedCapture();

      await repo.confirmCapture(
        capture.id,
        walletId: walletId,
        amount: 50000,
        direction: CaptureDirection.expense,
      );

      expect(await repo.pendingCaptureCount().first, 0);
    });

    test('pendingCaptureCount decrements on dismiss', () async {
      final capture = await seedCapture();
      await repo.dismissCapture(capture.id);
      expect(await repo.pendingCaptureCount().first, 0);
    });

    test('watchPendingCaptures returns only pending rows', () async {
      final walletId = await seedWallet();

      // Seed two captures.
      final c1 = await repo.insertCapture(
        packageName: 'com.ocb.app',
        rawText: 'first',
        capturedAt: DateTime(2026, 7, 7, 10),
        amount: 10000,
        direction: CaptureDirection.expense,
        parseStatus: ParseStatus.parsed,
      );
      await repo.insertCapture(
        packageName: 'com.ocb.app',
        rawText: 'second',
        capturedAt: DateTime(2026, 7, 7, 11),
        amount: 20000,
        direction: CaptureDirection.expense,
        parseStatus: ParseStatus.parsed,
      );

      expect(await repo.pendingCaptureCount().first, 2);

      // Confirm the first.
      await repo.confirmCapture(
        c1!.id,
        walletId: walletId,
        amount: 10000,
        direction: CaptureDirection.expense,
      );

      expect(await repo.pendingCaptureCount().first, 1);
      final pending = await repo.watchPendingCaptures().first;
      expect(pending.first.rawText, 'second');
    });
  });
}
