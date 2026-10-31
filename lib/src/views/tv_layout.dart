import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TvLayout extends InheritedWidget {
  final bool enabled;
  const TvLayout({super.key, required this.enabled, required super.child});
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TvLayout>()?.enabled ?? false;
  @override
  bool updateShouldNotify(TvLayout oldWidget) => enabled != oldWidget.enabled;
}

class TvFrame extends StatelessWidget {
  final bool television;
  final Widget child;
  final VoidCallback onBack;
  const TvFrame({
    super.key,
    required this.television,
    required this.child,
    required this.onBack,
  });
  @override
  Widget build(BuildContext context) => Builder(
    builder: (context) {
      final enabled = television;
      final base = Theme.of(context);
      final focusStyle = ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(56, 56)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.focused)
                ? Colors.white
                : Colors.transparent,
            width: 3,
          ),
        ),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? const Color(0x66555555)
              : null,
        ),
      );
      return TvLayout(
        enabled: enabled,
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
          },
          child: CallbackShortcuts(
            bindings: {
              if (enabled)
                const SingleActivator(LogicalKeyboardKey.escape): onBack,
            },
            child: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Theme(
                data: !enabled
                    ? base
                    : base.copyWith(
                        focusColor: const Color(0x66E50914),
                        textTheme: base.textTheme.apply(fontSizeFactor: 1.12),
                        filledButtonTheme: FilledButtonThemeData(
                          style:
                              base.filledButtonTheme.style?.merge(focusStyle) ??
                              focusStyle,
                        ),
                        outlinedButtonTheme: OutlinedButtonThemeData(
                          style: focusStyle,
                        ),
                        textButtonTheme: TextButtonThemeData(style: focusStyle),
                        iconButtonTheme: IconButtonThemeData(
                          style:
                              (base.iconButtonTheme.style ??
                                      const ButtonStyle())
                                  .merge(
                                    focusStyle.copyWith(
                                      iconSize: const WidgetStatePropertyAll(
                                        30,
                                      ),
                                      padding: const WidgetStatePropertyAll(
                                        EdgeInsets.all(14),
                                      ),
                                    ),
                                  ),
                        ),
                        inputDecorationTheme: base.inputDecorationTheme
                            .copyWith(
                              focusedBorder: const OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                            ),
                      ),
                child: child,
              ),
            ),
          ),
        ),
      );
    },
  );
}
