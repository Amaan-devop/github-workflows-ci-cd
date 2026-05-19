#!/bin/bash
set -euo pipefail

# ---------------- Defaults ----------------
BUCKET_SRC_DEFAULT="source-bucket"
BUCKET_DST_DEFAULT="destination-bucket"
PREFIX="/prefix/"

START_DATE=""
END_DATE=""
BUCKET_SRC=""
BUCKET_DST=""

# ---------------- Parse flags ----------------
while getopts "s:e:b:d:" opt; do
  case "$opt" in
    s) START_DATE="$OPTARG" ;;
    e) END_DATE="$OPTARG" ;;
    b) BUCKET_SRC="$OPTARG" ;;
    d) BUCKET_DST="$OPTARG" ;;
    *)
      echo "Usage: $0 [-s start_date] [-e end_date] [-b src_bucket] [-d dst_bucket]"
      exit 1
      ;;
  esac
done

# ---------------- Apply defaults ----------------
BUCKET_SRC="${BUCKET_SRC:-$BUCKET_SRC_DEFAULT}"
BUCKET_DST="${BUCKET_DST:-$BUCKET_DST_DEFAULT}"

# ---------------- Date resolution logic ----------------
CURRENT_DATE=$(date -u +"%Y-%m-%d")

# Case 1: Start date provided, end date NOT provided
if [[ -n "$START_DATE" && -z "$END_DATE" ]]; then
  END_DATE="$CURRENT_DATE"
fi

# Case 2: End date provided, start date NOT provided
if [[ -z "$START_DATE" && -n "$END_DATE" ]]; then
  START_DATE=$(date -u -d "$END_DATE - 30 days" +"%Y-%m-%d")
fi

# Case 4: Neither start nor end date provided
if [[ -z "$START_DATE" && -z "$END_DATE" ]]; then
  END_DATE="$CURRENT_DATE"
  START_DATE=$(date -u -d "30 days ago" +"%Y-%m-%d")
fi

START_TS="${START_DATE}T00:00:00Z"
END_TS="${END_DATE}T23:59:59Z"

echo "Starting S3 document sync"
echo "Source bucket : $BUCKET_SRC"
echo "Dest bucket   : $BUCKET_DST"
echo "Prefix        : $PREFIX"
echo "Start date    : $START_TS"
echo "End date      : $END_TS"
echo ""

# ---------------- Copy logic ----------------
# Disable pipefail only for this pipeline
set +o pipefail

aws s3api list-objects-v2 \
  --bucket "$BUCKET_SRC" \
  --prefix "$PREFIX" \
  --query "Contents[?LastModified>=\`$START_TS\` && LastModified<=\`$END_TS\`].Key" \
  --output text \
| tr '\t' '\n' \
| grep -v '^$' \
| while read -r key; do
    echo "COPY $key"
    aws s3 cp \
      "s3://$BUCKET_SRC/$key" \
      "s3://$BUCKET_DST/$key"
  done

# Re-enable pipefail
set -o pipefail

echo ""
echo "S3 document sync completed successfully"