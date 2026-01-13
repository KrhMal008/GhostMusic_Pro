import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ghostmusic/domain/services/http_overrides.dart';
import 'package:ghostmusic/domain/state/playback_controller.dart';
import 'package:ghostmusic/domain/state/playback_state.dart';
import 'package:ghostmusic/ui/audio/equalizer_tab.dart';
import 'package:ghostmusic/ui/library/library_tab.dart';
import 'package:ghostmusic/ui/player/mini_player.dart';
import 'package:ghostmusic/ui/player/now_playing_route.dart';
import 'package:ghostmusic/ui/theme/app_theme.dart';
import 'package:ghostmusic/ui/widgets/glass_app_bar.dart';
import 'package:ghostmusic/ui/widgets/glass_surface.dart';



final discogsTokenProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('discogs_token');
});

final proxyRuleProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('proxy_rule');
});

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with SingleTickerProviderStateMixin {
  int _index = 0;

  late final AnimationController _tabTransition;
  late final Animation<double> _tabTransitionCurve;

  @override
  void initState() {
    super.initState();
    _tabTransition = AnimationController(vsync: this, duration: AppDuration.medium);
    _tabTransitionCurve = CurvedAnimation(parent: _tabTransition, curve: AppCurves.enter);
    _tabTransition.value = 1.0;
  }

  @override
  void dispose() {
    _tabTransition.dispose();
    super.dispose();
  }

  void _setIndex(int value) {
    if (value == _index) return;

    _tabTransition
      ..stop()
      ..value = 0.0;

    setState(() => _index = value);
    _tabTransition.forward();
  }

  Future<void> _openNowPlaying() async {
    HapticFeedback.selectionClick();
    await NowPlayingRoute.open(context);
  }

  @override
  Widget build(BuildContext context) {
    final PlaybackState playback = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _tabTransitionCurve,
        builder: (context, child) {
          return FadeTransition(
            opacity: _tabTransitionCurve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.01),
                end: Offset.zero,
              ).animate(_tabTransitionCurve),
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 0.985,
                  end: 1.0,
                ).animate(_tabTransitionCurve),
                child: child!,
              ),
            ),
          );
        },
        child: IndexedStack(

          index: _index,
          children: const [
            LibraryTab(),
            EqualizerTab(),
            _SearchTab(),
            _SettingsTab(),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: MiniPlayer(
              onTap: _openNowPlaying,
              onNext: controller.next,
              onPrevious: controller.previous,
              onPlayPause: controller.togglePlayPause,
            ),
          ),
          _BottomTabs(
            index: _index,
            hasNowPlaying: playback.hasTrack,
            onChanged: _setIndex,
          ),
        ],
      ),

    );
  }
}

class _BottomTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final bool hasNowPlaying;

  const _BottomTabs({
    required this.index,
    required this.onChanged,
    required this.hasNowPlaying,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),

      child: GlassSurface.tabBar(
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _TabButton(
                label: 'Медиатека',
                icon: Icons.library_music_rounded,
                selected: index == 0,
                onTap: () => onChanged(0),
              ),
              _TabButton(
                label: 'EQ',
                icon: Icons.equalizer_rounded,
                selected: index == 1,
                onTap: () => onChanged(1),
              ),
              _TabButton(
                label: 'Поиск',
                icon: Icons.search_rounded,
                selected: index == 2,
                onTap: () => onChanged(2),
              ),
              _TabButton(
                label: 'Настройки',
                icon: Icons.settings_rounded,
                selected: index == 3,
                onTap: () => onChanged(3),
              ),
              if (hasNowPlaying)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                       color: cs.favorite,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final selectedColor = cs.favorite;
    final color = selected ? selectedColor : cs.onSurface.withValues(alpha: 0.65);

    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  color: color,
                  letterSpacing: -0.1,
                ),

              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchTab extends StatelessWidget {
  const _SearchTab();

  @override
  Widget build(BuildContext context) {
    final bottomOverlay =
        MediaQuery.paddingOf(context).bottom + AppHitTarget.tabBarHeight + AppHitTarget.miniPlayerHeight;

    return CustomScrollView(
      slivers: [
        const GlassSliverAppBar.large(title: Text('Поиск')),

        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          sliver: SliverToBoxAdapter(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Артисты, альбомы, треки',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: bottomOverlay + 24)),

      ],
    );
  }
}

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlaybackState state = ref.watch(playbackControllerProvider);
    final ctrl = ref.read(playbackControllerProvider.notifier);

    final bottomOverlay =
        MediaQuery.paddingOf(context).bottom + AppHitTarget.tabBarHeight + AppHitTarget.miniPlayerHeight;

    return CustomScrollView(

      slivers: [
        const GlassSliverAppBar.large(title: Text('Настройки')),

        SliverToBoxAdapter(
          child: Column(
            children: [
              SwitchListTile.adaptive(
                title: const Text('Перемешать'),
                value: state.shuffleEnabled,
                onChanged: (_) => ctrl.toggleShuffle(),
              ),
              ListTile(
                title: const Text('Повтор'),
                subtitle: Text('Режим: ${state.repeatMode}'),
                onTap: ctrl.toggleRepeat,
              ),
              ListTile(
                title: Text(state.isPlaying ? 'Пауза' : 'Воспроизвести'),
                onTap: ctrl.togglePlayPause,
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded),
                title: const Text('Автомикс'),
                subtitle: Text(
                  state.automixEnabled
                      ? 'Вкл • ${state.automixProfile == AutomixProfile.smooth ? 'Smooth' : 'Club'}'
                      : 'Выкл',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _AutomixSettingsSheet.show(context),
              ),
              const Divider(height: 24),
              if (kDebugMode && defaultTargetPlatform == TargetPlatform.windows)
                const _ProxyTile(),
              const _DiscogsTokenTile(),
              SizedBox(height: bottomOverlay + 24),

            ],
          ),
        ),
      ],
    );
  }
}

class _AutomixSettingsSheet extends ConsumerWidget {
  const _AutomixSettingsSheet();

  static Future<void> show(BuildContext context) {
    HapticFeedback.selectionClick();

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: AppOpacity.scrim),
      builder: (_) => const _AutomixSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final playback = ref.watch(playbackControllerProvider);
    final ctrl = ref.read(playbackControllerProvider.notifier);

    final enabled = playback.automixEnabled;
    final eqAvailable = defaultTargetPlatform == TargetPlatform.windows;

    final planned = playback.automixCrossfade;
    final plannedLabel = planned.inMilliseconds <= 0 ? 'auto' : '${planned.inSeconds}с';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: GlassSurface(
          variant: GlassVariant.solid,
          shape: GlassShape.roundedLarge,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GlassHandle(),
              const SizedBox(height: 10),
              Text('Автомикс', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Анализирует хвост трека (≈ последняя минута), выбирает музыкально правильный момент и сводит как DJ: beatmatch + EQ (если доступно).',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Включить'),
                subtitle: const Text('Автоматически сводить треки'),
                value: enabled,
                onChanged: (v) => ctrl.setAutomixEnabled(v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timelapse_rounded),
                title: const Text('Длина перехода'),
                subtitle: Text('Авто • обычно $plannedLabel'),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Beatmatch'),
                subtitle: const Text('Подгонять темп к текущему треку'),
                value: enabled && playback.automixBeatmatch,
                onChanged: enabled ? (v) => ctrl.setAutomixBeatmatchEnabled(v) : null,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('DJ‑EQ (bass swap)'),
                subtitle: Text(eqAvailable ? 'Сводить низ/бас как диджей' : 'Доступно на Windows (MediaKit)'),
                value: enabled && playback.automixEq,
                onChanged: (enabled && eqAvailable) ? (v) => ctrl.setAutomixEqEnabled(v) : null,
              ),
              const SizedBox(height: 10),
              Text(
                'Стиль',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface.withValues(alpha: 0.75),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<AutomixProfile>(
                segments: const [
                  ButtonSegment(value: AutomixProfile.smooth, label: Text('Smooth')),
                  ButtonSegment(value: AutomixProfile.club, label: Text('Club')),
                ],
                selected: {playback.automixProfile},
                onSelectionChanged: enabled ? (s) => ctrl.setAutomixProfile(s.first) : null,
              ),
              const SizedBox(height: 8),
              Text(
                'Во время сведения в Now Playing появится “ghost mixing”.',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProxyTile extends ConsumerWidget {
  const _ProxyTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxyAsync = ref.watch(proxyRuleProvider);

    final subtitle = proxyAsync.when(
      data: (value) {
        final v = value?.trim();
        if (v == null || v.isEmpty) return 'DIRECT (без прокси)';
        if (v.length <= 42) return v;
        return '${v.substring(0, 42)}…';
      },
      loading: () => 'Загрузка…',
      error: (_, __) => 'Ошибка чтения',
    );

    return ListTile(
      leading: const Icon(Icons.router_rounded),
      title: const Text('HTTP proxy (Windows debug)'),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        final current = proxyAsync.valueOrNull ?? '';
        final controller = TextEditingController(text: current);

        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black.withValues(alpha: AppOpacity.scrim),
          builder: (ctx) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: GlassSurface(
                  variant: GlassVariant.solid,
                  shape: GlassShape.roundedLarge,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const GlassHandle(),
                      const SizedBox(height: 10),
                      Text(
                        'HTTP proxy (Windows debug)',
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),

                    const SizedBox(height: 8),
                    Text(
                      'Полезно если запросы к iTunes/MusicBrainz/Wikimedia таймаутятся. Форматы: '
                      '"127.0.0.1:7890", "http://127.0.0.1:7890" или "PROXY 127.0.0.1:7890; DIRECT".',
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Proxy',
                        hintText: 'DIRECT / host:port / PROXY host:port; DIRECT',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(ctx);
                          final raw = controller.text.trim();
                          GhostHttpOverrides.setProxyFromUserInput(raw.isEmpty ? null : raw);

                          try {
                            final uri = Uri.https('itunes.apple.com', '/search', {
                              'term': 'test',
                              'entity': 'album',
                              'limit': '1',
                            });

                            final resp = await http
                                .get(uri, headers: {
                                  'User-Agent': 'GhostMusic/1.0',
                                  'Accept': 'application/json',
                                })
                                .timeout(const Duration(seconds: 10));

                            messenger.showSnackBar(
                              SnackBar(content: Text('Проверка iTunes: ${resp.statusCode}')),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Проверка не удалась: $e')),
                            );
                          }
                        },
                        icon: const Icon(Icons.network_check_rounded),
                        label: const Text('Проверить iTunes'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.remove('proxy_rule');
                              GhostHttpOverrides.setProxyFromUserInput(null);
                              ref.invalidate(proxyRuleProvider);
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            },
                            child: const Text('Очистить'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              final raw = controller.text.trim();
                              final prefs = await SharedPreferences.getInstance();
                              if (raw.isEmpty) {
                                await prefs.remove('proxy_rule');
                                GhostHttpOverrides.setProxyFromUserInput(null);
                              } else {
                                await prefs.setString('proxy_rule', raw);
                                GhostHttpOverrides.setProxyFromUserInput(raw);
                              }
                              ref.invalidate(proxyRuleProvider);
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            },
                            child: const Text('Сохранить'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );

          },
        );
      },
    );
  }
}

class _DiscogsTokenTile extends ConsumerWidget {
  const _DiscogsTokenTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokenAsync = ref.watch(discogsTokenProvider);

    final subtitle = tokenAsync.when(
      data: (token) {
        final v = token?.trim();
        if (v == null || v.isEmpty) return 'Не задан (Discogs выключен)';
        return 'Задан';
      },
      loading: () => 'Загрузка…',
      error: (_, __) => 'Ошибка чтения',
    );

    return ListTile(
      leading: const Icon(Icons.public_rounded),
      title: const Text('Discogs token'),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        final current = tokenAsync.valueOrNull ?? '';
        final controller = TextEditingController(text: current);

        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black.withValues(alpha: AppOpacity.scrim),
          builder: (ctx) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: GlassSurface(
                  variant: GlassVariant.solid,
                  shape: GlassShape.roundedLarge,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const GlassHandle(),
                      const SizedBox(height: 10),
                      Text(
                        'Discogs API token',
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),

                    const SizedBox(height: 8),
                    Text(
                      'Нужен только чтобы искать обложки на Discogs. Без токена используется MusicBrainz/CAA и iTunes.',
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Token',
                        hintText: 'вставь token…',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Где взять токен: Discogs → Settings → Developer → Generate new token (Personal access token).',
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(ctx);
                          final token = controller.text.trim();
                          if (token.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Сначала вставь токен')),
                            );
                            return;
                          }

                          try {
                            final uri = Uri.https('api.discogs.com', '/oauth/identity');
                            final resp = await http
                                .get(uri, headers: {
                                  'User-Agent': 'GhostMusic/1.0 (contact: dev@local)',
                                  'Accept': 'application/json',
                                  'Authorization': 'Discogs token=$token',
                                })
                                .timeout(const Duration(seconds: 10));

                            if (resp.statusCode == 200) {
                              final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
                              final username = decoded['username'] as String?;
                              messenger.showSnackBar(
                                SnackBar(content: Text('Discogs OK${username == null ? '' : ': $username'}')),
                              );
                            } else {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Discogs ответ: ${resp.statusCode}')),
                              );
                            }
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Проверка не удалась: $e')),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Проверить токен'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.remove('discogs_token');
                              ref.invalidate(discogsTokenProvider);
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            },
                            child: const Text('Очистить'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              final token = controller.text.trim();
                              final prefs = await SharedPreferences.getInstance();
                              if (token.isEmpty) {
                                await prefs.remove('discogs_token');
                              } else {
                                await prefs.setString('discogs_token', token);
                              }
                              ref.invalidate(discogsTokenProvider);
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            },
                            child: const Text('Сохранить'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );

          },
        );
      },
    );
  }
}
