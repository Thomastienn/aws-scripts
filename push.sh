CACHE_FILE=$HOME/aws-scripts/.bucket_cache
CACHE_TTL=28800

if [ -f "$CACHE_FILE" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
    if [ "$age" -ge "$CACHE_TTL" ]; then
        echo "Cache is stale, removing..."
        rm "$CACHE_FILE"
    fi
fi

# If cache exists, use it
if [ -f "$CACHE_FILE" ]; then
    echo "Using cached bucket name..."
    S3_BUCKET_NAME=$(cat "$CACHE_FILE")
else
    echo "Cache not found or stale, fetching bucket name..."
    S3_BUCKET_NAME=$(aws s3 ls | rg -o "dev.*webserver.*")
    echo "$S3_BUCKET_NAME" > "$CACHE_FILE"
fi

echo "Using S3 bucket: $S3_BUCKET_NAME"
FOLDER="$HOME/smartsuite/src/webserver_frontend"

cd $FOLDER
npm run build &&
aws s3 cp build "s3://$S3_BUCKET_NAME/" --recursive --profile smartsuite
