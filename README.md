# Internet Speed Test to InfluxDB

🇩🇪 [Deutsch](README.de.md) | 🇬🇧 English

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A Bash script that measures download speed with `curl`, enriches the result with basic network metadata (IP, geo lookup, traceroute hops), and writes the measurement to InfluxDB 2.x using line protocol.

## Features

- Download speed test via `curl` with timeout control.
- Optional max runtime watchdog to avoid long-running jobs.
- Auto-detects ISP (best-effort) from traceroute and IP info.
- Geo lookup for the download server IP.
- Traceroute hop count, first/last hop capture.
- Writes metrics to InfluxDB 2.x (or dry-run output).

## Requirements

- Bash
- `curl`
- `traceroute` (optional, but recommended)
- InfluxDB 2.x server, bucket, org, and token with write permission

## Quick Start

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

## Options

```
-c, --config FILE             load config from file (overrides all other options)
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

## Config File

You can use a config file instead of command-line options:

```bash
./internet-speed-test.sh -c /path/to/config.conf
```

Example config file format (see [config/config.example.conf](config/config.example.conf)):

```ini
# Required parameters
url=https://nbg1-speed.hetzner.com/100MB.bin
influx_server=http://192.0.2.10
influx_port=8086
influx_bucket=mybucket
influx_org=myorg
influx_token=mytoken

# Optional parameters
timeout=30
max_runtime=60
isp=telekom
debug=0
dry_run=0
```

**Note:** If a config file is specified, all command-line options are ignored except `-d|--debug` and `-n|--dry-run`, which can override the config file settings.

## What Gets Written to InfluxDB

Measurement: `speed_test`

Tags:
- `isp`
- `target_domain`
- `location`
- `test_type` (always `download`)

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

Timestamp: current epoch time in nanoseconds as emitted by `date +%s%N`.

## Grafana Dashboard

A comprehensive Grafana dashboard is included at [dashboards/internet-speed-test-dashboard.json](dashboards/internet-speed-test-dashboard.json).

### Dashboard Features

The dashboard provides detailed insights into your internet connection performance:

**Basic Metrics:**
- **Current Speed**: Real-time download speed
- **Average Speed**: Mean speed over the selected time range
- **Min/Max Speed**: Lowest and highest recorded speeds
- **Total Tests Run**: Count of all speed tests performed

**Advanced Analytics:**
- **Speed Percentiles (P50, P95, P99)**: Shows reliable performance across all conditions
  - P50 (Median): 50% of tests achieved this speed or higher
  - P95: 95% of tests achieved this speed or higher
  - P99: 99% of tests achieved this speed or higher
  - These metrics aggregate all tests regardless of server location, ISP, or test type

- **CDN Detection**: Monitors if your ISP routes you through CDNs
  - Value of "1": Direct routing (single server location)
  - Value of "2+": CDN detected (multiple server locations in 24h)

- **Connection Reliability**: Shows success rate percentage over time
  - Tracks successful tests (retcode=0) vs timeouts/failures
  - Aggregated across all conditions for overall reliability

**Visualizations:**
- **Speed Over Time**: Timeseries graph showing download speed trends
- **Speed by Hour of Day**: Heatmap revealing performance patterns throughout the day
- **Speed vs Network Hop Count**: Dual-axis graph correlating network distance with speed
- **Server Locations Over Time**: State timeline showing which locations are used
- **Success vs Fail Rate**: Bar and pie charts showing test outcome distribution
- **Return Code Breakdown**: Detailed success/timeout/failure analysis
- **Speed Test Server Locations**: Geographic map of test server locations

### Dashboard Configuration

All aggregated metrics use the full dataset:
- Time range: Controlled by dashboard time picker (default: last 12h)
- Aggregation: Combines all tests regardless of server location, ISP, domain, or test type
- Auto-refresh: 30 seconds

### Importing the Dashboard

1. Open Grafana
2. Go to **Dashboards** → **Import**
3. Upload `dashboards/internet-speed-test-dashboard.json`
4. Select your InfluxDB datasource
5. Click **Import**

The dashboard requires:
- Grafana v12.3.2 or later
- InfluxDB datasource configured with access to your speed-test-metrics bucket

## Notes

- The download URL should point to a reasonably large file (e.g., 100MB) for stable results.
- ISP detection and geo lookup are best-effort and may return `unknown` or `n.a.`.
- If `traceroute` is missing, hop-related fields fall back to defaults and ISP is set to `unknown` unless provided.

## Troubleshooting

- If the script exits with missing parameter errors, ensure all required InfluxDB options are provided.
- For connection issues, verify the server URL/port and token permissions.
- Use `--debug` for detailed output and `--dry-run` to validate payload without writing.

## Git Tips

If your filesystem toggles executable bits unexpectedly, you can disable file mode tracking for this repo:

```bash
git config core.fileMode false
```

Note: This is a local-only setting and does not get pushed to the remote.
