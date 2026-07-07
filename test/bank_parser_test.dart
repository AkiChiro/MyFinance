import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/format.dart';
import 'package:myfinance/models/domain.dart';
import 'package:myfinance/services/bank/bank_notification_parser.dart';
import 'package:myfinance/services/bank/mb_parser.dart';
import 'package:myfinance/services/bank/ocb_parser.dart';
import 'package:myfinance/services/bank/techcombank_parser.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  group('parseVndAmount', () {
    test('dot-separated thousands: 20.000 → 20000', () {
      expect(parseVndAmount('20.000'), 20000);
    });

    test('comma-separated thousands: 20,000 → 20000', () {
      expect(parseVndAmount('20,000'), 20000);
    });

    test('multi-dot: 6.000.000 → 6000000', () {
      expect(parseVndAmount('6.000.000'), 6000000);
    });

    test('four-digit dot group: 335.532 → 335532', () {
      expect(parseVndAmount('335.532'), 335532);
    });

    test('amount with trailing space and VND: "20.000 VND" → 20000', () {
      expect(parseVndAmount('20.000 VND'), 20000);
    });

    test('currency before number: "VND 20,013" → 20013', () {
      expect(parseVndAmount('VND 20,013'), 20013);
    });

    test('leading plus stripped: "+20.000 VND" → 20000', () {
      expect(parseVndAmount('+20.000 VND'), 20000);
    });

    test('leading minus stripped: "-20.000 VND" → 20000', () {
      expect(parseVndAmount('-20.000 VND'), 20000);
    });

    test('separator-only "." → 0 (no crash)', () {
      expect(parseVndAmount('.'), 0);
    });

    test('separator-only "," → 0 (no crash)', () {
      expect(parseVndAmount(','), 0);
    });

    test('empty string → 0 (no crash)', () {
      expect(parseVndAmount(''), 0);
    });

    test('trailing dot "335.532." → 335532 (OCB stray dot case)', () {
      expect(parseVndAmount('335.532.'), 335532);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('BankParserRegistry', () {
    test('returns OcbParser for OCB package', () {
      expect(BankParserRegistry.forPackage(BankPackages.ocb), isA<OcbParser>());
    });

    test('returns MbParser for MB package', () {
      expect(BankParserRegistry.forPackage(BankPackages.mb), isA<MbParser>());
    });

    test('returns TechcombankParser for Techcombank package', () {
      expect(BankParserRegistry.forPackage(BankPackages.techcombank),
          isA<TechcombankParser>());
    });

    test('returns null for unknown package', () {
      expect(BankParserRegistry.forPackage('com.unknown.bank'), isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('OcbParser', () {
    const parser = OcbParser();

    // Exact fixture from spec — expense
    test('expense fixture: -20.000 VND, balance 335.532.', () {
      const raw = RawNotification(
        packageName: BankPackages.ocb,
        title: 'Thông báo biến động số dư',
        text: '06/07 15:27\n'
            'Tài khoản: xxxxxxxxxxxxxxxx\n'
            'Số tiền: -20.000 VND\n'
            'Số dư: 335.532. VND\n'
            'Nội dung: XXX transfer',
      );
      final result = parser.parse(raw);
      expect(result, isNotNull);
      expect(result!.amount, 20000);
      expect(result.direction, CaptureDirection.expense);
      expect(result.endingBalance, 335532);
      expect(result.lowConfidence, isFalse);
    });

    // Exact fixture from spec — income
    test('income fixture: +20.000 VND, balance 335.532.', () {
      const raw = RawNotification(
        packageName: BankPackages.ocb,
        title: 'Thông báo biến động số dư',
        text: '06/07 15:27\n'
            'Tài khoản: xxxxxxxxxxxxxxxx\n'
            'Số tiền: +20.000 VND\n'
            'Số dư: 335.532. VND\n'
            'Nội dung: XXX transfer',
      );
      final result = parser.parse(raw);
      expect(result, isNotNull);
      expect(result!.amount, 20000);
      expect(result.direction, CaptureDirection.income);
      expect(result.endingBalance, 335532);
      expect(result.lowConfidence, isFalse);
    });

    test('parses accountHint from Tài khoản line', () {
      const raw = RawNotification(
        packageName: BankPackages.ocb,
        text: 'Tài khoản: xxxxxxxxxxxxxxxx\n'
            'Số tiền: -20.000 VND\n'
            'Số dư: 335.532. VND',
      );
      expect(parser.parse(raw)?.accountHint, 'xxxxxxxxxxxxxxxx');
    });

    // Negative: OTP message — no Số tiền line
    test('negative: OTP notification returns null', () {
      const raw = RawNotification(
        packageName: BankPackages.ocb,
        title: 'OCB',
        text: 'Mã OTP của bạn là: 123456\n'
            'Hiệu lực 5 phút. Không chia sẻ với ai.',
      );
      expect(parser.parse(raw), isNull);
    });

    // Negative: promo message with a number but no Số tiền line
    test('negative: promotional message with number returns null', () {
      const raw = RawNotification(
        packageName: BankPackages.ocb,
        text: 'Ưu đãi 20.000 VND cho lần thanh toán tiếp theo!\n'
            'Áp dụng đến 31/07.',
      );
      expect(parser.parse(raw), isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('MbParser', () {
    const parser = MbParser();

    // Exact fixture from spec — expense
    test('expense fixture: GD: -20,000VND, SD: 20,825VND', () {
      const raw = RawNotification(
        packageName: BankPackages.mb,
        title: 'Thông báo biến động số dư',
        text: 'TK xxxxxxxx|GD: -20,000VND 07/07/26 15:25 '
            '|SD: 20,825VND|DEN: XXX - XXXXXXXXXXXX'
            '|ND: XXX chuyển tiền D2EA9G4U/886938',
      );
      final result = parser.parse(raw);
      expect(result, isNotNull);
      expect(result!.amount, 20000);
      expect(result.direction, CaptureDirection.expense);
      expect(result.endingBalance, 20825);
      expect(result.lowConfidence, isFalse);
    });

    // Exact fixture from spec — income
    test('income fixture: GD: +20,000VND, SD: 20,825VND', () {
      const raw = RawNotification(
        packageName: BankPackages.mb,
        title: 'Thông báo biến động số dư',
        text: 'TK xxxxxxxx|GD: +20,000VND 07/07/26 15:25 '
            '|SD: 20,825VND|DEN: XXX - XXXXXXXXXXXX'
            '|ND: XXX chuyển tiền D2EA9G4U/886938',
      );
      final result = parser.parse(raw);
      expect(result, isNotNull);
      expect(result!.amount, 20000);
      expect(result.direction, CaptureDirection.income);
      expect(result.endingBalance, 20825);
      expect(result.lowConfidence, isFalse);
    });

    test('parses accountHint from TK field', () {
      const raw = RawNotification(
        packageName: BankPackages.mb,
        text: 'TK xxxxxxxx|GD: -20,000VND 07/07/26 15:25 |SD: 20,825VND',
      );
      expect(parser.parse(raw)?.accountHint, 'xxxxxxxx');
    });

    // Negative: login alert — no GD: field
    test('negative: login alert returns null', () {
      const raw = RawNotification(
        packageName: BankPackages.mb,
        title: 'MB Bank',
        text: 'Đăng nhập thành công lúc 15:27.'
            ' Nếu không phải bạn, liên hệ hotline ngay.',
      );
      expect(parser.parse(raw), isNull);
    });

    // Negative: OTP
    test('negative: OTP notification returns null', () {
      const raw = RawNotification(
        packageName: BankPackages.mb,
        title: 'MB Bank',
        text: 'Mã xác thực giao dịch: 654321. Hiệu lực 3 phút.',
      );
      expect(parser.parse(raw), isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('TechcombankParser', () {
    const parser = TechcombankParser();

    // Exact fixture from spec — income
    test('income fixture: title "+ VND 20,000", body "Số dư: VND 20,013"', () {
      const raw = RawNotification(
        packageName: BankPackages.techcombank,
        title: '+ VND 20,000',
        text: 'Tài khoản: xxxxxxxxxxxxxxxx\n'
            'Số dư: VND 20,013\n'
            'XXX chuyen tien',
      );
      final result = parser.parse(raw);
      expect(result, isNotNull);
      expect(result!.amount, 20000);
      expect(result.direction, CaptureDirection.income);
      expect(result.endingBalance, 20013);
      expect(result.lowConfidence, isFalse);
    });

    // Expense by symmetry — UNVERIFIED
    test('expense fixture (UNVERIFIED — symmetry): title "- VND 20,000"', () {
      const raw = RawNotification(
        packageName: BankPackages.techcombank,
        title: '- VND 20,000',
        text: 'Tài khoản: xxxxxxxxxxxxxxxx\n'
            'Số dư: VND 20,013\n'
            'XXX chuyen tien',
      );
      final result = parser.parse(raw);
      expect(result, isNotNull);
      expect(result!.amount, 20000);
      expect(result.direction, CaptureDirection.expense);
      expect(result.endingBalance, 20013);
      expect(result.lowConfidence, isFalse);
    });

    test('parses accountHint from Tài khoản line', () {
      const raw = RawNotification(
        packageName: BankPackages.techcombank,
        title: '+ VND 20,000',
        text: 'Tài khoản: xxxxxxxxxxxxxxxx\nSố dư: VND 20,013',
      );
      expect(parser.parse(raw)?.accountHint, 'xxxxxxxxxxxxxxxx');
    });

    // Negative: null title
    test('negative: null title returns null', () {
      const raw = RawNotification(
        packageName: BankPackages.techcombank,
        title: null,
        text: 'Tài khoản: xxxxxxxxxxxxxxxx\nSố dư: VND 20,013',
      );
      expect(parser.parse(raw), isNull);
    });

    // Negative: title that doesn't match ± VND pattern (security alert)
    test('negative: non-amount title returns null', () {
      const raw = RawNotification(
        packageName: BankPackages.techcombank,
        title: 'Thông báo bảo mật',
        text: 'Đăng nhập vào ứng dụng lúc 15:27. '
            'Nếu không phải bạn, liên hệ Techcombank ngay.',
      );
      expect(parser.parse(raw), isNull);
    });

    // Negative: OTP title
    test('negative: OTP title returns null', () {
      const raw = RawNotification(
        packageName: BankPackages.techcombank,
        title: 'Mã OTP',
        text: 'Mã OTP của bạn: 789012. Hiệu lực 2 phút.',
      );
      expect(parser.parse(raw), isNull);
    });
  });
}
