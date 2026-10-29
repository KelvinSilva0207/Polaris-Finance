import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_providers.dart';
import '../../data/models/enums.dart';
import '../../shared/utils/amount_format.dart';
import '../../shared/utils/transaction_math.dart';
import '../../shared/widgets/money_field.dart';

class FeeRulesScreen extends ConsumerWidget {
  const FeeRulesScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final draft = await _showFeeEditor(context);
    if (draft == null) return;
    await ref
        .read(appDatabaseProvider)
        .addFeeRule(
          name: draft.name,
          fixedAmount: draft.fixed,
          percent: draft.percent,
          minAmount: draft.minimum,
          maxAmount: draft.maximum,
          isActive: draft.isActive,
          feeType: draft.feeType,
          appliesTo: draft.appliesTo,
          tierThreshold: draft.tierThreshold,
          tierFixedAmount: draft.tierFixedAmount,
          tierPercent: draft.tierPercent,
        );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, FeeRule rule) async {
    final draft = await _showFeeEditor(context, initial: rule);
    if (draft == null) return;
    await ref
        .read(appDatabaseProvider)
        .updateFeeRule(
          rule.copyWith(
            name: draft.name,
            fixedAmount: draft.fixed,
            percent: draft.percent,
            minAmount: Value(draft.minimum),
            maxAmount: Value(draft.maximum),
            isActive: draft.isActive,
            feeType: draft.feeType.name,
            appliesTo: encodeFeeRuleTypes(draft.appliesTo),
            tierThreshold: Value(draft.tierThreshold),
            tierFixedAmount: Value(draft.tierFixedAmount),
            tierPercent: Value(draft.tierPercent),
          ),
        );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    FeeRule rule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar regla'),
        content: Text('¿Eliminar "${rule.name}"?'),
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
      await ref.read(appDatabaseProvider).deleteFeeRule(rule.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(feeRulesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Comisiones')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nueva regla',
        onPressed: () => _create(context, ref),
        child: const Icon(Icons.add),
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (rules) {
          if (rules.isEmpty) {
            return const Center(child: Text('Aún no hay reglas de comisión.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rules.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final rule = rules[index];
              final summary = feeRuleSummary(rule);
              final types = feeRuleTypes(rule);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            child: Icon(
                              rule.isActive
                                  ? Icons.price_change_outlined
                                  : Icons.lock_outline,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rule.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  summary.isEmpty ? 'Sin montos' : summary,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: rule.isActive,
                            onChanged: (value) async {
                              await ref
                                  .read(appDatabaseProvider)
                                  .updateFeeRule(
                                    rule.copyWith(isActive: value),
                                  );
                            },
                          ),
                          PopupMenuButton<String>(
                            onSelected: (action) {
                              switch (action) {
                                case 'edit':
                                  _edit(context, ref, rule);
                                case 'delete':
                                  _delete(context, ref, rule);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Eliminar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          const _Tag(label: 'Aplica a'),
                          for (final type in types) _Tag(label: type.label),
                        ],
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

/// Etiqueta pequeña para mostrar a qué tipos aplica una regla.
class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: scheme.onSecondaryContainer),
      ),
    );
  }
}

class _FeeDraft {
  const _FeeDraft({
    required this.name,
    required this.fixed,
    required this.percent,
    required this.isActive,
    required this.feeType,
    required this.appliesTo,
    this.minimum,
    this.maximum,
    this.tierThreshold,
    this.tierFixedAmount,
    this.tierPercent,
  });

  final String name;
  final double fixed;
  final double percent;
  final double? minimum;
  final double? maximum;
  final bool isActive;
  final FeeType feeType;
  final Set<TransactionType> appliesTo;
  final double? tierThreshold;
  final double? tierFixedAmount;
  final double? tierPercent;
}

Future<_FeeDraft?> _showFeeEditor(BuildContext context, {FeeRule? initial}) {
  return showDialog<_FeeDraft>(
    context: context,
    builder: (context) => _FeeEditorDialog(initial: initial),
  );
}

class _FeeEditorDialog extends StatefulWidget {
  const _FeeEditorDialog({this.initial});

  final FeeRule? initial;

  @override
  State<_FeeEditorDialog> createState() => _FeeEditorDialogState();
}

class _FeeEditorDialogState extends State<_FeeEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _fixedController;
  late final TextEditingController _percentController;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  late final TextEditingController _tierThresholdController;
  late final TextEditingController _tierFixedController;
  late final TextEditingController _tierPercentController;
  late bool _isActive;
  late FeeType _feeType;
  late Set<TransactionType> _appliesTo;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _fixedController = TextEditingController(
      text: _moneyField(initial?.fixedAmount),
    );
    _percentController = TextEditingController(
      text: initial == null ? '' : vePercentText(initial.percent),
    );
    _minController = TextEditingController(
      text: initial?.minAmount == null ? '' : _moneyField(initial!.minAmount),
    );
    _maxController = TextEditingController(
      text: initial?.maxAmount == null ? '' : _moneyField(initial!.maxAmount),
    );
    _tierThresholdController = TextEditingController(
      text: initial?.tierThreshold == null
          ? ''
          : _moneyField(initial!.tierThreshold),
    );
    _tierFixedController = TextEditingController(
      text: initial?.tierFixedAmount == null
          ? ''
          : _moneyField(initial!.tierFixedAmount),
    );
    _tierPercentController = TextEditingController(
      text: initial?.tierPercent == null
          ? ''
          : vePercentText(initial!.tierPercent!),
    );
    _isActive = widget.initial?.isActive ?? true;
    _feeType = FeeType.fromStorage(initial?.feeType);
    // Las comisiones bancarias solo se cobran en pagos móviles.
    _appliesTo = const {TransactionType.pagoMovil};
  }

  static String _moneyField(double? value) =>
      value == null ? '' : formatVeNumber(value);

  @override
  void dispose() {
    _nameController.dispose();
    _fixedController.dispose();
    _percentController.dispose();
    _minController.dispose();
    _maxController.dispose();
    _tierThresholdController.dispose();
    _tierFixedController.dispose();
    _tierPercentController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un nombre para la regla')),
      );
      return;
    }
    if (_appliesTo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige al menos un tipo de transacción')),
      );
      return;
    }
    final isTiered = _feeType == FeeType.tiered;
    final threshold = parseAmountInput(_tierThresholdController.text);
    if (isTiered && threshold == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indica el monto límite de los tramos')),
      );
      return;
    }
    final fixed = isTiered
        ? 0.0
        : (parseAmountInput(_fixedController.text) ?? 0);
    final percent = isTiered
        ? 0.0
        : (parsePercentInput(_percentController.text) ?? 0);
    Navigator.of(context).pop(
      _FeeDraft(
        name: name,
        fixed: fixed,
        percent: percent,
        minimum: parseAmountInput(_minController.text),
        maximum: parseAmountInput(_maxController.text),
        isActive: _isActive,
        feeType: _feeType,
        appliesTo: _appliesTo,
        tierThreshold: isTiered ? threshold : null,
        tierFixedAmount: isTiered
            ? (parseAmountInput(_tierFixedController.text) ?? 0)
            : null,
        tierPercent: isTiered
            ? (parsePercentInput(_tierPercentController.text) ?? 0)
            : null,
      ),
    );
  }

  /// Ejemplo en vivo de lo que se cobraría con la configuración actual.
  String _preview() {
    if (_feeType == FeeType.tiered) {
      final threshold = parseAmountInput(_tierThresholdController.text);
      if (threshold == null || threshold <= 0) {
        return 'Ej.: indica el monto límite para ver el ejemplo';
      }
      final fixed = parseAmountInput(_tierFixedController.text) ?? 0;
      final percent = parsePercentInput(_tierPercentController.text) ?? 0;
      final low = threshold / 2;
      final high = threshold * 2;
      return 'Ej.: ${formatVeNumber(low)} Bs → '
          '${formatVeNumber(_tierFee(low, threshold, fixed, percent))} Bs   |   '
          '${formatVeNumber(high)} Bs → '
          '${formatVeNumber(_tierFee(high, threshold, fixed, percent))} Bs';
    }
    final fixed = parseAmountInput(_fixedController.text) ?? 0;
    final percent = parsePercentInput(_percentController.text) ?? 0;
    final sample = 1000.0;
    final fee = fixed + sample * percent / 100;
    return 'Ej.: ${formatVeNumber(sample)} Bs → '
        '${formatVeNumber(fee)} Bs de comisión';
  }

  double _tierFee(
    double amount,
    double threshold,
    double fixed,
    double percent,
  ) {
    return amount < threshold ? fixed : amount * percent / 100;
  }

  @override
  Widget build(BuildContext context) {
    final isTiered = _feeType == FeeType.tiered;
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nueva regla' : 'Editar regla'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 16),
              Text('Aplica a', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Solo Pago Móvil. Los egresos y transferencias nunca llevan '
                  'comisión.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Cómo se calcula',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              SegmentedButton<FeeType>(
                segments: [
                  for (final type in FeeType.values)
                    ButtonSegment(value: type, label: Text(type.label)),
                ],
                selected: {_feeType},
                onSelectionChanged: (selection) {
                  setState(() => _feeType = selection.first);
                },
                showSelectedIcon: false,
              ),
              const SizedBox(height: 6),
              Text(
                _feeType.description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (isTiered) ...[
                Row(
                  children: [
                    Expanded(
                      child: MoneyField(
                        controller: _tierThresholdController,
                        label: 'Hasta (Bs)',
                        currency: 'VES',
                        showEquivalent: false,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MoneyField(
                        controller: _tierFixedController,
                        label: 'Comisión fija',
                        currency: 'VES',
                        showEquivalent: false,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tierPercentController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [vePercentFormatter()],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: '% a partir del límite',
                    suffixText: '%',
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: MoneyField(
                        controller: _fixedController,
                        label: 'Fijo',
                        currency: 'VES',
                        showEquivalent: false,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _percentController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [vePercentFormatter()],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: '% sobre monto',
                          suffixText: '%',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: MoneyField(
                      controller: _minController,
                      label: 'Mínimo (opc.)',
                      currency: 'VES',
                      showEquivalent: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MoneyField(
                      controller: _maxController,
                      label: 'Máximo (opc.)',
                      currency: 'VES',
                      showEquivalent: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _preview(),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(widget.initial == null ? 'Crear regla' : 'Guardar'),
        ),
      ],
    );
  }
}
