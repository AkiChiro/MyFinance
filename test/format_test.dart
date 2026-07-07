import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/format.dart';

void main() {
  group('formatMoney', () {
    test('formats with suffix by default', () {
      expect(formatMoney(100000), '100.000 ₫');
    });

    test('formats with custom symbol and suffix', () {
      expect(formatMoney(1000, symbol: 'đ', suffix: true), '1.000 đ');
    });

    test('formats with symbol as prefix when suffix=false', () {
      expect(formatMoney(50000, suffix: false), '₫ 50.000');
    });

    test('handles zero', () {
      expect(formatMoney(0), '0 ₫');
    });
  });

  group('formatSigned', () {
    test('negative spending has minus sign', () {
      expect(formatSigned(50000, negative: true), '-50.000 ₫');
    });

    test('positive earning has plus sign', () {
      expect(formatSigned(200000, negative: false), '+200.000 ₫');
    });

    test('custom symbol is used', () {
      expect(formatSigned(1000, negative: true, symbol: 'đ'), '-1.000 đ');
    });
  });

  group('parseAmount', () {
    test('parses plain digits', () {
      expect(parseAmount('100000'), 100000);
    });

    test('strips separator dots', () {
      expect(parseAmount('100.000'), 100000);
    });

    test('strips commas', () {
      expect(parseAmount('1,000'), 1000);
    });

    test('returns 0 for empty input', () {
      expect(parseAmount(''), 0);
    });

    test('returns 0 for non-numeric input', () {
      expect(parseAmount('abc'), 0);
    });

    test('strips all non-digit characters', () {
      expect(parseAmount('₫ 50.000'), 50000);
    });
  });
}
