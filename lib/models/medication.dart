/// Ein Medikament aus dem Katalog (Ampulle bzw. Darreichungsform).
///
/// Bewusst ohne Indikationen und Dosierungen: Die App ist ein
/// Trainingswerkzeug und keine Dosierhilfe. Welche Medikamente
/// eigenständig gegeben werden dürfen, ist regional verschieden (ÄLRD).
class Medication {
  /// Wirkstoff, z. B. „Adrenalin“
  final String wirkstoff;

  /// Stärke bzw. Packungsgröße, z. B. „1 mg / 1 ml“
  final String staerke;

  /// Handelsname, z. B. „Suprarenin“
  final String? handelsname;

  const Medication({
    required this.wirkstoff,
    required this.staerke,
    this.handelsname,
  });

  /// Eindeutiger Schlüssel (Wirkstoff + Stärke)
  String get id => '$wirkstoff|$staerke';

  /// Anzeige, z. B. „Adrenalin 1 mg / 1 ml“
  String get label => '$wirkstoff $staerke';

  Map<String, dynamic> toJson() => {
        'wirkstoff': wirkstoff,
        'staerke': staerke,
        if (handelsname != null) 'handelsname': handelsname,
      };

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
        wirkstoff: json['wirkstoff'] as String,
        staerke: json['staerke'] as String,
        handelsname: json['handelsname'] as String?,
      );
}

/// Applikationswege für die Dokumentation
class MedicationRoutes {
  static const List<String> all = [
    'i.v.',
    'i.o.',
    'i.m.',
    'i.n.',
    's.l.',
    'p.o.',
    'inhalativ',
  ];
}

/// Eine dokumentierte Medikamentengabe
class MedicationAdministration {
  final Medication medication;

  /// Dosis als Freitext, z. B. „1 mg“ – wird nie vorbelegt oder berechnet
  final String dose;
  final String route;
  final DateTime timestamp;

  const MedicationAdministration({
    required this.medication,
    required this.dose,
    required this.route,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'medication': medication.toJson(),
        'dose': dose,
        'route': route,
        'timestamp': timestamp.toIso8601String(),
      };

  factory MedicationAdministration.fromJson(Map<String, dynamic> json) =>
      MedicationAdministration(
        medication:
            Medication.fromJson(json['medication'] as Map<String, dynamic>),
        dose: json['dose'] as String,
        route: json['route'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// Medikamentenkatalog nach Bestückungsliste „Rucksack Kreislauf Modul 1“
/// (Medikamente Teil 1–3). Verbrauchsmaterial (Spritzen, Kanülen, Spikes,
/// MAD, Combistopper usw.) und Lösungsmittel für Trockensubstanzen sind
/// nicht enthalten.
class MedicationCatalog {
  static const Medication adrenalin = Medication(
      wirkstoff: 'Adrenalin',
      staerke: '1 mg / 1 ml',
      handelsname: 'Suprarenin');
  static const Medication amiodaron = Medication(
      wirkstoff: 'Amiodaron',
      staerke: '150 mg / 3 ml',
      handelsname: 'Cordarex');

  /// Aktuell verwendeter Katalog: Standard ([all]) oder die in der App
  /// angepasste Liste (siehe `MedicationCatalogService`).
  static List<Medication> current = all;

  /// Standard-Katalog laut Bestückungsliste
  static const List<Medication> all = [
    // Teil 1
    adrenalin,
    amiodaron,
    Medication(wirkstoff: 'Atropin', staerke: '0,5 mg / 1 ml'),
    Medication(
        wirkstoff: 'Butylscopolamin',
        staerke: '20 mg / 1 ml',
        handelsname: 'BS'),
    Medication(
        wirkstoff: 'Cafedrin/Theodrenalin',
        staerke: '2 ml',
        handelsname: 'Akrinor'),
    Medication(
        wirkstoff: 'Dimetinden',
        staerke: '4 mg / 4 ml',
        handelsname: 'Histakut'),
    Medication(
        wirkstoff: 'Flumazenil',
        staerke: '0,5 mg / 5 ml',
        handelsname: 'Anexate'),
    Medication(
        wirkstoff: 'Furosemid', staerke: '40 mg / 4 ml', handelsname: 'Lasix'),
    Medication(wirkstoff: 'Heparin', staerke: '5000 I.E. / 0,5 ml'),
    Medication(
        wirkstoff: 'Esketamin',
        staerke: '50 mg / 2 ml',
        handelsname: 'Ketanest S'),
    Medication(
        wirkstoff: 'Esketamin',
        staerke: '25 mg / 5 ml',
        handelsname: 'Ketanest S'),
    Medication(
        wirkstoff: 'Midazolam',
        staerke: '5 mg / 5 ml',
        handelsname: 'Dormicum'),
    Medication(
        wirkstoff: 'Midazolam',
        staerke: '15 mg / 3 ml',
        handelsname: 'Dormicum'),
    Medication(
        wirkstoff: 'Metoprolol', staerke: '5 mg / 5 ml', handelsname: 'Beloc'),
    Medication(
        wirkstoff: 'Naloxon',
        staerke: '0,4 mg / 1 ml',
        handelsname: 'Narcanti'),
    Medication(
        wirkstoff: 'Norepinephrin',
        staerke: '1 mg / 1 ml',
        handelsname: 'Sinora'),
    Medication(
        wirkstoff: 'Metamizol (Novaminsulfon)',
        staerke: '2,5 g / 5 ml',
        handelsname: 'Novalgin'),
    Medication(wirkstoff: 'Ondansetron', staerke: '8 mg / 4 ml'),
    Medication(
        wirkstoff: 'Terbutalin',
        staerke: '0,5 mg / 1 ml',
        handelsname: 'Bricanyl'),
    Medication(
        wirkstoff: 'Reproterol',
        staerke: '0,09 mg / 1 ml',
        handelsname: 'Bronchospasmin'),
    Medication(
        wirkstoff: 'Urapidil',
        staerke: '25 mg / 5 ml',
        handelsname: 'Ebrantil'),
    Medication(
        wirkstoff: 'Dimenhydrinat', staerke: '62 mg', handelsname: 'Vomex'),
    // Teil 2
    Medication(
        wirkstoff: 'Acetylsalicylsäure',
        staerke: '500 mg Trockensubstanz',
        handelsname: 'ASS'),
    Medication(
        wirkstoff: 'Acetylsalicylsäure',
        staerke: '300 mg Tablette',
        handelsname: 'ASS'),
    Medication(
        wirkstoff: 'Prednisolon',
        staerke: '250 mg Trockensubstanz',
        handelsname: 'Solu-Decortin'),
    Medication(
        wirkstoff: 'Adenosin', staerke: '6 mg / 2 ml', handelsname: 'Adrekar'),
    Medication(wirkstoff: 'Propofol', staerke: '1 % 20 ml'),
    Medication(wirkstoff: 'Magnesium', staerke: '10 % 1 g / 10 ml'),
    Medication(wirkstoff: 'NaCl', staerke: '0,9 % 10 ml'),
    Medication(wirkstoff: 'Glucose', staerke: '40 % 10 ml'),
    Medication(wirkstoff: 'Adrenalin', staerke: '25 mg / 25 ml Stechampulle'),
    Medication(wirkstoff: 'Rocuronium', staerke: '50 mg / 5 ml'),
    Medication(
        wirkstoff: 'Levetiracetam',
        staerke: '500 mg / 5 ml',
        handelsname: 'Keppra'),
    Medication(wirkstoff: 'Tranexamsäure', staerke: '1000 mg / 10 ml'),
    // Teil 3
    Medication(
        wirkstoff: 'Glucose-Gel', staerke: '40 g Tube', handelsname: 'Jubin'),
    Medication(
        wirkstoff: 'Nitroglycerin (Glyceroltrinitrat)',
        staerke: 'Spray',
        handelsname: 'Corangin'),
  ];

  /// Sucht in Wirkstoff, Handelsname und Stärke (ohne Groß-/Kleinschreibung)
  /// Durchsucht den aktuellen Katalog ([current]), alphabetisch sortiert.
  static List<Medication> search(String query) {
    final q = query.trim().toLowerCase();
    final sorted = List<Medication>.of(current)
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    if (q.isEmpty) return sorted;
    return sorted
        .where((m) =>
            m.wirkstoff.toLowerCase().contains(q) ||
            (m.handelsname?.toLowerCase().contains(q) ?? false) ||
            m.staerke.toLowerCase().contains(q))
        .toList();
  }
}
