import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/mihomo_profile.dart';
import '../services/mihomo_channel.dart';
import '../state/app_state.dart';
import 'mili_i18n.dart';
import 'theme.dart';

const _mihomoGreen = Color(0xFF34D399);
const _mihomoAmber = Color(0xFFFBBF24);
const _mihomoRed = Color(0xFFF87171);
const _mihomoCyan = Color(0xFF22D3EE);
const _mihomoSubsKey = 'mihomo.subscriptions.v1';

class MihomoPage extends StatefulWidget {
  const MihomoPage({super.key});

  @override
  State<MihomoPage> createState() => _MihomoPageState();
}

class _MihomoNode {
  final String name;
  final String type;
  final int? delay;
  final bool selected;

  const _MihomoNode({
    required this.name,
    required this.type,
    this.delay,
    this.selected = false,
  });

  _MihomoNode copyWith({int? delay, bool? selected}) => _MihomoNode(
    name: name,
    type: type,
    delay: delay ?? this.delay,
    selected: selected ?? this.selected,
  );
}

class _MihomoPageState extends State<MihomoPage> {
  final _searchController = TextEditingController();
  StreamSubscription<MihomoStateEvent>? _stateSubscription;
  Timer? _trafficTimer;

  MihomoStateEvent _core = const MihomoStateEvent(state: 'disconnected');
  MihomoTraffic _rate = const MihomoTraffic();
  List<MihomoSubscription> _subscriptions = const [];
  List<_MihomoNode> _nodes = const [];
  String? _selectedNode;
  String _search = '';
  static const _secure = FlutterSecureStorage();

  String? _error;
  bool _loading = true;
  bool _coreBusy = false;
  bool _testing = false;
  bool _refreshing = false;

  bool get _connected => _core.connected;
  bool get _working => _coreBusy || _core.connecting || _core.disconnecting;

  @override
  void initState() {
    super.initState();
    _stateSubscription = MihomoChannel.states.listen(
      _onState,
      onError: (Object error) {
        if (mounted) setState(() => _error = '$error');
      },
    );
    _load();
  }

  @override
  void dispose() {
    _trafficTimer?.cancel();
    _stateSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    String? stored;
    try {
      stored = await _secure.read(key: _mihomoSubsKey);
    } catch (_) {
      // A locked or migrating keystore must not make the whole tab unusable.
    }
    final subscriptions = MihomoSubscription.decodeList(stored);
    MihomoStateEvent? snapshot;
    try {
      snapshot = await MihomoChannel.status();
    } catch (_) {
      // The native channel is unavailable on platform-less widget previews.
    }
    if (!mounted) return;
    setState(() {
      _subscriptions = subscriptions;
      _loading = false;
      if (snapshot != null) _core = snapshot;
    });
    if (snapshot?.connected == true) {
      _startTrafficTicker();
      await _refreshNodes(silent: true);
    }
    if (subscriptions.isEmpty ||
        snapshot?.connected == true ||
        snapshot?.connecting == true) {
      return;
    }
    setState(() => _refreshing = true);
    try {
      await _applyProfile();
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _onState(MihomoStateEvent event) {
    if (!mounted) return;
    setState(() {
      _core = event;
      if (event.error != null && event.error!.isNotEmpty) {
        _error = event.error;
      }
      if (event.connected) _error = null;
    });
    if (event.connected) {
      _startTrafficTicker();
      _refreshNodes(silent: true);
    } else {
      _trafficTimer?.cancel();
      _trafficTimer = null;
      if (event.state == 'disconnected') _rate = const MihomoTraffic();
    }
  }

  void _startTrafficTicker() {
    _trafficTimer?.cancel();
    _trafficTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final value = await MihomoChannel.traffic();
        if (mounted) setState(() => _rate = value);
      } catch (_) {
        // The service can disappear while Android revokes the tunnel.
      }
    });
  }

  Future<void> _applyProfile({bool refreshProviders = false}) async {
    if (_subscriptions.isEmpty) return;
    if (refreshProviders) {
      for (var i = 0; i < _subscriptions.length; i++) {
        try {
          await MihomoChannel.refreshProvider('mili_$i');
        } catch (_) {
          // A provider can be unreachable; setup below reports the useful error.
        }
      }
    }
    await MihomoChannel.setup(
      MihomoConfigBuilder.build(_subscriptions),
    );
    await _refreshNodes();
    if (_nodes.isEmpty) {
      // The provider may still be downloading its first node list; retry once so
      // opening the tab or connecting does not require a manual refresh.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await _refreshNodes(silent: true);
    }
  }

  Future<void> _refreshNodes({bool silent = false}) async {
    if (silent == false && mounted) setState(() => _refreshing = true);
    try {
      final raw = await MihomoChannel.proxies();
      final parsed = _parseProxies(raw);
      if (mounted) {
        setState(() {
          _nodes = parsed.nodes;
          _selectedNode = parsed.selected ?? _selectedNode;
          if (silent == false) _error = null;
        });
      }
    } catch (e) {
      if (mounted && !silent) setState(() => _error = _message(e));
    } finally {
      if (mounted && !silent) setState(() => _refreshing = false);
    }
  }

  ({List<_MihomoNode> nodes, String? selected}) _parseProxies(String raw) {
    final nodes = <_MihomoNode>[];
    final seen = <String>{};
    String? selected;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return (nodes: nodes, selected: null);
      final proxies = decoded['proxies'];
      if (proxies is! Map) return (nodes: nodes, selected: null);
      for (final entry in proxies.entries) {
        final name = entry.key.toString();
        final value = entry.value;
        if (value is! Map) continue;
        final type = value['type']?.toString() ?? '';
        if (name == MihomoConfigBuilder.groupName) {
          selected = value['now']?.toString();
          continue;
        }
        if (const {
          'Selector',
          'URLTest',
          'Fallback',
          'LoadBalance',
          'Relay',
          'Direct',
          'Reject',
          'RejectDrop',
          'Pass',
          'Compatible',
          'Dns',
        }.contains(type)) {
          continue;
        }
        if (seen.add(name) == false) continue;
        int? delay;
        final history = value['history'];
        if (history is List && history.isNotEmpty) {
          final last = history.last;
          if (last is Map) delay = (last['delay'] as num?)?.toInt();
        }
        nodes.add(
          _MihomoNode(
            name: name,
            type: type,
            delay: delay == null || delay <= 0 ? null : delay,
            selected: name == selected,
          ),
        );
      }
    } catch (_) {
      // The UI keeps its empty state when the core is not ready yet.
    }
    return (nodes: nodes, selected: selected);
  }

  Future<void> _testAll() async {
    if (_nodes.isEmpty || _testing) return;
    setState(() => _testing = true);
    HapticFeedback.selectionClick();
    try {
      final raw = await MihomoChannel.testGroups([
        MihomoConfigBuilder.groupName,
      ]);
      final values = _parseDelays(raw);
      if (!mounted) return;
      if (values.isNotEmpty) {
        setState(() {
          _nodes = [
            for (final node in _nodes)
              node.copyWith(
                delay: values[node.name] ?? node.delay,
              ),
          ];
        });
      } else {
        // Some provider layouts don't expose a group result; test individually.
        for (final node in List<_MihomoNode>.of(_nodes)) {
          try {
            final delay = await MihomoChannel.testDelay(node.name);
            if (mounted && delay > 0) {
              setState(() {
                _nodes = [
                  for (final n in _nodes)
                    n.name == node.name ? n.copyWith(delay: delay) : n,
                ];
              });
            }
          } catch (_) {}
        }
      }
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Map<String, int> _parseDelays(String raw) {
    final result = <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is! Map) continue;
          final name = item['name']?.toString();
          final value = (item['value'] as num?)?.toInt() ?? 0;
          if (name != null && value > 0) result[name] = value;
        }
      }
    } catch (_) {}
    return result;
  }

  Future<void> _pingNode(_MihomoNode node) async {
    try {
      final delay = await MihomoChannel.testDelay(node.name);
      if (!mounted) return;
      setState(() {
        _nodes = [
          for (final item in _nodes)
            item.name == node.name
                ? item.copyWith(delay: delay > 0 ? delay : null)
                : item,
        ];
      });
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  Future<void> _selectNode(_MihomoNode node) async {
    HapticFeedback.selectionClick();
    try {
      await MihomoChannel.select(node.name);
      if (!mounted) return;
      setState(() {
        _selectedNode = node.name;
        _nodes = [
          for (final item in _nodes)
            item.copyWith(selected: item.name == node.name),
        ];
      });
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  Future<void> _selectFastest() async {
    if (_testing) return;
    if (_nodes.every((node) => node.delay == null)) {
      await _testAll();
    }
    final available = _nodes.where((node) => node.delay != null).toList()
      ..sort((a, b) => a.delay!.compareTo(b.delay!));
    if (available.isNotEmpty && mounted) await _selectNode(available.first);
  }

  Future<void> _connect() async {
    if (_working || _refreshing) return;
    if (_subscriptions.isEmpty) {
      setState(
        () => _error = MiliLocale.t(
          'اول یک سابلینک Mihomo اضافه کنید',
          'Add a Mihomo subscription first',
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _coreBusy = true;
      _error = null;
    });
    final main = AppScope.read(context);
    try {
      // Android has only one VPN slot. Let the Xray tunnel finish stopping first.
      if (main.isConnected) {
        await main.disconnect();
        for (var i = 0; i < 40 && main.isConnected; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        if (main.isConnected) {
          throw StateError(
            MiliLocale.t(
              'ابتدا اتصال اصلی را قطع کنید',
              'Stop the main VPN before connecting Mihomo',
            ),
          );
        }
      }
      await _applyProfile();
      if (!mounted) return;
      if (_nodes.isEmpty) {
        throw StateError(
          MiliLocale.t(
            'سابلینک هنوز نودی برنگرداند؛ دوباره تلاش کنید',
            'The subscription has not returned a node yet; try again',
          ),
        );
      }
      if (_selectedNode == null || _selectedNode == 'DIRECT') {
        // A fresh provider config starts on DIRECT, which would connect without
        // proxying. Pick the first real node before opening the TUN device.
        await _selectNode(_nodes.first);
      }
      if (!mounted) return;
      await MihomoChannel.start();
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _coreBusy = false);
    }
  }

  Future<void> _disconnect() async {
    if (_coreBusy) return;
    setState(() => _coreBusy = true);
    try {
      await MihomoChannel.stop();
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _coreBusy = false);
    }
  }

  Future<void> _refreshAll() async {
    if (_subscriptions.isEmpty || _working) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      if (_connected) {
        for (var i = 0; i < _subscriptions.length; i++) {
          await MihomoChannel.refreshProvider('mili_$i');
        }
        await _refreshNodes();
      } else {
        await _applyProfile(refreshProviders: true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _addSubscription() async {
    final added = await showDialog<MihomoSubscription>(
      context: context,
      builder: (_) => const _AddSubscriptionDialog(),
    );
    if (added == null || !mounted) return;
    final next = [..._subscriptions, added];
    if (_connected || _core.connecting || _core.disconnecting) {
      await _disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    if (!mounted) return;
    try {
      await _saveSubscriptions(next);
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
      return;
    }
    if (!mounted) return;
    setState(() {
      _subscriptions = next;
      _error = null;
    });
    setState(() => _refreshing = true);
    try {
      await _applyProfile();
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _removeSubscription(MihomoSubscription subscription) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(MiliLocale.t('حذف سابلینک؟', 'Remove subscription?')),
        content: Text(
          MiliLocale.t(
            'سابلینک «${subscription.name}» از کلاینت Mihomo حذف می‌شود. پروفایل اصلی VPN تغییری نمی‌کند.',
            'The “${subscription.name}” subscription is removed from Mihomo. Your main VPN profile is not changed.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MiliLocale.t('انصراف', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(MiliLocale.t('حذف', 'Remove')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_connected || _core.connecting || _core.disconnecting) {
      await _disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    if (!mounted) return;
    final next = _subscriptions
        .where((item) => item.id != subscription.id)
        .toList();
    try {
      await _saveSubscriptions(next);
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
      return;
    }
    if (!mounted) return;
    setState(() {
      _subscriptions = next;
      _nodes = next.isEmpty ? [] : _nodes;
      _selectedNode = null;
    });
    if (next.isEmpty) {
      if (_connected || _core.connecting) await _disconnect();
      return;
    }
    setState(() => _refreshing = true);
    try {
      await _applyProfile();
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _saveSubscriptions(List<MihomoSubscription> items) async {
    await _secure.write(
      key: _mihomoSubsKey,
      value: MihomoSubscription.encodeList(items),
    );
  }

  String? _message(Object error) {
    final raw = error is StateError ? error.message : error.toString();
    // Provider/core errors can echo the subscription URL; never surface its token.
    return raw.replaceAll(RegExp(r'https?://\S+'), 'subscription');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filtered = _nodes
        .where(
          (node) =>
              _search.isEmpty ||
              node.name.toLowerCase().contains(_search.toLowerCase()) ||
              node.type.toLowerCase().contains(_search.toLowerCase()),
        )
        .toList();

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
        children: [
          _MihomoHero(
            core: _core,
            busy: _working,
            subscriptions: _subscriptions.length,
            nodes: _nodes.length,
            rate: _rate,
            onToggle: _connected ? _disconnect : _connect,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(
              message: _error!,
              onDismiss: () => setState(() => _error = null),
            ),
          ],
          const SizedBox(height: 20),
          _MihomoSectionHeader(
            title: MiliLocale.t('سابلینک‌ها', 'Subscriptions'),
            subtitle: MiliLocale.t(
              'Mihomo خودش لینک‌های YAML، URI و Base64 را می‌خواند',
              'Mihomo reads YAML, URI lists and Base64 links directly',
            ),
            actions: [
              IconButton(
                tooltip: MiliLocale.t('افزودن سابلینک', 'Add subscription'),
                onPressed: _addSubscription,
                icon: const Icon(Symbols.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_subscriptions.isEmpty)
            _MihomoEmptyCard(
              icon: Symbols.link_rounded,
              title: MiliLocale.t('هنوز سابلینکی ندارید', 'No subscriptions yet'),
              body: MiliLocale.t(
                'لینک اشتراک Clash/Mihomo را اضافه کنید؛ این بخش کاملاً مستقل از پروفایل Xray کار می‌کند.',
                'Add a Clash/Mihomo subscription link. This section is fully independent from your Xray profile.',
              ),
              action: FilledButton.icon(
                onPressed: _addSubscription,
                icon: const Icon(Symbols.add_link_rounded),
                label: Text(MiliLocale.t('افزودن اولین سابلینک', 'Add first subscription')),
              ),
            )
          else
            for (var i = 0; i < _subscriptions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _SubscriptionTile(
                  subscription: _subscriptions[i],
                  index: i,
                  onRemove: () => _removeSubscription(_subscriptions[i]),
                ),
              ),
          const SizedBox(height: 20),
          _MihomoSectionHeader(
            title: MiliLocale.t('نودها', 'Nodes'),
            subtitle: _nodes.isEmpty
                ? MiliLocale.t(
                    'پس از افزودن سابلینک، نودها اینجا ظاهر می‌شوند',
                    'Nodes appear here after you add a subscription',
                  )
                : MiliLocale.t(
                    '${_nodes.length} نود · تست همزمان پینگ',
                    '${_nodes.length} nodes · concurrent latency test',
                  ),
            actions: [
              IconButton(
                tooltip: MiliLocale.t('تازه‌سازی', 'Refresh'),
                onPressed: _refreshing || _subscriptions.isEmpty
                    ? null
                    : _refreshAll,
                icon: _refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Symbols.refresh_rounded),
              ),
            ],
          ),
          if (_nodes.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                hintText: MiliLocale.t('جستجوی نود…', 'Search nodes…'),
                prefixIcon: const Icon(Symbols.search_rounded, size: 20),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                        icon: const Icon(Symbols.close_rounded, size: 18),
                      ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _testing ? null : _testAll,
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Symbols.speed_rounded, size: 18),
                    label: Text(
                      _testing
                          ? MiliLocale.t('در حال تست…', 'Testing…')
                          : MiliLocale.t('تست پینگ همه', 'Ping all'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _testing ? null : _selectFastest,
                  icon: const Icon(Symbols.bolt_rounded, size: 18),
                  label: Text(MiliLocale.t('سریع‌ترین', 'Fastest')),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final node in filtered)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _NodeTile(
                  node: node,
                  selected: node.selected || node.name == _selectedNode,
                  onTap: () => _selectNode(node),
                  onPing: () => _pingNode(node),
                ),
              ),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    MiliLocale.t('نودی با این جستجو پیدا نشد', 'No nodes match your search'),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
          ] else if (_subscriptions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: _MihomoEmptyCard(
                icon: Symbols.cloud_download_rounded,
                title: MiliLocale.t('در حال آماده‌سازی نودها', 'Preparing nodes'),
                body: MiliLocale.t(
                  'سابلینک ذخیره شده است. دکمه تازه‌سازی را بزنید یا چند لحظه صبر کنید؛ Mihomo در حال خواندن پروفایل است.',
                  'Your subscription is saved. Tap refresh or wait a moment while Mihomo reads the profile.',
                ),
                action: OutlinedButton.icon(
                  onPressed: _refreshAll,
                  icon: const Icon(Symbols.refresh_rounded),
                  label: Text(MiliLocale.t('تلاش دوباره', 'Try again')),
                ),
              ),
            ),
          const SizedBox(height: 18),
          const _MihomoIsolationNote(),
        ],
      ),
    );
  }
}

class _MihomoHero extends StatelessWidget {
  final MihomoStateEvent core;
  final bool busy;
  final int subscriptions;
  final int nodes;
  final MihomoTraffic rate;
  final VoidCallback onToggle;

  const _MihomoHero({
    required this.core,
    required this.busy,
    required this.subscriptions,
    required this.nodes,
    required this.rate,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final connected = core.connected;
    final accent = connected
        ? _mihomoGreen
        : (core.error != null ? _mihomoRed : _mihomoCyan);
    final status = switch (core.state) {
      'connected' => MiliLocale.t('متصل', 'Connected'),
      'connecting' => MiliLocale.t('در حال اتصال…', 'Connecting…'),
      'disconnecting' => MiliLocale.t('در حال قطع…', 'Disconnecting…'),
      _ => MiliLocale.t('آماده', 'Ready'),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            accent.withValues(alpha: 0.17),
            scheme.surfaceContainerHigh.withValues(alpha: 0.78),
            scheme.primary.withValues(alpha: 0.10),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 26,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: accent.withValues(alpha: 0.16),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Icon(Symbols.bolt_rounded, color: accent, size: 25),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Mihomo',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            'TUN',
                            style: TextStyle(
                              color: accent,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${MiliLocale.t('مستقل از Xray', 'Independent of Xray')} · v1.19.34',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              _MihomoStatusDot(color: accent),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        color: connected ? accent : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      connected
                          ? '${MiliLocale.t('دانلود', 'Down')} ${_bytes(rate.down)}/s  ·  ${MiliLocale.t('آپلود', 'Up')} ${_bytes(rate.up)}/s'
                          : MiliLocale.t(
                              '$subscriptions سابلینک · $nodes نود آماده',
                              '$subscriptions subscriptions · $nodes nodes ready',
                            ),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: busy ? null : onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(19),
                    color: connected ? _mihomoRed : accent,
                  ),
                  child: Center(
                    child: busy
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            connected
                                ? Symbols.stop_rounded
                                : Symbols.play_arrow_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _MiniPill(
                icon: Symbols.alt_route_rounded,
                label: MiliLocale.t('هسته Mihomo', 'Mihomo core'),
              ),
              _MiniPill(
                icon: Symbols.speed_rounded,
                label: MiliLocale.t('تست پینگ سریع', 'Fast ping'),
              ),
              _MiniPill(
                icon: Symbols.lock_rounded,
                label: MiliLocale.t('پروفایل جدا', 'Separate profile'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.54),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MihomoStatusDot extends StatelessWidget {
  final Color color;
  const _MihomoStatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 8),
        ],
      ),
    );
  }
}

class _MihomoSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;
  const _MihomoSectionHeader({
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  final MihomoSubscription subscription;
  final int index;
  final VoidCallback onRemove;
  const _SubscriptionTile({
    required this.subscription,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final host = Uri.tryParse(subscription.url)?.host ?? subscription.url;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _mihomoCyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Symbols.link_rounded,
              size: 18,
              color: _mihomoCyan,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subscription.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  host,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _mihomoGreen.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              'mili_$index',
              style: const TextStyle(
                color: _mihomoGreen,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: MiliLocale.t('حذف سابلینک', 'Remove subscription'),
            onPressed: onRemove,
            icon: Icon(
              Symbols.delete_outline_rounded,
              size: 19,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeTile extends StatelessWidget {
  final _MihomoNode node;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onPing;
  const _NodeTile({
    required this.node,
    required this.selected,
    required this.onTap,
    required this.onPing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final delayColor = node.delay == null
        ? scheme.onSurfaceVariant
        : node.delay! < 250
        ? _mihomoGreen
        : node.delay! < 700
        ? _mihomoAmber
        : _mihomoRed;
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.10)
          : scheme.surfaceContainer.withValues(alpha: 0.50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kSmallCardRadius),
        side: BorderSide(
          color: selected
              ? scheme.primary.withValues(alpha: 0.55)
              : scheme.outlineVariant.withValues(alpha: 0.72),
          width: selected ? 1.1 : 0.8,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(kSmallCardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 4, 9),
          child: Row(
            children: [
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? scheme.primary.withValues(alpha: 0.17)
                      : scheme.surfaceContainerHigh.withValues(alpha: 0.7),
                ),
                child: Icon(
                  Symbols.hub_rounded,
                  size: 16,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    Text(
                      node.type.isEmpty
                          ? MiliLocale.t('نود Mihomo', 'Mihomo node')
                          : node.type,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                node.delay == null
                    ? MiliLocale.t('تست کنید', 'Test')
                    : '${node.delay}ms',
                style: TextStyle(
                  color: delayColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: MiliLocale.t('تست پینگ', 'Ping'),
                onPressed: onPing,
                icon: const Icon(Symbols.speed_rounded, size: 17),
              ),
              if (selected)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 5),
                  child: Icon(
                    Symbols.check_circle_rounded,
                    size: 18,
                    color: scheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MihomoEmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget action;
  const _MihomoEmptyCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: scheme.surfaceContainer.withValues(alpha: 0.46),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Column(
        children: [
          Icon(icon, color: _mihomoCyan, size: 27),
          const SizedBox(height: 7),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 13),
          action,
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 9, 4, 9),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Symbols.error_outline_rounded, size: 19, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onErrorContainer, fontSize: 11.5),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: const Icon(Symbols.close_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}

class _MihomoIsolationNote extends StatelessWidget {
  const _MihomoIsolationNote();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: scheme.surfaceContainer.withValues(alpha: 0.34),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Symbols.shield_rounded,
            size: 17,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              MiliLocale.t(
                'این تب پروفایل، نودها و تونل جداگانه دارد. Android همزمان فقط یک VPN فعال می‌کند؛ اتصال Mihomo اتصال اصلی را متوقف می‌کند.',
                'This tab has its own profile, nodes and tunnel. Android allows one active VPN, so Mihomo stops the main connection when it starts.',
              ),
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 10.5,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddSubscriptionDialog extends StatefulWidget {
  const _AddSubscriptionDialog();

  @override
  State<_AddSubscriptionDialog> createState() => _AddSubscriptionDialogState();
}

class _AddSubscriptionDialogState extends State<_AddSubscriptionDialog> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    final url = _url.text.trim();
    final uri = Uri.tryParse(url);
    if (url.isEmpty ||
        uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      setState(() {
        _error = MiliLocale.t(
          'یک لینک معتبر http یا https وارد کنید',
          'Enter a valid http or https link',
        );
      });
      return;
    }
    final name = _name.text.trim();
    Navigator.of(context).pop(
      MihomoSubscription(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.isEmpty
            ? (uri.host.isEmpty ? 'Subscription' : uri.host)
            : name,
        url: url,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(MiliLocale.t('افزودن سابلینک', 'Add subscription')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: MiliLocale.t('نام (اختیاری)', 'Name (optional)'),
                hintText: MiliLocale.t('مثلاً سرورهای من', 'e.g. My servers'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: MiliLocale.t('لینک سابلینک', 'Subscription URL'),
                hintText: 'https://example.com/sub',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MiliLocale.t('انصراف', 'Cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(MiliLocale.t('افزودن', 'Add')),
        ),
      ],
    );
  }
}

String _bytes(int value) {
  if (value < 1024) return '$value B';
  if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
  return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
}
