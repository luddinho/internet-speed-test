# Set your variables
INFLUX_SERVER="http://YOUR_SERVER_IP:8086"
INFLUX_TOKEN="YOUR_TOKEN_HERE"
INFLUX_ORG="YOUR_ORG"
INFLUX_BUCKET="speed-test-metrics"

# Test 1: Auth
echo "Testing authentication..."
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" \
  "$INFLUX_SERVER/api/v2/me" \
  -H "Authorization: Token $INFLUX_TOKEN"

# Test 2: Bucket exists
echo -e "\nChecking if bucket exists..."
curl -s "$INFLUX_SERVER/api/v2/buckets?name=$INFLUX_BUCKET" \
  -H "Authorization: Token $INFLUX_TOKEN" | grep -q "\"name\":\"$INFLUX_BUCKET\"" \
  && echo "✓ Bucket '$INFLUX_BUCKET' found" \
  || echo "✗ Bucket '$INFLUX_BUCKET' NOT found"

# Test 3: Write permission
echo -e "\nTesting write permission..."
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" \
  -X POST "$INFLUX_SERVER/api/v2/write?bucket=$INFLUX_BUCKET&org=$INFLUX_ORG" \
  -H "Authorization: Token $INFLUX_TOKEN" \
  -H "Content-Type: text/plain" \
  --data-binary "test field=1 $(date +%s)000000000"