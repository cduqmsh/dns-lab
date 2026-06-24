# apply_dns.sh test.co.kr test.co.kr
# apply_dns.sh test.co.kr www.test.co.kr
# zone 설정 변경 시 master에서 적용하면 slave도 동기화 하는 스크립트


#!/usr/bin/bash

NC=$(tput sgr0)
CYAN=$(tput setaf 6)
RED=$(tput setaf 1)

MASTER_IP="1.1.1.1"
SLAVE_IP="1.1.1.2"

ZONE="$1"
DOMAIN="$2"
ZONE_FILE="$ZONE.zone"

# 1️⃣ 존파일 존재 확인
if [[ ! -f $ZONE_FILE ]]; then
    echo -e "${RED}존파일이 없습니다${NC}"
    echo -e "usage: $0 domain fqdn"
    exit 1
fi

# 2️⃣ named.conf ↔ 실제 파일 검증
ZONECHECK=$(/root/scripts/dns/check_zone.sh | egrep -v ^OK)
if [[ $? -eq 0 ]]; then
    echo -e "${RED}named.conf 설정 오류${NC}"
    echo -e "${ZONECHECK}"
    exit 1
fi

echo -e "${CYAN}++++++++++++++++++++++++++++++++++++++++++++++++++++++++${NC}"
echo "존 설정 확인 완료"

# 3️⃣ serial 자동 증가
echo -e "${CYAN}Serial 자동 증가${NC}"

CURRENT_SERIAL=$(grep -E '[0-9]{10}.*Serial' $ZONE_FILE | awk '{print $1}')
NEW_SERIAL=$(date +%Y%m%d%H)

if [[ "$CURRENT_SERIAL" -ge "$NEW_SERIAL" ]]; then
    NEW_SERIAL=$((CURRENT_SERIAL + 1))
fi

sed -i "s/$CURRENT_SERIAL/$NEW_SERIAL/" $ZONE_FILE
echo "Serial: $CURRENT_SERIAL → $NEW_SERIAL"

# 4️⃣ zone 검증
echo -e "${CYAN}++++++++++++++++++++++++++++++++++++++++++++++++++++++++${NC}"
named-checkzone $ZONE $ZONE_FILE || exit 1

# 5️⃣ Master reload
echo -e "${CYAN}++++++++++++++++++++++++++++++++++++++++++++++++++++++++${NC}"
echo -n "rndc reload $ZONE 실행 (y/n): "
read answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
    rndc reload $ZONE
else
    echo -e "${RED}중단됨${NC}"
    exit 1
fi

sleep 3

# 6️⃣ Master 확인
echo -e "${CYAN}++++++++++++++++++++++++++++++++++++++++++++++++++++++++${NC}"
echo -e "${CYAN}[MASTER - $MASTER_IP]${NC}"

MASTER_RESULT=$(dig @$MASTER_IP $DOMAIN ANY +noall +answer)

if [[ -z "$MASTER_RESULT" ]]; then
    echo -e "${RED}❌ NXDOMAIN${NC}"
else
    echo "$MASTER_RESULT"
fi

# 7️⃣ Slave 동기화 (retransfer)
echo -e "${CYAN}++++++++++++++++++++++++++++++++++++++++++++++++++++++++${NC}"
echo "Slave retransfer 시도"

ssh root@$SLAVE_IP "rndc retransfer $ZONE" 2>/dev/null

sleep 3

# 8️⃣ Slave 확인
echo -e "${CYAN}++++++++++++++++++++++++++++++++++++++++++++++++++++++++${NC}"
echo -e "${CYAN}[SLAVE - $SLAVE_IP]${NC}"

SLAVE_RESULT=$(dig @$SLAVE_IP $DOMAIN ANY +noall +answer)

if [[ -z "$SLAVE_RESULT" ]]; then
    echo -e "${RED}❌ NXDOMAIN → reload 시도${NC}"
    ssh root@$SLAVE_IP "rndc reload $ZONE" 2>/dev/null
    sleep 2
    SLAVE_RESULT=$(dig @$SLAVE_IP $DOMAIN ANY +noall +answer)
fi

echo "${SLAVE_RESULT:-❌ 반영 안됨}"

echo -e "${CYAN}++++++++++++++++++++++++++++++++++++++++++++++++++++++++${NC}"
echo -e "${CYAN}완료${NC}"
