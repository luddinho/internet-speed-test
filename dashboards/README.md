# Grafana Dashboards

This directory contains pre-built Grafana dashboards for visualizing internet speed test metrics.

## Dashboard: Internet Speed Test Monitoring

**File:** `internet-speed-test-dashboard.json`

### Features

The dashboard includes 11 panels organized in a comprehensive layout:

#### 📊 Main Visualizations

1. **Download Speed Over Time** (Time Series)
   - Full-width time series chart showing speed trends
   - Displays mean and last values in legend

2. **Current Speed** (Stat Panel)
   - Large display of most recent speed test result
   - Color-coded thresholds: Red (<50 Mbps), Yellow (50-100), Green (>100)

3. **HTTP Status** (Stat Panel)
   - Current HTTP response code
   - Quick health check indicator

4. **Network Hops** (Stat Panel)
   - Number of network hops to destination
   - Color-coded: Green (<15), Yellow (15-20), Red (>20)

5. **Server Location** (Stat Panel)
   - Displays current test server location

#### 📈 Comparative Analysis

6. **Speed by ISP Provider** (Time Series)
   - Compare performance across different ISPs
   - Grouped by ISP tag

7. **Speed by Server Location** (Time Series)
   - Compare speeds to different geographic locations
   - Useful for CDN performance analysis

8. **Average Speed by ISP (Last 24h)** (Bar Gauge)
   - Average speed per ISP over the last 24 hours
   - Horizontal bar chart with color thresholds

9. **Speed by Target Domain** (Time Series)
   - Compare different Hetzner test servers
   - Shows which server performs best

#### 🔍 Advanced Analysis

10. **Speed vs Network Hop Count** (Time Series - Dual Axis)
    - Correlate speed with network path complexity
    - Dual Y-axis: Speed (left), Hops (right)

11. **Speed Test Details** (Table)
    - Complete data view with all metrics
    - Columns: Time, ISP, Location, Domain, Speed, Hops, HTTP Code, etc.
    - Color-coded speed values

### How to Import

#### Method 1: Via Grafana UI

1. Open Grafana web interface
2. Navigate to **Dashboards** → **Import**
3. Click **Upload JSON file**
4. Select `internet-speed-test-dashboard.json`
5. Select your InfluxDB datasource
6. Click **Import**

#### Method 2: Via Command Line

```bash
# Copy to Grafana provisioning directory (if using provisioning)
sudo cp internet-speed-test-dashboard.json /etc/grafana/provisioning/dashboards/

# Restart Grafana
sudo systemctl restart grafana-server
```

#### Method 3: Via API

```bash
# Using curl to import directly
curl -X POST http://admin:admin@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @internet-speed-test-dashboard.json
```

### Configuration

#### Required Setup

1. **InfluxDB Datasource**
   - The dashboard uses a variable `${DS_INFLUXDB}` for the datasource
   - When importing, select your InfluxDB datasource
   - Make sure it's configured with:
     - Query Language: **Flux**
     - Organization: Your org name
     - Token: Read token for `speed-test-metrics` bucket
     - Default Bucket: `speed-test-metrics`

2. **Bucket Name**
   - All queries use `speed-test-metrics` as the bucket name
   - If you use a different bucket, edit the queries after import

#### Dashboard Settings

- **Auto-refresh:** 30 seconds (configurable)
- **Default time range:** Last 6 hours
- **Time picker intervals:** 10s, 30s, 1m, 5m, 15m, 30m, 1h, 2h, 1d

### Customization

#### Adjusting Thresholds

Edit panel → Field overrides → Thresholds:

**Speed Thresholds:**
- Red: < 50 Mbps (slow)
- Yellow: 50-100 Mbps (moderate)
- Green: > 100 Mbps (fast)

**Hop Count Thresholds:**
- Green: < 15 hops (optimal)
- Yellow: 15-20 hops (acceptable)
- Red: > 20 hops (suboptimal)

#### Adding More Panels

Common additions:
- **Upload Speed** (if you add upload tests)
- **Latency/Ping** metrics
- **Packet Loss** percentage
- **ISP Comparison Stats** (min/max/percentiles)

### Troubleshooting

#### No Data Displayed

1. **Check datasource connection:**
   ```bash
   # Test from command line
   ./debug/debug-influxdb.sh
   ```

2. **Verify bucket has data:**
   - Navigate to InfluxDB UI → Data Explorer
   - Select bucket: `speed-test-metrics`
   - Check if measurement `speed_test` exists

3. **Check time range:**
   - Make sure the dashboard time range covers when tests were run
   - Try "Last 24 hours" or "Last 7 days"

4. **Verify field names:**
   - Main field: `speed_mbps`
   - Measurement: `speed_test`
   - Tags: `isp`, `location`, `target_domain`

#### Panels Show Errors

- **"Bucket not found":** Token doesn't have read access
- **"Unauthorized":** Token expired or insufficient permissions
- **"No field":** Field name mismatch in query vs data

### Performance Tips

1. **Use aggregateWindow** for long time ranges (already configured)
2. **Limit query range** for tables (last 1h recommended)
3. **Enable query caching** in Grafana settings
4. **Set appropriate refresh intervals** (30s default)

### Dashboard Variables

The dashboard includes one variable:

- **DS_INFLUXDB**: Datasource selector
  - Allows switching between multiple InfluxDB sources
  - Set automatically on import

### Tags

Dashboard is tagged with:
- `speed-test`
- `networking`
- `monitoring`

Use these tags to organize and find the dashboard easily.

## Additional Resources

- [Main README](../README.md) - Project documentation
- [Script Documentation](../internet-speed-test.sh) - Speed test script
- [Config Examples](../config/config.example.conf) - Configuration templates
- [Debug Tools](../debug/debug-influxdb.example.sh) - Connection testing

## Questions?

Check the main README or examine the Flux queries in the dashboard JSON for details on data structure and calculations.
