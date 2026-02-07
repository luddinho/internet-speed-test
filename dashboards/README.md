# Grafana Dashboards

🇩🇪 [Deutsch](README.de.md) | 🇬🇧 English

This directory contains pre-built Grafana dashboards for visualizing internet speed test metrics.

## Dashboard: Internet Speed Test Monitoring

**File:** `internet-speed-test-dashboard.json`

### Features

The dashboard includes 24 comprehensive panels organized in a multi-layered layout:

#### 📊 Core Metrics (Top Row)

1. **Current Speed** (Stat Panel)
   - Large display of most recent speed test result
   - Color-coded thresholds: Red (<50 Mbps), Yellow (50-100), Green (>100)

2. **Average Speed** (Stat Panel)
   - Mean speed over selected time range
   - Quick performance overview

3. **Min/Max Speed** (Stat Panels)
   - Lowest and highest recorded speeds
   - Helps identify performance variance

4. **HTTP Status** (Stat Panel)
   - Current HTTP response code
   - Quick health check indicator

5. **Network Hops** (Stat Panel)
   - Number of network hops to destination
   - Color-coded: Green (<15), Yellow (15-20), Red (>20)

6. **Server Location** (Stat Panel)
   - Displays current test server location

7. **Total Tests Run** (Stat Panel)
   - Count of all speed tests performed

#### 📈 Performance Trends

8. **Download Speed Over Time** (Time Series)
   - Full-width time series chart showing speed trends
   - Displays mean and last values in legend

9. **Speed by ISP Provider** (Time Series)
   - Compare performance across different ISPs
   - Grouped by ISP tag

10. **Speed by Server Location** (Time Series)
    - Compare speeds to different geographic locations
    - Useful for CDN performance analysis

11. **Speed by Target Domain** (Time Series)
    - Compare different test servers
    - Shows which server performs best

#### 🎯 Statistical Analysis

12. **Speed Percentiles** (Stat Panel - P50, P95, P99)
    - **P50 (Median)**: 50% of all tests achieved this speed or higher
    - **P95**: 95% of tests achieved this speed or higher
    - **P99**: 99% of tests achieved this speed or higher
    - Shows reliable performance beyond simple averages
    - **Aggregates across all conditions** (all servers, ISPs, domains)

13. **Speed by Hour of Day** (Heatmap)
    - Hourly performance patterns visualization
    - Identifies peak/off-peak speed variations
    - Color gradient: Red (slow) → Yellow (moderate) → Green (fast)
    - **Aggregates across all conditions** for overall daily patterns

14. **Connection Reliability Over Time** (Time Series)
    - Shows success rate percentage over time
    - Tracks successful tests (retcode=0) vs timeouts/failures
    - Range: 0-100%
    - **Aggregates across all conditions** for overall reliability

#### 🔍 Network Analysis

15. **Speed vs Network Hop Count** (Time Series - Dual Axis)
    - Correlates speed with network path complexity
    - Shows two timelines: average speed and average hop count
    - Dual Y-axis: Speed (left), Hops (right)
    - **Aggregates across all server locations** for overall correlation

16. **Average Speed by ISP (Last 24h)** (Bar Gauge)
    - Average speed per ISP over the last 24 hours
    - Horizontal bar chart with color thresholds

17. **CDN Detection** (Stat Panel)
    - Monitors if your ISP routes you through CDNs
    - **Value "1"**: Direct routing (single server location in 24h)
    - **Value "2+"**: CDN detected (multiple server locations in 24h)

18. **Server Locations Over Time** (State Timeline)
    - Shows which server locations are used over time
    - Visualizes CDN switching behavior
    - Each color bar represents a different server city

#### 📊 Reliability Metrics

19. **Success vs Fail Rate** (Bar Chart)
    - Count-based visualization of test outcomes
    - Shows Success/Timeout/Other categories
    - **Aggregates across all conditions**

20. **Success vs Fail Rate** (Pie Chart)
    - Percentage distribution of test outcomes
    - Visual proportion of successful vs failed tests
    - **Aggregates across all conditions**

21. **Return Code Breakdown** (Pie Chart)
    - Detailed breakdown: Success/Timeout/Other
    - Color-coded categories for quick assessment

22. **Return Code Counts** (Bar Chart)
    - Absolute counts per return code category
    - Matches pie chart totals for verification

#### 🗺️ Geographic Visualization

23. **Speed Test Server Locations** (Geomap)
    - Geographic map showing all test server locations
    - Bubble size indicates speed performance
    - Color-coded by speed thresholds
    - Last 24 hours of data

#### 📋 Detailed Data

24. **Speed Test Details** (Table)
    - Complete data view with all metrics
    - Columns: Time, ISP, Location, Domain, Speed, Hops, HTTP Code, etc.
    - Color-coded speed values
    - Sortable and filterable

### Key Concepts

#### Aggregation Across All Conditions

Several panels use `group()` to combine all data regardless of:
- Server location (server_city)
- ISP provider
- Target domain
- Test type

These panels provide **overall performance metrics**:
- Speed Percentiles (P50, P95, P99)
- Speed by Hour of Day heatmap
- Connection Reliability Over Time
- Speed vs Network Hop Count
- Success/Fail rate charts

#### CDN Detection Logic

The CDN Detection panel counts unique server locations (`server_city`) over the last 24 hours:
- If you consistently reach the same server: **No CDN detected** (value = 1)
- If your tests reach multiple different servers: **CDN routing detected** (value = 2+)

This helps identify if your ISP uses content delivery networks for optimization.

#### Percentile Metrics Explained

Percentiles show **reliable performance**, not just averages:
- A high P50 (median) with similar P95/P99 indicates **consistent** performance
- A large gap between P50 and P99 indicates **variable** performance
- P99 tells you the worst 1% of your experience - important for real-world reliability

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

1. **Grafana**
   - Version: **12.3.2 or later** (dashboard uses CRD format)
   - Ensure InfluxDB plugin is installed and updated

2. **InfluxDB Datasource**
   - The dashboard uses a variable `${DS_INFLUXDB}` for the datasource
   - When importing, select your InfluxDB datasource
   - Make sure it's configured with:
     - Query Language: **Flux**
     - Organization: Your org name
     - Token: Read token for `speed-test-metrics` bucket
     - Default Bucket: `speed-test-metrics`

3. **Bucket Name**
   - All queries use `speed-test-metrics` as the bucket name
   - If you use a different bucket, edit the queries after import

#### Dashboard Settings

- **Grafana Version:** 12.3.2 or later (uses CRD format)
- **Auto-refresh:** 30 seconds (configurable)
- **Default time range:** Last 12 hours
- **Time picker intervals:** 10s, 30s, 1m, 5m, 15m, 30m, 1h, 2h, 1d
- **Dashboard Format:** Kubernetes CRD (dashboard.grafana.app/v1beta1)

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
- **Regional Percentiles** (filtered by server_city or ISP)
- **Download Time Estimates** (calculated from speed_mbps)

#### Filtering by Specific Conditions

To show metrics for a specific region or ISP, add a filter before `group()`:

```flux
|> filter(fn: (r) => r["server_city"] == "New York")
|> group()
```

This is useful for creating dedicated panels for specific locations or providers.

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
   - Tags: `isp`, `location`, `target_domain`, `server_city`
   - Additional fields: `hop_count`, `retcode`, `http_code`

#### Heatmap Not Showing Data

- Check that you have data spanning multiple hours
- Verify `aggregateWindow(every: 1h)` matches your data frequency
- Try expanding time range to "Last 7 days"

#### Percentiles Show Wrong Values

- Ensure `retcode` field exists (used for reliability calculation)
- Check that `group()` is called before `quantile()` in queries
- Verify field overrides match query refIds (A, B, C)

#### Panels Show Errors

- **"Bucket not found":** Token doesn't have read access
- **"Unauthorized":** Token expired or insufficient permissions
- **"No field":** Field name mismatch in query vs data

### Performance Tips

1. **Use aggregateWindow** for long time ranges (already configured in all timeseries)
2. **Limit query range** for tables (last 1h recommended)
3. **Enable query caching** in Grafana settings
4. **Set appropriate refresh intervals** (30s default is good for most use cases)
5. **Aggregated panels** (percentiles, heatmap, reliability) use `group()` which is efficient for large datasets
6. **Heatmap optimization**: Uses 1-hour windows - increase interval for very long time ranges

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
