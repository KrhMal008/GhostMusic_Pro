import 'dart:ui';

import 'package:flutter/material.dart';

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;
  final bool automaticallyImplyLeading;
  final double blur;
  final BorderRadius borderRadius;

  const GlassAppBar({
    super.key,
    this.title,
    this.actions,
    this.bottom,
    this.centerTitle = false,
    this.automaticallyImplyLeading = true,
    this.blur = 18,
    this.borderRadius = const BorderRadius.vertical(bottom: Radius.circular(28)),
  });

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final base = theme.appBarTheme.backgroundColor ?? cs.surface;
    final bg = base.withValues(alpha: 0.70);

    return AppBar(
      title: title,
      actions: actions,
      bottom: bottom,
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  bg.withValues(alpha: 0.50),
                  bg.withValues(alpha: 0.62),
                  bg.withValues(alpha: 0.70),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
              border: Border(
                bottom: BorderSide(
                  color: cs.onSurface.withValues(alpha: 0.06),
                  width: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassSliverAppBar extends StatelessWidget {
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;
  final bool automaticallyImplyLeading;
  final double blur;
  final BorderRadius borderRadius;
  final Color? backgroundColor;
  final bool large;
  final double expandedHeight;

  const GlassSliverAppBar.large({
    super.key,
    this.title,
    this.actions,
    this.bottom,
    this.centerTitle = false,
    this.automaticallyImplyLeading = true,
    this.blur = 20,
    this.borderRadius = const BorderRadius.vertical(bottom: Radius.circular(28)),
    this.backgroundColor,
    this.expandedHeight = 60,
  }) : large = true;

  const GlassSliverAppBar.small({
    super.key,
    this.title,
    this.actions,
    this.bottom,
    this.centerTitle = false,
    this.automaticallyImplyLeading = true,
    this.blur = 20,
    this.borderRadius = const BorderRadius.vertical(bottom: Radius.circular(28)),
    this.backgroundColor,
    this.expandedHeight = 0,
  }) : large = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final toolbarHeight = theme.appBarTheme.toolbarHeight ?? kToolbarHeight;
    final bottomHeight = bottom?.preferredSize.height ?? 0;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _GlassSliverAppBarDelegate(
        title: title,
        actions: actions,
        bottom: bottom,
        centerTitle: centerTitle,
        automaticallyImplyLeading: automaticallyImplyLeading,
        blur: blur,
        borderRadius: borderRadius,
        backgroundColor: backgroundColor,
        expandedHeight: large ? expandedHeight : 0,
        topPadding: topPadding,
        toolbarHeight: toolbarHeight,
        bottomHeight: bottomHeight,
      ),
    );
  }
}

class _GlassSliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;
  final bool automaticallyImplyLeading;
  final double blur;
  final BorderRadius borderRadius;
  final Color? backgroundColor;
  final double expandedHeight;
  final double topPadding;
  final double toolbarHeight;
  final double bottomHeight;

  const _GlassSliverAppBarDelegate({
    required this.title,
    required this.actions,
    required this.bottom,
    required this.centerTitle,
    required this.automaticallyImplyLeading,
    required this.blur,
    required this.borderRadius,
    required this.backgroundColor,
    required this.expandedHeight,
    required this.topPadding,
    required this.toolbarHeight,
    required this.bottomHeight,
  });

  @override
  double get minExtent {
    return topPadding + toolbarHeight + bottomHeight;
  }

  @override
  double get maxExtent {
    return minExtent + expandedHeight;
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bottomHeight = this.bottomHeight;

    final availableRange = (maxExtent - minExtent).clamp(0.001, double.infinity);
    final t = (shrinkOffset / availableRange).clamp(0.0, 1.0);

    final leading = _buildLeading(context);
    final hasLeading = leading != null;

    final baseBg = backgroundColor ?? theme.appBarTheme.backgroundColor ?? cs.surface;
    final bg = baseBg.withValues(alpha: 0.70);

    final largeStyle = theme.textTheme.displayLarge?.copyWith(color: cs.onSurface) ??
        TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          height: 1.08,
          color: cs.onSurface,
        );

    final smallStyle = theme.appBarTheme.titleTextStyle?.copyWith(color: cs.onSurface) ??
        TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          height: 1.18,
          color: cs.onSurface,
        );

    final titleText = _extractTitleText(title);

    Widget buildSmallTitle() {
      if (title == null) return const SizedBox.shrink();
      if (titleText != null) {
        return Text(
          titleText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: smallStyle,
        );
      }
      return DefaultTextStyle(style: smallStyle, child: title!);
    }

    Widget buildLargeTitle() {
      if (title == null) return const SizedBox.shrink();
      if (titleText != null) {
        return Text(
          titleText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: largeStyle,
        );
      }
      return DefaultTextStyle(style: largeStyle, child: title!);
    }

    final smallTitle = Opacity(
      opacity: expandedHeight <= 0 ? 1.0 : t,
      child: buildSmallTitle(),
    );

    final largeTitle = Opacity(
      opacity: expandedHeight <= 0 ? 0.0 : (1.0 - t),
      child: buildLargeTitle(),
    );

    final toolbar = SizedBox(
      height: toolbarHeight,
      child: Row(
        children: [
          if (leading != null) leading,
          if (leading == null) const SizedBox(width: 12),
          Expanded(
            child: centerTitle
                ? Center(child: smallTitle)
                : Padding(
                    padding: EdgeInsets.only(left: hasLeading ? 4 : 0, right: 8),
                    child: Align(alignment: Alignment.centerLeft, child: smallTitle),
                  ),
          ),
          if (actions != null) ...actions!,
          const SizedBox(width: 12),
        ],
      ),
    );

    final titleArea = expandedHeight <= 0
        ? const SizedBox.shrink()
        : Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: largeTitle,
              ),
            ),
          );

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                bg.withValues(alpha: 0.50),
                bg.withValues(alpha: 0.62),
                bg.withValues(alpha: 0.70),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
            border: Border(
              bottom: BorderSide(
                color: cs.onSurface.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                toolbar,
                titleArea,
                if (bottom != null) bottom!,
                if (bottom == null && bottomHeight > 0) SizedBox(height: bottomHeight),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildLeading(BuildContext context) {
    if (!automaticallyImplyLeading) return null;
    if (!Navigator.of(context).canPop()) return null;
    return const BackButton();
  }

  String? _extractTitleText(Widget? title) {
    if (title is Text) return title.data;
    return null;
  }

  @override
  bool shouldRebuild(covariant _GlassSliverAppBarDelegate oldDelegate) {
    return oldDelegate.title != title ||
        oldDelegate.actions != actions ||
        oldDelegate.bottom != bottom ||
        oldDelegate.centerTitle != centerTitle ||
        oldDelegate.automaticallyImplyLeading != automaticallyImplyLeading ||
        oldDelegate.blur != blur ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.expandedHeight != expandedHeight ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.toolbarHeight != toolbarHeight ||
        oldDelegate.bottomHeight != bottomHeight;
  }
}
