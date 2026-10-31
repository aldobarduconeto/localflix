import 'dart:ui';
import 'package:flutter/material.dart';

/// Tema Escuro puro otimizado para telas OLED com acabamento Liquid Glass.
/// Fundo #000000 absoluto garantindo desligamento de pixels OLED e economia de energia.
final liquidGlassOledTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF000000),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFFE50914),
    brightness: Brightness.dark,
    surface: const Color(0xFF0C0C12),
  ).copyWith(
    onSurface: Colors.white,
    primary: const Color(0xFFE50914),
    surfaceContainer: const Color(0xFF0E0E16),
    surfaceContainerHigh: const Color(0xFF161622),
    outline: const Color(0x28FFFFFF),
    outlineVariant: const Color(0x16FFFFFF),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: Colors.white,
      letterSpacing: -0.5,
    ),
    iconTheme: IconThemeData(color: Colors.white),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    color: const Color(0xFF0C0C12),
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0x24FFFFFF), width: 1),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: const Color(0xFF0A0A10),
    surfaceTintColor: Colors.transparent,
    elevation: 24,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: Color(0x2AFFFFFF), width: 1.2),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(EdgeInsets.all(12)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? Colors.transparent
            : states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)
            ? const Color(0x33FFFFFF)
            : const Color(0x14FFFFFF),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? Colors.white24
            : Colors.white,
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.focused)
              ? Colors.white
              : const Color(0x1EFFFFFF),
          width: 1,
        ),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      foregroundColor: Colors.white,
      side: const BorderSide(color: Color(0x35FFFFFF)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      foregroundColor: const Color(0xFFFF5263),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 48),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      backgroundColor: const Color(0xFFE50914),
      foregroundColor: Colors.white,
      elevation: 4,
      shadowColor: const Color(0x66E50914),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: const Color(0xFF040406),
    surfaceTintColor: Colors.transparent,
    indicatorColor: const Color(0xFF4C101A),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(color: Colors.white);
      }
      return const IconThemeData(color: Colors.white54);
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        );
      }
      return const TextStyle(color: Colors.white54, fontSize: 12);
    }),
  ),
  navigationRailTheme: const NavigationRailThemeData(
    backgroundColor: Color(0xFF040406),
    indicatorColor: Color(0xFF4C101A),
    selectedIconTheme: IconThemeData(color: Colors.white),
    unselectedIconTheme: IconThemeData(color: Colors.white54),
    selectedLabelTextStyle: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
    ),
    unselectedLabelTextStyle: TextStyle(color: Colors.white54),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF0E0E16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0x2EFFFFFF)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0x22FFFFFF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE50914), width: 1.5),
    ),
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: const Color(0xFF12121A),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0x28FFFFFF)),
    ),
  ),
  chipTheme: const ChipThemeData(
    backgroundColor: Color(0xFF101018),
    side: BorderSide(color: Color(0x24FFFFFF)),
    shape: StadiumBorder(),
    labelStyle: TextStyle(color: Colors.white70),
  ),
  dividerTheme: const DividerThemeData(color: Color(0x18FFFFFF)),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: Color(0xFFE50914),
    linearTrackColor: Color(0x26FFFFFF),
  ),
  sliderTheme: const SliderThemeData(
    activeTrackColor: Color(0xFFE50914),
    thumbColor: Colors.white,
    inactiveTrackColor: Color(0x28FFFFFF),
    trackHeight: 4,
    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
    overlayShape: RoundSliderOverlayShape(overlayRadius: 18),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return Colors.white;
      return Colors.white54;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return const Color(0xFFE50914);
      return const Color(0x22FFFFFF);
    }),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      side: const WidgetStatePropertyAll(
        BorderSide(color: Color(0x28FFFFFF)),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return const Color(0xFFE50914);
        return const Color(0x0EFFFFFF);
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return Colors.white70;
      }),
    ),
  ),
);

/// Tema Claro inspirado em Liquid Glass: superfícies translúcidas, tons cristalinos e alto contraste.
final liquidGlassLightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFF2F4F8),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFFE50914),
    brightness: Brightness.light,
    surface: const Color(0xFFFFFFFF),
  ).copyWith(
    onSurface: const Color(0xFF11141A),
    primary: const Color(0xFFE50914),
    surfaceContainer: const Color(0xFFF7F9FC),
    surfaceContainerHigh: const Color(0xFFEDF1F7),
    outline: const Color(0x1F000000),
    outlineVariant: const Color(0x10000000),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: Color(0xFF11141A),
      letterSpacing: -0.5,
    ),
    iconTheme: IconThemeData(color: Color(0xFF11141A)),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    color: const Color(0xFFFFFFFF),
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0x15000000), width: 1),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: const Color(0xFFFFFFFF),
    surfaceTintColor: Colors.transparent,
    elevation: 20,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: Color(0x18000000), width: 1.2),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(EdgeInsets.all(12)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? Colors.transparent
            : states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)
            ? const Color(0x16000000)
            : const Color(0x0A000000),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? Colors.black26
            : const Color(0xFF11141A),
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.focused)
              ? const Color(0xFF11141A)
              : const Color(0x12000000),
          width: 1,
        ),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      foregroundColor: const Color(0xFF11141A),
      side: const BorderSide(color: Color(0x28000000)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      foregroundColor: const Color(0xFFD60813),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 48),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      backgroundColor: const Color(0xFFE50914),
      foregroundColor: Colors.white,
      elevation: 4,
      shadowColor: const Color(0x40E50914),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: const Color(0xFFFCFDFF),
    surfaceTintColor: Colors.transparent,
    indicatorColor: const Color(0xFFFFDDE0),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(color: Color(0xFFD60813));
      }
      return const IconThemeData(color: Color(0xFF6B7280));
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const TextStyle(
          color: Color(0xFF11141A),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        );
      }
      return const TextStyle(color: Color(0xFF6B7280), fontSize: 12);
    }),
  ),
  navigationRailTheme: const NavigationRailThemeData(
    backgroundColor: Color(0xFFFCFDFF),
    indicatorColor: Color(0xFFFFDDE0),
    selectedIconTheme: IconThemeData(color: Color(0xFFD60813)),
    unselectedIconTheme: IconThemeData(color: Color(0xFF6B7280)),
    selectedLabelTextStyle: TextStyle(
      color: Color(0xFF11141A),
      fontWeight: FontWeight.w700,
    ),
    unselectedLabelTextStyle: TextStyle(color: Color(0xFF6B7280)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFFFFFFF),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0x1F000000)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0x18000000)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE50914), width: 1.5),
    ),
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: const Color(0xFFFFFFFF),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0x18000000)),
    ),
  ),
  chipTheme: const ChipThemeData(
    backgroundColor: Color(0xFFFFFFFF),
    side: BorderSide(color: Color(0x1A000000)),
    shape: StadiumBorder(),
    labelStyle: TextStyle(color: Color(0xFF374151)),
  ),
  dividerTheme: const DividerThemeData(color: Color(0x14000000)),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: Color(0xFFE50914),
    linearTrackColor: Color(0x18000000),
  ),
  sliderTheme: const SliderThemeData(
    activeTrackColor: Color(0xFFE50914),
    thumbColor: Color(0xFFE50914),
    inactiveTrackColor: Color(0x1F000000),
    trackHeight: 4,
    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
    overlayShape: RoundSliderOverlayShape(overlayRadius: 18),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return Colors.white;
      return const Color(0xFF6B7280);
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return const Color(0xFFE50914);
      return const Color(0x1A000000);
    }),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      side: const WidgetStatePropertyAll(
        BorderSide(color: Color(0x1E000000)),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return const Color(0xFFE50914);
        return const Color(0x08000000);
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return const Color(0xFF374151);
      }),
    ),
  ),
);

/// Mantido para compatibilidade com qualquer referência legada
final appTheme = liquidGlassOledTheme;

/// Componente de container com acabamento Liquid Glass (vidro translúcido, desfoque e reflexos sutis).
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final double blur;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 22,
    this.borderColor,
    this.backgroundColor,
    this.onTap,
    this.blur = 14,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBorder = borderColor ??
        (isDark ? const Color(0x26FFFFFF) : const Color(0x1A000000));
    final defaultBg = backgroundColor ??
        (isDark ? const Color(0x18FFFFFF) : const Color(0xD9FFFFFF));

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: defaultBg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: defaultBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0x33000000)
                    : const Color(0x0D000000),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: content,
        ),
      );
    }
    return content;
  }
}

/// Tag decorativa no formato pílula Liquid Glass
class LiquidGlassBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;

  const LiquidGlassBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? const Color(0xFFE50914);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: effectiveColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: effectiveColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: effectiveColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
