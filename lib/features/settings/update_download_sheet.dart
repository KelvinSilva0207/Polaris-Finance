import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/apk_installer.dart';
import '../../data/services/apk_downloader.dart';
import '../../data/services/update_service.dart';

/// Hoja de descarga e instalacion de la actualizacion.
///
/// La descarga se hace dentro de la app (con progreso, reanudacion y
/// verificacion del tamaño) en lugar de enviar al usuario al navegador, que
/// era donde la descarga se quedaba colgada al final.
Future<void> showUpdateDownloadSheet(BuildContext context, UpdateInfo info) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _UpdateDownloadSheet(info: info),
  );
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '$bytes B';
}

class _UpdateDownloadSheet extends ConsumerStatefulWidget {
  const _UpdateDownloadSheet({required this.info});

  final UpdateInfo info;

  @override
  ConsumerState<_UpdateDownloadSheet> createState() =>
      _UpdateDownloadSheetState();
}

class _UpdateDownloadSheetState extends ConsumerState<_UpdateDownloadSheet> {
  final ApkDownloader _downloader = ApkDownloader();

  bool _cancelled = false;
  ApkDownloadProgress? _progress;
  String? _error;
  File? _file;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    setState(() {
      _cancelled = false;
      _progress = null;
      _error = null;
      _file = null;
    });

    final url = widget.info.downloadUrl;
    if (url == null || url.isEmpty) {
      setState(() => _error = 'No hay enlace de descarga para esta versión.');
      return;
    }

    try {
      final file = await _downloader.download(
        Uri.parse(url),
        fileName: 'polaris-finance-${widget.info.latestVersion}.apk',
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
        isCancelled: () => _cancelled,
      );
      if (!mounted) return;
      setState(() => _file = file);
    } on ApkDownloadCancelled {
      if (mounted) Navigator.of(context).maybePop();
    } on ApkDownloadException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo descargar la actualización: $error',
        );
      }
    }
  }

  Future<void> _install() async {
    final file = _file;
    if (file == null) return;
    final started = await installApk(file.path);
    if (!mounted) return;
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo abrir el instalador. Usa "Descargar en el navegador".',
          ),
        ),
      );
    }
  }

  Future<void> _openInBrowser() async {
    final opened = await ref
        .read(updateServiceProvider)
        .openDownload(widget.info.downloadUrl);
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el navegador.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _progress;
    final file = _file;
    final error = _error;
    final fraction = progress?.fraction;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Actualizar a ${widget.info.latestVersion}',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (error != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 20,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(error, style: theme.textTheme.bodyMedium)),
              ],
            ),
            const SizedBox(height: 16),
          ] else if (file != null) ...[
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Descarga completa (${_formatBytes(file.lengthSync())})',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Al instalar, la app se reemplazará y tus datos se conservarán.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: fraction, minHeight: 8),
            ),
            const SizedBox(height: 12),
            Text(
              progress == null
                  ? 'Conectando...'
                  : '${_formatBytes(progress.received)}'
                        '${progress.total != null ? ' de ${_formatBytes(progress.total!)}' : ''}',
              style: theme.textTheme.bodyMedium,
            ),
            if (progress?.bytesPerSecond != null) ...[
              const SizedBox(height: 4),
              Text(
                '${_formatBytes(progress!.bytesPerSecond!.round())}/s',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
          const SizedBox(height: 20),
          if (error != null)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reintentar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openInBrowser,
                    icon: const Icon(Icons.public, size: 18),
                    label: const Text('Navegador'),
                  ),
                ),
              ],
            )
          else if (file != null)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Cerrar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _install,
                    icon: const Icon(Icons.install_mobile, size: 18),
                    label: const Text('Instalar'),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      _cancelled = true;
                    },
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _openInBrowser,
                    child: const Text('Usar el navegador'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
