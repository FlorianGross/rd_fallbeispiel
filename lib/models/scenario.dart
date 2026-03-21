import 'package:flutter/material.dart';

class PredefinedScenario {
  final String name;
  final String description;
  final String category;
  final IconData icon;
  final Color color;
  final bool suggestResuscitation;
  final String clinicalPicture;
  final String difficulty;

  const PredefinedScenario({
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.color,
    this.suggestResuscitation = false,
    required this.clinicalPicture,
    required this.difficulty,
  });
}

class PredefinedScenarios {
  static const List<PredefinedScenario> scenarios = [
    PredefinedScenario(
      name: 'Akuter Herzinfarkt',
      description: 'STEMI / NSTEMI – plötzlicher Brustschmerz mit Ausstrahlung',
      category: 'Kardiologie',
      icon: Icons.favorite,
      color: Colors.red,
      clinicalPicture:
          'Patient (58 J., männlich) klagt über starken Brustschmerz seit ~20 min, '
          'Ausstrahlung in den linken Arm, Schweißausbruch, Übelkeit. '
          '"Wie ein Stein auf der Brust." RR 90/60 mmHg, Puls 110/min, SpO₂ 94 %.',
      difficulty: 'Mittel',
    ),
    PredefinedScenario(
      name: 'Schlaganfall (Stroke)',
      description: 'Ischämischer Insult – plötzliche neurologische Ausfälle',
      category: 'Neurologie',
      icon: Icons.psychology,
      color: Colors.purple,
      clinicalPicture:
          'Patientin (72 J.) mit plötzlicher Gesichtslähmung rechts, Armsschwäche links, '
          'verwaschener Sprache. Ereignis seit ~45 min. '
          'GCS 12, RR 180/100 mmHg, Puls 88/min, SpO₂ 96 %.',
      difficulty: 'Mittel',
    ),
    PredefinedScenario(
      name: 'Polytrauma (Verkehrsunfall)',
      description: 'Schwerverletzter nach PKW-Frontalaufprall',
      category: 'Traumatologie',
      icon: Icons.car_crash,
      color: Colors.orange,
      clinicalPicture:
          'Fahrer (34 J.) nach Frontalaufprall, Airbag ausgelöst. '
          'Bewusstseinsgetrübt (GCS 9), Deformierung Lenkrad, Sicherheitsgurt eingeschnitten. '
          'Tachykardie 130/min, RR 80/50 mmHg. Verdacht: Thoraxtrauma + SHT.',
      difficulty: 'Schwer',
    ),
    PredefinedScenario(
      name: 'Kreislaufstillstand (Reanimation)',
      description: 'Plötzlicher Herz-Kreislauf-Stillstand in der Öffentlichkeit',
      category: 'Reanimation',
      icon: Icons.monitor_heart,
      color: Colors.red,
      suggestResuscitation: true,
      clinicalPicture:
          'Person (50 J.) kollabiert auf dem Gehweg. Keine Reaktion, keine normale Atmung, '
          'keine tastbaren Pulse. Zeugen berichten über plötzlichen Kollaps. '
          'CPR-Beginn durch Ersthelfer vor ~2 min.',
      difficulty: 'Schwer',
    ),
    PredefinedScenario(
      name: 'Hypoglykämie',
      description: 'Diabetischer Patient mit schwerer Unterzuckerung',
      category: 'Endokrinologie',
      icon: Icons.bloodtype,
      color: Colors.amber,
      clinicalPicture:
          'Diabetiker Typ 1 (28 J.) von Angehörigen bewusstseinsgetrübt aufgefunden. '
          'Kalter Schweiß, Zittern, verwirrt. Letzte Insulingabe vor ~3 h, '
          'letzte Mahlzeit vor ~8 h. BZ 32 mg/dl.',
      difficulty: 'Einfach',
    ),
    PredefinedScenario(
      name: 'Akuter Asthmaanfall',
      description: 'Schwere bronchospastische Dyspnoe',
      category: 'Pneumologie',
      icon: Icons.air,
      color: Colors.blue,
      clinicalPicture:
          'Asthmatikerin (22 J.) mit bekannter Anamnese, giemende Atmung, '
          'ausgeprägte Dyspnoe, Sitzen in Schonhaltung. '
          'Inhalator zuhause vergessen. SpO₂ 88 %, AF 28/min.',
      difficulty: 'Mittel',
    ),
    PredefinedScenario(
      name: 'Anaphylaxie',
      description: 'Schwere allergische Reaktion nach Insektenstich',
      category: 'Immunologie',
      icon: Icons.warning_amber,
      color: Colors.deepOrange,
      clinicalPicture:
          'Patient (35 J.) nach Bienenstich, generalisierte Urtikaria, '
          'Quincke-Ödem im Gesicht, Stridor, Blutdruckabfall RR 70/40 mmHg. '
          'Keine bekannte Allergie. Puls 130/min, SpO₂ 91 %.',
      difficulty: 'Schwer',
    ),
    PredefinedScenario(
      name: 'Sturz / Schenkelhalsfraktur',
      description: 'Ältere Patientin nach häuslichem Sturz',
      category: 'Traumatologie',
      icon: Icons.elderly,
      color: Colors.brown,
      clinicalPicture:
          'Patientin (82 J.) nach Sturz im Badezimmer, liegt auf dem Boden. '
          'Schmerzen in der rechten Hüfte, Bein in Außenrotation und Verkürzung. '
          'Liegedauer ~2 h, RR 130/85 mmHg, AF 18/min.',
      difficulty: 'Einfach',
    ),
    PredefinedScenario(
      name: 'Medikamenten-Intoxikation',
      description: 'Bewusstlosigkeit nach Benzodiazepineinnahme',
      category: 'Toxikologie',
      icon: Icons.science,
      color: Colors.teal,
      clinicalPicture:
          'Junger Patient (23 J.) bewusstseinsgetrübt aufgefunden, '
          'leere Tablettenpäckchen (Benzodiazepine) in der Nähe. '
          'AF 8/min, enge Pupillen, GCS 8, SpO₂ 89 %.',
      difficulty: 'Mittel',
    ),
    PredefinedScenario(
      name: 'Kindlicher Fieberkrampf',
      description: 'Krampfanfall bei Kleinkind mit hohem Fieber',
      category: 'Pädiatrie',
      icon: Icons.child_care,
      color: Colors.pink,
      clinicalPicture:
          'Kleinkind (2 J.) mit Fieber 40,2 °C. Tonisch-klonischer Krampfanfall '
          'für ~2 min (durch Eltern beobachtet), jetzt postikal verwirrt. '
          'Keine Vorerkrankungen, keine Medikamente, SpO₂ 94 %.',
      difficulty: 'Schwer',
    ),
  ];

  static List<String> get categories {
    final cats = scenarios.map((s) => s.category).toSet().toList();
    cats.sort();
    return cats;
  }
}
