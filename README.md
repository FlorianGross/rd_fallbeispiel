# RD Fallbeispiel

Eine Flutter-App, die beim Erlernen der standardisierten Patientenversorgung im
Rettungsdienst hilft. Ausbilder oder Lernende haken während eines Fallbeispiels
die abgearbeiteten Schemata ab; die App wertet anschließend aus, welche
Pflichtmaßnahmen für die gewählte Qualifikation gefehlt haben.

## Funktionen

- **Qualifikationsstufen** SAN, RH, RS und NFS mit eigenen Anforderungen je Maßnahme
  (verpflichtend, erwartet, optional, nicht zulässig).
- **Schemata**: SSSS, Erster Eindruck, WASB, (c)ABCDE, STU, BE-FAST, ZOPS,
  SAMPLERS, OPQRST, 4H/HITS, Maßnahmen, ISBAR-Übergabe, Nachforderung.
- **Szenario-Bibliothek** mit Fallbildern; bewertet werden die Grundschemata plus
  die zum Szenario passenden situativen Schemata.
- **Reanimationsmodus** mit Frequenzmessung per Antippen, Beatmungszähler
  (30:2 bzw. 15:2 beim Kind), 2-Minuten-Rhythmuskontrolle und Frequenzverlauf.
- **Nachalarmierte Fahrzeuge** (KTW, RTW, NEF, RTH) mit Ankunftszeit.
- **Auswertung, Verlauf und PDF-Bericht** inkl. „Häufig vergessen“ und Notizen.

## Entwicklung

Voraussetzung: Flutter (stable, siehe `.github/workflows/ci.yml` für die in der
CI verwendete Version).

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

Die Bewertungslogik steht in `lib/measure_requirements.dart`, die
Szenarien in `lib/models/scenario.dart`.

## Lizenzen

Die im PDF-Bericht eingebettete Schrift Liberation Sans steht unter der
SIL Open Font License (siehe `assets/fonts/`).
