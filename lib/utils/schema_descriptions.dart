/// Kurzbeschreibungen für die einzelnen Schemata (als Tooltip / Info-Dialog)
const Map<String, String> schemaDescriptions = {
  'SSSS':
      'Scene – Safety – Situation – Support\n'
      'Erste Überblick am Einsatzort: Gefahren erkennen, Einsatzsicherheit '
      'herstellen, Situation erfassen, Unterstützung organisieren.',

  'Erster Eindruck':
      'Schnellbeurteilung des Allgemeinzustands (5–10 Sekunden).\n'
      'Lebensbedrohliche Zeichen, Zyanose, Atemgeräusche, Hauttonus.',

  'WASB':
      'Bewusstseinsstatus nach AVPU-Prinzip:\n'
      'Wach – Ansprechbar – Schmerzreaktiv – Bewusstlos.',

  'c/x':
      'Kritische externe Blutungskontrolle (Catastrophic Haemorrhage).\n'
      'Lebensbedrohliche Blutungen sofort stillen, bevor ABCDE beginnt.',

  'a':
      'Primäre Atemwegskontrolle:\n'
      'Durchgängigkeit der Atemwege, Schleimhautfarbe und -feuchtigkeit, Zahnstatus.',

  'b':
      'Primäre Atembeurteilung:\n'
      'Atemfrequenz und Atemzugvolumen visuell erfassen.',

  'c':
      'Primäre Kreislaufbeurteilung:\n'
      'Pulsfrequenz, Tastbarkeit, Rhythmik, Pulsqualität, Rekapillarisierungszeit.',

  'STU':
      'Sekundäres Trauma-Assessment – Kopf bis Fuß:\n'
      'Systematische körperliche Untersuchung auf Verletzungen, Instabilitäten '
      'und neurologische Ausfälle.',

  'A':
      'Sekundäre Atemwegskontrolle:\n'
      'Reevaluation nach Erstversorgung, Sicherung des Atemwegs prüfen.',

  'B':
      'Sekundäre Atembeurteilung mit Monitoring:\n'
      'Auskultation, Atemhilfsmuskulatur, SpO₂, etCO₂ (ab NFS), Atemmuster.',

  'C':
      'Sekundäre Kreislaufbeurteilung mit Monitoring:\n'
      'Blutdruck, Puls, Recap, EKG (ab NFS), Schock-Index.',

  'D':
      'Disability – Neurologischer Status:\n'
      'Pupillenkontrolle, Glasgow Coma Scale (Augen/Motorik/Verbal), Blutzucker.',

  'E':
      'Exposure – Körperliche Untersuchung:\n'
      'Temperatur, Body-Check (Entkleiden), Exsikkose, Ödeme, Verletzungen, '
      'Einstichstellen, Insulinpumpe.',

  'BE-FAST':
      'Schlaganfall-Schnelltest:\n'
      'Balance – Eyes – Face – Arms – Speech – Time.\n'
      'Sofortiger Notruf bei positivem Befund!',

  'ZOPS':
      'Orientierungsstatus:\n'
      'Zeit – Ort – Person – Situation.\n'
      'Prüft zeitliche, örtliche, personenbezogene und situative Orientierung.',

  'SAMPLERS':
      'Strukturierte Anamnese:\n'
      'Symptome/Zeichen – Allergien – Medikamente – Patientenvorgeschichte – '
      'Letzte Mahlzeit – Ereignis – Risikofaktoren – Schwangerschaft.',

  'OPQRST':
      'Strukturierte Schmerzanamnese:\n'
      'Onset (Beginn) – Provocation (Auslöser) – Quality (Charakter) – '
      'Radiation (Ausstrahlung) – Severity (Stärke 0–10) – Time (Zeitverlauf).',

  '4H':
      'Reversible Reanimationsursachen – „4H":\n'
      'Hypoxie – Hypovolämie – Hypo-/Hyperkaliämie – Hypothermie/Hyperthermie.\n'
      'Ursache suchen und beheben!',

  'HITS':
      'Reversible Reanimationsursachen – „HITS":\n'
      'Herzbeuteltamponade – Intoxikation – Thrombose – Spannungspneumothorax.\n'
      'Ursache suchen und beheben!',

  'Maßnahmen':
      'Basismaßnahmen der Patientenversorgung:\n'
      'Sauerstoffgabe, Beatmung, Wärmeerhalt, Lagerung, Defibrillation, Reanimation.',

  'Maßnahmen (erweitert)':
      'Erweiterte Maßnahmen (qualifikationsabhängig):\n'
      'Venöser/intraossärer Zugang, Volumengabe, Medikamente, '
      'Larynxtubus, Thoraxdekompression, Beckenschlinge.',

  'Übergabe (ISBAR)':
      'Strukturierte Patientenübergabe nach ISBAR:\n'
      'Identität – Situation – Beurteilung – Aktionen – Reaktion/Rückmeldung.',

  'Nachforderung':
      'Nachforderung weiterer Rettungsmittel oder Dienste:\n'
      'NEF, RTW, RTH, KTW, Feuerwehr, Polizei, PSNV.',
};

String getSchemaDescription(String schema) {
  return schemaDescriptions[schema] ?? 'Kein Beschreibungstext vorhanden.';
}
