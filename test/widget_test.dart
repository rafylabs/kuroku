import 'package:flutter_test/flutter_test.dart';
import 'package:kotatsu/features/reader/providers/reader_provider.dart';

void main() {
  test('ReaderMode default is webtoon', () {
    const defaultMode = ReaderMode.webtoon;
    expect(defaultMode, ReaderMode.webtoon);
  });
}
