import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/sync/sync_models.dart';
import '../../data/sync/sync_providers.dart';
import '../export/file_saver.dart';

/// Pantalla de sincronización en la nube y entre dispositivos.
///
/// Permite:
/// * configurar el servidor de sincronización y activarla;
/// * ver el estado (última sincronización, cambios pendientes);
/// * sincronizar a mano;
/// * pasar los datos a otro dispositivo mediante un archivo de
///   transferencia (sin necesidad de servidor).
class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  late final TextEditingController _endpointController;
  late final TextEditingController _tokenController;
  late final TextEditingController _nameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(syncControllerProvider).config;
    _endpointController = TextEditingController(text: config.endpoint);
    _tokenController = TextEditingController(text: config.token);
    _nameController = TextEditingController(text: config.deviceName);
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _tokenController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save({bool? enabled}) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(syncControllerProvider.notifier)
          .patch(
            enabled: enabled,
            endpoint: _endpointController.text.trim(),
            token: _tokenController.text.trim(),
            deviceName: _nameController.text.trim().isEmpty
                ? 'Este dispositivo'
                : _nameController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Configuración guardada')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo guardar: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _syncNow() async {
    final summary = await ref.read(syncControllerProvider.notifier).syncNow();
    if (!mounted) return;
    final state = ref.read(syncControllerProvider);
    if (summary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.lastError ?? 'No se pudo sincronizar')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Enviados ${summary.pushed} · recibidos ${summary.pulled} · '
          'aplicados ${summary.applied}',
        ),
      ),
    );
  }

  Future<void> _exportTransfer() async {
    try {
      final raw = await ref
          .read(syncControllerProvider.notifier)
          .exportDeviceState();
      final saved = await saveBackupFile(
        'polaris_sincronizacion_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json',
        raw.codeUnits,
      );
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: raw));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transferencia guardada: $saved (copiada al portapapeles)',
          ),
        ),
      );
    } on SaveCanceledException {
      return;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo exportar: $error')));
    }
  }

  Future<void> _importTransfer() async {
    final raw = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: '');
        return AlertDialog(
          title: const Text('Recibir de otro dispositivo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pega aquí el contenido del archivo de transferencia generado '
                'en el otro dispositivo.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText:
                      '{"app": "Polaris Finance", "type": "sync-transfer"}',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Aplicar'),
            ),
          ],
        );
      },
    );
    if (raw == null || raw.trim().isEmpty || !mounted) return;

    final summary = await ref
        .read(syncControllerProvider.notifier)
        .importDeviceState(raw);
    if (!mounted) return;
    final state = ref.read(syncControllerProvider);
    if (summary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.lastError ?? 'No se pudo importar')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Recibidos ${summary.pulled} · aplicados ${summary.applied} · '
          'descartados ${summary.skipped}',
        ),
      ),
    );
  }

  String _statusLabel(SyncState state) {
    switch (state.phase) {
      case SyncPhase.syncing:
        return 'Sincronizando…';
      case SyncPhase.success:
        return 'Sincronizado';
      case SyncPhase.error:
        return 'Error al sincronizar';
      case SyncPhase.disabled:
        return state.config.enabled
            ? 'Sin servidor configurado'
            : 'Desactivada';
      case SyncPhase.idle:
        return 'Sin sincronizar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(syncControllerProvider);
    final controller = ref.read(syncControllerProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sincronización')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        state.phase == SyncPhase.error
                            ? Icons.error_outline
                            : state.phase == SyncPhase.success
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_queue_outlined,
                        color: state.phase == SyncPhase.error
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusLabel(state),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.lastSyncAt == null
                        ? 'Todavía no se ha sincronizado en este dispositivo'
                        : 'Última sincronización: '
                              '${DateFormat('dd/MM/yyyy HH:mm').format(state.lastSyncAt!)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    'Cambios pendientes de enviar: ${state.pendingCount}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (state.lastError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.lastError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: state.isBusy ? null : () => _syncNow(),
                    icon: state.isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: const Text('Sincronizar ahora'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Servidor', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: state.config.enabled,
                    onChanged: (value) => controller.patch(enabled: value),
                    title: const Text('Sincronización en la nube'),
                    subtitle: const Text(
                      'Mantiene los datos al día entre tus dispositivos',
                    ),
                  ),
                  TextField(
                    controller: _endpointController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Dirección del servidor',
                      hintText: 'https://api.midominio.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tokenController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Token de acceso',
                      helperText: 'Se guarda cifrado en este dispositivo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: state.config.autoSync,
                    onChanged: (value) => controller.patch(autoSync: value),
                    title: const Text('Sincronización automática'),
                    subtitle: const Text('Al abrir la app y cada 15 minutos'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: _saving ? null : () => _save(),
                    child: const Text('Guardar configuración'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Este dispositivo', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del dispositivo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ID: ${state.config.deviceId}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copiar ID',
                        icon: const Icon(Icons.copy_all_outlined),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: state.config.deviceId),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ID copiado')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => controller.patch(
                      deviceName: _nameController.text.trim().isEmpty
                          ? 'Este dispositivo'
                          : _nameController.text.trim(),
                    ),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar nombre'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pasar a otro dispositivo',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Genera un archivo con todos tus datos y aplícalo en el otro '
                    'dispositivo. No necesita servidor.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _exportTransfer,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Exportar para otro dispositivo'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _importTransfer,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Recibir de otro dispositivo'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Los datos que se sincronizan son cuentas, categorías, '
            'movimientos, comisiones, metas, servicios, monedas, préstamos, '
            'pagos de préstamos y presupuestos. Cuando dos dispositivos '
            'modifican lo mismo, gana el cambio más reciente.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
