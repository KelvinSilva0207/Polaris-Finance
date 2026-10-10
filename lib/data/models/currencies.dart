const commonCurrencies = <String>[
  'VES',
  'USD',
  'USDT',
  'EUR',
  'COP',
  'CLP',
  'ARS',
  'MXN',
  'PEN',
  'BRL',
];

/// Símbolo con el que se muestra una moneda en los campos de dinero.
String currencySymbol(String code) {
  switch (code) {
    case 'VES':
      return 'Bs';
    case 'USD':
    case 'USDT':
      return r'$';
    case 'EUR':
      return '€';
    case 'COP':
      return r'COL$';
    case 'CLP':
      return r'CLP$';
    case 'ARS':
      return r'ARS$';
    case 'MXN':
      return r'MXN$';
    case 'PEN':
      return 'S/';
    case 'BRL':
      return r'R$';
    default:
      return code;
  }
}