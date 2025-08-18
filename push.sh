CACHE_FILE_DEV=$HOME/aws-scripts/.bucket_cache_dev
CACHE_FILE_PROD=$HOME/aws-scripts/.bucket_cache_prod
CACHE_TTL=28800
BRANCH=${1:-"dev"}

CACHE_FILE=""
if [ "$BRANCH" == "dev" ]; then
    CACHE_FILE="$CACHE_FILE_DEV"
elif [ "$BRANCH" == "prod" ]; then
    CACHE_FILE="$CACHE_FILE_PROD"
else
    echo "Usage: $0 [dev|prod]"
    exit 1
fi

if [ -f "$CACHE_FILE" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
    if [ "$age" -ge "$CACHE_TTL" ]; then
        echo "Cache is stale, removing..."
        rm "$CACHE_FILE"
    fi
fi

# If cache exists, use it
if [ -f $CACHE_FILE ]; then
    echo "Using cached $BRANCH bucket name..."
    S3_BUCKET_NAME=$(cat "$CACHE_FILE")
else
    echo "Cache not found or stale, fetching bucket name..."
    S3_BUCKET_NAME=$(aws s3 ls | rg -o "$BRANCH.*webserver.*")
    if [ "$BRANCH" == "prod" ]; then
        CACHE_FILE="$CACHE_FILE_PROD"
    else
        CACHE_FILE="$CACHE_FILE_DEV"
    fi
    echo "$S3_BUCKET_NAME" > CACHE_FILE
fi

echo "Using S3 bucket: $S3_BUCKET_NAME"
FOLDER="$HOME/smartsuite/src/webserver_frontend"

cd $FOLDER
npm run build &&
aws s3 cp build "s3://$S3_BUCKET_NAME/" --recursive --profile smartsuite
