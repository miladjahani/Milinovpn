import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/settings.dart';
import '../services/vpn_channel.dart';
import '../state/app_state.dart';
import 'bettbox_widgets.dart';
import 'cf_accounts_page.dart';
import 'chain_proxies_page.dart';
import 'dns_page.dart';
import 'fragments_page.dart';
import 'license_page.dart';
import 'mili_i18n.dart';
import 'mili_toolbox_page.dart';
import 'noises_page.dart';
import 'per_app_page.dart';
import 'routing_page.dart';
import 'settings_page.dart';
import 'tor_bridges_page.dart';
import 'update_sheet.dart';

/// Bettbox-style Tools & Settings Hub:
/// Searchable settings bar, visual Theme Preview cards (7 Mili themes),
/// Worker Protocol switcher (VLESS WS / VLESS XHTTP / Trojan WS / Shadowsocks WS),
/// tinted icon badges, and clean rounded Bettbox cards for every native feature.
class MiliBettboxSettingsTab extends StatefulWidget {
  const MiliBettboxSettingsTab({super.key});

  @override
  State<MiliBettboxSettingsTab> createState() => _MiliBettboxSettingsTabState();
}

class _MiliBettboxSettingsTabState extends State<MiliBettboxSettingsTab> {
  String _search = '';
  bool _showSettings = false;

  bool _matches(String fa, String en, [String extra = '']) {
    if (_search.isEmpty) return true;
    final q = _search.toLowerCase();
    return fa.toLowerCase().contains(q) ||
        en.toLowerCase().contains(q) ||
        extra.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.profile;

    return Column(
      children: [
        _ToolsHeader(
          showSettings: _showSettings,
          onModeChanged: (settings) => setState(() => _showSettings = settings),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: state.motionEnabled.value
                ? const Duration(milliseconds: 220)
                : Duration.zero,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: _showSettings
                ? const SettingsPage(key: ValueKey('settings'), embedded: true)
                : ListView(
                    key: const ValueKey('tools'),
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 106),
                    children: [
        _UpdateCard(state: state),
        const SizedBox(height: 12),
        // Bettbox-style top search bar
        TextField(
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Symbols.search_rounded, size: 20),
            hintText: MiliLocale.t(
              'جستجو در تنظیمات و ابزارها…',
              'Search settings & tools…',
            ),
            suffixIcon: _search.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Symbols.close_rounded, size: 18),
                    onPressed: () => setState(() => _search = ''),
                  ),
          ),
          onChanged: (v) => setState(() => _search = v.trim()),
        ),
        const SizedBox(height: 14),

        // Theme, language, worker protocol and everything else live in one place (Settings);
        // the Advanced row below opens it, so the same controls don't appear twice.

        // 1. Core, Accounts & Routing Section (Bettbox Tools List)
        BettboxTileCard(
          title: MiliLocale.t('اکانت‌ها، زنجیره و هسته', 'Accounts, Chains & Core'),
          icon: Symbols.dns_rounded,
          contentPadding: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              if (_matches('جعبه‌ابزار تست سرعت پینگ', 'Toolbox Speed Test Unlock Ping DNS'))
                _BettboxRow(
                  icon: Symbols.construction_rounded,
                  title: MiliLocale.t('جعبه‌ابزار شبکه (تست سرعت · بازگشایی · پینگ · DNS)', 'Network Toolbox'),
                  subtitle: MiliLocale.t(
                    'تست سرعت، بررسی بازگشایی سرویس‌ها، موقعیت آی‌پی، پینگ و DoH',
                    'Speed test, Media/AI unlock, IP lookup, TCP ping & DNS query',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MiliToolboxPage()),
                  ),
                ),
              if (_matches('کلادفلر ورکر', 'Cloudflare Accounts Worker'))
                _BettboxRow(
                  icon: Symbols.cloud_rounded,
                  title: MiliLocale.t('حساب‌های کلادفلر و ورکرها', 'Cloudflare Accounts'),
                  subtitle: MiliLocale.t(
                    '${state.cfAccounts.length} حساب ذخیره شده · مدیریت و استقرار مجدد',
                    '${state.cfAccounts.length} saved account(s) · deploy & manage',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CfAccountsPage()),
                  ),
                ),
              if (_matches('زنجیره پروکسی', 'Chain Proxies'))
                _BettboxRow(
                  icon: Symbols.link_rounded,
                  title: MiliLocale.t('پروکسی‌های زنجیره‌ای', 'Chain Proxies'),
                  subtitle: MiliLocale.t(
                    '${p.chains.length} کانفیگ وارد شده (VLESS, Trojan, SS, WG)',
                    '${p.chains.length} imported config(s)',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChainProxiesPage()),
                  ),
                ),
              if (_matches('فرگمنت', 'TCP Fragments'))
                _BettboxRow(
                  icon: Symbols.broken_image_rounded,
                  title: MiliLocale.t('تنظیمات فرگمنت TCP', 'TCP Fragments'),
                  subtitle: MiliLocale.t(
                    'تکه‌تکه‌سازی بسته‌ها برای عبور از DPI',
                    'Split TLS ClientHello to bypass DPI',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FragmentsPage()),
                  ),
                ),
              if (_matches('نویز مبهم‌سازی', 'UDP Noises Obfuscation'))
                _BettboxRow(
                  icon: Symbols.graphic_eq_rounded,
                  title: MiliLocale.t('نویز UDP و مبهم‌سازی', 'UDP Noises'),
                  subtitle: MiliLocale.t(
                    'تنظیمات نویز برای WARP و MASQUE',
                    'UDP obfuscation tuning for WARP & MASQUE',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NoisesPage()),
                  ),
                ),
              if (_matches('مسیریابی ایران', 'Routing Rules'))
                _BettboxRow(
                  icon: Symbols.alt_route_rounded,
                  title: MiliLocale.t('مسیریابی و قوانین ایران', 'Routing & Rules'),
                  subtitle: MiliLocale.t(
                    'عبور مستقیم سایت‌های ایرانی و مسدودسازی تبلیغات',
                    'Bypass local domains, LAN & ad blocking',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RoutingPage(
                        title: MiliLocale.t('مسیریابی و عبور مستقیم', 'Bypass Rules'),
                        group: 'bypass',
                        labels: RoutingPage.bypassLabels,
                        domainHint: 'example.ir, geosite:ir',
                      ),
                    ),
                  ),
                ),
              if (_matches('تفکیک برنامه', 'Per-App Proxy'))
                _BettboxRow(
                  icon: Symbols.apps_rounded,
                  title: MiliLocale.t('تفکیک برنامه‌ها (Per-App)', 'Per-App Proxy'),
                  subtitle: MiliLocale.t(
                    'انتخاب برنامه‌های عبوری یا مستثنی از VPN',
                    'Include or exclude specific Android apps',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PerAppPage()),
                  ),
                ),
              if (_matches('تور پل', 'Tor Bridges'))
                _BettboxRow(
                  icon: Symbols.vpn_key_rounded,
                  title: MiliLocale.t('پل‌های شبکه تور (Tor)', 'Tor Bridges'),
                  subtitle: MiliLocale.t(
                    'مدیریت پل‌های Snowflake و obfs4',
                    'Manage Snowflake, WebTunnel & custom bridges',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TorBridgesPage()),
                  ),
                ),
              if (_matches('DNS سرور', 'DNS Servers'))
                _BettboxRow(
                  icon: Symbols.dns_rounded,
                  title: MiliLocale.t('سرورهای DNS و DoH', 'DNS Servers'),
                  subtitle: MiliLocale.t(
                    'انتخاب سرورهای DoH / DoQ / UDP',
                    'Manage encrypted DoH, DoQ & local DNS',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DnsPage()),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 4. Support, version and in-app update are part of this hub; the update check
        // lives at the top of the tab and the advanced settings are one tap away in the
        // segmented header, not on a separate Settings page.
        BettboxTileCard(
          title: MiliLocale.t('پشتیبانی و برنامه', 'Support & App'),
          icon: Symbols.support_agent_rounded,
          contentPadding: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              _BettboxRow(
                icon: Symbols.system_update_rounded,
                title: MiliLocale.t('بررسی بروزرسانی', 'Check for updates'),
                subtitle: MiliLocale.t(
                  'آخرین نسخه را بگیرید و بدون خروج از برنامه نصب کنید',
                  'Get the latest release and install it in-app',
                ),
                onTap: () async {
                  try {
                    final update = await state.checkForUpdate();
                    if (!context.mounted) return;
                    if (update == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            MiliLocale.t('شما آخرین نسخه را دارید', 'You are up to date'),
                          ),
                        ),
                      );
                    } else {
                      await showUpdateSheet(context, update);
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                },
              ),
              _BettboxRow(
                icon: Symbols.support_agent_rounded,
                title: MiliLocale.t('پشتیبانی و جامعه MiliConfig', 'MiliConfig Community'),
                subtitle: '@miliconfig',
                onTap: () => VpnChannel.openUrl('https://t.me/miliconfig'),
              ),
              _BettboxRow(
                icon: Symbols.copyright_rounded,
                title: MiliLocale.t('مجوز متن‌باز', 'Open Source License'),
                subtitle: 'GNU GPL v3.0',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LicensePageView()),
                ),
              ),
            ],
          ),
        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _ToolsHeader extends StatelessWidget {
  final bool showSettings;
  final ValueChanged<bool> onModeChanged;
  const _ToolsHeader({
    required this.showSettings,
    required this.onModeChanged,
  });

  Future<void> _resetSettings(BuildContext context, AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(MiliLocale.t('بازنشانی تنظیمات؟', 'Reset settings?')),
        content: Text(
          MiliLocale.t(
            'تنظیمات پروکسی به حالت پیش‌فرض برمی‌گردند. آی‌پی‌های سالم VLESS، اندپوینت‌های WARP/MASQUE و بریج‌های تور حفظ می‌شوند.',
            'Proxy settings return to their defaults. VLESS Clean IPs, WARP and MASQUE '
                'endpoints and Tor custom bridges are preserved.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MiliLocale.t('انصراف', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(MiliLocale.t('بازنشانی', 'Reset')),
          ),
        ],
      ),
    );
    if (ok == true) state.resetSettings();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
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
                  color: scheme.primary.withValues(alpha: 0.14),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.30),
                  ),
                ),
                child: Icon(
                  Symbols.tune_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      MiliLocale.t('ابزارها و تنظیمات', 'Tools & Settings'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      MiliLocale.t(
                        'همه ابزارها، تنظیمات ریز، ظاهر و بروزرسانی در یک‌جا',
                        'All tools, granular settings, appearance and updates in one place',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: MiliLocale.t('بازنشانی تنظیمات', 'Reset settings'),
                visualDensity: VisualDensity.compact,
                onPressed: () => _resetSettings(context, state),
                icon: const Icon(Symbols.settings_backup_restore_rounded, size: 20),
              ),
              IconButton(
                tooltip: MiliLocale.t('بروزرسانی', 'Update'),
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  if (state.availableUpdate != null) {
                    await showUpdateSheet(context, state.availableUpdate!);
                    return;
                  }
                  try {
                    final update = await state.checkForUpdate();
                    if (!context.mounted) return;
                    if (update == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            MiliLocale.t('شما آخرین نسخه را دارید', 'You are up to date'),
                          ),
                        ),
                      );
                    } else {
                      await showUpdateSheet(context, update);
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                },
                icon: Badge(
                  isLabelVisible: state.availableUpdate != null,
                  child: const Icon(Symbols.system_update_rounded, size: 21),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 42,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                _ToolsModePill(
                  icon: Symbols.grid_view_rounded,
                  label: MiliLocale.t('جعبه‌ابزار', 'Toolbox'),
                  selected: !showSettings,
                  onTap: () => onModeChanged(false),
                ),
                _ToolsModePill(
                  icon: Symbols.tune_rounded,
                  label: MiliLocale.t('تنظیمات کامل', 'All settings'),
                  selected: showSettings,
                  onTap: () => onModeChanged(true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolsModePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToolsModePill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
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

class _UpdateCard extends StatelessWidget {
  final AppState state;
  const _UpdateCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final update = state.availableUpdate;
    final downloading = state.downloadingUpdate;
    return BettboxTileCard(
      title: MiliLocale.t('بروزرسانی برنامه', 'App update'),
      icon: Symbols.system_update_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            update == null
                ? MiliLocale.t(
                    'آخرین نسخه را بررسی کنید؛ بروزرسانی داخل برنامه دانلود و نصب می‌شود.',
                    'Check for the latest release; it downloads and installs inside the app.',
                  )
                : MiliLocale.t(
                    'نسخه ${update.version} آماده است. با یک لمس نصب کنید.',
                    'Version ${update.version} is ready. Install it with one tap.',
                  ),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, height: 1.45),
          ),
          if (downloading) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: state.updateProgress > 0 ? state.updateProgress : null,
                minHeight: 5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.checkingUpdate || downloading
                      ? null
                      : () async {
                          try {
                            await state.checkForUpdate();
                            if (!context.mounted) return;
                            final found = state.availableUpdate;
                            if (found == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    MiliLocale.t(
                                      'شما آخرین نسخه را دارید',
                                      'You are up to date',
                                    ),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')),
                            );
                          }
                        },
                  icon: state.checkingUpdate
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Symbols.refresh_rounded, size: 17),
                  label: Text(MiliLocale.t('بررسی', 'Check')),
                ),
              ),
              if (update != null) ...[
                const SizedBox(width: 9),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: downloading
                        ? null
                        : () => showUpdateSheet(context, update),
                    icon: const Icon(Symbols.download_rounded, size: 17),
                    label: Text(MiliLocale.t('نصب', 'Install')),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BettboxRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BettboxRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          color: scheme.primary.withValues(alpha: 0.13),
        ),
        child: Icon(icon, size: 19, color: scheme.primary),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
      ),
      trailing: Icon(
        Symbols.chevron_right_rounded,
        size: 20,
        color: scheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
