# named.conf 검증 하여 해당 zone 존재여부 체크

#!/usr/bin/bash

CONF="/etc/bind/named.conf"

# zone file list 추출
LIST=$(egrep 'zone "' $CONF | awk -F\" '{print $4}')

# 파일 존재 여부 확인
for FILE in $LIST; do
    if [[ ! -f $FILE ]]; then
        echo "파일이 존재하지 않음 : $FILE"
    else
        echo "OK : $FILE"
    fi
done
