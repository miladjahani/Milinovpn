import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/settings.dart';
import '../services/chain_proxy.dart';
import '../services/my_ip.dart';
import '../services/xray_config.dart';
import '../state/app_state.dart';
import 'chip_menu.dart';
import 'mili_i18n.dart';
import 'theme.dart';

/// The connection's settings, above the status card: its type and mode, and where traffic
/// leaves for the internet (the connection itself, the chain proxy, or Psiphon / Tor in a
/// chosen region).
class ConnectionCard extends StatelessWidget {
  const ConnectionCard({super.key});

  static const _rowAnimation = Duration(milliseconds: 250);

  /// What the exit carries: the worker relays only TCP, Tor too; WARP, MASQUE and Psiphon also
  /// UDP; the chain proxy depends on its protocol ([ChainInfo.carries]).
  static List<String> _transports(
    ExitNode node,
    ConnectionMode mode, {
    required ChainProxy? chain,
  }) => switch (node) {
    ExitNode.worker => switch (mode) {
      ConnectionMode.worker => const ['TCP'],
      ConnectionMode.warp || ConnectionMode.masque => const ['TCP', 'UDP'],
      _ => const [],
    },
    ExitNode.chain =>
      chain == null ? const [] : ChainInfo.of(chain.link)?.carries ?? const [],
    ExitNode.psiphon => const ['TCP', 'UDP'],
    ExitNode.tor => const ['TCP'],
  };

  static String _regionLabel(String code) => code.isEmpty
      ? 'Fastest'
      : '${countryFlag(code)} ${exitRegions[code] ?? code}';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final exit = state.exitNode;
    final isServerlessDns =
        state.mode == ConnectionMode.serverless &&
        state.serverlessMode == ServerlessMode.dns;
    // The Psiphon and Tor types have no exit node to choose: only the region can change.
    final hasExitNode =
        state.mode != ConnectionMode.psiphon &&
        state.mode != ConnectionMode.tor &&
        state.mode != ConnectionMode.node &&
        !isServerlessDns;
    final nodes = switch (state.mode) {
      ConnectionMode.serverless => state.serverlessMode ==
              ServerlessMode.domainFronting
          ? [ExitNode.worker, ExitNode.psiphon]
          : [ExitNode.worker, ExitNode.psiphon, ExitNode.tor],
      // The chain proxy is an exit node once there's one the type can carry (Settings → Chain proxies).
      _ => [
        for (final n in ExitNode.values)
          if (n != ExitNode.chain || state.usableChains.isNotEmpty) n,
      ],
    };
    final chain = state.exitChain;
    final nodeChain = state.nodeChain;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      shape: roundedShape(
        kHeroRadius,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.75),
          width: 0.75,
        ),
      ),
      color: scheme.surfaceContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Row(
              icon: Symbols.category_rounded,
              label: 'Connection',
              selector: _TypeSelector(),
            ),
            // Node mode: the standalone proxy this connection dials.
            AnimatedSize(
              duration: _rowAnimation,
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: state.mode == ConnectionMode.node && nodeChain != null
                  ? _Row(
                      icon: Symbols.dns_rounded,
                      label: 'Node',
                      selector: ChipMenu(
                        values: state.usableChains,
                        selected: nodeChain,
                        label: (c) => c.name,
                        subtitleBadges: (c) =>
                            ChainInfo.of(c.link)?.tags ?? const [],
                        onSelected: state.setNode,
                        enabled: !state.isBusy && state.usableChains.length > 1,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            // The variant (Worker, WARP, MASQUE), Serverless's mode or Tor's bridges.
            AnimatedSize(
              duration: _rowAnimation,
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: state.hasModeOption
                  ? const _Row(
                      icon: Symbols.tune_rounded,
                      label: 'Mode',
                      selector: _ModeSelector(),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            AnimatedSize(
              duration: _rowAnimation,
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: hasExitNode
                  ? _Row(
                      icon: Symbols.exit_to_app_rounded,
                      label: 'Exit Node',
                      selector: ChipMenu(
                        values: nodes,
                        selected: exit,
                        label: (n) => switch (n) {
                          ExitNode.worker => 'Default',
                          ExitNode.chain => 'Chain proxy',
                          ExitNode.psiphon => 'Psiphon',
                          ExitNode.tor => 'Tor',
                        },
                        badges: (n) => _transports(n, state.mode, chain: chain),
                        onSelected: state.setExitNode,
                        enabled: !state.isBusy && nodes.length > 1,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            AnimatedSize(
              duration: _rowAnimation,
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: !isServerlessDns &&
                      (exit == ExitNode.psiphon || exit == ExitNode.tor)
                  ? _Row(
                      icon: Symbols.location_on_rounded,
                      label: 'Region',
                      selector: _RegionSelector(
                        selected: state.device.exitRegion,
                        enabled: !state.isBusy,
                        onSelected: state.setExitRegion,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            // The chain proxy this type exits through: names, with their tags in the open menu.
            AnimatedSize(
              duration: _rowAnimation,
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: exit == ExitNode.chain && chain != null
                  ? _Row(
                      icon: Symbols.link_rounded,
                      label: 'Chain',
                      selector: ChipMenu(
                        values: state.usableChains,
                        selected: chain,
                        label: (c) => c.name,
                        subtitleBadges: (c) =>
                            ChainInfo.of(c.link)?.tags ?? const [],
                        onSelected: state.setExitChain,
                        enabled: !state.isBusy && state.usableChains.length > 1,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// The chosen Psiphon / Tor region: fastest, or one country from the grouped picker.
class _RegionSelector extends StatelessWidget {
  final String selected;
  final bool enabled;
  final ValueChanged<String> onSelected;
  const _RegionSelector({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: enabled
          ? () async {
              final picked = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => _RegionSheet(selected: selected),
              );
              if (picked != null) onSelected(picked);
            }
          : null,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 7, 8, 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ConnectionCard._regionLabel(selected),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Symbols.expand_more_rounded, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Psiphon's exit picker: fastest first, then every country by name, with search.
class _RegionSheet extends StatefulWidget {
  final String selected;
  const _RegionSheet({required this.selected});

  @override
  State<_RegionSheet> createState() => _RegionSheetState();
}

class _RegionSheetState extends State<_RegionSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final countries = exitRegions.entries
        .where(
          (e) =>
              _query.isEmpty ||
              e.value.toLowerCase().contains(_query.toLowerCase()) ||
              e.key.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: SizedBox(
          // Shrinks with the keyboard so the search field and the country list stay usable.
          height:
              (MediaQuery.sizeOf(context).height -
                  MediaQuery.viewInsetsOf(context).bottom) *
              0.82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                MiliLocale.t('انتخاب ریجن سایفون', 'Choose a region'),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Text(
                MiliLocale.t(
                  'سریع‌ترین به‌صورت خودکار یا یک کشور مشخص',
                  'Fastest automatically, or a specific country',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _RegionOption(
                label: MiliLocale.t('سریع‌ترین (خودکار)', 'Fastest (automatic)'),
                leading: '⚡',
                selected: widget.selected.isEmpty,
                onTap: () => Navigator.of(context).pop(''),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Symbols.search_rounded, size: 20),
                  hintText: MiliLocale.t('جستجوی کشور…', 'Search countries…'),
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4),
                child: Text(
                  MiliLocale.t('کشورها', 'Countries'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: countries.isEmpty
                    ? Center(
                        child: Text(
                          MiliLocale.t('کشوری پیدا نشد', 'No country found'),
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        itemCount: countries.length,
                        itemBuilder: (context, index) {
                          final e = countries[index];
                          return _RegionOption(
                            label: e.value,
                            leading: countryFlag(e.key),
                            selected: widget.selected == e.key,
                            onTap: () => Navigator.of(context).pop(e.key),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegionOption extends StatelessWidget {
  final String label;
  final String leading;
  final bool selected;
  final VoidCallback onTap;
  const _RegionOption({
    required this.label,
    required this.leading,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: selected ? scheme.primaryContainer.withValues(alpha: 0.5) : null,
      leading: SizedBox(
        width: 32,
        child: Text(leading, style: const TextStyle(fontSize: 20)),
      ),
      title: Text(label),
      trailing: selected
          ? Icon(Symbols.check_circle_rounded, color: scheme.primary)
          : null,
      onTap: onTap,
    );
  }
}

/// "Label ········ [chip ▾]".
class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget selector;
  const _Row({required this.icon, required this.label, required this.selector});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          selector,
        ],
      ),
    );
  }
}

/// Connection types. Every type except Serverless connects with a best-ping config.
class _TypeSelector extends StatelessWidget {
  const _TypeSelector();

  static String _protocol(ConnectionMode m) => switch (m) {
    ConnectionMode.worker => 'HTTPS',
    ConnectionMode.warp => 'WireGuard',
    // CONNECT-IP over HTTP/2 or 3: HTTPS either way.
    ConnectionMode.masque => 'HTTPS',
    ConnectionMode.serverless => 'Direct',
    // Psiphon's tunnels are all SSH based, under various obfuscation layers.
    ConnectionMode.psiphon => 'SSH',
    ConnectionMode.tor => 'Onion',
    ConnectionMode.node => 'Proxy',
  };

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ChipMenu(
      // Only what's installed (see AppState.availableModes).
      values: state.availableModes,
      selected: state.mode,
      label: (m) => m.label,
      badges: (m) => [_protocol(m)],
      onSelected: state.setMode,
      enabled: !state.isBusy,
    );
  }
}

/// Serverless: Packet or Domain Fronting. Tor: bridges. MASQUE: mode. Worker / WARP: variant.
class _ModeSelector extends StatelessWidget {
  const _ModeSelector();

  /// Domain Fronting needs its CA installed: until it exists, choosing it asks first.
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.mode == ConnectionMode.masque) {
      return ChipMenu(
        values: MasqueVariant.values,
        selected: state.masqueVariant,
        label: (v) => v.label(state.profile.masque.transport == 'h3'),
        onSelected: state.setMasqueVariant,
        enabled: !state.isBusy,
      );
    }
    if (state.mode == ConnectionMode.tor) {
      // Direct, Tor's built-in bridges of a transport, or the custom bridges from Settings → Tor.
      return ChipMenu(
        values: torBridges.keys.toList(),
        selected: state.device.torBridge,
        label: (v) {
          final count = state.profile.tor.bridges.length;
          return v == 'custom' && count > 0
              ? 'Custom bridges ($count)'
              : torBridges[v] ?? v;
        },
        onSelected: state.setTorBridge,
        enabled: !state.isBusy,
      );
    }
    if (state.mode == ConnectionMode.serverless) {
      return ChipMenu(
        values: ServerlessMode.values,
        selected: state.serverlessMode,
        label: (v) => v.label,
        onSelected: state.setServerlessMode,
        enabled: !state.isBusy,
      );
    }
    return ChipMenu(
      values: ConnectionVariant.of(state.mode),
      selected: state.variant,
      label: (v) => v.label(state.mode),
      onSelected: state.setVariant,
      enabled: !state.isBusy,
    );
  }
}
