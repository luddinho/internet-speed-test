# Internet Speed Test zu InfluxDB

🇩🇪 Deutsch | 🇬🇧 [English](README.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Ein Bash-Skript, das die Download-Geschwindigkeit mit `curl` misst, die Messung mit Netzwerk-Metadaten (IP, Geo-Check, Traceroute-Hops) anreichert und die Daten per Line Protocol in InfluxDB 2.x schreibt.

## Funktionen

- Download-Speedtest via `curl` mit Timeout-Kontrolle.
- Optionaler Max-Runtime-Watchdog gegen haengende Jobs.
- ISP-Erkennung (Best Effort) via Traceroute und IP-Info.
- Geo-Check fuer die Download-Server-IP.
- Traceroute-Hop-Anzahl und First/Last Hop.
- Schreiben der Messwerte in InfluxDB 2.x (oder Dry-Run Ausgabe).

## Voraussetzungen

- Bash
- `curl`
- `traceroute` (optional, aber empfohlen)
- InfluxDB 2.x Server, Bucket, Org und Token mit Write-Rechten

## Schnellstart

```bash
chmod +x internet-speed-test.sh

./internet-speed-test.sh \
  -u https://nbg1-speed.hetzner.com/100MB.bin \
  -s http://192.0.2.10 \
  -p 8086 \
  -b mybucket \
  -o myorg \
  -a mytoken
```

## Optionen

```
-c, --config FILE             Konfiguration aus Datei laden (überschreibt alle anderen Optionen)
-t, --timeout SECONDS         curl timeout in seconds (default: 30)
-m, --max-runtime SECONDS     max script runtime (0 = no limit)
-u, --url URL                 download URL for speed test (required)
-i, --isp PROVIDER            ISP provider name (auto if not set)
-d, --debug                   enable debug output
-n, --dry-run                 do not send data to InfluxDB

-s, --server URL              InfluxDB server URL (required)
-p, --port PORT               InfluxDB server port (required)
-b, --bucket NAME             InfluxDB bucket name (required)
-o, --org NAME                InfluxDB organization (required)
-a, --auth-token TOKEN        InfluxDB token (required*)
-f, --auth-token-file FILE    file containing InfluxDB token (required*)
                            *Either -a or -f must be provided

-h, --help                    show help
```

## Config-Datei

Du kannst eine Config-Datei anstelle von Kommandozeilen-Optionen verwenden:

```bash
./internet-speed-test.sh -c /pfad/zur/config.conf
```

Beispiel Config-Datei Format (siehe [config/config.example.conf](config/config.example.conf)):

```ini
# Erforderliche Parameter
url=https://nbg1-speed.hetzner.com/100MB.bin
influx_server=http://192.0.2.10
influx_port=8086
influx_bucket=mybucket
influx_org=myorg
influx_token=mytoken

# Optionale Parameter
timeout=30
max_runtime=60
isp=telekom
debug=0
dry_run=0
```

**Hinweis:** Wenn eine Config-Datei angegeben wird, werden alle Kommandozeilen-Optionen ignoriert außer `-d|--debug` und `-n|--dry-run`, die die Config-Datei überschreiben können.

## Was in InfluxDB geschrieben wird

Measurement: `speed_test`

Tags:
- `isp`
- `target_domain`
- `location`
- `test_type` (immer `download`)

Fields:
- `speed` (bytes/sec)
- `speed_mbps`
- `http_code`
- `retcode` (curl exit code)
- `client_ip`
- `server_ip`
- `traceroute_target_ip`
- `server_city`
- `server_country`
- `hop_count`
- `first_hop`
- `last_hop`

Timestamp: aktuelle Epoch-Zeit in Nanosekunden via `date +%s%N`.

## Grafana Dashboard

Ein umfassendes Grafana-Dashboard ist enthalten unter [dashboards/internet-speed-test-dashboard.json](dashboards/internet-speed-test-dashboard.json).

### Dashboard-Funktionen

Das Dashboard bietet detaillierte Einblicke in die Leistung Ihrer Internetverbindung:

**Grundlegende Metriken:**
- **Aktuelle Geschwindigkeit**: Download-Geschwindigkeit in Echtzeit
- **Durchschnittsgeschwindigkeit**: Mittlere Geschwindigkeit über den ausgewählten Zeitraum
- **Min/Max Geschwindigkeit**: Niedrigste und höchste aufgezeichnete Geschwindigkeiten
- **Gesamtzahl der Tests**: Anzahl aller durchgeführten Geschwindigkeitstests

**Erweiterte Analysen:**
- **Geschwindigkeits-Perzentile (P50, P95, P99)**: Zeigt zuverlässige Leistung über alle Bedingungen hinweg
  - P50 (Median): 50% der Tests erreichten diese Geschwindigkeit oder höher
  - P95: 95% der Tests erreichten diese Geschwindigkeit oder höher
  - P99: 99% der Tests erreichten diese Geschwindigkeit oder höher
  - Diese Metriken aggregieren alle Tests unabhängig von Serverstandort, ISP oder Testtyp

- **CDN-Erkennung**: Überwacht, ob Ihr ISP Sie durch CDNs leitet
  - Wert "1": Direktes Routing (einzelner Serverstandort)
  - Wert "2+": CDN erkannt (mehrere Serverstandorte in 24h)

- **Verbindungszuverlässigkeit**: Zeigt die Erfolgsrate in Prozent im Zeitverlauf
  - Verfolgt erfolgreiche Tests (retcode=0) vs. Timeouts/Fehler
  - Aggregiert über alle Bedingungen für Gesamtzuverlässigkeit

**Visualisierungen:**
- **Geschwindigkeit im Zeitverlauf**: Zeitreihendiagramm mit Download-Geschwindigkeitstrends
- **Geschwindigkeit nach Tageszeit**: Heatmap zeigt Leistungsmuster im Tagesverlauf
- **Geschwindigkeit vs. Netzwerk-Hop-Anzahl**: Dual-Achsen-Diagramm korreliert Netzwerkdistanz mit Geschwindigkeit
- **Serverstandorte im Zeitverlauf**: State Timeline zeigt, welche Standorte verwendet werden
- **Erfolgs- vs. Fehlerrate**: Balken- und Kreisdiagramme zeigen Testergebnis-Verteilung
- **Rückgabecode-Aufschlüsselung**: Detaillierte Erfolgs-/Timeout-/Fehleranalyse
- **Geschwindigkeitstest-Serverstandorte**: Geografische Karte der Testserver-Standorte

### Dashboard-Konfiguration

Alle aggregierten Metriken verwenden den vollständigen Datensatz:
- Zeitbereich: Gesteuert durch Dashboard-Zeitauswahl (Standard: letzte 12h)
- Aggregation: Kombiniert alle Tests unabhängig von Serverstandort, ISP, Domain oder Testtyp
- Auto-Refresh: 30 Sekunden

### Dashboard importieren

1. Öffnen Sie Grafana
2. Gehen Sie zu **Dashboards** → **Import**
3. Laden Sie `dashboards/internet-speed-test-dashboard.json` hoch
4. Wählen Sie Ihre InfluxDB-Datenquelle
5. Klicken Sie auf **Import**

Das Dashboard benötigt:
- Grafana v12.3.2 oder neuer
- InfluxDB-Datenquelle konfiguriert mit Zugriff auf Ihren speed-test-metrics Bucket

## Hinweise

- Die Download-URL sollte auf eine ausreichend grosse Datei zeigen (z.B. 100MB) fuer stabile Werte.
- ISP-Erkennung und Geo-Check sind Best Effort und koennen `unknown` oder `n.a.` liefern.
- Wenn `traceroute` fehlt, sind Hop-Felder Default-Werte und ISP ist `unknown`, falls nicht gesetzt.

## Troubleshooting

- Bei fehlenden Parametern alle erforderlichen InfluxDB-Optionen angeben.
- Bei Verbindungsproblemen Server-URL/Port und Token-Rechte pruefen.
- Mit `--debug` Details anzeigen und mit `--dry-run` Payload pruefen ohne zu schreiben.

## Git Tipps

Wenn dein Dateisystem die Executable-Bits unerwartet aendert, kannst du das File-Mode-Tracking fuer dieses Repo deaktivieren:

```bash
git config core.fileMode false
```

Hinweis: Diese Einstellung ist lokal und wird nicht zum Remote gepusht.
