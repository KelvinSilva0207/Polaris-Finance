import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_providers.dart';
import '../../data/models/currencies.dart';
import '../../shared/utils/amount_format.dart';
import '../../shared/widgets/money_field.dart';

final _numberFormat = NumberFormat.decimalPatternDigits(
  locale: 'es',
  decimalDigits: 2,
);

String _fmt(double value) => _numberFormat.format(value);

double? _parseAmount(String text) => parseAmountInput(text);

const _noneCategory = '__none__';

class _ServiceDraft {
  const _ServiceDraft(
    this.name,
    this.amount,
    this.currency,
    this.dayOfMonth,
    this.accountId,
    this.categoryId,
    this.isActive,
    this.note,
  );

  final String name;
  final double amount;
  final String currency;
  final int dayOfMonth;
  final String? accountId;
  final String? categoryId;
  final bool isActive;
  final String? note;
}

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final draft = await _showServiceEditor(context, ref);
    if (draft == null) return;
    await ref.read(appDatabaseProvider).addService(
          name: draft.name,
          amount: draft.amount,
          currency: draft.currency,
          dayOfMonth: draft.dayOfMonth,
          accountId: draft.accountId,
          categoryId: draft.categoryId,
          isActive: draft.isActive,
          note: draft.note,
        );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    RecurringService service,
  ) async {
    final draft = await _showServiceEditor(context, ref, initial: service);
    if (draft == null) return;
    await ref.read(appDatabaseProvider).updateService(
          service.copyWith(
            name: draft.name,
            amount: draft.amount,
            currency: draft.currency,
            dayOfMonth: draft.dayOfMonth,
            accountId: Value(draft.accountId),
            categoryId: Value(draft.categoryId),
            isActive: draft.isActive,
            note: Value(draft.note),
          ),
        );
  }

  Future<void> _pay(
    BuildContext context,
    WidgetRef ref,
    RecurringService service,
  ) async {
    if (service.accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Asigna una cuenta a "${service.name}" antes de pagarlo',
          ),
        ),
      );
      return;
    }
    final draft = await _showPayDialog(context, service);
    if (draft == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(appDatabaseProvider).payService(
            service,
            date: draft.date,
            amountOverride: draft.amount,
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Pago registrado')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    RecurringService service,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar servicio'),
        content: Text('¿Eliminar "${service.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(appDatabaseProvider).deleteService(service.id);
    }
  }

  Future<void> _toggleActive(
    WidgetRef ref,
    RecurringService service,
  ) async {
    await ref.read(appDatabaseProvider).updateService(
          service.copyWith(isActive: !service.isActive),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(servicesProvider);
    final accounts = ref.watch(accountsProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Servicios')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuevo servicio',
        onPressed: () => _create(context, ref),
        child: const Icon(Icons.add),
      ),
      body: servicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (services) {
          if (services.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 72),
                    const SizedBox(height: 16),
                    Text(
                      'Aún no hay servicios',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Netflix, internet, alquiler… pagos periódicos con un clic.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _create(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Crear servicio'),
                    ),
                  ],
                ),
              ),
            );
          }
          final now = DateTime.now();
          final accountNames = {
            for (final account in accounts) account.id: account.name,
          };
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final service = services[index];
              final paidThisMonth =
                  service.lastPaidDate != null &&
                  service.lastPaidDate!.year == now.year &&
                  service.lastPaidDate!.month == now.month;
              final pending =
                  service.isActive &&
                  service.dayOfMonth <= now.day &&
                  !paidThisMonth;
              return Card(
                child: ListTile(
                  onTap: () => _edit(context, ref, service),
                  leading: CircleAvatar(
                    backgroundColor: pending
                        ? const Color(0xFFEF5350).withValues(alpha: 0.16)
                        : Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.receipt_long_outlined,
                      color: pending
                          ? const Color(0xFFEF5350)
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(service.name, overflow: TextOverflow.ellipsis),
                      ),
                      if (pending) ...[
                        const SizedBox(width: 8),
                        const Chip(
                          label: Text('Pendiente'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    [
                      'día ${service.dayOfMonth}',
                      '${service.currency} ${_fmt(service.amount)}',
                      if (service.accountId != null)
                        accountNames[service.accountId] ?? 'cuenta borrada',
                      if (service.lastPaidDate != null)
                        'último pago ${DateFormat('dd/MM/yyyy').format(service.lastPaidDate!)}',
                    ].join(' · '),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'pay':
                          await _pay(context, ref, service);
                        case 'edit':
                          await _edit(context, ref, service);
                        case 'toggle':
                          await _toggleActive(ref, service);
                        case 'delete':
                          await _delete(context, ref, service);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'pay',
                        child: ListTile(
                          leading: Icon(Icons.payment_outlined),
                          title: Text('Pagar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: ListTile(
                          leading: Icon(
                            service.isActive
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                          ),
                          title: Text(
                            service.isActive ? 'Pausar' : 'Activar',
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Eliminar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PayDraft {
  const _PayDraft(this.amount, this.date);

  final double amount;
  final DateTime date;
}

Future<_PayDraft?> _showPayDialog(
  BuildContext context,
  RecurringService service,
) async {
  final amountController = TextEditingController(
    text: formatVeNumber(service.amount),
  );
  var date = DateTime.now();

  return showDialog<_PayDraft>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Pagar ${service.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MoneyField(
              controller: amountController,
              label: 'Monto del recibo',
              currency: service.currency,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(DateFormat('dd/MM/yyyy').format(date)),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2015),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => date = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: const Text('Fecha'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final amount = _parseAmount(amountController.text);
              if (amount == null || amount <= 0) return;
              Navigator.of(context).pop(_PayDraft(amount, date));
            },
            child: const Text('Registrar pago'),
          ),
        ],
      ),
    ),
  );
}

Future<_ServiceDraft?> _showServiceEditor(
  BuildContext context,
  WidgetRef ref, {
  RecurringService? initial,
}) async {
  final nameController = TextEditingController(text: initial?.name ?? '');
  final amountController = TextEditingController(
    text: initial == null ? '' : formatVeNumber(initial.amount),
  );
  final noteController = TextEditingController(text: initial?.note ?? '');
  var currency = initial?.currency ?? 'VES';
  var dayOfMonth = initial?.dayOfMonth ?? 1;
  var accountId = initial?.accountId;
  var categoryId = initial?.categoryId;
  var isActive = initial?.isActive ?? true;

  final accounts = ref.read(accountsProvider).value ?? const [];
  final categories =
      (ref.read(categoriesProvider).value ?? const []).where(
        (category) => !category.isIncome,
      );

  final draft = await showDialog<_ServiceDraft>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(initial == null ? 'Nuevo servicio' : 'Editar servicio'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: MoneyField(
                      controller: amountController,
                      label: 'Monto',
                      currency: currency,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 104,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('svc-currency-$currency'),
                      initialValue: currency,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Moneda'),
                      items: [
                        for (final code in commonCurrencies)
                          DropdownMenuItem(value: code, child: Text(code)),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => currency = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: ValueKey('svc-day-$dayOfMonth'),
                initialValue: dayOfMonth,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Día de cada mes (1-31)',
                ),
                items: [
                  for (var day = 1; day <= 31; day++)
                    DropdownMenuItem(value: day, child: Text('$day')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => dayOfMonth = value);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('svc-account-${accountId ?? 'none'}'),
                initialValue: accountId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Cuenta'),
                hint: const Text('Sin cuenta'),
                items: [
                  const DropdownMenuItem(
                    value: _noneCategory,
                    child: Text('Sin cuenta'),
                  ),
                  for (final account in accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(account.name),
                    ),
                ],
                onChanged: (value) {
                  setState(
                    () => accountId = value == _noneCategory ? null : value,
                  );
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('svc-cat-${categoryId ?? 'none'}'),
                initialValue: categoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Categoría'),
                hint: const Text('Sin categoría'),
                items: [
                  const DropdownMenuItem(
                    value: _noneCategory,
                    child: Text('Sin categoría'),
                  ),
                  for (final category in categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (value) {
                  setState(
                    () => categoryId = value == _noneCategory ? null : value,
                  );
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Servicio activo'),
                value: isActive,
                onChanged: (value) => setState(() => isActive = value),
              ),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Nota'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final amount = _parseAmount(amountController.text);
              if (name.isEmpty || amount == null || amount <= 0) return;
              Navigator.of(context).pop(
                _ServiceDraft(
                  name,
                  amount,
                  currency,
                  dayOfMonth,
                  accountId,
                  categoryId,
                  isActive,
                  noteController.text.trim().isEmpty
                      ? null
                      : noteController.text.trim(),
                ),
              );
            },
            child: Text(initial == null ? 'Crear' : 'Guardar'),
          ),
        ],
      ),
    ),
  );
  return draft;
}
