import 'package:flutter/material.dart';

// monday.com Vibe light-theme tokens:
// https://github.com/mondaycom/vibe/blob/master/packages/style/src/themes/light-theme.scss
const paper = Color(0xfff6f7fb),
    panel = Color(0xffffffff),
    sidebar = Color(0xffeceff8),
    line = Color(0xffd0d4e4),
    ink = Color(0xff323338),
    muted = Color(0xff676879),
    primaryBlue = Color(0xff0073ea),
    successGreen = Color(0xff00854d),
    selectionColor = Color(0xffcce5ff),
    highlightColor = Color(0xfff0f7ff),
    uiBackground = Color(0xffe7e9ef),
    warningInk = Color(0xff8f6500),
    errorColor = Color(0xffd83a52);
const categoryColors = <String, Color>{
  'catholic': Color(0xff9d50dd),
  'uni': Color(0xff579bfc),
  'family': Color(0xfffdab3d),
  'friends': Color(0xffffcb00),
  'exercise': Color(0xff00c875),
  'home': Color(0xffc4c4c4),
  'work': Color(0xff0073ea),
  'personal': Color(0xffff6d3b),
};
ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: paper,
  colorScheme: ColorScheme.fromSeed(seedColor: primaryBlue).copyWith(
    primary: primaryBlue,
    onPrimary: Colors.white,
    primaryContainer: selectionColor,
    onPrimaryContainer: ink,
    surface: panel,
    surfaceTint: Colors.transparent,
    onSurface: ink,
    outline: line,
    secondary: successGreen,
    secondaryContainer: selectionColor,
    onSecondaryContainer: ink,
    error: errorColor,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: ink, fontSize: 14),
    bodySmall: TextStyle(color: muted, fontSize: 12),
    titleLarge: TextStyle(
      color: ink,
      fontSize: 22,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      color: ink,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
  ),
  dividerColor: line,
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: panel,
    isDense: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: line),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: ink,
      side: const BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
    ),
  ),
  snackBarTheme: const SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: ink,
  ),
  dialogTheme: DialogTheme(
    backgroundColor: panel,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
);

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.color = panel,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(12),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}
