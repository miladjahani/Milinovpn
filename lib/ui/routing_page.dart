import 'package:flutter/material.dart';

import 'expressive.dart';
import 'mili_i18n.dart';
import 'prefs.dart';

/// One routing group: its built-in presets (`routing.<group>.presets.<name>`), then its custom
/// domains (`routing.<group>.domains`) and, unless [ipHint] is null, IPs (`routing.<group>.ips`).
class RoutingPage extends StatelessWidget {
  final String title;

  /// "bypass", "sanctionBypass" or "block".
  final String group;
  final Map<String, String> labels;
  final String domainHint;

  /// Null for a group without custom IPs (sanction rules: domains only).
  final String? ipHint;

  /// Shown at the top of the page, or null.
  final String? help;
  const RoutingPage({
    super.key,
    required this.title,
    required this.group,
    required this.labels,
    required this.domainHint,
    this.ipHint,
    this.help,
  });

  /// When the sanction rules apply (see XrayConfigBuilder._antiSanction).
  static const sanctionHelp =
      'These rules only apply to Serverless, WARP and MASQUE connections when Exit node is set to Default.';

  static const sanctionHelpFa =
      'این قوانین فقط در اتصال‌های Serverless، WARP و MASQUE وقتی خروجی روی Default است اعمال می‌شوند.';

  /// Direct connection, resolved with the local DNS.
  static const bypassLabels = {'iran': 'Iran', 'china': 'China', 'russia': 'Russia', 'bittorrent': 'BitTorrent'};

  /// Direct connection, resolved with the anti-sanction DNS.
  static const sanctionBypassLabels = {
    'openAi': 'ChatGPT',
    'googleAi': 'Google AIs',
    'microsoft': 'Microsoft',
    'oracle': 'Oracle',
    'docker': 'Docker',
    'adobe': 'Adobe',
    'epicGames': 'Epic Games',
    'intel': 'Intel',
    'amd': 'AMD',
    'nvidia': 'Nvidia',
    'asus': 'Asus',
    'hp': 'HP',
    'lenovo': 'Lenovo',
  };

  static const blockLabels = {
    'ads': 'Ads',
    'porn': 'Porn',
    'malware': 'Malware',
    'phishing': 'Phishing',
    'cryptominers': 'Cryptominers',
    'quic': 'QUIC',
  };

  static const _faLabels = {
    'iran': 'ایران',
    'china': 'چین',
    'russia': 'روسیه',
    'bittorrent': 'بیت‌تورنت',
    'openAi': 'چت‌جی‌پی‌تی',
    'googleAi': 'هوش مصنوعی گوگل',
    'microsoft': 'مایکروسافت',
    'oracle': 'اوراکل',
    'docker': 'داکر',
    'adobe': 'ادوبی',
    'epicGames': 'اپیک گیمز',
    'intel': 'اینتل',
    'amd': 'AMD',
    'nvidia': 'انویدیا',
    'asus': 'ایسوس',
    'hp': 'اچ‌پی',
    'lenovo': 'لنوو',
    'ads': 'تبلیغات',
    'porn': 'محتوای بزرگسال',
    'malware': 'بدافزار',
    'phishing': 'فیشینگ',
    'cryptominers': 'ماینرهای رمزارز',
    'quic': 'QUIC',
  };

  String _label(String key, String fallback) =>
      MiliLocale.t(_faLabels[key] ?? fallback, fallback);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: MiliLocale.code,
      builder: (context, _, __) => Scaffold(
        appBar: ExpressiveSubpageHeader(
          title: title,
          subtitle: MiliLocale.t(
            'پیش‌تنظیم‌ها و قوانین دستی مسیر مستقیم',
            'Presets and custom direct-route rules',
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            if (help != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                child: Text(
                  help!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            SectionHeader(MiliLocale.t('پیش‌تنظیم‌ها', 'Presets')),
            SettingsCard(
              children: [
                for (final e in labels.entries)
                  SwitchPref(
                    'routing.$group.presets.${e.key}',
                    _label(e.key, e.value),
                    subtitle: e.key == 'quic'
                        ? MiliLocale.t(
                            'VLESS همیشه UDP را مسدود می‌کند؛ این گزینه فقط روی پروتکل‌های دیگر اثر دارد.',
                            'VLESS always blocks UDP, this only applies to other protocols',
                          )
                        : null,
                  ),
              ],
            ),
            SectionHeader(MiliLocale.t('دستی', 'Manual')),
            SettingsCard(
              children: [
                ListPref(
                  'routing.$group.domains',
                  MiliLocale.t('دامنه‌ها', 'Domains'),
                  hint: domainHint,
                  itemValidator: validateDomain,
                ),
                if (ipHint != null)
                  ListPref(
                    'routing.$group.ips',
                    MiliLocale.t('آی‌پی یا CIDR', 'IPs or CIDRs'),
                    hint: ipHint,
                    itemValidator: validateIpOrCidr,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
