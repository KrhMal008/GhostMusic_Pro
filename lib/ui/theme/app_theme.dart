import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppSpacing {
  static const double zero = 0;
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 12;
  static const double xxl = 14;
  static const double xxxl = 16;

  static const double section1 = 18;
  static const double section2 = 20;
  static const double section3 = 24;
  static const double section4 = 28;
  static const double section5 = 32;

  static const double hero1 = 40;
  static const double hero2 = 48;
  static const double hero3 = 56;
  static const double hero4 = 64;
  static const double hero5 = 72;
  static const double hero6 = 80;

  static const double screenHorizontal = 16;
  static const double screenVertical = 14;
  static const double cardPadding = 14;
  static const double cardPaddingLarge = 18;
  static const double listItemVertical = 12;
  static const double listItemHorizontal = 16;
  static const double buttonHorizontal = 20;
  static const double buttonVertical = 14;
  static const double chipHorizontal = 12;
  static const double chipVertical = 6;
  static const double inputHorizontal = 16;
  static const double inputVertical = 14;
  static const double iconTextGap = 8;
  static const double rowGap = 10;
  static const double columnGap = 16;
  static const double bottomNavPadding = 90;
  static const double bottomPlayerPadding = 160;

  static EdgeInsets get screenPadding => const EdgeInsets.symmetric(
        horizontal: screenHorizontal,
        vertical: screenVertical,
      );
  static EdgeInsets get screenHorizontalPadding =>
      const EdgeInsets.symmetric(horizontal: screenHorizontal);
  static EdgeInsets get cardInsets => const EdgeInsets.all(cardPadding);
  static EdgeInsets get cardLargeInsets => const EdgeInsets.all(cardPaddingLarge);
  static EdgeInsets get listItemInsets => const EdgeInsets.symmetric(
        horizontal: listItemHorizontal,
        vertical: listItemVertical,
      );
  static EdgeInsets get buttonInsets => const EdgeInsets.symmetric(
        horizontal: buttonHorizontal,
        vertical: buttonVertical,
      );
  static EdgeInsets get chipInsets => const EdgeInsets.symmetric(
        horizontal: chipHorizontal,
        vertical: chipVertical,
      );
  static EdgeInsets get inputInsets => const EdgeInsets.symmetric(
        horizontal: inputHorizontal,
        vertical: inputVertical,
      );
  static EdgeInsets get none => EdgeInsets.zero;
}

abstract final class AppRadius {
  static const double none = 0;
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 12;
  static const double xxl = 14;
  static const double xxxl = 16;

  static const double card = 18;
  static const double modal = 20;
  static const double sheet = 22;
  static const double panel = 24;
  static const double fullscreen = 26;
  static const double max = 28;
  static const double hero = 32;
  static const double pill = 999;

  static const double artworkSmall = 10;
  static const double artworkLarge = 20;
  static const double miniPlayer = 16;
  static const double tabBar = 22;
  static const double progressBar = 4;
  static const double sliderThumb = 999;
  static const double avatar = 999;

  static BorderRadius get cardBorder => BorderRadius.circular(card);
  static BorderRadius get modalBorder => BorderRadius.circular(modal);
  static BorderRadius get sheetBorder => const BorderRadius.vertical(top: Radius.circular(sheet));
  static BorderRadius get panelBorder => BorderRadius.circular(panel);
  static BorderRadius get thumbnailBorder => BorderRadius.circular(artworkSmall);
  static BorderRadius get artworkBorder => BorderRadius.circular(artworkLarge);
  static BorderRadius get miniPlayerBorder => BorderRadius.circular(miniPlayer);
  static BorderRadius get tabBarBorder => BorderRadius.circular(tabBar);
  static BorderRadius get pillBorder => BorderRadius.circular(pill);
  static BorderRadius get inputBorder => BorderRadius.circular(md);
  static BorderRadius get chipBorder => BorderRadius.circular(sm);
  static BorderRadius get noneBorder => BorderRadius.zero;

  static BorderRadius topOnly(double radius) =>
      BorderRadius.vertical(top: Radius.circular(radius));
  static BorderRadius bottomOnly(double radius) =>
      BorderRadius.vertical(bottom: Radius.circular(radius));
  static BorderRadius leftOnly(double radius) =>
      BorderRadius.horizontal(left: Radius.circular(radius));
  static BorderRadius rightOnly(double radius) =>
      BorderRadius.horizontal(right: Radius.circular(radius));
}

abstract final class AppDuration {
  static const Duration zero = Duration.zero;
  static const Duration instant = Duration(milliseconds: 50);
  static const Duration fastest = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration modal = Duration(milliseconds: 350);
  static const Duration smooth = Duration(milliseconds: 400);
  static const Duration complex = Duration(milliseconds: 450);
  static const Duration hero = Duration(milliseconds: 500);
  static const Duration slowest = Duration(milliseconds: 600);
  static const Duration gradient = Duration(milliseconds: 700);
  static const Duration page = Duration(milliseconds: 800);
  static const Duration long = Duration(milliseconds: 1000);
  static const Duration veryLong = Duration(milliseconds: 1500);
  static const Duration max = Duration(milliseconds: 2000);

  static const Duration progressUpdate = Duration(milliseconds: 100);
  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const Duration shimmerLoop = Duration(milliseconds: 1500);
  static const Duration pulse = Duration(milliseconds: 1000);
  static const Duration gradientShift = Duration(milliseconds: 3000);
}

abstract final class AppCurves {
  static const Curve standard = Curves.easeInOutCubic;
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve transition = Curves.easeInOut;
  static const Curve spring = Curves.easeOutBack;
  static const Curve springStrong = Curves.elasticOut;
  static const Curve bounce = Curves.bounceOut;
  static const Curve overshoot = Curves.easeOutBack;
  static const Curve modal = Curves.easeInOutQuart;
  static const Curve hero = Curves.fastOutSlowIn;
  static const Curve gradient = Curves.easeInOutSine;
  static const Curve scale = Curves.easeOutQuint;
  static const Curve fade = Curves.easeInOutQuad;
  static const Curve slide = Curves.easeOutQuart;
  static const Curve rotate = Curves.easeInOutCubic;
  static const Curve linear = Curves.linear;
  static const Curve decelerate = Curves.decelerate;
  static const Curve iosPush = Curves.easeOut;
  static const Curve iosPop = Curves.easeIn;
  static const Curve iosSheetPresent = Curves.easeOutExpo;
  static const Curve iosSheetDismiss = Curves.easeInExpo;
  static const Curve iosKeyboardShow = Curves.easeOutQuint;
  static const Curve iosKeyboardHide = Curves.easeInQuint;
}

abstract final class AppShadows {
  static List<BoxShadow> get none => const [];

  static List<BoxShadow> get xs => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get sm => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get md => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get lg => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.14),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get xl => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.16),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get xxl => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.20),
          blurRadius: 32,
          spreadRadius: -4,
          offset: const Offset(0, 16),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.14),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> colored(Color color, {double intensity = 0.4}) => [
        BoxShadow(
          color: color.withValues(alpha: intensity * 0.8),
          blurRadius: 24,
          spreadRadius: -8,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: color.withValues(alpha: intensity * 0.5),
          blurRadius: 48,
          spreadRadius: -12,
          offset: const Offset(0, 16),
        ),
      ];

  static List<BoxShadow> artworkGlow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.35),
          blurRadius: 32,
          spreadRadius: -8,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: color.withValues(alpha: 0.20),
          blurRadius: 64,
          spreadRadius: -16,
          offset: const Offset(0, 24),
        ),
      ];

  static List<BoxShadow> primary(Color primaryColor) => [
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.30),
          blurRadius: 16,
          spreadRadius: -4,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get miniPlayer => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.20),
          blurRadius: 20,
          spreadRadius: -4,
          offset: const Offset(0, -4),
        ),
      ];

  static List<BoxShadow> get tabBar => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 16,
          spreadRadius: -2,
          offset: const Offset(0, -2),
        ),
      ];

  static List<BoxShadow> get sheet => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 32,
          spreadRadius: -8,
          offset: const Offset(0, -8),
        ),
      ];

  static List<Shadow> textGlow(Color color, {double blur = 8}) => [
        Shadow(color: color.withValues(alpha: 0.5), blurRadius: blur),
      ];
}

abstract final class AppBlur {
  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 22;
  static const double xl = 30;
  static const double xxl = 40;
  static const double max = 60;

  static const double miniPlayer = 20;
  static const double tabBar = 18;
  static const double modalBackground = 50;
  static const double artworkBackground = 80;
  static const double navBar = 24;
  static const double contextMenu = 30;

  static ImageFilter get thinGlass => ImageFilter.blur(sigmaX: md, sigmaY: md);
  static ImageFilter get regularGlass => ImageFilter.blur(sigmaX: lg, sigmaY: lg);
  static ImageFilter get thickGlass => ImageFilter.blur(sigmaX: xl, sigmaY: xl);
  static ImageFilter get frostedGlass => ImageFilter.blur(sigmaX: xxl, sigmaY: xxl);
  static ImageFilter get backgroundFilter => ImageFilter.blur(sigmaX: max, sigmaY: max);
  static ImageFilter custom(double sigma) => ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
}

abstract final class AppOpacity {
  static const double transparent = 0.0;
  static const double faint = 0.04;
  static const double subtle = 0.08;
  static const double light = 0.12;
  static const double soft = 0.16;
  static const double gentle = 0.20;
  static const double medium = 0.30;
  static const double moderate = 0.40;
  static const double half = 0.50;
  static const double strong = 0.60;
  static const double heavy = 0.70;
  static const double dense = 0.80;
  static const double thick = 0.90;
  static const double solid = 0.95;
  static const double opaque = 1.0;

  static const double disabled = 0.38;
  static const double secondaryText = 0.68;
  static const double tertiaryText = 0.46;
  static const double quaternaryText = 0.30;
  static const double border = 0.12;
  static const double divider = 0.10;
  static const double hover = 0.08;
  static const double pressed = 0.12;
  static const double focus = 0.16;
  static const double selected = 0.16;
  static const double scrim = 0.60;
  static const double glassTint = 0.70;
  static const double glassBorder = 0.15;
}

abstract final class AppBorders {
  static const double thin = 0.5;
  static const double normal = 1.0;
  static const double thick = 1.5;
  static const double heavy = 2.0;

  static Border get none => Border.all(color: Colors.transparent, width: 0);

  static Border subtle(ColorScheme cs) => Border.all(
        color: cs.onSurface.withValues(alpha: AppOpacity.border),
        width: thin,
      );

  static Border standard(ColorScheme cs) => Border.all(
        color: cs.onSurface.withValues(alpha: AppOpacity.border),
        width: normal,
      );

  static Border glass(ColorScheme cs) => Border.all(
        color: cs.onSurface.withValues(alpha: AppOpacity.glassBorder),
        width: thin,
      );

  static Border primary(ColorScheme cs) => Border.all(color: cs.primary, width: normal);

  static Border focus(ColorScheme cs) => Border.all(color: cs.primary, width: thick);

  static Border error(ColorScheme cs) => Border.all(color: cs.error, width: normal);

  static Border dividerTop(ColorScheme cs) => Border(
        top: BorderSide(
          color: cs.onSurface.withValues(alpha: AppOpacity.divider),
          width: thin,
        ),
      );

  static Border dividerBottom(ColorScheme cs) => Border(
        bottom: BorderSide(
          color: cs.onSurface.withValues(alpha: AppOpacity.divider),
          width: thin,
        ),
      );

  static BorderSide subtleSide(ColorScheme cs) => BorderSide(
        color: cs.onSurface.withValues(alpha: AppOpacity.border),
        width: thin,
      );

  static BorderSide glassSide(ColorScheme cs) => BorderSide(
        color: cs.onSurface.withValues(alpha: AppOpacity.glassBorder),
        width: thin,
      );

  static BorderSide primarySide(ColorScheme cs) => BorderSide(color: cs.primary, width: normal);
}

abstract final class AppGradients {
  static LinearGradient get appBackground => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF0A0A0C),
          const Color(0xFF0A0A0C),
          const Color(0xFF0F0F12),
        ],
        stops: const [0.0, 0.5, 1.0],
      );

  static LinearGradient get libraryBackground => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF0D0D10), const Color(0xFF08080A)],
      );

  static LinearGradient get playerDefault => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF1A1A2E),
          const Color(0xFF16213E),
          const Color(0xFF0F0F1A),
        ],
        stops: const [0.0, 0.5, 1.0],
      );

  static LinearGradient playerBackground(Color dominantColor) {
    final hsl = HSLColor.fromColor(dominantColor);
    final dark = hsl
        .withLightness((hsl.lightness * 0.15).clamp(0.02, 0.12))
        .withSaturation((hsl.saturation * 0.7).clamp(0.1, 0.5))
        .toColor();
    final medium = hsl
        .withLightness((hsl.lightness * 0.25).clamp(0.05, 0.18))
        .withSaturation((hsl.saturation * 0.8).clamp(0.15, 0.6))
        .toColor();
    final light = hsl
        .withLightness((hsl.lightness * 0.35).clamp(0.08, 0.25))
        .withSaturation((hsl.saturation * 0.9).clamp(0.2, 0.7))
        .toColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [light, medium, dark],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  static RadialGradient artworkGlow(Color color) => RadialGradient(
        center: Alignment.center,
        radius: 1.5,
        colors: [
          color.withValues(alpha: 0.30),
          color.withValues(alpha: 0.15),
          color.withValues(alpha: 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.6, 1.0],
      );

  static LinearGradient glassThin(ColorScheme cs) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          cs.surface.withValues(alpha: 0.08),
          cs.surface.withValues(alpha: 0.04),
          cs.surface.withValues(alpha: 0.02),
        ],
        stops: const [0.0, 0.5, 1.0],
      );

  static LinearGradient glassRegular(ColorScheme cs) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          cs.surface.withValues(alpha: 0.14),
          cs.surface.withValues(alpha: 0.10),
          cs.surface.withValues(alpha: 0.06),
        ],
        stops: const [0.0, 0.5, 1.0],
      );

  static LinearGradient glassThick(ColorScheme cs) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          cs.surface.withValues(alpha: 0.22),
          cs.surface.withValues(alpha: 0.16),
          cs.surface.withValues(alpha: 0.10),
        ],
        stops: const [0.0, 0.5, 1.0],
      );

  static LinearGradient get fadeTop => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.60),
          Colors.black.withValues(alpha: 0.30),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      );

  static LinearGradient get fadeBottom => LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.black.withValues(alpha: 0.70),
          Colors.black.withValues(alpha: 0.35),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      );

  static LinearGradient get scrim => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.40),
          Colors.black.withValues(alpha: 0.60),
        ],
      );

  static LinearGradient shimmer(ColorScheme cs) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          cs.surface.withValues(alpha: 0.0),
          cs.surface.withValues(alpha: 0.15),
          cs.surface.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      );

  static const List<List<Color>> artworkPlaceholders = [
    [Color(0xFF5B2CFF), Color(0xFF00D4FF)],
    [Color(0xFF7C3AED), Color(0xFF22C55E)],
    [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
    [Color(0xFFF43F5E), Color(0xFF8B5CF6)],
    [Color(0xFF10B981), Color(0xFF3B82F6)],
    [Color(0xFFEAB308), Color(0xFFFB7185)],
    [Color(0xFFEC4899), Color(0xFF8B5CF6)],
    [Color(0xFF14B8A6), Color(0xFF6366F1)],
  ];

  static LinearGradient artworkPlaceholder(int seed) {
    final index = seed.abs() % artworkPlaceholders.length;
    final colors = artworkPlaceholders[index];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [colors[0].withValues(alpha: 0.85), colors[1].withValues(alpha: 0.70)],
    );
  }
}

abstract final class AppColorsDark {
  static const Color primary = Color(0xFF0A84FF);
  static const Color primaryHover = Color(0xFF409CFF);
  static const Color primaryPressed = Color(0xFF0060DF);
  static const Color primaryMuted = Color(0xFF0A3D6E);
  static const Color primarySubtle = Color(0xFF0A2540);

  static const Color background = Color(0xFF000000);
  static const Color backgroundElevated = Color(0xFF0A0A0C);
  static const Color backgroundSecondary = Color(0xFF0F0F12);

  static const Color surface = Color(0xFF0F0F12);
  static const Color surfaceElevated = Color(0xFF1C1C1E);
  static const Color surfaceSecondary = Color(0xFF2C2C2E);
  static const Color surfaceTertiary = Color(0xFF3A3A3C);
  static const Color surfaceQuaternary = Color(0xFF48484A);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFEBEBF5);
  static const Color textTertiary = Color(0xFF8E8E93);
  static const Color textQuaternary = Color(0xFF636366);
  static const Color textQuinary = Color(0xFF48484A);

  static const Color success = Color(0xFF30D158);
  static const Color successSubtle = Color(0xFF0D3D1F);
  static const Color warning = Color(0xFFFF9F0A);
  static const Color warningSubtle = Color(0xFF3D2D0A);
  static const Color error = Color(0xFFFF453A);
  static const Color errorSubtle = Color(0xFF3D1411);
  static const Color info = Color(0xFF64D2FF);
  static const Color infoSubtle = Color(0xFF0A2D3D);

  static const Color glassTint = Color(0xFF1C1C1E);
  static const Color glassBorder = Color(0xFF38383A);
  static const Color overlay = Color(0x99000000);
  static const Color overlayHeavy = Color(0xCC000000);
  static const Color overlayLight = Color(0x66000000);

  static const Color divider = Color(0xFF38383A);
  static const Color dividerSubtle = Color(0xFF2C2C2E);
  static const Color dividerStrong = Color(0xFF48484A);

  static const Color highlight = Color(0x1AFFFFFF);
  static const Color ripple = Color(0x14FFFFFF);
  static const Color hover = Color(0x0DFFFFFF);
  static const Color selected = Color(0x29FFFFFF);
  static const Color focused = Color(0xFF0A84FF);

  static const Color nowPlaying = Color(0xFF30D158);
  static const Color shuffleActive = Color(0xFF0A84FF);
  static const Color repeatActive = Color(0xFF0A84FF);
  static const Color favorite = Color(0xFFFF375F);
  static const Color waveformActive = Color(0xFF0A84FF);
  static const Color waveformInactive = Color(0xFF48484A);
  static const Color progressBuffered = Color(0xFF48484A);

  static const Color playerGradientStart = Color(0xFF1A1A2E);
  static const Color playerGradientMiddle = Color(0xFF16213E);
  static const Color playerGradientEnd = Color(0xFF0F0F1A);

  static List<Color> get playerGradient =>
      [playerGradientStart, playerGradientMiddle, playerGradientEnd];
  static List<Color> get glassGradient => [
        glassTint.withValues(alpha: 0.70),
        glassTint.withValues(alpha: 0.50),
        glassTint.withValues(alpha: 0.30),
      ];
}

abstract final class AppColorsLight {
  static const Color primary = Color(0xFF007AFF);
  static const Color primaryHover = Color(0xFF0056B3);
  static const Color primaryPressed = Color(0xFF004799);
  static const Color primaryMuted = Color(0xFFB3D7FF);
  static const Color primarySubtle = Color(0xFFE5F2FF);

  static const Color background = Color(0xFFF2F2F7);
  static const Color backgroundElevated = Color(0xFFFFFFFF);
  static const Color backgroundSecondary = Color(0xFFE5E5EA);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF2F2F7);
  static const Color surfaceTertiary = Color(0xFFE5E5EA);
  static const Color surfaceQuaternary = Color(0xFFD1D1D6);

  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF3C3C43);
  static const Color textTertiary = Color(0xFF8E8E93);
  static const Color textQuaternary = Color(0xFFC7C7CC);
  static const Color textQuinary = Color(0xFFD1D1D6);

  static const Color success = Color(0xFF34C759);
  static const Color successSubtle = Color(0xFFD4F5DD);
  static const Color warning = Color(0xFFFF9500);
  static const Color warningSubtle = Color(0xFFFFEBD0);
  static const Color error = Color(0xFFFF3B30);
  static const Color errorSubtle = Color(0xFFFFD9D7);
  static const Color info = Color(0xFF5AC8FA);
  static const Color infoSubtle = Color(0xFFD6F2FE);

  static const Color glassTint = Color(0xFFF9F9F9);
  static const Color glassBorder = Color(0xFFE5E5EA);
  static const Color overlay = Color(0x4D000000);
  static const Color overlayHeavy = Color(0x80000000);
  static const Color overlayLight = Color(0x26000000);

  static const Color divider = Color(0xFFD1D1D6);
  static const Color dividerSubtle = Color(0xFFE5E5EA);
  static const Color dividerStrong = Color(0xFFC7C7CC);

  static const Color highlight = Color(0x14000000);
  static const Color ripple = Color(0x0A000000);
  static const Color hover = Color(0x08000000);
  static const Color selected = Color(0x1A000000);
  static const Color focused = Color(0xFF007AFF);

  static const Color nowPlaying = Color(0xFF34C759);
  static const Color shuffleActive = Color(0xFF007AFF);
  static const Color repeatActive = Color(0xFF007AFF);
  static const Color favorite = Color(0xFFFF2D55);
  static const Color waveformActive = Color(0xFF007AFF);
  static const Color waveformInactive = Color(0xFFD1D1D6);
  static const Color progressBuffered = Color(0xFFD1D1D6);

  static const Color playerGradientStart = Color(0xFFE8E8ED);
  static const Color playerGradientMiddle = Color(0xFFF5F5F7);
  static const Color playerGradientEnd = Color(0xFFFFFFFF);

  static List<Color> get playerGradient =>
      [playerGradientStart, playerGradientMiddle, playerGradientEnd];
  static List<Color> get glassGradient => [
        glassTint.withValues(alpha: 0.85),
        glassTint.withValues(alpha: 0.70),
        glassTint.withValues(alpha: 0.55),
      ];
}

abstract final class AppTypography {
  static TextStyle largeTitle(Color color) => TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        height: 1.08,
        color: color,
      );

  static TextStyle largeTitleRegular(Color color) => TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.4,
        height: 1.08,
        color: color,
      );

  static TextStyle title1(Color color) => TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.10,
        color: color,
      );

  static TextStyle title1Regular(Color color) => TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.4,
        height: 1.10,
        color: color,
      );

  static TextStyle title2(Color color) => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.12,
        color: color,
      );

  static TextStyle title2Regular(Color color) => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.3,
        height: 1.12,
        color: color,
      );

  static TextStyle title3(Color color) => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.15,
        color: color,
      );

  static TextStyle title3Regular(Color color) => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
        height: 1.15,
        color: color,
      );

  static TextStyle headline(Color color) => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.18,
        color: color,
      );

  static TextStyle headlineItalic(Color color) => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        letterSpacing: -0.1,
        height: 1.18,
        color: color,
      );

  static TextStyle body(Color color) => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.29,
        color: color,
      );

  static TextStyle bodyMedium(Color color) => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.29,
        color: color,
      );

  static TextStyle bodySemibold(Color color) => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.29,
        color: color,
      );

  static TextStyle bodyItalic(Color color) => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        letterSpacing: 0,
        height: 1.29,
        color: color,
      );

  static TextStyle callout(Color color) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.25,
        color: color,
      );

  static TextStyle calloutRegular(Color color) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.25,
        color: color,
      );

  static TextStyle calloutSemibold(Color color) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.25,
        color: color,
      );

  static TextStyle subheadline(Color color) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.20,
        color: color,
      );

  static TextStyle subheadlineRegular(Color color) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.20,
        color: color,
      );

  static TextStyle subheadlineSemibold(Color color) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.20,
        color: color,
      );

  static TextStyle footnote(Color color) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.18,
        color: color,
      );

  static TextStyle footnoteRegular(Color color) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.18,
        color: color,
      );

  static TextStyle footnoteSemibold(Color color) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.18,
        color: color,
      );

  static TextStyle caption1(Color color) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.16,
        color: color,
      );

  static TextStyle caption1Regular(Color color) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.16,
        color: color,
      );

  static TextStyle caption1Semibold(Color color) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.16,
        color: color,
      );

  static TextStyle caption2(Color color) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.13,
        color: color,
      );

  static TextStyle caption2Regular(Color color) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        height: 1.13,
        color: color,
      );

  static TextStyle caption2Semibold(Color color) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.13,
        color: color,
      );

  static TextStyle playerTime(Color color) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
        letterSpacing: 0.5,
        height: 1.0,
        color: color,
      );

  static TextStyle playerTimeLarge(Color color) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
        letterSpacing: 0.5,
        height: 1.0,
        color: color,
      );

  static TextStyle trackTitle(Color color) => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.15,
        color: color,
      );

  static TextStyle trackTitleLarge(Color color) => TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.12,
        color: color,
      );

  static TextStyle trackArtist(Color color) => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.20,
        color: color,
      );

  static TextStyle trackArtistLarge(Color color) => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.1,
        height: 1.18,
        color: color,
      );

  static TextStyle tabLabel(Color color) => TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.10,
        color: color,
      );

  static TextStyle navTitle(Color color) => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.18,
        color: color,
      );

  static TextStyle button(Color color) => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.18,
        color: color,
      );

  static TextStyle buttonSmall(Color color) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.15,
        color: color,
      );

  static TextStyle badge(Color color) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1.0,
        color: color,
      );

  static TextStyle searchPlaceholder(Color color) => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.29,
        color: color,
      );

  static TextStyle queueNumber(Color color) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
        letterSpacing: 0,
        height: 1.0,
        color: color,
      );

  static TextStyle shortcut(Color color) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
        letterSpacing: 0.5,
        height: 1.0,
        color: color,
      );
}

abstract final class AppIconSize {
  static const double xxs = 12;
  static const double xs = 14;
  static const double sm = 16;
  static const double smd = 18;
  static const double md = 20;
  static const double mdl = 22;
  static const double lg = 24;
  static const double xl = 28;
  static const double xxl = 32;
  static const double xxxl = 36;

  static const double hero1 = 40;
  static const double hero2 = 44;
  static const double hero3 = 48;
  static const double hero4 = 56;
  static const double hero5 = 64;

  static const double tabBar = 22;
  static const double navBar = 24;
  static const double playerSmall = 24;
  static const double playerMedium = 28;
  static const double playerLarge = 32;
  static const double playerMain = 38;
  static const double listItem = 20;
  static const double menu = 20;
  static const double alert = 24;
  static const double emptyState = 48;
  static const double errorState = 64;
}

abstract final class AppHitTarget {
  static const double xs = 36;
  static const double sm = 40;
  static const double min = 44;
  static const double md = 48;
  static const double lg = 52;
  static const double xl = 56;

  static const double tabBarItem = 64;
  static const double tabBarHeight = 80;
  static const double navBarHeight = 44;
  static const double miniPlayerHeight = 132;
  static const double playerMain = 72;
  static const double playerMainLarge = 80;
  static const double playerSecondary = 48;
  static const double listRowMin = 44;
  static const double listRowStandard = 52;
  static const double listRowLarge = 64;
  static const double searchBar = 36;
  static const double buttonHeight = 50;
  static const double buttonHeightSmall = 36;
  static const double sliderThumb = 44;
  static const double switchTarget = 44;
}

class AppTheme {
  AppTheme._();

  static const double r12 = 12;
  static const double r16 = 16;
  static const double r20 = 20;
  static const double r24 = 24;

  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;

  static const double controlHit = 48;

  static Color textSecondary(ColorScheme cs) =>
      cs.onSurface.withValues(alpha: AppOpacity.secondaryText);

  static Color textTertiary(ColorScheme cs) =>
      cs.onSurface.withValues(alpha: AppOpacity.tertiaryText);

  static Color textQuaternary(ColorScheme cs) =>
      cs.onSurface.withValues(alpha: AppOpacity.quaternaryText);

  static Color disabled(ColorScheme cs) =>
      cs.onSurface.withValues(alpha: AppOpacity.disabled);

  static Color glassBorder(ColorScheme cs) =>
      cs.onSurface.withValues(alpha: AppOpacity.glassBorder);

  static Color border(ColorScheme cs) =>
      cs.onSurface.withValues(alpha: AppOpacity.border);

  static Color divider(ColorScheme cs) =>
      cs.onSurface.withValues(alpha: AppOpacity.divider);

  static Color highlight(ColorScheme cs) =>
      cs.onSurface.withValues(alpha: AppOpacity.pressed);

  static Color hover(ColorScheme cs) =>
      cs.onSurface.withValues(alpha: AppOpacity.hover);

  static ThemeData dark() {
    final scheme = _buildDarkColorScheme();
    final textTheme = _buildTextTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColorsDark.background,
      canvasColor: AppColorsDark.surface,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColorsDark.surfaceElevated.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        foregroundColor: scheme.onSurface,
        titleTextStyle: AppTypography.navTitle(scheme.onSurface),
        iconTheme: IconThemeData(color: scheme.onSurface, size: AppIconSize.navBar),
        titleSpacing: AppSpacing.screenHorizontal,
        toolbarHeight: AppHitTarget.navBarHeight,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        height: AppHitTarget.tabBarHeight,
        indicatorColor: scheme.primary.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTypography.tabLabel(selected ? scheme.primary : textSecondary(scheme));
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : textSecondary(scheme),
            size: AppIconSize.tabBar,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        thickness: AppBorders.thin,
        space: AppBorders.thin,
        color: AppColorsDark.dividerSubtle,
      ),
      dividerColor: AppColorsDark.dividerSubtle,
      listTileTheme: ListTileThemeData(
        dense: false,
        minVerticalPadding: AppSpacing.listItemVertical,
        contentPadding: AppSpacing.listItemInsets,
        horizontalTitleGap: AppSpacing.xl,
        iconColor: textSecondary(scheme),
        textColor: scheme.onSurface,
        titleTextStyle: AppTypography.body(scheme.onSurface),
        subtitleTextStyle: AppTypography.footnote(textTertiary(scheme)),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        selectedTileColor: scheme.primary.withValues(alpha: AppOpacity.selected),
        selectedColor: scheme.primary,
        tileColor: Colors.transparent,
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4.0,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.onSurface.withValues(alpha: 0.15),
        secondaryActiveTrackColor: AppColorsDark.progressBuffered,
        thumbColor: Colors.white,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 6.0,
          elevation: 2.0,
          pressedElevation: 4.0,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18.0),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(AppHitTarget.min, AppHitTarget.min)),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(AppSpacing.md)),
          iconSize: const WidgetStatePropertyAll(AppIconSize.lg),
          foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return scheme.onSurface.withValues(alpha: AppOpacity.pressed);
            }
            if (states.contains(WidgetState.hovered)) {
              return scheme.onSurface.withValues(alpha: AppOpacity.hover);
            }
            return Colors.transparent;
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.primary.withValues(alpha: AppOpacity.disabled);
            }
            return scheme.primary;
          }),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: WidgetStatePropertyAll(scheme.primary.withValues(alpha: AppOpacity.hover)),
          textStyle: WidgetStatePropertyAll(AppTypography.button(scheme.primary)),
          minimumSize:
              const WidgetStatePropertyAll(Size(AppHitTarget.min, AppHitTarget.buttonHeightSmall)),
          padding: WidgetStatePropertyAll(AppSpacing.buttonInsets),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.primary.withValues(alpha: AppOpacity.disabled);
            }
            if (states.contains(WidgetState.pressed)) return AppColorsDark.primaryPressed;
            if (states.contains(WidgetState.hovered)) return AppColorsDark.primaryHover;
            return scheme.primary;
          }),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          overlayColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.1)),
          textStyle: WidgetStatePropertyAll(AppTypography.button(Colors.white)),
          minimumSize:
              const WidgetStatePropertyAll(Size(AppHitTarget.min, AppHitTarget.buttonHeight)),
          padding: WidgetStatePropertyAll(AppSpacing.buttonInsets),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.primary.withValues(alpha: AppOpacity.disabled);
            }
            return scheme.primary;
          }),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: WidgetStatePropertyAll(scheme.primary.withValues(alpha: AppOpacity.hover)),
          textStyle: WidgetStatePropertyAll(AppTypography.button(scheme.primary)),
          minimumSize:
              const WidgetStatePropertyAll(Size(AppHitTarget.min, AppHitTarget.buttonHeight)),
          padding: WidgetStatePropertyAll(AppSpacing.buttonInsets),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: scheme.primary.withValues(alpha: AppOpacity.disabled));
            }
            return BorderSide(color: scheme.primary);
          }),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBackgroundColor: Colors.transparent,
        modalElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheetBorder),
        clipBehavior: Clip.antiAlias,
        constraints: const BoxConstraints(maxWidth: 600),
        dragHandleColor: scheme.onSurface.withValues(alpha: 0.3),
        dragHandleSize: const Size(36, 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColorsDark.surfaceElevated.withValues(alpha: 0.95),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.modal),
          side: BorderSide(color: AppColorsDark.glassBorder.withValues(alpha: 0.5)),
        ),
        titleTextStyle: AppTypography.title3(scheme.onSurface),
        contentTextStyle: AppTypography.body(textSecondary(scheme)),
        actionsPadding: AppSpacing.cardInsets,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColorsDark.surfaceSecondary,
        contentTextStyle: AppTypography.callout(scheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColorsDark.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorder,
          side: BorderSide(color: AppColorsDark.dividerSubtle.withValues(alpha: 0.5)),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorsDark.surfaceSecondary,
        contentPadding: AppSpacing.inputInsets,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: AppBorders.thick),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error),
        ),
        hintStyle: AppTypography.body(textTertiary(scheme)),
        prefixIconColor: textSecondary(scheme),
        suffixIconColor: textSecondary(scheme),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(scheme.onSurface.withValues(alpha: 0.3)),
        thickness: const WidgetStatePropertyAll(4),
        radius: const Radius.circular(2),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.onSurface.withValues(alpha: 0.1),
        circularTrackColor: scheme.onSurface.withValues(alpha: 0.1),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.onSurface.withValues(alpha: 0.2);
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: BorderSide(color: textTertiary(scheme), width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xs)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return textTertiary(scheme);
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColorsDark.surfaceSecondary,
        selectedColor: scheme.primary.withValues(alpha: 0.2),
        labelStyle: AppTypography.footnote(scheme.onSurface),
        padding: AppSpacing.chipInsets,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.chipBorder),
        side: BorderSide.none,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColorsDark.surfaceElevated.withValues(alpha: 0.98),
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColorsDark.glassBorder.withValues(alpha: 0.5)),
        ),
        textStyle: AppTypography.body(scheme.onSurface),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColorsDark.surfaceSecondary,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: AppTypography.caption1(scheme.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.error,
        textColor: Colors.white,
        textStyle: AppTypography.badge(Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      ),
      tabBarTheme: TabBarThemeData(
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: scheme.primary, width: 2),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        ),
      // indicatorColor: scheme.primary, // moved to TabBarThemeData.indicatorColor
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelColor: scheme.onSurface,
        labelStyle: AppTypography.headline(scheme.onSurface),
        unselectedLabelColor: textSecondary(scheme),
        unselectedLabelStyle: AppTypography.headline(textSecondary(scheme)),
        overlayColor: WidgetStatePropertyAll(scheme.primary.withValues(alpha: AppOpacity.hover)),
        splashFactory: NoSplash.splashFactory,
        tabAlignment: TabAlignment.start,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: AppColorsDark.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrimColor: AppColorsDark.overlay,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(AppRadius.panel)),
        ),
        width: 320,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      splashFactory: NoSplash.splashFactory,
      highlightColor: AppColorsDark.highlight,
      splashColor: AppColorsDark.ripple,
      hoverColor: AppColorsDark.hover,
      focusColor: scheme.primary.withValues(alpha: 0.12),
      disabledColor: textQuaternary(scheme),
      unselectedWidgetColor: textTertiary(scheme),
      // indicatorColor: scheme.primary, // set via TabBarThemeData.indicatorColor
      hintColor: textTertiary(scheme),
    );
  }

  static ThemeData light() {
    final scheme = _buildLightColorScheme();
    final textTheme = _buildTextTheme(scheme);

    return dark().copyWith(
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColorsLight.background,
      canvasColor: AppColorsLight.surface,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColorsLight.surfaceElevated.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        foregroundColor: scheme.onSurface,
        titleTextStyle: AppTypography.navTitle(scheme.onSurface),
        iconTheme: IconThemeData(color: scheme.onSurface, size: AppIconSize.navBar),
      ),
      dividerColor: AppColorsLight.dividerSubtle,
      highlightColor: AppColorsLight.highlight,
      splashColor: AppColorsLight.ripple,
      hoverColor: AppColorsLight.hover,
      disabledColor: textQuaternary(scheme),
      unselectedWidgetColor: textTertiary(scheme),
      hintColor: textTertiary(scheme),
    );
  }

  static ColorScheme _buildDarkColorScheme() {
    return ColorScheme(
      brightness: Brightness.dark,
      primary: AppColorsDark.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColorsDark.primaryMuted,
      onPrimaryContainer: AppColorsDark.textPrimary,
      secondary: AppColorsDark.primary,
      onSecondary: Colors.white,
      secondaryContainer: AppColorsDark.primarySubtle,
      onSecondaryContainer: AppColorsDark.textPrimary,
      tertiary: AppColorsDark.info,
      onTertiary: Colors.black,
      tertiaryContainer: AppColorsDark.infoSubtle,
      onTertiaryContainer: AppColorsDark.textPrimary,
      error: AppColorsDark.error,
      onError: Colors.white,
      errorContainer: AppColorsDark.errorSubtle,
      onErrorContainer: AppColorsDark.textPrimary,
      surface: AppColorsDark.surface,
      onSurface: AppColorsDark.textPrimary,
      surfaceDim: AppColorsDark.background,
      surfaceBright: AppColorsDark.surfaceSecondary,
      surfaceContainerLowest: AppColorsDark.background,
      surfaceContainerLow: AppColorsDark.surface,
      surfaceContainer: AppColorsDark.surfaceElevated,
      surfaceContainerHigh: AppColorsDark.surfaceSecondary,
      surfaceContainerHighest: AppColorsDark.surfaceTertiary,
      onSurfaceVariant: AppColorsDark.textSecondary,
      inverseSurface: AppColorsDark.textPrimary,
      onInverseSurface: AppColorsDark.background,
      inversePrimary: AppColorsDark.primaryMuted,
      outline: AppColorsDark.divider,
      outlineVariant: AppColorsDark.dividerSubtle,
      shadow: Colors.black,
      scrim: AppColorsDark.overlay,
      surfaceTint: AppColorsDark.primary,
    );
  }

  static ColorScheme _buildLightColorScheme() {
    return ColorScheme(
      brightness: Brightness.light,
      primary: AppColorsLight.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColorsLight.primaryMuted,
      onPrimaryContainer: AppColorsLight.textPrimary,
      secondary: AppColorsLight.primary,
      onSecondary: Colors.white,
      secondaryContainer: AppColorsLight.primarySubtle,
      onSecondaryContainer: AppColorsLight.textPrimary,
      tertiary: AppColorsLight.info,
      onTertiary: Colors.white,
      tertiaryContainer: AppColorsLight.infoSubtle,
      onTertiaryContainer: AppColorsLight.textPrimary,
      error: AppColorsLight.error,
      onError: Colors.white,
      errorContainer: AppColorsLight.errorSubtle,
      onErrorContainer: AppColorsLight.textPrimary,
      surface: AppColorsLight.surface,
      onSurface: AppColorsLight.textPrimary,
      surfaceDim: AppColorsLight.backgroundSecondary,
      surfaceBright: AppColorsLight.surface,
      surfaceContainerLowest: AppColorsLight.surface,
      surfaceContainerLow: AppColorsLight.surfaceSecondary,
      surfaceContainer: AppColorsLight.surfaceElevated,
      surfaceContainerHigh: AppColorsLight.surfaceSecondary,
      surfaceContainerHighest: AppColorsLight.surfaceTertiary,
      onSurfaceVariant: AppColorsLight.textSecondary,
      inverseSurface: AppColorsLight.textPrimary,
      onInverseSurface: AppColorsLight.background,
      inversePrimary: AppColorsLight.primaryMuted,
      outline: AppColorsLight.divider,
      outlineVariant: AppColorsLight.dividerSubtle,
      shadow: Colors.black,
      scrim: AppColorsLight.overlay,
      surfaceTint: AppColorsLight.primary,
    );
  }

  static TextTheme _buildTextTheme(ColorScheme cs) {
    return TextTheme(
      displayLarge: AppTypography.largeTitle(cs.onSurface),
      displayMedium: AppTypography.title1(cs.onSurface),
      displaySmall: AppTypography.title2(cs.onSurface),
      headlineLarge: AppTypography.title1(cs.onSurface),
      headlineMedium: AppTypography.title2(cs.onSurface),
      headlineSmall: AppTypography.title3(cs.onSurface),

      // Make section headers feel "premium" (Poweramp density + iOS weight).
      titleLarge: AppTypography.title2(cs.onSurface),
      titleMedium: AppTypography.title3(cs.onSurface),
      titleSmall: AppTypography.headline(cs.onSurface),

      bodyLarge: AppTypography.body(cs.onSurface),
      bodyMedium: AppTypography.subheadline(cs.onSurface),
      bodySmall: AppTypography.footnote(cs.onSurface),
      labelLarge: AppTypography.headline(cs.onSurface),
      labelMedium: AppTypography.caption1(cs.onSurface),
      labelSmall: AppTypography.caption2(cs.onSurface),
    );
  }
}

class NoGlowScrollBehavior extends MaterialScrollBehavior {
  const NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}

extension ThemeDataExtension on ThemeData {
  ColorScheme get colors => colorScheme;
  bool get isDark => brightness == Brightness.dark;
  bool get isLight => brightness == Brightness.light;
}

extension ColorSchemeExtension on ColorScheme {
  Color get success =>
      brightness == Brightness.dark ? AppColorsDark.success : AppColorsLight.success;
  Color get warning =>
      brightness == Brightness.dark ? AppColorsDark.warning : AppColorsLight.warning;
  Color get info => brightness == Brightness.dark ? AppColorsDark.info : AppColorsLight.info;
  Color get glassTint =>
      brightness == Brightness.dark ? AppColorsDark.glassTint : AppColorsLight.glassTint;
  Color get glassBorderColor =>
      brightness == Brightness.dark ? AppColorsDark.glassBorder : AppColorsLight.glassBorder;
  Color get overlayColor =>
      brightness == Brightness.dark ? AppColorsDark.overlay : AppColorsLight.overlay;
  Color get textTertiary =>
      brightness == Brightness.dark ? AppColorsDark.textTertiary : AppColorsLight.textTertiary;
  Color get textQuaternary =>
      brightness == Brightness.dark ? AppColorsDark.textQuaternary : AppColorsLight.textQuaternary;
  Color get nowPlaying =>
      brightness == Brightness.dark ? AppColorsDark.nowPlaying : AppColorsLight.nowPlaying;
  Color get favorite =>
      brightness == Brightness.dark ? AppColorsDark.favorite : AppColorsLight.favorite;
  Color get dividerSubtle =>
      brightness == Brightness.dark ? AppColorsDark.dividerSubtle : AppColorsLight.dividerSubtle;
  Color get surfaceElevated =>
      brightness == Brightness.dark ? AppColorsDark.surfaceElevated : AppColorsLight.surfaceElevated;
  Color get surfaceSecondary =>
      brightness == Brightness.dark ? AppColorsDark.surfaceSecondary : AppColorsLight.surfaceSecondary;
}

extension ThemeContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => mediaQuery.size;
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;
  double get bottomPadding => mediaQuery.padding.bottom;
  double get topPadding => mediaQuery.padding.top;
  bool get isDark => theme.isDark;
}