/// Status eines Rettungsmittels
enum VehicleStatus {
  none, // Nicht angefordert
  besetzt, // Besetzt/Abgemeldet
  kommt, // Auf Anfahrt
}

/// BPM-Grenzwerte für die Reanimationsqualität
class BpmThresholds {
  static const int optimalMin = 100;
  static const int optimalMax = 120;
  static const int acceptableMin = 90;
  static const int acceptableMax = 130;
}

/// Eine durchgeführte Maßnahme
class CompletedAction {
  final String schema;
  final String action;
  final DateTime timestamp;

  const CompletedAction({
    required this.schema,
    required this.action,
    required this.timestamp,
  });
}

/// Eine fehlende verpflichtende Maßnahme
class MissingAction {
  final String schema;
  final String action;
  final RequirementLevel requirementLevel;
  final String? note;

  const MissingAction({
    required this.schema,
    required this.action,
    required this.requirementLevel,
    this.note,
  });
}

/// Qualifikationsstufen
enum Qualification {
  SAN, // Sanitäter
  RH, // Rettungshelfer
  RS, // Rettungssanitäter
  NFS, // Notfallsanitäter
}

/// Anforderungsstufe für eine Maßnahme pro Qualifikation
enum RequirementLevel {
  notApplicable, // Kann nicht durchgeführt werden (über Qualifikation)
  optional, // Kann durchgeführt werden, wird aber nicht erwartet
  expected, // Wird erwartet, aber nicht zwingend
  required, // Verpflichtend
}

/// Model für eine Maßnahme mit qualifikationsabhängigen Anforderungen
class MeasureRequirement {
  final String schema;
  final String action;
  final String? note; // Optionale Notiz/Hinweis

  // Anforderungsstufen pro Qualifikation
  final Map<Qualification, RequirementLevel> requirementByQualification;

  MeasureRequirement({
    required this.schema,
    required this.action,
    this.note,
    Map<Qualification, RequirementLevel>? requirementByQualification,
  }) : requirementByQualification = requirementByQualification ??
            {
              Qualification.SAN: RequirementLevel.required,
              Qualification.RH: RequirementLevel.required,
              Qualification.RS: RequirementLevel.required,
              Qualification.NFS: RequirementLevel.required,
            };

  /// Factory für einfache verpflichtende Maßnahmen (für alle Qualifikationen)
  factory MeasureRequirement.required({
    required String schema,
    required String action,
    String? note,
  }) {
    return MeasureRequirement(
      schema: schema,
      action: action,
      note: note,
      requirementByQualification: {
        Qualification.SAN: RequirementLevel.required,
        Qualification.RH: RequirementLevel.required,
        Qualification.RS: RequirementLevel.required,
        Qualification.NFS: RequirementLevel.required,
      },
    );
  }

  /// Factory für optionale Maßnahmen (für alle Qualifikationen)
  factory MeasureRequirement.optional({
    required String schema,
    required String action,
    String? note,
  }) {
    return MeasureRequirement(
      schema: schema,
      action: action,
      note: note,
      requirementByQualification: {
        Qualification.SAN: RequirementLevel.optional,
        Qualification.RH: RequirementLevel.optional,
        Qualification.RS: RequirementLevel.optional,
        Qualification.NFS: RequirementLevel.optional,
      },
    );
  }

  /// Factory für Maßnahmen, die erst ab einer bestimmten Qualifikation verfügbar sind
  factory MeasureRequirement.fromQualification({
    required String schema,
    required String action,
    required Qualification minQualification,
    bool optionalForMinQual = false,
    String? note,
  }) {
    final Map<Qualification, RequirementLevel> requirements = {};

    for (var qual in Qualification.values) {
      if (qual.index < minQualification.index) {
        // Unterhalb der Mindestqualifikation: nicht verfügbar
        requirements[qual] = RequirementLevel.notApplicable;
      } else if (qual.index == minQualification.index) {
        // Bei Mindestqualifikation: optional oder verpflichtend
        requirements[qual] = optionalForMinQual
            ? RequirementLevel.optional
            : RequirementLevel.required;
      } else {
        // Über der Mindestqualifikation: verpflichtend
        requirements[qual] = RequirementLevel.required;
      }
    }

    return MeasureRequirement(
      schema: schema,
      action: action,
      note: note,
      requirementByQualification: requirements,
    );
  }

  /// Gibt die Anforderungsstufe für eine bestimmte Qualifikation zurück
  RequirementLevel getRequirementLevel(Qualification qualification) {
    return requirementByQualification[qualification] ??
        RequirementLevel.required;
  }

  /// Prüft ob die Maßnahme mit der gegebenen Qualifikation durchgeführt werden kann
  bool canPerformWithQualification(Qualification userQualification) {
    return getRequirementLevel(userQualification) !=
        RequirementLevel.notApplicable;
  }

  /// Gibt zurück ob die Maßnahme als fehlend gewertet werden soll
  bool shouldCountAsMissing(Qualification userQualification) {
    final level = getRequirementLevel(userQualification);
    return level == RequirementLevel.required;
  }

  /// Prüft ob die Maßnahme für diese Qualifikation optional ist
  bool isOptionalFor(Qualification userQualification) {
    final level = getRequirementLevel(userQualification);
    return level == RequirementLevel.optional ||
        level == RequirementLevel.expected;
  }
}

/// Vordefinierte Maßnahmenanforderungen
class MeasureRequirements {
  static final Map<String, List<MeasureRequirement>> requirements = {
    'SSSS': [
      MeasureRequirement.required(schema: 'SSSS', action: 'Scene'),
      MeasureRequirement.required(schema: 'SSSS', action: 'Safety'),
      MeasureRequirement.required(schema: 'SSSS', action: 'Situation'),
      MeasureRequirement.required(schema: 'SSSS', action: 'Support'),
    ],
    'Erster Eindruck': [
      MeasureRequirement.required(schema: 'Erster Eindruck', action: 'Zyanose'),
      MeasureRequirement.required(
          schema: 'Erster Eindruck', action: 'Austreten Flüssigkeiten'),
      MeasureRequirement.required(
          schema: 'Erster Eindruck', action: 'Hauttonus'),
      MeasureRequirement.required(
          schema: 'Erster Eindruck', action: 'Pathologische Atemgeräusche'),
      MeasureRequirement.required(
          schema: 'Erster Eindruck', action: 'Allgemeinzustand'),
    ],
    'WASB': [
      MeasureRequirement.required(schema: 'WASB', action: 'Wach'),
      MeasureRequirement.required(schema: 'WASB', action: 'Ansprechbar'),
      MeasureRequirement.required(schema: 'WASB', action: 'Schmerzreiz'),
      MeasureRequirement.required(schema: 'WASB', action: 'Bewusstlos'),
    ],
    'c/x': [
      MeasureRequirement.required(schema: 'c/x', action: 'Kritische Blutungen'),
    ],
    'a': [
      MeasureRequirement.required(schema: 'a', action: 'Atemwege Frei'),
      MeasureRequirement(
        schema: 'a',
        action: 'Schleimhautfarbe',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'a',
        action: 'Schleimhautfeuchtigkeit',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      // Zahnstatus: Für SAN optional, für RH und RS verpflichtend
      MeasureRequirement(
        schema: 'a',
        action: 'Zahnstatus',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
    ],
    'b': [
      MeasureRequirement.required(schema: 'b', action: 'Atemfrequenz'),
      MeasureRequirement.required(schema: 'b', action: 'Atemzugvolumen'),
    ],
    'c': [
      MeasureRequirement.required(schema: 'c', action: 'Pulsfrequenz'),
      MeasureRequirement.required(schema: 'c', action: 'Tastbarkeit'),
      MeasureRequirement.required(schema: 'c', action: 'Rythmik'),
      MeasureRequirement.required(schema: 'c', action: 'Recap'),
    ],
    'STU': [
      MeasureRequirement(
        schema: 'STU',
        action: 'Rückenlage',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'Kopf-Fixierung',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'Blutungen Kopf',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'Gesichtsknochen',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'Austritt Flüssigkeiten Nase',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'Austritt Flüssigkeiten Ohr',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'Pupillen Isokor',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'Battlesigns',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'HWS Stufenbildung',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'HWS Hartspann',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'Trachea zentral',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'Halsvenenstauung',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'Thorax 2 Ebenen',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'Auskultation',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'Abdomen Palpation',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'Abdomen Abwehrspannung',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'Abdomen Druckschmerz',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'Beckenstabilität',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'Oberschenkel Volumen',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'Oberschenkel 2 Ebenen',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'pDMS Beine',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'pDMS Arme',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'Achsengerechte Drehung',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'Rücken Stufenbildung',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'STU',
        action: 'Rücken Hartspann',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
    ],
    'A': [
      MeasureRequirement.optional(schema: 'A', action: 'Reevaluation Atemwege'),
    ],
    'B': [
      MeasureRequirement(
        schema: 'B',
        action: 'Auskultation Beidseits',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'B',
        action: 'Auskultation Atemgeräusche',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement.required(schema: 'B', action: 'Atemhilfsmuskulatur'),
      MeasureRequirement.required(schema: 'B', action: 'Sp02'),
      MeasureRequirement(
        schema: 'B',
        action: 'etCO2',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.notApplicable,
          Qualification.RH: RequirementLevel.optional,
          Qualification.RS: RequirementLevel.optional,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement.required(schema: 'B', action: 'Atemmuster'),
    ],
    'C': [
      MeasureRequirement.required(schema: 'C', action: 'Blutdruck'),
      MeasureRequirement.required(schema: 'C', action: 'Puls'),
      MeasureRequirement.required(schema: 'C', action: 'Recap'),
      MeasureRequirement(
        schema: 'C',
        action: 'EKG',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.optional,
          Qualification.RS: RequirementLevel.optional,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
    ],
    'D': [
      MeasureRequirement(
        schema: 'D',
        action: 'Pupillenkontrolle',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'D',
        action: 'GCS',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement.required(schema: 'D', action: 'BZ'),
    ],
    'E': [
      MeasureRequirement.required(schema: 'E', action: 'Temperatur'),
      MeasureRequirement.required(schema: 'E', action: 'Body-Check'),
      MeasureRequirement.required(schema: 'E', action: 'Exikkose'),
      MeasureRequirement.required(schema: 'E', action: 'Ödeme'),
      MeasureRequirement.required(schema: 'E', action: 'Verletzungen'),
      MeasureRequirement(
        schema: 'E',
        action: 'Einstichstellen',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
      MeasureRequirement(
        schema: 'E',
        action: 'Insulinpumpe',
        requirementByQualification: {
          Qualification.SAN: RequirementLevel.optional,
          Qualification.RH: RequirementLevel.required,
          Qualification.RS: RequirementLevel.required,
          Qualification.NFS: RequirementLevel.required,
        },
      ),
    ],
    'BE-FAST': [
      MeasureRequirement.required(schema: 'BE-FAST', action: 'Balance'),
      MeasureRequirement.required(schema: 'BE-FAST', action: 'Eyes'),
      MeasureRequirement.required(schema: 'BE-FAST', action: 'Face'),
      MeasureRequirement.required(schema: 'BE-FAST', action: 'Arms'),
      MeasureRequirement.required(schema: 'BE-FAST', action: 'Speech'),
      MeasureRequirement.required(schema: 'BE-FAST', action: 'Time'),
    ],
    'ZOPS': [
      MeasureRequirement.required(schema: 'ZOPS', action: 'Zeit'),
      MeasureRequirement.required(schema: 'ZOPS', action: 'Ort'),
      MeasureRequirement.required(schema: 'ZOPS', action: 'Person'),
      MeasureRequirement.required(schema: 'ZOPS', action: 'Situation'),
    ],
    'SAMPLERS': [
      MeasureRequirement.required(schema: 'SAMPLERS', action: 'Symptome'),
      MeasureRequirement.required(schema: 'SAMPLERS', action: 'Allergien'),
      MeasureRequirement.required(schema: 'SAMPLERS', action: 'Medikamente'),
      MeasureRequirement.required(
          schema: 'SAMPLERS', action: 'Patientenvorgeschichte'),
      MeasureRequirement.required(
          schema: 'SAMPLERS',
          action: 'Letzte Mahlzeit / Flüssigkeits Aufnahme,...'),
      MeasureRequirement.required(schema: 'SAMPLERS', action: 'Ereignis'),
      MeasureRequirement.required(schema: 'SAMPLERS', action: 'Risikofaktoren'),
      MeasureRequirement.required(
          schema: 'SAMPLERS', action: 'Schwangerschaft'),
    ],
    'OPQRST': [
      MeasureRequirement.required(schema: 'OPQRST', action: 'Onset'),
      MeasureRequirement.required(schema: 'OPQRST', action: 'Provocation'),
      MeasureRequirement.required(schema: 'OPQRST', action: 'Quality'),
      MeasureRequirement.required(schema: 'OPQRST', action: 'Radiation'),
      MeasureRequirement.required(schema: 'OPQRST', action: 'Severity'),
      MeasureRequirement.required(schema: 'OPQRST', action: 'Time'),
    ],
    'Maßnahmen': [
      MeasureRequirement.optional(
          schema: 'Maßnahmen', action: 'Sauerstoffgabe'),
      MeasureRequirement.optional(
          schema: 'Maßnahmen', action: 'Beatmung (kontrolliert/assistiert)'),
      MeasureRequirement.optional(schema: 'Maßnahmen', action: 'Wärmeerhalt'),
      MeasureRequirement.optional(
        schema: 'Maßnahmen',
        action: 'Intubation',
      ),
      MeasureRequirement.optional(schema: 'Maßnahmen', action: 'Lagerung'),
      MeasureRequirement.optional(
        schema: 'Maßnahmen',
        action: 'Defibrillation',
      ),
      MeasureRequirement.optional(schema: 'Maßnahmen', action: 'Reanimation'),
    ],
    'Maßnahmen (erweitert)': [
      MeasureRequirement.fromQualification(
        schema: 'Maßnahmen (erweitert)',
        action: 'Zugang IV / IO',
        minQualification: Qualification.RS,
        optionalForMinQual: true,
      ),
      MeasureRequirement.fromQualification(
        schema: 'Maßnahmen (erweitert)',
        action: 'Volumengabe',
        minQualification: Qualification.RS,
        optionalForMinQual: true,
      ),
      MeasureRequirement.fromQualification(
        schema: 'Maßnahmen (erweitert)',
        action: 'Medikamentengabe',
        minQualification: Qualification.RS,
        optionalForMinQual: true,
      ),
      MeasureRequirement.fromQualification(
        schema: 'Maßnahmen (erweitert)',
        action: 'Larynxtubus',
        minQualification: Qualification.RS,
        optionalForMinQual: true,
      ),
    ],
    'Nachforderung': [
      MeasureRequirement.optional(schema: 'Nachforderung', action: 'NEF'),
      MeasureRequirement.optional(schema: 'Nachforderung', action: 'RTW'),
      MeasureRequirement.optional(schema: 'Nachforderung', action: 'RTH'),
      MeasureRequirement.optional(schema: 'Nachforderung', action: 'KTW'),
      MeasureRequirement.optional(schema: 'Nachforderung', action: 'Feuerwehr'),
      MeasureRequirement.optional(schema: 'Nachforderung', action: 'Polizei'),
      MeasureRequirement.optional(schema: 'Nachforderung', action: 'PSNV'),
      MeasureRequirement.optional(schema: 'Nachforderung', action: 'Sonstige'),
    ],
  };

  /// Hilfsfunktion um alle Maßnahmen eines Schemas zu bekommen
  static List<String> getActionsForSchema(String schema) {
    return requirements[schema]?.map((req) => req.action).toList() ?? [];
  }

  /// Hilfsfunktion um eine spezifische Maßnahmenanforderung zu bekommen
  static MeasureRequirement? getRequirement(String schema, String action) {
    return requirements[schema]?.firstWhere(
      (req) => req.action == action,
      orElse: () => MeasureRequirement.required(schema: schema, action: action),
    );
  }

  /// Berechnet fehlende verpflichtende Maßnahmen basierend auf Qualifikation
  static List<MissingAction> calculateMissingRequiredActions(
    List<CompletedAction> completedActions,
    Qualification userQualification,
  ) {
    List<MissingAction> missingRequired = [];

    requirements.forEach((schema, measures) {
      for (var measure in measures) {
        // Prüfe ob die Maßnahme durchgeführt wurde
        bool isCompleted = completedActions.any(
          (action) =>
              action.schema == measure.schema &&
              action.action == measure.action,
        );

        // Wenn nicht durchgeführt und verpflichtend für diese Qualifikation
        if (!isCompleted && measure.shouldCountAsMissing(userQualification)) {
          missingRequired.add(MissingAction(
            schema: measure.schema,
            action: measure.action,
            requirementLevel: measure.getRequirementLevel(userQualification),
            note: measure.note,
          ));
        }
      }
    });

    return missingRequired;
  }
}
