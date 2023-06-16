#!/bin/bash

echo "== $(date) =="
ts=$(date  +%s%3N)
echo "ts: $ts"
echo "sending: $1"
curl -s -o - -w "status code: %{http_code}\n" -X POST -d "ts=$ts&mode=auto" "http://raceserver:9292/competitor_$1"
echo "=================================="
echo -e
