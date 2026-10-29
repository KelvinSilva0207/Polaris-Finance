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
  AccentPreset('Violeta', Color(0xFF7C4DFF)),
  AccentPreset('Índigo', Color(0xFF536DFE)),
  AccentPreset('Cian profundo', Color(0xFF00ACC1)),
  AccentPreset('Lima', Color(0xFF8BC34A)),
  AccentPreset('Naranja', Color(0xFFFFA726)),
  AccentPreset('Orquídea', Color(0xFFAB47BC)),
  AccentPreset('Pizarra', Color(0xFF78909C)),
  AccentPreset('Rojo', Color(0xFFEF5350)),
];

const themeSecondaryPresets = <AccentPreset>[
  AccentPreset('Cyan', Color(0xFF00BCD4)),
  AccentPreset('Menta', Color(0xFF26A69A)),
  AccentPreset('Lavanda', Color(0xFFB39DDB)),
  AccentPreset('Cielo', Color(0xFF4FC3F7)),
  AccentPreset('Durazno', Color(0xFFFFB74D)),
  AccentPreset('Salvia', Color(0xFF81C784)),
  AccentPreset('Rosa suave', Color(0xFFF48FB1)),
  AccentPreset('Arena', Color(0xFFBCAAA4)),
];

const themeBackgroundPresets = <AccentPreset>[
  AccentPreset('Polar', Color(0xFF0B0E14)),
  AccentPreset('Grafito', Color(0xFF141414)),
  AccentPreset('Noche azul', Color(0xFF0B1220)),
  AccentPreset('Violeta', Color(0xFF100B18)),
  AccentPreset('Bosque', Color(0xFF0B1410)),
  AccentPreset('Vino', Color(0xFF170B0D)),
  AccentPreset('Petróleo', Color(0xFF07161A)),
  AccentPreset('Sepia', Color(0xFF17120C)),
];

const themePanelPresets = <AccentPreset>[
  AccentPreset('Polar', Color(0xFF12151D)),
  AccentPreset('Grafito', Color(0xFF1C1C1C)),
  AccentPreset('Noche azul', Color(0xFF131C2E)),
  AccentPreset('Violeta', Color(0xFF1A1226)),
  AccentPreset('Bosque', Color(0xFF12211A)),
  AccentPreset('Vino', Color(0xFF261216)),
  AccentPreset('Petróleo', Color(0xFF0E252B)),
  AccentPreset('Sepia', Color(0xFF251D13)),
];

/// Combinaciones completas de colores para aplicar con un toque.
class ThemePalette {
  const ThemePalette({
    required this.label,
    required this.primary,
    required this.secondary,
    required this.background,
    required this.panel,
  });

  final String label;
  final Color primary;
  final Color secondary;
  final Color background;
  final Color panel;
}

const themePalettes = <ThemePalette>[
  ThemePalette(
    label: 'Polar',
    primary: Color(0xFF9C6BFF),
    secondary: Color(0xFF00BCD4),
    background: Color(0xFF0B0E14),
    panel: Color(0xFF12151D),
  ),
  ThemePalette(
    label: 'Océano',
    primary: Color(0xFF42A5F5),
    secondary: Color(0xFF4DD0E1),
    background: Color(0xFF07121C),
    panel: Color(0xFF0E1E2B),
  ),
  ThemePalette(
    label: 'Bosque',
    primary: Color(0xFF66BB6A),
    secondary: Color(0xFF26A69A),
    background: Color(0xFF0B1410),
    panel: Color(0xFF12211A),
  ),
  ThemePalette(
    label: 'Atardecer',
    primary: Color(0xFFFF7043),
    secondary: Color(0xFFFFB300),
    background: Color(0xFF170B0D),
    panel: Color(0xFF261216),
  ),
  ThemePalette(
    label: 'Lavanda',
    primary: Color(0xFFB39DDB),
    secondary: Color(0xFFF48FB1),
    background: Color(0xFF100B18),
    panel: Color(0xFF1A1226),
  ),
  ThemePalette(
    label: 'Grafito',
    primary: Color(0xFF90A4AE),
    secondary: Color(0xFF00BCD4),
    background: Color(0xFF141414),
    panel: Color(0xFF1C1C1C),
  ),
];

class ThemeEditorScreen extends ConsumerWidget {
  const ThemeEditorScreen({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final dark = _isDark(context, settings.themeMode);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalizar tema'),
        actions: [
          IconButton(
            tooltip: 'Restablecer',
            icon: const Icon(Icons.restart_alt),
            onPressed: () {
              controller.setAccentColor(AppSettingsState.defaults.accentColor);
              controller.setSecondaryColor(
                AppSettingsState.defaults.secondaryColor,
              );
              controller.setBackgroundColor(
                AppSettingsState.defaults.backgroundColor,
              );
              controller.setPanelColor(AppSettingsState.defaults.panelColor);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Paletas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final palette in themePalettes)
                _PaletteCard(
                  palette: palette,
                  selected:
                      settings.accentColorValue ==
                          palette.primary.toARGB32() &&
                      settings.backgroundColorValue ==
                          palette.background.toARGB32() &&
                      settings.panelColorValue == palette.panel.toARGB32(),
                  onTap: () => controller.applyPalette(
                    primary: palette.primary,
                    secondary: palette.secondary,
                    background: palette.background,
                    panel: palette.panel,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Vista previa', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Theme(
            data: dark
                ? AppTheme.dark(
                    settings.accentColor,
                    secondary: settings.secondaryColor,
                    background: settings.backgroundColor,
                    panel: settings.panelColor,
                  )
                : AppTheme.light(
                    settings.accentColor,
                    secondary: settings.secondaryColor,
                  ),
            child: const _PreviewCard(),
          ),
          const SizedBox(height: 20),
          _ColorSection(
            title: 'Color principal',
            value: settings.accentColor,
            presets: themeAccentPresets,
            onChanged: controller.setAccentColor,
          ),
          const SizedBox(height: 16),
          _ColorSection(
            title: 'Color secundario',
            value: settings.secondaryColor,
            presets: themeSecondaryPresets,
            onChanged: controller.setSecondaryColor,
          ),
          const SizedBox(height: 16),
          _ColorSection(
            title: 'Fondo (modo oscuro)',
            value: settings.backgroundColor,
            presets: themeBackgroundPresets,
            minValue: 0.02,
            maxValue: 0.25,
            onChanged: controller.setBackgroundColor,
          ),
          const SizedBox(height: 16),
          _ColorSection(
            title: 'Panel y tarjetas (modo oscuro)',
            value: settings.panelColor,
            presets: themePanelPresets,
            minValue: 0.02,
            maxValue: 0.3,
            onChanged: controller.setPanelColor,
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 8),
          Text(
            'El tema claro usa un fondo suave para no cansar la vista; el '
            'color de fondo se aplica al modo oscuro.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PaletteCard extends StatelessWidget {
  const _PaletteCard({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final ThemePalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 118,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? palette.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _dot(palette.primary),
                const SizedBox(width: 4),
                _dot(palette.secondary),
                const SizedBox(width: 4),
                _dot(palette.panel),
                const Spacer(),
                if (selected)
                  Icon(Icons.check, size: 14, color: palette.primary),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 24,
              decoration: BoxDecoration(
                color: palette.panel,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              palette.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _ColorSection extends StatefulWidget {
  const _ColorSection({
    required this.title,
    required this.value,
    required this.presets,
    required this.onChanged,
    this.minValue = 0.2,
    this.maxValue = 1,
  });

  final String title;
  final Color value;
  final List<AccentPreset> presets;
  final ValueChanged<Color> onChanged;
  final double minValue;
  final double maxValue;

  @override
  State<_ColorSection> createState() => _ColorSectionState();
}

class _ColorSectionState extends State<_ColorSection> {
  late HSVColor _hsv = HSVColor.fromColor(widget.value);
  bool _expanded = false;

  Color get _color => _hsv.toColor();

  void _apply(Color color) {
    setState(() => _hsv = HSVColor.fromColor(color));
    widget.onChanged(color);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hex = _color
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _color,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.title, style: theme.textTheme.titleSmall),
                ),
                Text('#$hex', style: theme.textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final preset in widget.presets)
                  _PresetDot(
                    preset: preset,
                    selected: _color.toARGB32() == preset.color.toARGB32(),
                    onTap: () => _apply(preset.color),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(_expanded ? Icons.expand_less : Icons.tune, size: 18),
              label: Text(_expanded ? 'Ocultar ajuste' : 'Ajuste fino'),
            ),
            if (_expanded) ...[
              _Slider(
                label: 'Tono',
                value: _hsv.hue,
                min: 0,
                max: 360,
                onChanged: (value) =>
                    setState(() => _hsv = _hsv.withHue(value)),
                onChangeEnd: (_) => widget.onChanged(_color),
              ),
              _Slider(
                label: 'Saturación',
                value: _hsv.saturation,
                min: 0,
                max: 1,
                onChanged: (value) =>
                    setState(() => _hsv = _hsv.withSaturation(value)),
                onChangeEnd: (_) => widget.onChanged(_color),
              ),
              _Slider(
                label: 'Brillo',
                value: _hsv.value,
                min: widget.minValue,
                max: widget.maxValue,
                onChanged: (value) =>
                    setState(() => _hsv = _hsv.withValue(value)),
                onChangeEnd: (_) => widget.onChanged(_color),
              ),
            ],
          ],
        ),
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
            value: value.clamp(min, max),
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
    return Tooltip(
      message: preset.label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
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
              ? Icon(
                  Icons.check,
                  size: 20,
                  color: preset.color.computeLuminance() > 0.6
                      ? Colors.black
                      : Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard();

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
              const SizedBox(width: 8),
              Icon(Icons.star, color: theme.colorScheme.secondary, size: 20),
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
