# Internet Speed Test to InfluxDB

🇩🇪 [Deutsch](README.de.md) | 🇬🇧 English

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

## Notes

- The download URL should point to a reasonably large file (e.g., 100MB) for stable results.
- ISP detection and geo lookup are best-effort and may return `unknown` or `n.a.`.
- If `traceroute` is missing, hop-related fields fall back to defaults and ISP is set to `unknown` unless provided.

## Troubleshooting

- If the script exits with missing parameter errors, ensure all required InfluxDB options are provided.
- For connection issues, verify the server URL/port and token permissions.
- Use `--debug` for detailed output and `--dry-run` to validate payload without writing.
