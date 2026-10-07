import 'package:flutter/material.dart';

const defaultColorPalette = <Color>[
  Color(0xFF9C6BFF),
  Color(0xFF00BCD4),
  Color(0xFF26A69A),
  Color(0xFFFFB300),
  Color(0xFFFF7043),
  Color(0xFF42A5F5),
  Color(0xFF66BB6A),
  Color(0xFFEC407A),
  Color(0xFF8D6E63),
  Color(0xFF78909C),
];

class ColorPickerRow extends StatelessWidget {
  const ColorPickerRow({
    super.key,
    required this.selected,
    required this.onChanged,
    this.colors = defaultColorPalette,
  });

  final int selected;
  final ValueChanged<int> onChanged;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final color in colors)
          InkWell(
            onTap: () => onChanged(color.toARGB32()),
            customBorder: const CircleBorder(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  width: selected == color.toARGB32() ? 3 : 1,
                  color: selected == color.toARGB32() ? Colors.white : Colors.white24,
                ),
              ),
              child: selected == color.toARGB32()
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          ),
      ],
    );
  }
}