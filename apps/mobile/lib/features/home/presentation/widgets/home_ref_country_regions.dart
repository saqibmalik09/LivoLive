enum HomeCountryRegion { middleEast, asia, america, europe, africa }

abstract final class HomeCountryRegions {
  static const List<HomeCountryRegion> order = [
    HomeCountryRegion.middleEast,
    HomeCountryRegion.asia,
    HomeCountryRegion.america,
    HomeCountryRegion.europe,
    HomeCountryRegion.africa,
  ];

  static const Map<HomeCountryRegion, List<String>> codes = {
    HomeCountryRegion.middleEast: [
      'AE', 'JO', 'BH', 'DZ', 'SA', 'SD', 'IQ', 'KW', 'MA', 'YE', 'TR', 'OM',
      'PS', 'QA', 'LB', 'EG', 'LY', 'SY', 'KM', 'MR', 'SO', 'TN', 'DJ', 'IR',
      'IL', 'EH',
    ],
    HomeCountryRegion.asia: [
      'IN', 'PK', 'ID', 'BD', 'PH', 'MY', 'VN', 'TH', 'AF',
      'AM', 'AZ', 'BN', 'BT', 'CN', 'GE', 'HK', 'IO', 'JP', 'KG', 'KH', 'KP',
      'KR', 'KZ', 'LA', 'LK', 'MM', 'MN', 'MO', 'MV', 'NP', 'SG', 'TJ', 'TL',
      'TM', 'TW', 'UZ',
      'AS', 'AU', 'CC', 'CK', 'CX', 'FJ', 'FM', 'GU', 'HM', 'KI', 'MH', 'MP',
      'NC', 'NF', 'NR', 'NU', 'NZ', 'PF', 'PG', 'PW', 'SB', 'TK', 'TO', 'TV',
      'VU', 'WF', 'WS',
    ],
    HomeCountryRegion.america: [
      'BR', 'US', 'CR', 'AR', 'PE', 'CL', 'CO', 'VE', 'MX', 'CA', 'UY', 'PY',
      'EC', 'GT', 'CU', 'HN', 'NI', 'PR', 'DO',
      'AG', 'AI', 'AW', 'BB', 'BL', 'BM', 'BO', 'BQ', 'BS', 'BZ', 'CW', 'DM',
      'FK', 'GD', 'GF', 'GL', 'GP', 'GS', 'GY', 'HT', 'JM', 'KN', 'KY', 'LC',
      'MF', 'MQ', 'MS', 'PA', 'PM', 'SR', 'SV', 'SX', 'TC', 'TT', 'VC', 'VG',
      'VI',
    ],
    HomeCountryRegion.europe: [
      'GB', 'ES', 'DE', 'PT', 'IT', 'SE', 'CH', 'DK', 'NL', 'CY', 'FR',
      'AD', 'AL', 'AT', 'AX', 'BA', 'BE', 'BG', 'BY', 'CZ', 'EE', 'FI', 'FO',
      'GG', 'GI', 'GR', 'HR', 'HU', 'IE', 'IM', 'IS', 'JE', 'LI', 'LT', 'LU',
      'LV', 'MC', 'MD', 'ME', 'MK', 'MT', 'NO', 'PL', 'RO', 'RS', 'RU', 'SI',
      'SJ', 'SK', 'SM', 'UA', 'VA', 'XK',
    ],
    HomeCountryRegion.africa: [
      'NG', 'GH', 'AO',
      'AC', 'BF', 'BI', 'BJ', 'BW', 'CD', 'CF', 'CG', 'CI', 'CM', 'CV', 'ER',
      'ET', 'GA', 'GM', 'GN', 'GQ', 'GW', 'KE', 'LR', 'LS', 'MG', 'ML', 'MU',
      'MW', 'MZ', 'NA', 'NE', 'RE', 'RW', 'SC', 'SH', 'SL', 'SN', 'SS', 'ST',
      'SZ', 'TD', 'TG', 'TZ', 'UG', 'YT', 'ZA', 'ZM', 'ZW',
    ],
  };

  static HomeCountryRegion? regionOf(String? code) {
    final c = code?.trim().toUpperCase();
    if (c == null || c.isEmpty) return null;
    for (final entry in codes.entries) {
      if (entry.value.contains(c)) return entry.key;
    }
    return null;
  }
}
