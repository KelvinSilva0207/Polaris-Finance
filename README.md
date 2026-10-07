# Polaris Finance

Gestión financiera personal minimalista, modular y multimoneda. Multiplataforma (Windows, macOS, Linux, Android, iOS y Web) desde un único código base.

## Stack

- **Flutter** / Dart 3.13
- **drift** (SQLite) — offline-first
- **flutter_riverpod** — estado y modularidad
- **go_router** — navegación
- **shared_preferences** — preferencias de usuario
- **intl** — formato de monedas/fechas
- **http** — tasas de referencia (BCV, Binance P2P)

## Estructura (feature-first)

```
lib/
  core/          tema, enrutado, módulos, proveedores base
  data/          drift (tablas, seeds) y modelos
  features/      dashboard, transactions, accounts, rates,
                 loans, goals, services, analytics, settings
  shared/        widgets reutilizables
```

## Estado actual (Fase 2)

- Base de datos SQLite (drift) con los modelos base: `Account`, `Category`, `Transaction`, `FeeRule`, `SavingsGoal`, `RecurringService`, `CurrencyRate`, `Loan`, `LoanPayment` (schema v3).
- Navegación modular: las pestañas se activan/desactivan en Ajustes.
- Tema dark por defecto con color de acento y modo privacidad (ocultar montos).
- Dashboard con saldo por cuenta y tasa de referencia.
- Cuentas: alta, edición y borrado (tipos banco/billetera/cripto/efectivo), sugerencias de instituciones venezolanas, selector de icono y color.
- Transacciones: ingresos, egresos y transferencias entre cuentas con fecha/hora, nota y etiquetas; CRUD completo y conversión USD ↔ VES según la tasa de referencia.
- Categorías personalizadas (ingresos/egresos) sobre el set predefinido.
- Tasas de referencia: BCV (pydolarve.org), Binance P2P (USDT/VES) y manual, con historial guardado.
- Metas de ahorro: objetivos vinculados a cuentas, aportes (virtuales o con transferencia real), historial de progreso y cierre.
- Comisiones configurables: reglas fijo + % con mínimo/máximo, aplicadas a movimientos con cálculo en vivo.
- Préstamos/deudas: "Debo" y "Me deben" con pagos/cobros, historial, estado abierta/cerrada e interés.
- Onboarding de primer uso: país + creación rápida de cuentas sugeridas (omisible).

## Roadmap

| Fase | Alcance |
| ---- | ------- |
| 0 | Scaffolding, arquitectura, modelos base, navegación modular |
| 1 | Cuentas, transacciones, categorías/etiquetas, tasas (BCV/Binance P2P/manual) |
| 2 | Comisiones configurables, préstamos/deudas, metas de ahorro, onboarding (actual) |
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

- Android: los APK se compilan en GitHub Actions (ver `.github/workflows/build-apk.yml`) y se descargan como artefacto; para compilar en local instalar Android Studio + SDK.
- Windows desktop: Visual Studio 2022 BuildTools con workload "Desktop development with C++" (ya instalado en esta máquina).
- Web: habilitar soporte de drift (drift_wasm) para que la BD funcione en el navegador.

> Importante: en esta máquina `flutter` está en `C:\Users\Usuario\flutter\bin` y `git` en `C:\Program Files\Git\cmd`.