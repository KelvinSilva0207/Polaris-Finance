import 'package:flutter/material.dart';

IconData iconFromName(String name) {
  const icons = <String, IconData>{
    'account_balance': Icons.account_balance,
    'account_balance_wallet': Icons.account_balance_wallet,
    'payments': Icons.payments,
    'work_outline': Icons.work_outline,
    'storefront': Icons.storefront,
    'sell': Icons.sell,
    'card_giftcard': Icons.card_giftcard,
    'restaurant': Icons.restaurant,
    'shopping_cart': Icons.shopping_cart,
    'directions_car': Icons.directions_car,
    'local_gas_station': Icons.local_gas_station,
    'home': Icons.home,
    'receipt_long': Icons.receipt_long,
    'local_hospital': Icons.local_hospital,
    'school': Icons.school,
    'movie': Icons.movie,
    'shopping_bag': Icons.shopping_bag,
    'savings': Icons.savings,
    'more_horiz': Icons.more_horiz,
    'currency_bitcoin': Icons.currency_bitcoin,
    'cash': Icons.payments,
  };
  return icons[name] ?? Icons.category;
}