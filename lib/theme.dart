import 'package:flutter/material.dart';

const paper = Color(0xfff6f3ec),
    panel = Color(0xfffdfbf6),
    sidebar = Color(0xffeae3d8),
    line = Color(0xffded7cb),
    ink = Color(0xff51483f),
    muted = Color(0xff897e71),
    terracotta = Color(0xffa35b3d),
    sage = Color(0xff65806a);
const categoryColors = <String, Color>{
  'catholic': Color(0xff7851a2),
  'uni': Color(0xff2f699d),
  'family': Color(0xffb2594d),
  'friends': Color(0xff87630c),
  'exercise': Color(0xff3c7d56),
  'home': Color(0xff8c7866),
  'work': Color(0xff5d7386),
  'personal': Color(0xff7b7b76),
};
ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: paper,
  colorScheme: ColorScheme.fromSeed(seedColor: terracotta).copyWith(
    primary: terracotta,
    surface: panel,
    onSurface: ink,
    outline: line,
    secondary: sage,
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
