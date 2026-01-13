import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ghostmusic/ui/theme/app_theme.dart';

enum GlassVariant {
  ultraThin,
  thin,
  regular,
  thick,
  ultraThick,
  solid,
}

enum GlassShape {
  rectangle,
  roundedSmall,
  roundedMedium,
  roundedLarge,
  roundedXLarge,
  stadium,
  circle,
  custom,
}

class GlassSurface extends StatelessWidget {
  final GlassVariant variant;
  final GlassShape shape;
  final double? customRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Widget child;
  final double? sigma;
  final Color? tint;
  final Color? borderColor;
  final double borderWidth;
  final bool blurEnabled;
  final bool borderEnabled;
  final bool shadowEnabled;
  final Gradient? gradient;
  final List<BoxShadow>? shadows;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final Clip clipBehavior;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enableFeedback;

  const GlassSurface({
    super.key,
    this.variant = GlassVariant.regular,
    this.shape = GlassShape.roundedMedium,
    this.customRadius,
    this.padding = EdgeInsets.zero,
    this.margin,
    required this.child,
    this.sigma,
    this.tint,
    this.borderColor,
    this.borderWidth = 0.5,
    this.blurEnabled = true,
    this.borderEnabled = true,
    this.shadowEnabled = false,
    this.gradient,
    this.shadows,
    this.width,
    this.height,
    this.constraints,
    this.clipBehavior = Clip.antiAlias,
    this.onTap,
    this.onLongPress,
    this.enableFeedback = true,
  });

  factory GlassSurface.thin({
    Key? key,
    GlassShape shape = GlassShape.roundedMedium,
    double? customRadius,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    EdgeInsetsGeometry? margin,
    required Widget child,
    Color? tint,
    Color? borderColor,
    bool blurEnabled = true,
    VoidCallback? onTap,
  }) =>
      GlassSurface(
        key: key,
        variant: GlassVariant.thin,
        shape: shape,
        customRadius: customRadius,
        padding: padding,
        margin: margin,
        tint: tint,
        borderColor: borderColor,
        blurEnabled: blurEnabled,
        onTap: onTap,
        child: child,
      );

  factory GlassSurface.regular({
    Key? key,
    GlassShape shape = GlassShape.roundedMedium,
    double? customRadius,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    EdgeInsetsGeometry? margin,
    required Widget child,
    Color? tint,
    Color? borderColor,
    bool blurEnabled = true,
    VoidCallback? onTap,
  }) =>
      GlassSurface(
        key: key,
        variant: GlassVariant.regular,
        shape: shape,
        customRadius: customRadius,
        padding: padding,
        margin: margin,
        tint: tint,
        borderColor: borderColor,
        blurEnabled: blurEnabled,
        onTap: onTap,
        child: child,
      );

  factory GlassSurface.thick({
    Key? key,
    GlassShape shape = GlassShape.roundedMedium,
    double? customRadius,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    EdgeInsetsGeometry? margin,
    required Widget child,
    Color? tint,
    Color? borderColor,
    bool blurEnabled = true,
    VoidCallback? onTap,
  }) =>
      GlassSurface(
        key: key,
        variant: GlassVariant.thick,
        shape: shape,
        customRadius: customRadius,
        padding: padding,
        margin: margin,
        tint: tint,
        borderColor: borderColor,
        blurEnabled: blurEnabled,
        onTap: onTap,
        child: child,
      );

  factory GlassSurface.card({
    Key? key,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    required Widget child,
    VoidCallback? onTap,
  }) =>
      GlassSurface(
        key: key,
        variant: GlassVariant.regular,
        shape: GlassShape.roundedLarge,
        padding: padding ?? const EdgeInsets.all(16),
        margin: margin,
        onTap: onTap,
        child: child,
      );

  factory GlassSurface.button({
    Key? key,
    EdgeInsetsGeometry? padding,
    required Widget child,
    VoidCallback? onTap,
  }) =>
      GlassSurface(
        key: key,
        variant: GlassVariant.thin,
        shape: GlassShape.stadium,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        onTap: onTap,
        child: child,
      );

  factory GlassSurface.chip({
    Key? key,
    EdgeInsetsGeometry? padding,
    required Widget child,
    VoidCallback? onTap,
  }) =>
      GlassSurface(
        key: key,
        variant: GlassVariant.ultraThin,
        shape: GlassShape.stadium,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        onTap: onTap,
        child: child,
      );

  factory GlassSurface.bar({
    Key? key,
    GlassVariant variant = GlassVariant.thin,
    double? sigma,
    double radius = 28,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    EdgeInsetsGeometry? margin,
    required Widget child,
    List<BoxShadow>? shadows,
    bool shadowEnabled = true,
    bool blurEnabled = true,
    bool borderEnabled = true,
    Color? borderColor,
    double borderWidth = 0.5,
    double? width,
    double? height,
    BoxConstraints? constraints,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool enableFeedback = true,
  }) =>
      GlassSurface(
        key: key,
        variant: variant,
        sigma: sigma,
        shape: GlassShape.custom,
        customRadius: radius,
        padding: padding,
        margin: margin,
        shadows: shadows,
        shadowEnabled: shadowEnabled,
        blurEnabled: blurEnabled,
        borderEnabled: borderEnabled,
        borderColor: borderColor,
        borderWidth: borderWidth,
        width: width,
        height: height,
        constraints: constraints,
        onTap: onTap,
        onLongPress: onLongPress,
        enableFeedback: enableFeedback,
        child: child,
      );

  factory GlassSurface.miniPlayer({
    Key? key,
    EdgeInsetsGeometry? padding,
    required Widget child,
    List<BoxShadow>? shadows,
    VoidCallback? onTap,
  }) =>
      GlassSurface.bar(
        key: key,
        variant: GlassVariant.thin,
        sigma: AppBlur.miniPlayer,
        radius: 24,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shadows: shadows,
        onTap: onTap,
        child: child,
      );

  factory GlassSurface.tabBar({
    Key? key,
    EdgeInsetsGeometry? padding,
    required Widget child,
    List<BoxShadow>? shadows,
  }) =>
      GlassSurface.bar(
        key: key,
        variant: GlassVariant.thin,
        sigma: AppBlur.tabBar,
        radius: 28,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 10),
        shadows: shadows,
        child: child,
      );

  factory GlassSurface.sheet({
    Key? key,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    required Widget child,
    List<BoxShadow>? shadows,
  }) =>
      GlassSurface(
        key: key,
        variant: GlassVariant.thick,
        shape: GlassShape.custom,
        customRadius: 32,
        padding: padding,
        shadowEnabled: true,
        shadows: shadows,
        child: child,
      );

  factory GlassSurface.modal({
    Key? key,
    EdgeInsetsGeometry? padding,
    required Widget child,
    List<BoxShadow>? shadows,
  }) =>
      GlassSurface(
        key: key,
        variant: GlassVariant.thick,
        shape: GlassShape.roundedLarge,
        padding: padding ?? const EdgeInsets.all(24),
        shadowEnabled: true,
        shadows: shadows,
        child: child,
      );

  factory GlassSurface.contextMenu({
    Key? key,
    EdgeInsetsGeometry? padding,
    required Widget child,
    List<BoxShadow>? shadows,
  }) =>
      GlassSurface(
        key: key,
        variant: GlassVariant.ultraThick,
        shape: GlassShape.roundedMedium,
        padding: padding ?? const EdgeInsets.symmetric(vertical: 8),
        shadowEnabled: true,
        shadows: shadows,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveBlurRaw = sigma ?? _blurFor(variant);
    final effectiveBlur = effectiveBlurRaw.clamp(0.0, 22.0);
    final effectiveBorder = borderColor ?? _borderFor(cs, variant, isDark);
    final effectiveRadius = _radiusFor(shape, customRadius);
    final effectiveGradient = gradient ?? _gradientFor(cs, variant, isDark);

    final decoration = BoxDecoration(
      gradient: effectiveGradient,
      borderRadius: shape == GlassShape.circle ? null : effectiveRadius,
      shape: shape == GlassShape.circle ? BoxShape.circle : BoxShape.rectangle,
      border: borderEnabled
          ? Border.all(color: effectiveBorder, width: borderWidth)
          : null,
      boxShadow: shadowEnabled ? (shadows ?? _defaultShadows(cs)) : null,
    );

    Widget content = Container(
      width: width,
      height: height,
      constraints: constraints,
      decoration: decoration,
      padding: padding,
      child: child,
    );

    content = RepaintBoundary(
      child: ClipRRect(
        borderRadius: shape == GlassShape.circle
            ? BorderRadius.circular(10000)
            : effectiveRadius,
        clipBehavior: clipBehavior,
        child: blurEnabled
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
                child: content,
              )
            : content,
      ),
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    if (onTap != null || onLongPress != null) {
      content = _GlassInkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: shape == GlassShape.circle
            ? BorderRadius.circular(10000)
            : effectiveRadius,
        enableFeedback: enableFeedback,
        child: content,
      );
    }

    return content;
  }

  List<BoxShadow> _defaultShadows(ColorScheme cs) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.15),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];
  }

  double _blurFor(GlassVariant v) {
    return switch (v) {
      GlassVariant.ultraThin => AppBlur.xs,
      GlassVariant.thin => AppBlur.md,
      GlassVariant.regular => AppBlur.lg,
      GlassVariant.thick => AppBlur.xl,
      GlassVariant.ultraThick => AppBlur.xxl,
      GlassVariant.solid => AppBlur.none,
    };
  }


  Color _borderFor(ColorScheme cs, GlassVariant v, bool isDark) {
    final base = cs.onSurface;
    return switch (v) {
      GlassVariant.ultraThin => base.withValues(alpha: 0.06),
      GlassVariant.thin => base.withValues(alpha: 0.08),
      GlassVariant.regular => base.withValues(alpha: 0.10),
      GlassVariant.thick => base.withValues(alpha: 0.12),
      GlassVariant.ultraThick => base.withValues(alpha: 0.14),
      GlassVariant.solid => base.withValues(alpha: 0.16),
    };
  }

  BorderRadius _radiusFor(GlassShape s, double? custom) {
    if (custom != null) return BorderRadius.circular(custom);
    return switch (s) {
      GlassShape.rectangle => BorderRadius.zero,
      GlassShape.roundedSmall => BorderRadius.circular(8),
      GlassShape.roundedMedium => BorderRadius.circular(16),
      GlassShape.roundedLarge => BorderRadius.circular(20),
      GlassShape.roundedXLarge => BorderRadius.circular(28),
      GlassShape.stadium => BorderRadius.circular(999),
      GlassShape.circle => BorderRadius.circular(10000),
      GlassShape.custom => BorderRadius.circular(16),
    };
  }

  LinearGradient _gradientFor(ColorScheme cs, GlassVariant v, bool isDark) {
    final base = cs.surface;

    // Less transparency for readability (Windows blur is expensive and makes text muddy).
    final (aTop, aMid, aBot) = switch (v) {
      GlassVariant.ultraThin => (0.22, 0.20, 0.18),
      GlassVariant.thin => (0.30, 0.28, 0.24),
      GlassVariant.regular => (0.40, 0.36, 0.32),
      GlassVariant.thick => (0.52, 0.48, 0.44),
      GlassVariant.ultraThick => (0.68, 0.62, 0.56),
      GlassVariant.solid => (0.92, 0.90, 0.88),
    };


    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        base.withValues(alpha: aTop),
        base.withValues(alpha: aMid),
        base.withValues(alpha: aBot),
      ],
      stops: const [0.0, 0.55, 1.0],
    );
  }
}

class _GlassInkWell extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;
  final bool enableFeedback;

  const _GlassInkWell({
    required this.child,
    this.onTap,
    this.onLongPress,
    required this.borderRadius,
    this.enableFeedback = true,
  });

  @override
  State<_GlassInkWell> createState() => _GlassInkWellState();
}

class _GlassInkWellState extends State<_GlassInkWell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  bool _isPressed = false;

  static const _duration = Duration(milliseconds: 100);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _duration,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!_isPressed) {
      _isPressed = true;
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      _isPressed = false;
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      _isPressed = false;
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final Color? color;
  final BorderRadius borderRadius;
  final Border? border;
  final List<BoxShadow>? shadows;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 22,
    this.color,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.border,
    this.shadows,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final effectiveColor = color ?? cs.surface.withValues(alpha: 0.14);

    Widget content = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveColor,
        gradient: gradient,
        borderRadius: borderRadius,
        border: border ??
            Border.all(
              color: cs.onSurface.withValues(alpha: 0.10),
              width: 0.5,
            ),
        boxShadow: shadows,
      ),
      padding: padding,
      child: child,
    );

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      ),
    );
  }
}

class GlassDivider extends StatelessWidget {
  final double thickness;
  final double indent;
  final double endIndent;
  final Color? color;
  final bool vertical;

  const GlassDivider({
    super.key,
    this.thickness = 0.5,
    this.indent = 0,
    this.endIndent = 0,
    this.color,
    this.vertical = false,
  });

  const GlassDivider.horizontal({
    super.key,
    this.thickness = 0.5,
    this.indent = 0,
    this.endIndent = 0,
    this.color,
  }) : vertical = false;

  const GlassDivider.vertical({
    super.key,
    this.thickness = 0.5,
    this.indent = 0,
    this.endIndent = 0,
    this.color,
  }) : vertical = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = color ?? cs.onSurface.withValues(alpha: 0.08);

    if (vertical) {
      return Container(
        width: thickness,
        margin: EdgeInsets.only(top: indent, bottom: endIndent),
        color: effectiveColor,
      );
    }

    return Container(
      height: thickness,
      margin: EdgeInsets.only(left: indent, right: endIndent),
      color: effectiveColor,
    );
  }
}

class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final Color? backgroundColor;
  final bool blurEnabled;
  final String? tooltip;
  final bool selected;
  final Color? selectedColor;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 44,
    this.iconSize = 22,
    this.iconColor,
    this.backgroundColor,
    this.blurEnabled = true,
    this.tooltip,
    this.selected = false,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final effectiveIconColor = selected
        ? (selectedColor ?? cs.primary)
        : (iconColor ?? cs.onSurface);

    Widget button = GlassSurface(
      variant: GlassVariant.ultraThin,
      shape: GlassShape.circle,
      blurEnabled: blurEnabled,
      borderEnabled: false,
      width: size,
      height: size,
      onTap: onPressed,
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: effectiveIconColor,
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}

class GlassTextButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool iconLeading;
  final TextStyle? textStyle;
  final Color? textColor;
  final GlassVariant variant;
  final EdgeInsetsGeometry? padding;

  const GlassTextButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.iconLeading = true,
    this.textStyle,
    this.textColor,
    this.variant = GlassVariant.thin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = textColor ?? cs.onSurface;

    final style = textStyle ??
        TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: color,
        );

    final textWidget = Text(text, style: style);

    Widget content;
    if (icon != null) {
      final iconWidget = Icon(icon, size: 20, color: color);
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: iconLeading
            ? [iconWidget, const SizedBox(width: 8), textWidget]
            : [textWidget, const SizedBox(width: 8), iconWidget],
      );
    } else {
      content = textWidget;
    }

    return GlassSurface(
      variant: variant,
      shape: GlassShape.stadium,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      onTap: onPressed,
      child: content,
    );
  }
}

class GlassChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;
  final bool selected;
  final Color? selectedColor;
  final Color? labelColor;

  const GlassChip({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.onDeleted,
    this.selected = false,
    this.selectedColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final effectiveColor = selected
        ? (selectedColor ?? cs.primary)
        : (labelColor ?? cs.onSurface);

    return GlassSurface(
      variant: selected ? GlassVariant.regular : GlassVariant.ultraThin,
      shape: GlassShape.stadium,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      onTap: onTap,
      borderColor: selected ? cs.primary.withValues(alpha: 0.3) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: effectiveColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: effectiveColor,
            ),
          ),
          if (onDeleted != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDeleted,
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: effectiveColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class GlassProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? bufferedColor;
  final double? bufferedValue;
  final BorderRadius? borderRadius;

  const GlassProgressBar({
    super.key,
    required this.value,
    this.height = 4,
    this.activeColor,
    this.inactiveColor,
    this.bufferedColor,
    this.bufferedValue,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(height / 2);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: inactiveColor ?? cs.onSurface.withValues(alpha: 0.12),
                borderRadius: radius,
              ),
            ),
            if (bufferedValue != null)
              FractionallySizedBox(
                widthFactor: bufferedValue!.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: bufferedColor ?? cs.onSurface.withValues(alpha: 0.20),
                    borderRadius: radius,
                  ),
                ),
              ),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: activeColor ?? cs.primary,
                  borderRadius: radius,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedGlassSurface extends StatelessWidget {
  final GlassVariant variant;
  final GlassShape shape;
  final double? customRadius;
  final EdgeInsetsGeometry padding;
  final Widget child;
  final Duration duration;
  final Curve curve;

  const AnimatedGlassSurface({
    super.key,
    this.variant = GlassVariant.regular,
    this.shape = GlassShape.roundedMedium,
    this.customRadius,
    this.padding = EdgeInsets.zero,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: curve,
      switchOutCurve: curve,
      child: GlassSurface(
        key: ValueKey(variant),
        variant: variant,
        shape: shape,
        customRadius: customRadius,
        padding: padding,
        child: child,
      ),
    );
  }
}

class GlassScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final Color? backgroundColor;

  const GlassScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.extendBody = true,
    this.extendBodyBehindAppBar = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? Colors.transparent,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

class GlassHandle extends StatelessWidget {
  final double width;
  final double height;
  final Color? color;

  const GlassHandle({
    super.key,
    this.width = 44,
    this.height = 5,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? cs.onSurface.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

class GlassListTile extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? contentPadding;
  final bool dense;
  final bool selected;

  const GlassListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.contentPadding,
    this.dense = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final effectivePadding = contentPadding ??
        EdgeInsets.symmetric(
          horizontal: 16,
          vertical: dense ? 8 : 12,
        );

    Widget content = Padding(
      padding: effectivePadding,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle(
                  style: TextStyle(
                    fontSize: dense ? 15 : 16,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? cs.primary : cs.onSurface,
                  ),
                  child: title,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  DefaultTextStyle(
                    style: TextStyle(
                      fontSize: dense ? 12 : 13,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                    child: subtitle!,
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
    );

    if (onTap != null || onLongPress != null) {
      content = GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return content;
  }
}

class GlassSegmentedControl<T> extends StatelessWidget {
  final List<T> segments;
  final T selected;
  final Widget Function(T segment, bool isSelected) builder;
  final ValueChanged<T> onChanged;
  final EdgeInsetsGeometry? padding;

  const GlassSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.builder,
    required this.onChanged,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GlassSurface(
      variant: GlassVariant.ultraThin,
      shape: GlassShape.stadium,
      padding: padding ?? const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: segments.map((segment) {
          final isSelected = segment == selected;

          return GestureDetector(
            onTap: () => onChanged(segment),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: builder(segment, isSelected),
            ),
          );
        }).toList(),
      ),
    );
  }
}