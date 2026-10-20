import 'package:flutter/material.dart';

/// Decisión tomada en [askNewBackupPassphrase]: `protected` indica si la copia
/// se protege con frase y `passphrase` contiene la frase elegida.
typedef NewBackupPassphrase = ({bool protected, String? passphrase});

/// Pregunta si la copia nueva se protege con frase. Devuelve `null` si el
/// usuario canceló.
Future<NewBackupPassphrase?> askNewBackupPassphrase(BuildContext context) {
  return showDialog<NewBackupPassphrase>(
    context: context,
    builder: (context) => const _NewBackupPassphraseDialog(),
  );
}

/// Pide la frase de una copia existente. Devuelve `null` si se canceló.
Future<String?> askRestorePassphrase(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _RestorePassphraseDialog(),
  );
}

class _NewBackupPassphraseDialog extends StatefulWidget {
  const _NewBackupPassphraseDialog();

  @override
  State<_NewBackupPassphraseDialog> createState() =>
      _NewBackupPassphraseDialogState();
}

class _NewBackupPassphraseDialogState
    extends State<_NewBackupPassphraseDialog> {
  static const _minLength = 8;

  final _formKey = GlobalKey<FormState>();
  final _phraseController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _protect = false;

  @override
  void dispose() {
    _phraseController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validatePhrase(String? value) {
    final phrase = value ?? '';
    if (phrase.length < _minLength) {
      return 'Usa al menos $_minLength caracteres';
    }
    return null;
  }

  void _submit() {
    if (!_protect) {
      Navigator.of(context).pop((protected: false, passphrase: null));
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context)
        .pop((protected: true, passphrase: _phraseController.text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Proteger la copia'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Con una frase podrás restaurar esta copia en otro equipo. '
              'Sin frase, la copia solo se podrá abrir en este dispositivo.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _protect,
              onChanged: (value) => setState(() => _protect = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Proteger con frase'),
            ),
            if (_protect) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _phraseController,
                autofocus: true,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Frase de respaldo',
                  helperText: 'Mínimo $_minLength caracteres',
                ),
                validator: _validatePhrase,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Repite la frase'),
                validator: (value) {
                  if (value != _phraseController.text) {
                    return 'Las frases no coinciden';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Continuar')),
      ],
    );
  }
}

class _RestorePassphraseDialog extends StatefulWidget {
  const _RestorePassphraseDialog();

  @override
  State<_RestorePassphraseDialog> createState() =>
      _RestorePassphraseDialogState();
}

class _RestorePassphraseDialogState extends State<_RestorePassphraseDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final phrase = _controller.text;
    if (phrase.isEmpty) return;
    Navigator.of(context).pop(phrase);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Frase de la copia'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'Frase de respaldo',
          helperText: 'La frase con la que se creó esta copia',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Restaurar')),
      ],
    );
  }
}
