import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons.dart';
import '../../core/providers.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_providers.dart';
import 'category_editor.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar "${category.name}"? No se borrarán movimientos, pero dejarán de mostrar esta categoría.'),
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
    if (confirmed != true) return;
    try {
      await ref.read(appDatabaseProvider).deleteCategory(category.id);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCategoryEditor(context, defaultIsIncome: false),
        tooltip: 'Nueva categoría',
        child: const Icon(Icons.add),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (categories) {
          final income = categories.where((c) => c.isIncome).toList();
          final expense = categories.where((c) => !c.isIncome).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section(context, 'Ingresos', income, ref),
              const SizedBox(height: 16),
              _section(context, 'Egresos', expense, ref),
            ],
          );
        },
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    List<Category> items,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Sin categorías'),
          )
        else
          for (final category in items)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(category.colorValue).withValues(alpha: 0.18),
                  child: Icon(
                    iconFromName(category.icon),
                    color: Color(category.colorValue),
                  ),
                ),
                title: Text(category.name),
                subtitle: Text(category.isBuiltIn ? 'Predefinida' : 'Personalizada'),
                trailing: category.isBuiltIn
                    ? const Icon(Icons.lock_outline, size: 18)
                    : IconButton(
                        tooltip: 'Editar',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => showCategoryEditor(
                          context,
                          initial: category,
                          defaultIsIncome: category.isIncome,
                        ),
                      ),
                onLongPress: category.isBuiltIn
                    ? null
                    : () => _confirmDelete(context, ref, category),
              ),
            ),
      ],
    );
  }
}