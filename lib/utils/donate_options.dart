/// One way to support SMDB, shown under Settings > Support.
///
/// [isCrypto] entries hold a wallet address in [value] (shown selectable,
/// with a copy button); all others hold a web URL in [value] (opened in
/// the browser).
class DonateOption {
  final String name;
  final String value;
  final bool isCrypto;
  const DonateOption({
    required this.name,
    required this.value,
    this.isCrypto = false,
  });
}

/// Fill this list in to make donation methods appear in Settings > Support.
/// Example:
///   DonateOption(name: 'Ko-fi', value: 'https://ko-fi.com/yourname'),
///   DonateOption(name: 'USDT (TRC20)', value: 'T...', isCrypto: true),
const donateOptions = <DonateOption>[];
