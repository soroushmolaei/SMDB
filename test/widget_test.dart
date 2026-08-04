// `flutter create --platforms=windows .` runs on every CI build to
// (re)scaffold the Windows platform folder. As a side effect it also
// regenerates any file it considers "missing" from its default
// templates — including this one. The stock template references a
// `MyApp` class that has never existed in this project (the real root
// widget is `SmdbApp` in lib/main.dart), which made `flutter analyze`
// fail on every single run with "creation_with_non_type".
//
// Keeping a valid file here means `flutter create` finds it already
// present and leaves it alone instead of overwriting it with the
// mismatched template. This project doesn't have a test suite yet, so
// this is intentionally just a placeholder rather than real coverage.
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder', () {
    expect(1 + 1, 2);
  });
}
