/// Una tipografía seleccionable por el usuario. [family] es el nombre tal como
/// lo conoce `google_fonts` (null = fuente del sistema).
class AppFont {
  const AppFont({
    required this.id,
    required this.label,
    required this.description,
    this.family,
  });

  final String id;
  final String label;
  final String description;
  final String? family;
}

/// Catálogo de tipografías que combinan con el diseño de la app.
abstract final class AppFonts {
  static const defaultId = 'default';

  static const catalog = <AppFont>[
    AppFont(
      id: defaultId,
      label: 'Predeterminada',
      description: 'La fuente del sistema',
    ),
    AppFont(
      id: 'jakarta',
      label: 'Plus Jakarta Sans',
      description: 'Moderna y premium',
      family: 'Plus Jakarta Sans',
    ),
    AppFont(
      id: 'inter',
      label: 'Inter',
      description: 'Nítida y neutra',
      family: 'Inter',
    ),
    AppFont(
      id: 'manrope',
      label: 'Manrope',
      description: 'Geométrica y suave',
      family: 'Manrope',
    ),
    AppFont(
      id: 'space',
      label: 'Space Grotesk',
      description: 'Tecnológica y con carácter',
      family: 'Space Grotesk',
    ),
    AppFont(
      id: 'lora',
      label: 'Lora',
      description: 'Serif elegante',
      family: 'Lora',
    ),
  ];

  static AppFont byId(String id) =>
      catalog.firstWhere((font) => font.id == id, orElse: () => catalog.first);

  static String? familyOf(String id) => byId(id).family;
}
