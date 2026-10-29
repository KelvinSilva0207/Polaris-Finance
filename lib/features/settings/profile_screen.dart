import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_settings.dart';
import '../../data/models/currencies.dart';
import '../../shared/widgets/profile_avatar.dart';

/// Redimensiona la imagen elegida y la devuelve como PNG en base64.
Future<String?> pickAvatarBase64() async {
  final result = await FilePicker.pickFiles(
    dialogTitle: 'Elige una foto de perfil',
    type: FileType.image,
  );
  if (result.isEmpty) return null;
  final Uint8List bytes;
  try {
    bytes = await result.first.readAsBytes();
  } catch (_) {
    return null;
  }
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 320);
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  frame.image.dispose();
  codec.dispose();
  if (data == null) return null;
  return base64Encode(data.buffer.asUint8List());
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late String _baseCurrency;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    _nameController = TextEditingController(text: settings.profileName);
    _bioController = TextEditingController(text: settings.profileBio);
    _baseCurrency = settings.baseCurrency;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    setState(() => _saving = true);
    final controller = ref.read(appSettingsProvider.notifier);
    await controller.setProfileName(_nameController.text);
    await controller.setProfileBio(_bioController.text);
    await controller.setBaseCurrency(_baseCurrency);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
  }

  Future<void> _pickAvatar() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final avatar = await pickAvatarBase64();
      if (avatar == null) return;
      await ref.read(appSettingsProvider.notifier).setProfileAvatar(avatar);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo usar la imagen: $error')),
      );
    }
  }

  Future<void> _removeAvatar() async {
    await ref.read(appSettingsProvider.notifier).setProfileAvatar('');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final theme = Theme.of(context);
    final initialsName = _nameController.text.trim().isEmpty
        ? settings.profileName
        : _nameController.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ProfileAvatar(
              base64Image: settings.profileAvatar,
              name: initialsName,
              size: 112,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _pickAvatar,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Elegir foto'),
              ),
              if (settings.profileAvatar.isNotEmpty) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _removeAvatar,
                  icon: const Icon(Icons.close),
                  label: const Text('Quitar'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      hintText: '¿Cómo te llamas?',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bioController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'Biografía corta',
                      hintText: 'Ej.: Ahorrando para mi primer viaje',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _baseCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Moneda base',
                      helperText: 'Se usa para mostrar equivalencias',
                    ),
                    items: [
                      for (final code in commonCurrencies)
                        DropdownMenuItem(
                          value: code,
                          child: Text('$code · ${currencySymbol(code)}'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _baseCurrency = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveName,
                    icon: const Icon(Icons.check),
                    label: const Text('Guardar'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Tu nombre, foto, biografía y moneda base se guardan solo en este '
              'dispositivo.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
