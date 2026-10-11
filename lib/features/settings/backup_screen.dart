import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../../data/services/backup_service.dart';

/// Pantalla de copia de seguridad: crea copias de la base (archivo .sqlite
/// único) y restaura una copia existente. La restauración se aplica en el
/// próximo arranque para no tocar la base estando abierta.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  BackupService? _service;
  List<String> _backups = const [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _service = BackupService(prefs);
      _loading = true;
    });
    await _reload();
  }

  Future<void> _reload() async {
    final service = _service;
    if (service == null) return;
    setState(() => _loading = true);
    try {
      final backups = await service.listBackups();
      if (!mounted) return;
      setState(() => _backups = backups);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo leer las copias: $error')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createBackup() async {
    final service = _service;
    if (service == null) return;
    setState(() => _busy = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final path = await service.createBackup(db);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Copia creada en $path')));
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear la copia: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRestore(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar copia'),
        content: const Text(
          'Los datos actuales se reemplazarán por los de esta copia. '
          'La copia se aplicará al reiniciar la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _service!.scheduleRestore(path);
      if (!mounted) return;
      final restarted = await _service!.restartNow();
      if (!mounted) return;
      if (!restarted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Restauración programada'),
            content: const Text(
              'Cierra y vuelve a abrir Polaris Finance para aplicar la copia.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo restaurar: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteBackup(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar copia'),
        content: const Text('¿Eliminar esta copia de seguridad?'),
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
    if (confirmed != true || !mounted) return;
    try {
      await _service!.deleteBackup(path);
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo eliminar: $error')));
    }
  }

  String _fileName(String path) {
    final index = path.lastIndexOf(RegExp(r'[/\\]'));
    return index < 0 ? path : path.substring(index + 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Copia de seguridad')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Crea copias de todos tus datos (cuentas, movimientos, metas, '
            'préstamos, tasas). Guarda la copia en un lugar seguro: si pierdes '
            'el teléfono podrás restaurarla.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _createBackup,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_alt),
            label: const Text('Crear copia ahora'),
          ),
          const SizedBox(height: 24),
          Text('Copias guardadas', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_backups.isEmpty)
            Text(
              'Aún no hay copias.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final path in _backups) ...[
                    ListTile(
                      leading: const Icon(Icons.save_outlined),
                      title: Text(
                        _fileName(path),
                        style: theme.textTheme.bodyMedium,
                      ),
                      subtitle: const Text('Toca para restaurar'),
                      trailing: IconButton(
                        tooltip: 'Eliminar',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteBackup(path),
                      ),
                      onTap: () => _confirmRestore(path),
                    ),
                    if (path != _backups.last) const Divider(height: 1),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
