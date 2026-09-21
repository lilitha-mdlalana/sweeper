import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/core/theme/app_theme.dart';
import 'package:sweeper/core/theme/app_colors.dart';

void main() {
  testWidgets('AppTheme.light uses Material 3 and the Sweep background color',
      (WidgetTester tester) async {
    final theme = AppTheme.light;
    expect(theme.useMaterial3, isTrue);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.primary, AppColors.accent);
  });
}
