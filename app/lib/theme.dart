import 'package:material_ui/material_ui.dart';

/// Colors and text sizes for Vector. The app is read outdoors in direct
/// sunlight, so everything is high contrast and large.
class VxColors {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF141414);
  static const text = Color(0xFFF5F5F5);
  static const textDim = Color(0xFF9E9E9E);
  static const accent = Color(0xFF00E5FF);
  static const warning = Color(0xFFFFB300);
  static const danger = Color(0xFFFF3D3D);
  static const ok = Color(0xFF00E676);
}

ThemeData buildVectorTheme() {
  const scheme = ColorScheme.dark(
    primary: VxColors.accent,
    onPrimary: VxColors.background,
    secondary: VxColors.accent,
    surface: VxColors.surface,
    onSurface: VxColors.text,
    error: VxColors.danger,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: VxColors.background,
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: VxColors.text),
      displayMedium: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: VxColors.text),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: VxColors.text),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: VxColors.text),
      bodyLarge: TextStyle(fontSize: 20, color: VxColors.text),
      bodyMedium: TextStyle(fontSize: 18, color: VxColors.text),
      labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    ),
  );
}
