import 'package:flutter/material.dart';

import '../../core/icons.dart';
import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import 'amount_text.dart';

class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.account,
    required this.balance,
    this.hidden = false,
  });

  final Account account;
  final double balance;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final color = Color(account.colorValue);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.18),
          child: Icon(iconFromName(account.icon), color: color),
        ),
        title: Text(account.name),
        subtitle: Text(AccountType.fromStorage(account.type).label),
        trailing: AmountText(
          balance,
          currency: account.currency,
          hidden: hidden,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}