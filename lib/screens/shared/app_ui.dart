import 'package:flutter/material.dart';

/// ===============================
/// Design Tokens (Colors/Spacing)
/// ===============================
class AppColors {
  // Brand (change once, updates everywhere)
  static const Color brandA = Color(0xFF2563EB); // blue
  static const Color brandB = Color(0xFF06B6D4); // cyan

  // Surfaces
  static const Color background = Color(0xFFF6F7FB);
  static const Color surface = Colors.white;

  // Text
  static const Color textStrong = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  // UI
  static const Color borderSoft = Color(0x14000000); // subtle border
  static const Color danger = Color(0xFFEF4444);
}

/// Consistent spacing tokens
class AppSpacing {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Rounded corners
class AppRadii {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
}

/// Shadows
class AppShadows {
  static List<BoxShadow> soft({double strength = 0.10}) => [
        BoxShadow(
          blurRadius: 18,
          offset: const Offset(0, 10),
          color: Colors.black.withOpacity(strength),
        ),
      ];

  static List<BoxShadow> hover({double strength = 0.14}) => [
        BoxShadow(
          blurRadius: 22,
          offset: const Offset(0, 12),
          color: Colors.black.withOpacity(strength),
        ),
      ];
}

/// ===============================
/// Theme (use in MaterialApp)
/// ===============================
class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandA,
      brightness: Brightness.light,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
    );

    final t = base.textTheme;

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,

      /// AppBar defaults (you can still override per screen)
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textStrong,
      ),

      textTheme: t.copyWith(
        titleLarge: t.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.textStrong,
        ),
        titleMedium: t.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textStrong,
        ),
        bodyLarge: t.bodyLarge?.copyWith(
          color: AppColors.textStrong,
          height: 1.25,
        ),
        bodyMedium: t.bodyMedium?.copyWith(
          color: AppColors.textStrong,
          height: 1.25,
        ),
        bodySmall: t.bodySmall?.copyWith(
          color: AppColors.textMuted,
          height: 1.25,
        ),
      ),

      /// Cards
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: const BorderSide(color: AppColors.borderSoft),
        ),
      ),

      /// Filled buttons (recommended)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandA,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),

      /// ElevatedButton compatibility (if you still use ElevatedButton anywhere)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandA,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),

      /// Outlined buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textStrong,
          side: const BorderSide(color: AppColors.borderSoft),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),

      /// Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandA,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      /// Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.borderSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),

      /// Snackbars (optional but cleaner)
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textStrong,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
    );
  }
}

/// ===============================
/// Responsive Helpers
/// ===============================
class AppBreakpoints {
  static const double sm = 600;
  static const double md = 900;
  static const double lg = 1200;
}

/// Handy context helpers (navigation, snackbars, breakpoints)
extension AppContextX on BuildContext {
  Size get size => MediaQuery.sizeOf(this);
  double get w => size.width;

  bool get isSmUp => w >= AppBreakpoints.sm;
  bool get isMdUp => w >= AppBreakpoints.md;
  bool get isLgUp => w >= AppBreakpoints.lg;

  /// Your OLD method kept for compatibility
  int responsiveGridCount({int xs = 2, int md = 3, int lg = 4}) {
    if (isLgUp) return lg;
    if (isMdUp) return md;
    return xs;
  }

  /// NEW: matches the code you used in dashboard: context.gridCount(...)
  int gridCount({int xs = 2, int md = 3, int lg = 4}) {
    if (isLgUp) return lg;
    if (isMdUp) return md;
    return xs;
  }

  /// NEW: matches context.tileAspectRatio in your dashboard
  double get tileAspectRatio {
    if (isLgUp) return 1.60;
    if (isMdUp) return 1.45;
    return 1.25;
  }

  /// NEW: responsive page padding (web looks cleaner)
  EdgeInsets get pagePadding {
    if (isLgUp) return const EdgeInsets.all(24);
    if (isMdUp) return const EdgeInsets.all(20);
    return const EdgeInsets.all(16);
  }

  /// NEW: max content width (prevents super wide layout on web)
  double get contentMaxWidth {
    if (isLgUp) return 1100;
    if (isMdUp) return 900;
    return w;
  }

  void push(Widget page) =>
      Navigator.push(this, MaterialPageRoute(builder: (_) => page));

  void pushReplaceAll(Widget page) => Navigator.pushAndRemoveUntil(
        this,
        MaterialPageRoute(builder: (_) => page),
        (route) => false,
      );

  void pop<T extends Object?>([T? result]) => Navigator.pop(this, result);

  void snack(String msg) {
    ScaffoldMessenger.of(this).clearSnackBars();
    ScaffoldMessenger.of(this).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// ===============================
/// Reusable UI Widgets
/// ===============================

/// Header for consistent top sections:
/// - If backgroundImageAsset is provided -> uses that image (e.g. assets/images/top.jpg)
/// - Otherwise falls back to your blue/cyan gradient
class AppGradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing; // e.g. back/logout button
  final EdgeInsets? padding;
  final String? description;

  // ✅ optional background image to replace gradient
  final String? backgroundImageAsset;
  final BoxFit backgroundFit;
  final double overlayOpacity;

  const AppGradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding,
    this.description,
    this.backgroundImageAsset,
    this.backgroundFit = BoxFit.cover,
    this.overlayOpacity = 0.45,
  });

  @override
  Widget build(BuildContext context) {
    final innerPadding = padding ?? const EdgeInsets.fromLTRB(18, 18, 18, 16);

    return SafeArea(
      bottom: false,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppRadii.lg),
          bottomRight: Radius.circular(AppRadii.lg),
        ),
        child: SizedBox(
          width: double.infinity,
          child: Stack(
            children: [
              // Background
              Positioned.fill(
                child: backgroundImageAsset != null
                    ? Image.asset(
                        backgroundImageAsset!,
                        fit: backgroundFit,
                        filterQuality: FilterQuality.high,
                      )
                    : const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.brandA, AppColors.brandB],
                          ),
                        ),
                      ),
              ),

              // Overlay for readability
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(overlayOpacity),
                        Colors.black.withOpacity(overlayOpacity * 0.35),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: innerPadding,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (subtitle != null) ...[
                            Text(
                              subtitle!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (description != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              description!,
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 12),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hover/press scale wrapper (nice on Flutter Web too)
class AppHoverScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const AppHoverScale({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  State<AppHoverScale> createState() => _AppHoverScaleState();
}

class _AppHoverScaleState extends State<AppHoverScale> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.98 : (_hover ? 1.02 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          scale: scale,
          child: widget.child,
        ),
      ),
    );
  }
}

/// A consistent “action tile” card used for dashboards/menus
/// ✅ UPDATED: prevents mid-word breaking + better sizing
class AppActionTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const AppActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<AppActionTile> createState() => _AppActionTileState();
}

class _AppActionTileState extends State<AppActionTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final shadow = _hover ? AppShadows.hover() : AppShadows.soft();
    final isCompact = context.w < 380;

    final titleStyle = TextStyle(
      fontSize: isCompact ? 15 : 16,
      fontWeight: FontWeight.w900,
      color: AppColors.textStrong,
      height: 1.05,
    );

    final subtitleStyle = TextStyle(
      fontSize: isCompact ? 12.5 : 13,
      color: AppColors.textMuted,
      height: 1.2,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AppHoverScale(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.borderSoft),
            boxShadow: shadow,
          ),
          padding: EdgeInsets.all(isCompact ? 12 : AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: isCompact ? 48 : 54,
                    width: isCompact ? 48 : 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.brandA, AppColors.brandB],
                      ),
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 26),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: titleStyle,
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: subtitleStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Consistent page padding + max width for web (looks professional)
class AppPage extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const AppPage({
    super.key,
    required this.child,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final mw = maxWidth ?? context.contentMaxWidth;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mw),
        child: Padding(
          padding: context.pagePadding,
          child: child,
        ),
      ),
    );
  }
}
