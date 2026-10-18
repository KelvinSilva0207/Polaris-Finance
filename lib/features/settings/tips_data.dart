import 'package:flutter/material.dart';

/// Un consejo financiero concreto.
class FinanceTip {
  const FinanceTip({required this.title, required this.body});

  final String title;
  final String body;
}

/// Agrupación temática de consejos.
class TipTopic {
  const TipTopic({
    required this.title,
    required this.icon,
    required this.color,
    required this.tips,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<FinanceTip> tips;
}

/// Consejos de finanzas personales mostrados en la sección "Consejos".
const financeTipTopics = <TipTopic>[
  TipTopic(
    title: 'Cómo ahorrar',
    icon: Icons.savings_outlined,
    color: Color(0xFF26A69A),
    tips: [
      FinanceTip(
        title: 'Págate a ti primero',
        body:
            'Aparta el ahorro justo al recibir tu ingreso, no lo que sobre a '
            'fin de mes. Un 10 % es un gran punto de partida.',
      ),
      FinanceTip(
        title: 'Regla de las 24 horas',
        body:
            'Antes de una compra no planificada, espera un día. Si sigues '
            'queriéndola mañana, evalúala con calma.',
      ),
      FinanceTip(
        title: 'Fondo de emergencia',
        body:
            'Reúne entre 3 y 6 meses de tus gastos fijos. Es tu colchón para '
            'imprevistos y evita endeudarte.',
      ),
      FinanceTip(
        title: 'Ahorra los aumentos',
        body:
            'Cuando suba tu ingreso, mantén el mismo nivel de gasto y destina '
            'la diferencia directamente al ahorro.',
      ),
    ],
  ),
  TipTopic(
    title: 'Cómo repartir tu dinero',
    icon: Icons.pie_chart_outline,
    color: Color(0xFF42A5F5),
    tips: [
      FinanceTip(
        title: 'Regla 50/30/20',
        body:
            'Destina 50 % a necesidades, 30 % a gustos y 20 % a ahorro e '
            'inversión. Ajústala a tu realidad.',
      ),
      FinanceTip(
        title: 'Presupuesta por categorías',
        body:
            'Asigna un límite a las categorías donde más gastas y revísalo '
            'cada semana, no solo a fin de mes.',
      ),
      FinanceTip(
        title: 'Separa por sobres',
        body:
            'Divide el dinero en sobres: gastos fijos, variables, ahorro y '
            'emergencias. Lo que no se mezcla, no se pierde.',
      ),
    ],
  ),
  TipTopic(
    title: 'Cómo invertir con criterio',
    icon: Icons.trending_up,
    color: Color(0xFFAB47BC),
    tips: [
      FinanceTip(
        title: 'Primero el fondo, luego invertir',
        body:
            'Invierte solo el dinero que no necesitarás en el corto plazo y '
            'después de tener tu fondo de emergencia.',
      ),
      FinanceTip(
        title: 'Diversifica',
        body:
            'No pongas todo en un solo activo o moneda. La diversificación '
            'reduce el riesgo de una caída puntual.',
      ),
      FinanceTip(
        title: 'Interés compuesto',
        body:
            'Reinvertir tus rendimientos hace que tu dinero crezca como bola '
            'de nieve. Empieza pronto, aunque sea con poco.',
      ),
      FinanceTip(
        title: 'Desconfía de lo "seguro y rápido"',
        body:
            'Si te prometen rendimientos altos sin riesgo ni explicación, '
            'probablemente sea una estafa.',
      ),
    ],
  ),
  TipTopic(
    title: 'Cómo manejar las deudas',
    icon: Icons.account_balance_outlined,
    color: Color(0xFFFF7043),
    tips: [
      FinanceTip(
        title: 'Método bola de nieve',
        body:
            'Paga primero la deuda más pequeña: verla desaparecer te da '
            'impulso para seguir con las demás.',
      ),
      FinanceTip(
        title: 'Método avalancha',
        body:
            'Si prefieres eficiencia, ataca primero la deuda con la tasa de '
            'interés más alta.',
      ),
      FinanceTip(
        title: 'No financies gustos con deuda',
        body:
            'Evita pagar en cuotas lo que pierde valor con el tiempo. Reserva '
            'el crédito para lo que te hace crecer.',
      ),
    ],
  ),
  TipTopic(
    title: 'Hábitos y mentalidad',
    icon: Icons.psychology_alt_outlined,
    color: Color(0xFFFFB300),
    tips: [
      FinanceTip(
        title: 'Registra todos los días',
        body:
            'Anotar cada movimiento tarda segundos y te vuelve consciente de '
            'tus patrones de gasto.',
      ),
      FinanceTip(
        title: 'Compara meses, no personas',
        body:
            'Tu progreso se mide contra tu yo del mes pasado, no contra lo que '
            'ves en redes sociales.',
      ),
      FinanceTip(
        title: 'Revisiones semanales',
        body:
            'Dedica 10 minutos cada semana a revisar presupuestos y metas. '
            'Ajustar a tiempo evita sorpresas.',
      ),
    ],
  ),
];

/// Índice determinista del "consejo del día".
FinanceTip tipOfTheDay(DateTime date) {
  final all = [for (final topic in financeTipTopics) ...topic.tips];
  final days = DateTime(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime(2024, 1, 1)).inDays;
  return all[days.abs() % all.length];
}
