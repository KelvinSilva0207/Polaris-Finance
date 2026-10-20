import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_settings.dart';
import '../../core/theme/app_theme.dart';

class AccentPreset {
  const AccentPreset(this.label, this.color);

  final String label;
  final Color color;
}

const themeAccentPresets = <AccentPreset>[
  AccentPreset('Morado', Color(0xFF9C6BFF)),
  AccentPreset('Azul polar', Color(0xFF42A5F5)),
  AccentPreset('Cyan', Color(0xFF00BCD4)),
  AccentPreset('Verde neón', Color(0xFF00E676)),
  AccentPreset('Ámbar', Color(0xFFFFB300)),
  AccentPreset('Coral', Color(0xFFFF7043)),
  AccentPreset('Rosa', Color(0xFFEC407A)),
  AccentPreset('Turquesa', Color(0xFF26A69A)),
];

class ThemeEditorScreen extends ConsumerStatefulWidget {
  const ThemeEditorScreen({super.key});

  @override
  ConsumerState<ThemeEditorScreen> createState() => _ThemeEditorScreenState();
}

class _ThemeEditorScreenState extends ConsumerState<ThemeEditorScreen> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    _hsv = HSVColor.fromColor(settings.accentColor);
  }

  Color get _color => _hsv.toColor();

  void _apply(Color color) {
    setState(() => _hsv = HSVColor.fromColor(color));
    ref.read(appSettingsProvider.notifier).setAccentColor(color);
  }

  void _persist() {
    ref.read(appSettingsProvider.notifier).setAccentColor(_color);
  }

  bool _isDark(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final dark = _isDark(context, settings.themeMode);
    final hex = _color
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalizar tema'),
        actions: [
          IconButton(
            tooltip: 'Restablecer',
            icon: const Icon(Icons.restart_alt),
            onPressed: () => _apply(const Color(0xFF9C6BFF)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Vista previa', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Theme(
            data: dark ? AppTheme.dark(_color) : AppTheme.light(_color),
            child: _PreviewCard(dark: dark),
          ),
          const SizedBox(height: 20),
          Text(
            'Color de acento',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final preset in themeAccentPresets)
                _PresetDot(
                  preset: preset,
                  selected: _color.toARGB32() == preset.color.toARGB32(),
                  onTap: () => _apply(preset.color),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Personalizado',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      Text(
                        '#$hex',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _Slider(
                    label: 'Tono',
                    value: _hsv.hue,
                    min: 0,
                    max: 360,
                    onChanged: (value) =>
                        setState(() => _hsv = _hsv.withHue(value)),
                    onChangeEnd: (_) => _persist(),
                  ),
                  _Slider(
                    label: 'Saturación',
                    value: _hsv.saturation,
                    min: 0,
                    max: 1,
                    onChanged: (value) =>
                        setState(() => _hsv = _hsv.withSaturation(value)),
                    onChangeEnd: (_) => _persist(),
                  ),
                  _Slider(
                    label: 'Brillo',
                    value: _hsv.value,
                    min: 0.2,
                    max: 1,
                    onChanged: (value) =>
                        setState(() => _hsv = _hsv.withValue(value)),
                    onChangeEnd: (_) => _persist(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Modo', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('Sistema'),
                icon: Icon(Icons.brightness_auto_outlined, size: 18),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Claro'),
                icon: Icon(Icons.light_mode_outlined, size: 18),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Oscuro'),
                icon: Icon(Icons.dark_mode_outlined, size: 18),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (selection) =>
                controller.setThemeMode(selection.first),
          ),
        ],
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }
}

class _PresetDot extends StatelessWidget {
  const _PresetDot({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final AccentPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: preset.color,
              border: Border.all(
                width: selected ? 3 : 1,
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(preset.label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Saldo total', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    r'$ 1.250,00',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: 0.62,
                      minHeight: 10,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(onPressed: () {}, child: const Text('Guardar')),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () {}, child: const Text('Cancelar')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ChoiceChip(
                label: const Text('VES'),
                selected: true,
                onSelected: (_) {},
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('USD'),
                selected: false,
                onSelected: (_) {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}
