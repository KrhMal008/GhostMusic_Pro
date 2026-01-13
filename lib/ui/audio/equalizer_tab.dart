import 'package:flutter/material.dart';

import 'package:ghostmusic/ui/theme/app_theme.dart';
import 'package:ghostmusic/ui/widgets/glass_app_bar.dart';
import 'package:ghostmusic/ui/widgets/glass_surface.dart';


class EqualizerTab extends StatefulWidget {
  const EqualizerTab({super.key});

  @override
  State<EqualizerTab> createState() => _EqualizerTabState();
}

class _EqualizerTabState extends State<EqualizerTab> {
  static const _presets = <String>[
    'Default',
    'Bass Boost',
    'Vocal',
    'Rock',
    'Classical',
  ];

  static const _bands = <String>[
    '31',
    '62',
    '125',
    '250',
    '500',
    '1K',
    '2K',
    '4K',
    '8K',
    '16K',
  ];

  // Пока это UI-скелет: DSP не подключен.
  final bool _dspAvailable = false;

  bool _enabled = false;
  int _presetIndex = 0;

  double _preamp = 0.5;
  final List<double> _values = List<double>.filled(_bands.length, 0.5);

  double _toneBass = 0.5;
  double _toneTreble = 0.5;
  double _limiter = 0.5;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final enabled = _dspAvailable && _enabled;

    final bottomOverlay =
        MediaQuery.paddingOf(context).bottom + AppHitTarget.tabBarHeight + AppHitTarget.miniPlayerHeight;

    Widget sectionTitle(String text) {
      return Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
      );
    }

    return CustomScrollView(
      slivers: [
        GlassSliverAppBar.large(

          title: const Text('Эквалайзер'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Row(
                children: [
                  Text(
                    'EQ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface.withValues(alpha: 0.55),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: _enabled,
                    onChanged: _dspAvailable
                        ? (v) => setState(() => _enabled = v)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_dspAvailable)
                  GlassSurface.card(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: cs.onSurface.withValues(alpha: 0.65),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DSP пока не подключён',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Это премиум‑UI скелет в стиле Poweramp. Следующий шаг — связать управление с аудио‑эффектами.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurface.withValues(alpha: 0.65),
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                sectionTitle('Пресеты'),
                const SizedBox(height: 10),
                Opacity(
                  opacity: _dspAvailable ? 1.0 : 0.55,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(_presets.length, (i) {
                      final selected = _presetIndex == i;
                      return _PresetChip(
                        label: _presets[i],
                        selected: selected,
                        onSelected: _dspAvailable
                            ? (_) => setState(() => _presetIndex = i)
                            : null,
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 18),

                sectionTitle('10‑полосный EQ'),
                const SizedBox(height: 10),
                _EqCard(
                  accent: cs.favorite,
                  enabled: enabled,
                  dspAvailable: _dspAvailable,
                  preamp: _preamp,
                  onPreampChanged: _dspAvailable
                      ? (v) => setState(() => _preamp = v)
                      : null,
                  bands: _bands,
                  values: _values,
                  onBandChanged: _dspAvailable
                      ? (index, v) => setState(() => _values[index] = v)
                      : null,
                ),
                const SizedBox(height: 18),

                sectionTitle('Модули'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ModuleCard(
                        title: 'Тон',
                        subtitle: 'Низ / Верх',
                        icon: Icons.tune_rounded,
                        enabled: enabled,
                        child: Column(
                          children: [
                            _LabeledSlider(
                              label: 'Низ',
                              value: _toneBass,
                              accent: cs.favorite,
                              onChanged: _dspAvailable
                                  ? (v) => setState(() => _toneBass = v)
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            _LabeledSlider(
                              label: 'Верх',
                              value: _toneTreble,
                              accent: cs.favorite,
                              onChanged: _dspAvailable
                                  ? (v) => setState(() => _toneTreble = v)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModuleCard(
                        title: 'Лимит',
                        subtitle: 'Limiter',
                        icon: Icons.graphic_eq_rounded,
                        enabled: enabled,
                        child: _LabeledSlider(
                          label: 'Level',
                          value: _limiter,
                          accent: cs.favorite,
                          onChanged: _dspAvailable
                              ? (v) => setState(() => _limiter = v)
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: bottomOverlay + 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  const _PresetChip({
    required this.label,
    this.selected = false,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: onSelected,
      selectedColor: cs.favorite.withValues(alpha: 0.16),
      checkmarkColor: cs.favorite,
      side: BorderSide(color: cs.onSurface.withValues(alpha: 0.10), width: 0.5),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        color: cs.onSurface,
      ),
    );
  }
}

class _EqCard extends StatelessWidget {
  final Color accent;
  final bool enabled;
  final bool dspAvailable;

  final double preamp;
  final ValueChanged<double>? onPreampChanged;

  final List<String> bands;
  final List<double> values;
  final void Function(int index, double value)? onBandChanged;

  const _EqCard({
    required this.accent,
    required this.enabled,
    required this.dspAvailable,
    required this.preamp,
    required this.onPreampChanged,
    required this.bands,
    required this.values,
    required this.onBandChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final effectiveOpacity = dspAvailable ? 1.0 : 0.65;

    return GlassSurface.card(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Opacity(
        opacity: effectiveOpacity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'PREAMP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface.withValues(alpha: 0.55),
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                _DbReadout(value01: preamp, enabled: enabled),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: accent,
                inactiveTrackColor: cs.onSurface.withValues(alpha: 0.12),
                thumbColor: accent,
                overlayColor: accent.withValues(alpha: 0.10),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: preamp,
                onChanged: onPreampChanged,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: cs.surface.withValues(alpha: 0.25),
                border: Border.all(
                  color: cs.onSurface.withValues(alpha: 0.10),
                  width: 0.5,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Align(
                        alignment: Alignment.center,
                        child: Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          color: cs.onSurface.withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: List.generate(bands.length, (i) {
                        return Expanded(
                          child: _VerticalEqBand(
                            label: bands[i],
                            value: values[i],
                            accent: accent,
                            enabled: enabled,
                            onChanged: onBandChanged == null
                                ? null
                                : (v) => onBandChanged!.call(i, v),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              enabled ? 'Активен' : 'Отключён',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled
                    ? accent.withValues(alpha: 0.95)
                    : cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalEqBand extends StatelessWidget {
  final String label;
  final double value;
  final Color accent;
  final bool enabled;
  final ValueChanged<double>? onChanged;

  const _VerticalEqBand({
    required this.label,
    required this.value,
    required this.accent,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          _DbReadout(value01: value, enabled: enabled),
          const SizedBox(height: 6),
          Expanded(
            child: RotatedBox(
              quarterTurns: -1,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: accent,
                  inactiveTrackColor: cs.onSurface.withValues(alpha: 0.12),
                  thumbColor: accent,
                  overlayColor: accent.withValues(alpha: 0.12),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                ),
                child: Slider(
                  value: value,
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: cs.onSurface.withValues(alpha: 0.75),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DbReadout extends StatelessWidget {
  final double value01;
  final bool enabled;

  const _DbReadout({
    required this.value01,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final db = ((value01 - 0.5) * 24.0);

    final rounded = (db * 10).round() / 10;
    final sign = rounded > 0 ? '+' : '';

    return Text(
      '$sign${rounded.toStringAsFixed(1)}',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: enabled
            ? cs.favorite.withValues(alpha: 0.95)
            : cs.onSurface.withValues(alpha: 0.55),
        letterSpacing: 0.2,
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final Widget child;

  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.enabled,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GlassSurface.card(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: cs.onSurface.withValues(alpha: 0.75)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: enabled ? 1.0 : 0.65,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  final String label;
  final double value;
  final Color accent;
  final ValueChanged<double>? onChanged;

  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const Spacer(),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: accent,
            inactiveTrackColor: cs.onSurface.withValues(alpha: 0.12),
            thumbColor: accent,
            overlayColor: accent.withValues(alpha: 0.10),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
