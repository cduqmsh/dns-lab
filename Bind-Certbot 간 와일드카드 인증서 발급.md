## BIND RFC2136 기반 Let's Encrypt Wildcard 인증서 발급 구성

## 1. 목적

Let's Encrypt Wildcard 인증서 발급을 위해 DNS-01 Challenge 방식을 사용한다.

HTTP-01 방식은 Wildcard 인증서를 지원하지 않기 때문에 DNS TXT 검증이 필요하며, BIND DNS의 RFC2136 Dynamic Update 기능을 이용하여 Certbot이 자동으로 TXT 레코드를 생성/삭제하도록 구성한다.

## 2. 구성 환경
```bash
구성 흐름

Certbot 서버
    |
    | RFC2136 DNS UPDATE
    | (TSIG Key 인증)
    |
    ↓
BIND Master DNS
    |
    | TXT 레코드 생성
    |
    ↓
_acme-challenge.도메인 TXT
    |
    ↓
Let's Encrypt 검증
    |
    ↓
인증서 발급
```

## 3. DNS-01 Challenge 동작 방식
```bash
Wildcard 인증서 발급 시 Let's Encrypt는 DNS TXT 레코드 검증을 수행한다.

Certbot 실행 시:

certbot
    |
    ↓
Let's Encrypt Challenge 요청
    |
    ↓
검증용 랜덤 Token 생성
    |
    ↓
_acme-challenge.도메인 TXT 등록 요청
Certbot은 RFC2136 Dynamic Update를 통해 BIND DNS에 임시 TXT 레코드를 생성한다.
 
예:

_acme-challenge.yumin.org TXT "랜덤검증값"
Let's Encrypt가 해당 TXT 값을 확인하면 인증서를 발급한다.

인증 완료 후 Certbot은 생성했던 TXT 레코드를 삭제한다.

따라서 인증 완료 후:

dig TXT _acme-challenge.yumin.org
결과가:

NXDOMAIN
으로 나오는 것은 정상이다.

* 임시 인증이라 zone 파일에는 반영 안될 수 있음
```

## 4. BIND 설정
```bash
Zone 설정

파일:

named.conf 파일 설정 변경 필요
설정:

key "certbot-key" {
        algorithm hmac-sha256;
        secret "p8tzgw7UCm75Jm7RQXa7Z95EzkGK6ibYgDNbcIZ+hLs=";
};


zone "yumin.org" IN {
    type master;
    file "/var/named/joongang/yumin.org.zone";

    update-policy {
        grant certbot-key zonesub TXT;
    }; => certbot-key 값으로 인증 받아 TXT 레코드 갱신

    zone-statistics yes;
};
추가 후 rndc reconfig 로 설정 반영 필요
```

## 5. TSIG Key 설정
```bash
Certbot과 BIND 간 인증을 위해 TSIG Key 사용.

해당 키값  생성(바인드에서 생성) : tsig-keygen -a hmac-sha256 certbot-key > certbot.key

예:

key "certbot-key" {
    algorithm hmac-sha256;
    secret "SECRET_VALUE";
};
권한:

chmod 600 rfc2136.ini
```

## 6. Certbot 설정
```bash
파일:
/etc/letsencrypt/rfc2136.ini
예:

dns_rfc2136_server = DNS_SERVER_IP
dns_rfc2136_name = certbot-key  (바인드에서 생성한 키값 이름)
dns_rfc2136_secret = SECRET_VALUE (바인드에서 생성한 키값 데이터)
dns_rfc2136_algorithm = HMAC-SHA256
```

## 7. 인증서 발급
```bash
실행:

certbot certonly \
--dns-rfc2136 \
--dns-rfc2136-credentials /etc/letsencrypt/rfc2136.ini \
-d yumin.org \
-d "*.yumin.org"
정상 결과:

Successfully received certificate.

Certificate is saved at:
/etc/letsencrypt/live/yumin.org/fullchain.pem

Key is saved at:
/etc/letsencrypt/live/yumin.org/privkey.pem
```

## 8. 와일드카드 인증서 확인
```bash
Certbot 확인
Edit
certbot certificates
예상:

Certificate Name: yumin.org
Domains:
    yumin.org
    *.yumin.org
Expiry Date:
    2026-10-08
OpenSSL 확인

openssl x509 \
-in /etc/letsencrypt/live/yumin.org/fullchain.pem \
-text \
-noout | grep -A1 "Subject Alternative Name"
결과:

X509v3 Subject Alternative Name:
    DNS:yumin.org, DNS:*.yumin.org
```

## 9. Dynamic Update 동작 확인
```bash
동적 업데이트는 zone 파일을 직접 수정하지 않고 journal 파일을 통해 변경된다.

구조:

yumin.org.zone
        +
yumin.org.zone.jnl
        |
        ↓
BIND 서비스 반영
RFC2136 업데이트 발생 시:

SOA Serial 자동 증가
zone.jnl 파일 생성/변경
DNS 응답 변경
```

## 10. 테스트 과정
```bash
기존 테스트 TXT 확인

dig TXT _acme-challenge.yumin.org
기존:

_acme-challenge TXT "remote-test"
TXT 삭제

RFC2136 nsupdate 사용:

update delete _acme-challenge.yumin.org TXT
send
확인:

dig TXT _acme-challenge.yumin.org
결과:

status: NXDOMAIN
ANSWER: 0
정상 삭제 확인.
```

## 11. 자동 갱신 테스트
```bash
Certbot은 자동 갱신 작업을 등록한다.

확인:

certbot renew --dry-run
성공 결과:

Congratulations, all simulated renewals succeeded
```

## 12. 운영 적용 시 주의사항
```bash
권장

TSIG Key 사용
update-policy 사용
TXT 레코드만 허용
Certbot 서버 IP 제한
비권장

allow-update {
    any;
};
모든 클라이언트가 DNS 변경 가능하므로 운영 환경에서는 사용하지 않는다.
```

## 13. 최종 상태
```bash
구성 완료 항목:

항목	상태
BIND Master DNS 구성	완료
RFC2136 Dynamic Update	완료
TSIG 인증	완료
Wildcard 인증서 발급	완료
TXT 자동 생성	정상
TXT 자동 삭제	정상
Certbot 자동 갱신	설정 완료
최종 구성은 BIND DNS와 Let's Encrypt Wildcard 인증서를 자동 연동하는 운영 가능한 구조이다.
```
