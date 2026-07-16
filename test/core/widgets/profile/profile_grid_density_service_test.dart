import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vyooo/core/widgets/profile/profile_grid_density_service.dart';
import 'package:vyooo/screens/profile/profile_figma_tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProfileGridDensityService', () {
    test('load returns default when unset', () async {
      expect(
        await ProfileGridDensityService.load(),
        ProfileFigmaTokens.contentGridCrossAxisCount,
      );
    });

    test('save and load round-trip', () async {
      await ProfileGridDensityService.save(2);
      expect(await ProfileGridDensityService.load(), 2);
    });

    test('clampColumns enforces 1–3 range', () {
      expect(ProfileGridDensityService.clampColumns(0), 1);
      expect(ProfileGridDensityService.clampColumns(5), 3);
      expect(ProfileGridDensityService.clampColumns(2), 2);
    });

    test('save clamps out-of-range values', () async {
      await ProfileGridDensityService.save(99);
      expect(await ProfileGridDensityService.load(), 3);
    });
  });
}
