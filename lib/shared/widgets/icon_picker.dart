import 'package:flutter/material.dart';

import '../../core/icons.dart';

const editableIconNames = <String>[
  'account_balance',
  'account_balance_wallet',
  'payments',
  'currency_bitcoin',
  'cash',
  'attach_money',
  'work_outline',
  'storefront',
  'sell',
  'card_giftcard',
  'restaurant',
  'shopping_cart',
  'directions_car',
  'local_gas_station',
  'home',
  'receipt_long',
  'local_hospital',
  'school',
  'movie',
  'shopping_bag',
  'savings',
  'flight',
  'fitness_center',
  'pets',
  'phone_iphone',
  'laptop',
  'favorite',
  'celebration',
  'local_shipping',
  'menu_book',
  'beach_access',
  'trending_up',
  'more_horiz',
];

class IconPicker extends StatelessWidget {
  const IconPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.selectedTint = const Color(0xFF9C6BFF),
  });

  final String selected;
  final ValueChanged<String> onChanged;
  final Color selectedTint;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final name in editableIconNames)
          InkWell(
            onTap: () => onChanged(name),
            customBorder: const CircleBorder(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected == name
                    ? selectedTint.withValues(alpha: 0.22)
                    : Theme.of(context).colorScheme.surface,
                border: Border.all(
                  width: selected == name ? 2 : 1,
                  color: selected == name
                      ? selectedTint
                      : Theme.of(context).dividerColor,
                ),
              ),
              child: Icon(iconFromName(name), size: 20, color: selected == name ? selectedTint : null),
            ),
          ),
      ],
    );
  }
}