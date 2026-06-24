# test.co.kr 에 대한 zone 파일 설정 예시

$ORIGIN .
$TTL 600        ; 10 minutes
folin.co                IN SOA  ns.test.com. dnsadmin.test.com. (
                                2025040301 ; serial
                                10800      ; refresh (3 hours)
                                900        ; retry (15 minutes)
                                604800     ; expire (1 week)
                                600        ; minimum (10 minutes)
                                )
                        NS      ns.test.com.
                        NS      ns2.test.com.
                        
                        A       211.212.223.244
                        
                        MX      1 ASPMX.L.GOOGLE.COM.
                        MX      5 ALT1.ASPMX.L.GOOGLE.COM.
                        MX      5 ALT2.ASPMX.L.GOOGLE.COM.
                        MX      10 ALT3.ASPMX.L.GOOGLE.COM.
                        MX      10 ALT4.ASPMX.L.GOOGLE.COM.
                        
                        TXT     "afaadadafagagagfafd"
$ORIGIN folin.co.

www                     A       2.2.2.4
www01                   A       2.2.2.1
www02                   A       2.2.2.3
