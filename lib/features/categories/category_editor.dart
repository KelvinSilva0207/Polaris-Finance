import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/database/app_database.dart';
import '../../data/models/enums.dart' show TransactionType;
import '../../shared/widgets/color_picker_row.dart';
import '../../shared/widgets/icon_picker.dart';

Future<Category?> showCategoryEditor(
  BuildContext context, {
  Category? initial,
  required bool defaultIsIncome,
}) {
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => CategoryEditorSheet(
      initial: initial,
      defaultIsIncome: defaultIsIncome,
    ),
  );
}

class CategoryEditorSheet extends ConsumerStatefulWidget {
  const CategoryEditorSheet({
    super.key,
    this.initial,
    required this.defaultIsIncome,
  });

  final Category? initial;
  final bool defaultIsIncome;

  @override
  ConsumerState<CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends ConsumerState<CategoryEditorSheet> {
  late final TextEditingController _nameController;
  late String _icon;
  late int _color;
  late bool _isIncome;
  bool _saving = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _icon = initial?.icon ?? 'category';
    _color = initial?.colorValue ?? 0xFF9C6BFF;
    _isIncome = initial?.isIncome ?? widget.defaultIsIncome;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un nombre para la categoría')),
      );
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(appDatabaseProvider);
    final Category? result;
    if (_isEditing) {
      await db.updateCategory(
        widget.initial!.copyWith(
          name: name,
          icon: _icon,
          colorValue: _color,
          isIncome: _isIncome,
        ),
      );
      result = widget.initial;
    } else {
      result = await db.addCategory(
        name: name,
        icon: _icon,
        colorValue: _color,
        isIncome: _isIncome,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Editar categoría' : 'Nueva categoría',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Es un ingreso'),
              value: _isIncome,
              onChanged: (value) => setState(() => _isIncome = value),
            ),
            const SizedBox(height: 8),
            Text('Icono', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            IconPicker(selected: _icon, onChanged: (value) => setState(() => _icon = value)),
            const SizedBox(height: 16),
            Text('Color', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            ColorPickerRow(selected: _color, onChanged: (value) => setState(() => _color = value)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_isEditing ? 'Guardar cambios' : 'Crear categoría'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool categoryMatchesType(Category category, TransactionType type) =>
    category.isIncome == (type == TransactionType.income);