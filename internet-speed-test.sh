#!/bin/bash
# Author: luddinho
# Date: 2026-02-06
# Version: 1.0.0
# Description: This script performs an internet speed test by downloading a file from a specified URL
# and measuring the download speed. It also performs a traceroute to analyze the network path and hop count.
# The results are sent to an InfluxDB instance for storage and visualization.
# The script includes error handling, timeout management, and auto-detection of the ISP provider based on traceroute data and client IP geolocation.
# It can be run in debug mode for detailed output.

VERSION="1.0.0"


# Example influxdb server URL: http://192.0.2.10
# Example InfluxDB server port: 8086
# Example InfluxDB bucket: mybucket
# Example InfluxDB organization: myorg
# Example InfluxDB authentication token: mytoken
# Note: The InfluxDB server must be running and accessible from the machine where this script is executed.
# The bucket and organization must already exist in InfluxDB, and the authentication token must have write permissions for the specified bucket.


# Function to display usage
show_help() {
    cat << EOF
Version: $VERSION
Usage: $(basename "$0") [OPTIONS]

Options:
  -t, --timeout SECONDS         Set curl timeout in seconds (default: 30)
  -m, --max-runtime SECONDS     Maximum script runtime in seconds (0 = no limit, default: 0)
  -u, --url URL                 Set download URL for speed test (REQUIRED)
  -i, --isp PROVIDER            ISP provider name (auto-detected if not specified)
  -d, --debug                   Enable debug output
  -n, --dry-run                 Run in dry-run mode (do not send data to InfluxDB)

  -s, --server URL              InfluxDB server URL (REQUIRED)
  -p, --port PORT               InfluxDB server port (REQUIRED)
  -b, --bucket NAME             InfluxDB bucket name (REQUIRED)
  -o, --org NAME                InfluxDB organization name (REQUIRED)
  -a, --auth-token TOKEN        InfluxDB authentication token (REQUIRED*)
  -f, --auth-token-file FILE    File containing InfluxDB authentication token (REQUIRED*)
                                *Either -a or -f must be provided

  -h, --help                    Display this help message

Example:
    $(basename "$0") -u https://example.com/file.zip -s http://192.0.2.10 -p 8086 -b mybucket -o myorg -a mytoken
    $(basename "$0") -u https://example.com/file.zip -i telekom -m 120 -s http://192.0.2.10 -p 8086 -b mybucket -o myorg -f /path/to/token.txt
EOF
    exit 0
}

# --------------------------------------------------------------------------------
# Default values
# --------------------------------------------------------------------------------
# Available Hetzner speed test servers:
#
# https://nbg1-speed.hetzner.com   located in Nuremberg, Germany
# https://fsn1-speed.hetzner.com   located in Falkenstein, Germany
# https://hel1-speed.hetzner.com   located in Helsinki, Finland
# https://ash-speed.hetzner.com    located in Ashburn, USA
# https://hil-speed.hetzner.com    located in Hilversum, Netherlands
# https://sin-speed.hetzner.com    located in Singapore
#
# --------------------------------------------------------------------------------
# Note: The URL should point to a reasonably large file (e.g., 100MB) to get an accurate speed measurement.
# Default download URL (can be overridden by command-line argument)
url="https://nbg1-speed.hetzner.com/100MB.bin"

# Default timeout for curl in seconds (can be overridden by command-line argument)
timeout=30

# Default maximum script runtime in seconds (0 = no limit, can be overridden by command-line argument)
# Set default max runtime to timeout + 30 seconds buffer
# This ensures that if curl or traceroute hangs or takes too long, the script will terminate in a reasonable time frame, preventing it from running indefinitely.
# If there is a cron job running this script every minute, this also prevents overlapping runs in case of unexpected delays.
max_runtime=$((timeout + 30))

# Default debug mode (0 = off, 1 = on)
debug=0

# Default dry-run mode (0 = off, 1 = on)
dry_run=0

# --------------------------------------------------------------------------------
# Parse command-line arguments
# --------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--timeout)
            timeout="$2"
            shift 2
            ;;
        -m|--max-runtime)
            max_runtime="$2"
            shift 2
            ;;
        -u|--url)
            url="$2"
            shift 2
            ;;
        -i|--isp)
            isp="$2"
            shift 2
            ;;
        -d|--debug)
            debug=1
            shift
            ;;
        -n|--dry-run)
            dry_run=1
            shift
            ;;
        -s|--server)
            influx_server="$2"
            shift 2
            ;;
        -p|--port)
            influx_port="$2"
            shift 2
            ;;
        -b|--bucket)
            influx_bucket="$2"
            shift 2
            ;;
        -o|--org)
            influx_org="$2"
            shift 2
            ;;
        -a|--auth-token)
            influx_token="$2"
            shift 2
            ;;
        -f|--auth-token-file)
            influx_token_file="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            echo "Use -h or --help for usage information" >&2
            exit 1
            ;;
    esac
done

# --------------------------------------------------------------------------------
# Read token from file if file option is provided
# --------------------------------------------------------------------------------
if [ -n "$influx_token_file" ]; then
    if [ ! -f "$influx_token_file" ]; then
        echo "Error: Token file '$influx_token_file' does not exist" >&2
        exit 1
    fi
    if [ ! -r "$influx_token_file" ]; then
        echo "Error: Token file '$influx_token_file' is not readable" >&2
        exit 1
    fi
    # Read first line from file, trimming whitespace
    influx_token=$(head -n 1 "$influx_token_file" | tr -d '[:space:]')
    if [ -z "$influx_token" ]; then
        echo "Error: Token file '$influx_token_file' is empty or contains only whitespace" >&2
        exit 1
    fi
fi

# -----------------------------------------------------------------------------
# Check if mandatory parameters are provided
# -----------------------------------------------------------------------------

# Check if URL parameter is provided
if [ -z "$url" ]; then
    echo "Error: URL parameter (-u|--url) is required" >&2
    echo "Use -h or --help for usage information" >&2
    exit 1
fi

# Check if InfluxDB server parameter is provided
if [ -z "$influx_server" ]; then
    echo "Error: InfluxDB server URL (-s|--server) is required" >&2
    echo "Use -h or --help for usage information" >&2
    exit 1
fi

# Check if InfluxDB port parameter is provided
if [ -z "$influx_port" ]; then
    echo "Error: InfluxDB server port (-p|--port) is required" >&2
    echo "Use -h or --help for usage information" >&2
    exit 1
fi

# Check if InfluxDB bucket name is provided
if [ -z "$influx_bucket" ]; then
    echo "Error: InfluxDB bucket name (-b|--bucket) is required" >&2
    echo "Use -h or --help for usage information" >&2
    exit 1
fi

# Check if InfluxDB organization name is provided
if [ -z "$influx_org" ]; then
    echo "Error: InfluxDB organization name (-o|--org) is required" >&2
    echo "Use -h or --help for usage information" >&2
    exit 1
fi

# Check if InfluxDB authentication token is provided (either directly or via file)
if [ -z "$influx_token" ]; then
    echo "Error: InfluxDB authentication token (-a|--auth-token) or token file (-f|--auth-token-file) is required" >&2
    echo "Use -h or --help for usage information" >&2
    exit 1
fi

# --------------------------------------------------------------------------------
# Set up script timeout watchdog if max_runtime is specified
# --------------------------------------------------------------------------------
watchdog_pid=""

if [ "$max_runtime" -gt 0 ]; then
    # Start a background watchdog process that will kill this script after max_runtime
    (
        sleep "$max_runtime"
        echo "Error: Script exceeded maximum runtime of $max_runtime seconds" >&2
        kill -TERM $$ 2>/dev/null
    ) &
    watchdog_pid=$!

    # Set up trap to clean up watchdog on normal exit
    trap "kill $watchdog_pid 2>/dev/null; exit" EXIT INT TERM
fi

# -----------------------------------------------------------------------------
# Prepare the InfluxDB tags and fields
# ------------------------------------------------------------------------------
# Get current time in milliseconds since epoch for InfluxDB timestamp
epoch_time_ms=$(date +%s%N)

# Extract domain from URL for InfluxDB tag
domain=$(echo "$url" | awk -F/ '{print $3}')

# Get public IPv4 address of client (for InfluxDB field); fallback to "n.a." if retrieval fails
if ! ipv4=$(curl -s https://ipinfo.io/ip 2>/dev/null); then
    ipv4="n.a."
fi

# ------------------------------------------------------------------------------
# Use curl's --write-out to get a reliable numeric bytes/sec value and HTTP code
# This avoids parsing the progress meter which differs between curl versions/OS
# Use pipefail to ensure we capture curl's exit code even if we pipe output
# ------------------------------------------------------------------------------
set -o pipefail
# Run curl with specified timeout, follow redirects, and capture speed, HTTP code, and remote IP
curl_output=$(curl --connect-timeout "$timeout" --max-time "$timeout" -L -sS -o /dev/null -w "%{speed_download} %{http_code} %{remote_ip}" "$url")
curl_retcode=$?

# Check if curl command succeeded; if not, set speed to 0 and keep retcode for InfluxDB
if [ "$curl_retcode" -ne 0 ]; then
        # curl failed (timeout, DNS, network); set speed to 0 and keep retcode
        speed=0
        http_code=0
        speed_mbps=0
        server_ip="n.a."
        server_city="n.a."
        server_country="n.a."
        location="unknown"
else
        # parse speed (bytes/sec), http response code, and remote IP
        speed=$(printf "%s" "$curl_output" | awk '{print $1}')
        http_code=$(printf "%s" "$curl_output" | awk '{print $2}')
        server_ip=$(printf "%s" "$curl_output" | awk '{print $3}')

        # Calculate speed in Mbps (Megabits per second) for easier dashboard visualization
        # Formula: (bytes/sec * 8) / 1,000,000 = Mbps
        speed_mbps=$(awk "BEGIN {printf \"%.2f\", $speed * 8 / 1000000}")

        # Query geolocation API to get actual server location
        # Using ip-api.com (free, no API key required)
        if [ -n "$server_ip" ] && [ "$server_ip" != "0.0.0.0" ]; then
            geo_data=$(curl -s --connect-timeout 5 --max-time 10 "http://ip-api.com/json/$server_ip?fields=status,city,country,countryCode" 2>/dev/null)

            # Parse JSON response (simple approach without jq dependency)
            if echo "$geo_data" | grep -q '"status":"success"'; then
                server_city=$(echo "$geo_data" | grep -o '"city":"[^"]*"' | cut -d'"' -f4)
                server_country=$(echo "$geo_data" | grep -o '"countryCode":"[^"]*"' | cut -d'"' -f4)

                # Set location based on city or fallback to country code
                if [ -n "$server_city" ]; then
                    location="$server_city"
                elif [ -n "$server_country" ]; then
                    location="$server_country"
                else
                    location="unknown"
                fi
            else
                # Geolocation API failed, fall back to URL parsing
                server_city="n.a."
                server_country="n.a."
                location=$(echo "$domain" | awk -F. '{print $1}' | awk -F- '{print $1}')
                if [ -z "$location" ] || [ "$location" = "$domain" ]; then
                    location="unknown"
                fi
            fi
        else
            server_city="n.a."
            server_country="n.a."
            location="unknown"
        fi
fi

# ------------------------------------------------------------------------------
# Perform traceroute to analyze network path and hop count
# ------------------------------------------------------------------------------
# Run traceroute with limited hops and timeout to avoid long waits
# Use -m for max hops, -w for timeout per hop
if command -v traceroute &> /dev/null; then
    # Run traceroute (works on both macOS and Linux)
    traceroute_output=$(traceroute -m 30 -w 2 -q 1 "$domain" 2>/dev/null)

    # Extract target IP from first line of traceroute output
    # Format: "traceroute to domain.com (IP_ADDRESS), 30 hops max, 80 byte packets"
    traceroute_target_ip=$(echo "$traceroute_output" | head -n 1 | grep -oE '\([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\)|\([0-9a-f:]+:[0-9a-f:]+\)' | tr -d '()' | head -n 1)
    if [ -z "$traceroute_target_ip" ]; then
        traceroute_target_ip="n.a."
    fi

    # Count actual hops (lines with IP addresses, excluding header and failed hops)
    hop_count=$(echo "$traceroute_output" | grep -c '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\|[0-9a-f]*:[0-9a-f]*:[0-9a-f]')

    # Extract first hop (usually local gateway)
    first_hop=$(echo "$traceroute_output" | grep -m 1 -oE '\([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\)|\([0-9a-f]*:[0-9a-f:]+\)' | tr -d '()')
    if [ -z "$first_hop" ]; then
        first_hop="n.a."
    fi

    # Extract last hop before destination
    last_hop=$(echo "$traceroute_output" | tail -n 2 | head -n 1 | grep -oE '\([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\)|\([0-9a-f]*:[0-9a-f:]+\)' | tr -d '()')
    if [ -z "$last_hop" ]; then
        last_hop="n.a."
    fi

    # Auto-detect ISP from traceroute if not manually specified
    if [ -z "$isp" ]; then
        # Step 1: Check hops 2-3 first (local ISP hops) for consumer ISPs
        local_isp_hops=$(echo "$traceroute_output" | head -n 5 | tail -n 3 | grep -oE '[a-zA-Z0-9-]+\.[a-zA-Z0-9.-]+' | grep -v '^[0-9]')

        if echo "$local_isp_hops" | grep -qi 'dtag\|telekom'; then
            isp="telekom"
        elif echo "$local_isp_hops" | grep -qi 'vodafone\|unitymedia'; then
            isp="vodafone"
        elif echo "$local_isp_hops" | grep -qi 'o2online\|telefonica'; then
            isp="o2"
        elif echo "$local_isp_hops" | grep -qi '1und1\|1and1'; then
            isp="1und1"
        elif echo "$local_isp_hops" | grep -qi 'kabel'; then
            isp="kabel"
        else
            # Step 2: If no local ISP found, query client IP for ISP information
            if [ "$ipv4" != "n.a." ]; then
                isp_data=$(curl -s --connect-timeout 3 --max-time 5 "http://ip-api.com/json/$ipv4?fields=status,isp,org" 2>/dev/null)

                if echo "$isp_data" | grep -q '"status":"success"'; then
                    isp_info=$(echo "$isp_data" | grep -o '"isp":"[^"]*"' | cut -d'"' -f4)

                    # Check ISP info for known patterns
                    if echo "$isp_info" | grep -qi 'telekom\|dtag\|deutsche telekom'; then
                        isp="telekom"
                    elif echo "$isp_info" | grep -qi 'vodafone'; then
                        isp="vodafone"
                    elif echo "$isp_info" | grep -qi 'o2\|telefonica'; then
                        isp="o2"
                    elif echo "$isp_info" | grep -qi '1&1\|1und1'; then
                        isp="1und1"
                    else
                        # Step 3: Check hops 4-5 for transit providers as last resort
                        transit_hops=$(echo "$traceroute_output" | head -n 8 | tail -n 3 | grep -oE '[a-zA-Z0-9-]+\.[a-zA-Z0-9.-]+' | grep -v '^[0-9]')

                        if echo "$transit_hops" | grep -qi 'telia\|twelve99'; then
                            isp="telia"
                        elif echo "$transit_hops" | grep -qi 'level3'; then
                            isp="level3"
                        elif echo "$transit_hops" | grep -qi 'cogent'; then
                            isp="cogent"
                        elif echo "$transit_hops" | grep -qi 'hurricane\|he\.net'; then
                            isp="hurricane"
                        else
                            isp="unknown"
                        fi
                    fi
                else
                    isp="unknown"
                fi
            else
                isp="unknown"
            fi
        fi
    fi
else
    # Traceroute not available
    hop_count=0
    first_hop="n.a."
    last_hop="n.a."
    traceroute_target_ip="n.a."

    # If provider not specified and traceroute not available, set to unknown
    if [ -z "$isp" ]; then
        isp="unknown"
    fi
fi

# Keep human-readable unit only for optional display (not used for influx)
# unit="B/s"

# -----------------------------------------------------------------------
# Debug output if enabled
# -----------------------------------------------------------------------
# Note: The speed is in bytes per second (B/s) as returned by curl's %{speed_download}.
# If you want to convert it to bits per second (bps), you can multiply by 8, but for InfluxDB it's often more useful to keep it in bytes per second for easier calculations and graphing.
# If you want to display it in a more human-readable format (e.g., Mbps), you can convert it for display purposes, but keep the raw value for InfluxDB.
# For example, to convert to Mbps for display:
# display_speed=$(awk "BEGIN {printf \"%.2f\", $speed * 8 / 1000000}")
# echo "Download speed: $display_speed Mbps (HTTP code: $http_code, curl retcode: $retcode)"
# For InfluxDB, we will keep the speed in bytes per second (B/s) as it is more straightforward for calculations and graphing.
if [ "$debug" -eq 1 ]; then
    echo ""
    echo "=========================================="
    echo "DEBUG OUTPUT"
    echo "=========================================="
    printf "%-25s : %s\n" "Epoch (ms)" "$epoch_time_ms"
    printf "%-25s : %s\n" "Provider" "$isp"
    printf "%-25s : %s\n" "Server Domain" "$domain"
    printf "%-25s : %s\n" "Server IP" "$server_ip"
    printf "%-25s : %s\n" "Traceroute Target IP" "$traceroute_target_ip"
    printf "%-25s : %s\n" "Server City" "$server_city"
    printf "%-25s : %s\n" "Server Country" "$server_country"
    printf "%-25s : %s\n" "Server Location" "$location"
    printf "%-25s : %s\n" "Download URL" "$url"
    printf "%-25s : %s\n" "Client IPv4" "$ipv4"
    printf "%-25s : %s\n" "Timeout (s)" "$timeout"
    printf "%-25s : %s\n" "Max Runtime (s)" "$max_runtime"
    echo "------------------------------------------"
    printf "%-25s : %s\n" "curl output" "$curl_output"
    printf "%-25s : %s\n" "Speed (B/s)" "$speed"
    printf "%-25s : %s\n" "Speed (Mbps)" "$speed_mbps"
    printf "%-25s : %s\n" "HTTP code" "$http_code"
    printf "%-25s : %s\n" "curl return code" "$curl_retcode"
    echo "------------------------------------------"
    printf "%-25s : %s\n" "Network Hop Count" "$hop_count"
    printf "%-25s : %s\n" "First Hop (Gateway)" "$first_hop"
    printf "%-25s : %s\n" "Last Hop" "$last_hop"
    echo "=========================================="
    echo ""
fi

# -----------------------------------------------------------------------
# InfluxDB line protocol format:
# measurement,tag1=value1,tag2=value2 field1=value1,field2=value2 timestamp
# For our case:
# measurement: speed_test
# tags: isp, target_domain, location, test_type
# fields: speed, speed_mbps, http_code, retcode, client_ip, server_ip, traceroute_target_ip, server_city, server_country, hop_count, first_hop, last_hop
# timestamp: epoch_time_ms
# Example line protocol:
# speed_test,isp=telekom,target_domain=nbg1-speed.hetzner.com,location=Nuremberg,test_type=download speed=12500000,speed_mbps=100.00,http_code=200,retcode=0,client_ip="198.51.100.23",server_ip="203.0.113.45",traceroute_target_ip="203.0.113.46",server_city="Nuremberg",server_country="DE",hop_count=15,first_hop="192.0.2.1",last_hop="203.0.113.1" 1690000000000
# -----------------------------------------------------------------------
if [ "$dry_run" -eq 1 ]; then
    echo "[DRY-RUN] Would send to InfluxDB:"
    echo "[DRY-RUN] URL: $influx_server:$influx_port/api/v2/write?bucket=$influx_bucket&org=$influx_org"
    echo "[DRY-RUN] Data: speed_test,isp=$isp,target_domain=$domain,location=$location,test_type=download speed=$speed,speed_mbps=$speed_mbps,http_code=$http_code,retcode=$curl_retcode,client_ip=\"$ipv4\",server_ip=\"$server_ip\",traceroute_target_ip=\"$traceroute_target_ip\",server_city=\"$server_city\",server_country=\"$server_country\",hop_count=$hop_count,first_hop=\"$first_hop\",last_hop=\"$last_hop\" $epoch_time_ms"
    influx_retcode=0
else
    curl -X POST \
    --data "speed_test,isp=$isp,target_domain=$domain,location=$location,test_type=download speed=$speed,speed_mbps=$speed_mbps,http_code=$http_code,retcode=$curl_retcode,client_ip=\"$ipv4\",server_ip=\"$server_ip\",traceroute_target_ip=\"$traceroute_target_ip\",server_city=\"$server_city\",server_country=\"$server_country\",hop_count=$hop_count,first_hop=\"$first_hop\",last_hop=\"$last_hop\" $epoch_time_ms" \
    -H "Authorization: Token $influx_token" \
    -H 'Content-Type: text/plain' \
    "$influx_server:$influx_port/api/v2/write?bucket=$influx_bucket&org=$influx_org"
    influx_retcode=$?
fi

# ------------------------------------------------------------------------
# Check if InfluxDB write succeeded (HTTP 204 No Content)
# only in debug mode we check the HTTP response code, otherwise we rely on curl's exit code
# ------------------------------------------------------------------------
if [ "$influx_retcode" -ne 0 ] && [ "$debug" -eq 1 ]; then
    echo "Error: Failed to write data to InfluxDB" >&2
    exit 1
fi

exit 0