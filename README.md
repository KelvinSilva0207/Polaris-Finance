# Polaris Finance

Gestión financiera personal minimalista, modular y multimoneda. Multiplataforma (Windows, macOS, Linux, Android, iOS y Web) desde un único código base.

## Stack

- **Flutter** / Dart 3.13
- **drift** (SQLite) — offline-first
- **flutter_riverpod** — estado y modularidad
- **go_router** — navegación
- **shared_preferences** — preferencias de usuario
- **intl** — formato de monedas/fechas

## Estructura (feature-first)

```
lib/
  core/          tema, enrutado, módulos, proveedores base
  data/          drift (tablas, seeds) y modelos
  features/      dashboard, transactions, accounts, rates,
                 loans, goals, services, analytics, settings
  shared/        widgets reutilizables
```

## Estado actual (Fase 0)

- Proyecto Flutter creado con todas las plataformas habilitadas.
- Base de datos SQLite (drift) con los modelos base: `Account`, `Category`, `Transaction`, `FeeRule`, `SavingsGoal`, `RecurringService`, `CurrencyRate`.
- Navegación modular: las pestañas se activan/desactivan en Ajustes.
- Tema dark por defecto con color de acento y modo privacidad (ocultar montos).
- Dashboard con saldo por cuenta y tasa de referencia.

## Roadmap

| Fase | Alcance |
| ---- | ------- |
| 0 | Scaffolding, arquitectura, modelos base, navegación modular (actual) |
| 1 | Onboarding país/bancos, cuentas, transacciones, categorías/etiquetas, tasas (BCV/Binance P2P/manual) |
| 2 | Comisiones configurables, préstamos/deudas, metas de ahorro |
| 3 | Servicios recurrentes, analítica + gastos hormiga, export PDF/CSV/JSON |
| 4 | Sincronización/backup (local + Google Drive), presupuestos, widgets, onboarding final |

## Ejecución

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d chrome
flutter run -d windows   # requiere Visual Studio (C++ workload)
flutter analyze
flutter test
```

## Pendientes de entorno

- Android: instalar Android Studio + SDK.
- Windows desktop: instalar Visual Studio (workload "Desktop development with C++").
- Web: habilitar soporte de drift (drift_wasm) para que la BD funcione en el navegador.

> Importante: en esta máquina `flutter` está en `C:\Users\Usuario\flutter\bin` y `git` en `C:\Program Files\Git\cmd`.