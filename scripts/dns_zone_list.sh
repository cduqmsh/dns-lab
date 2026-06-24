# dns zone 리스트 및 각 zone 레코드 값 추출

#!/bin/bash

NAMED_CONF="/etc/bind/named.conf"
ZONE_BASE_DIR="/var/cache/bind"   # 필요 시 변경
OUTPUT_FILE="/home/bluesky/dns.csv"

echo "DNS,VALUE,TYPE" > "$OUTPUT_FILE"

grep 'zone "' "$NAMED_CONF" | while read -r line; do

    zone=$(echo "$line" | sed -E 's/.*zone "([^"]+)".*/\1/')
    zonefile=$(echo "$line" | sed -E 's/.*file "([^"]+)".*/\1/')

    if [[ "$zonefile" != /* ]]; then
        zonefile="$ZONE_BASE_DIR/$zonefile"
    fi

    if [ -f "$zonefile" ]; then
        named-compilezone -f text -F text -o - "$zone" "$zonefile" 2>/dev/null
    fi

done \
| grep -v '^zone ' \
| grep -v '^OK$' \
| grep -v '^;' \
| grep -v '^$' \
| awk '$4 != "NS" && $4 != "SOA" {

    name=$1
    type=$4

    $1=$2=$3=$4=""

    sub(/^[ \t]+/, "", $0)
    data=$0

    gsub(/"/, "", data)

    print name "," data "," type
}' \
>> "$OUTPUT_FILE"

echo "완료: $OUTPUT_FILE"
