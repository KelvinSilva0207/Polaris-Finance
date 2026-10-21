import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/update_service.dart';
import '../../shared/widgets/brand_logo.dart';

/// Ejecuta la verificación mostrando un diálogo de carga y, según el
/// resultado, presenta el diálogo de actualización disponible o un aviso
/// sutil de que la app está al día. Devuelve el [UpdateInfo] obtenido.
Future<UpdateInfo?> runUpdateCheck(BuildContext context, WidgetRef ref) async {
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CheckingUpdatesDialog(),
    ),
  );

  final info = await ref.read(updateServiceProvider).check();

  if (!context.mounted) return info;
  Navigator.of(context, rootNavigator: true).pop();

  if (info.hasUpdate) {
    await ref.read(updateControllerProvider.notifier).check();
    if (!context.mounted) return info;
    await showUpdateDialog(context, info);
  } else if (info.status == UpdateStatus.error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(info.error ?? 'No se pudo comprobar la actualización.'),
      ),
    );
  } else {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Tu aplicación está al día')));
  }
  return info;
}

/// Diálogo con la información de la nueva versión y el botón de actualizar.
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) {
  return showDialog<void>(
    context: context,
    builder: (_) => _UpdateAvailableDialog(info: info),
  );
}

class _CheckingUpdatesDialog extends StatelessWidget {
  const _CheckingUpdatesDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 16),
          Text('Buscando actualizaciones...'),
        ],
      ),
    );
  }
}

class _UpdateAvailableDialog extends ConsumerWidget {
  const _UpdateAvailableDialog({required this.info});

  final UpdateInfo info;

  Future<void> _update(BuildContext context, WidgetRef ref) async {
    final opened = await ref
        .read(updateServiceProvider)
        .openDownload(info.downloadUrl);
    if (!context.mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el enlace de descarga.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notes = info.releaseNotes?.trim();

    return AlertDialog(
      icon: const BrandLogo(height: 56),
      title: const Text('Nueva versión disponible'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _VersionChip(
                  label: 'Actual',
                  value: info.currentVersion,
                  color: scheme.surfaceContainerHighest,
                  onColor: scheme.onSurfaceVariant,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: scheme.primary,
                  ),
                ),
                _VersionChip(
                  label: 'Nueva',
                  value: info.latestVersion,
                  color: scheme.primary,
                  onColor: scheme.onPrimary,
                ),
              ],
            ),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Novedades',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(notes, style: theme.textTheme.bodyMedium),
            ] else ...[
              const SizedBox(height: 16),
              Text(
                'Hay una actualización lista para instalar con mejoras y '
                'correcciones.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Se abrirá el enlace de descarga del APK. Instálalo para '
                    'actualizar la app manteniendo tus datos.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Más tarde'),
        ),
        FilledButton.icon(
          onPressed: () => _update(context, ref),
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Actualizar ahora'),
        ),
      ],
    );
  }
}

class _VersionChip extends StatelessWidget {
  const _VersionChip({
    required this.label,
    required this.value,
    required this.color,
    required this.onColor,
  });

  final String label;
  final String value;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: onColor.withValues(alpha: 0.8),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: onColor,
            ),
          ),
        ],
      ),
    );
  }
}
