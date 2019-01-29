# HAProxy với SSL/TLS

# Nội dung

- [1. Tự tạo self-signed certificate](#selfsigned-cert)
  - [Step1: Tạo private key](#private-key)
  - [Step2: Đăng ký certificate -Certificate Sign Request](#csr)
  - [Step3: Tạo certificate - CRT](#crt)
  - [Step4: Mở rộng key và cert thành tệp pem](#append-pem)
  - [Step5: Cấu hình HAProxy với SSL cho website](#config-ssl)
- [2. Sử SSL sử dụng LetsEncrypt](#letsencrypt)
  - [Step1: Cài đặt Certbot](#install-certbot)
  - [Step2: Cấu hình HAProxy khi chưa https](haproxy-http)
  - [Step3: Tạo New letsencrypt certificate bằng certbot](#create-letsencrypt)
  - [Step4: Mở rộng key và cert thành tệp pem](#letsencrypt-pem)
  - [Step5: Cấu hình HAProxy sử dụng LetsEncrypt SSL](#haproxy-https)

=============================================================================

Trong mô hình Load Balancing, HAProxy đứng giữa client và các backend servers, vì vậy  kết nối mã hóa SSL giữa client và server sẽ có thể được thực hiện theo các phương thức sau:

- Thực hiện yêu cầu kết nối mã hóa SSL giữa Client và HAProxy, còn từ HAProxy thực hiện các kết nối không mã hóa với backend servers. Phương thức kết nối này làm cho CPU của HAProxy tăng cao hơn do phải thực hiện xử lý chấp nhận các yêu cầu kết nối không SSL. Phương thức này gọi là SSL Termination

- Thực hiện yêu cầu kết nối trực tiếp giữa Client và các backend servers. Vì kết nối đến nhiều backend server nên phân tải được việc xử lý của CPU được giảm tải hơn. Tuy nhiên, khi đó chúng ta lại không thể thực hiện Add/Set phần Header. Phương thức này gọi là SSL-Pass-Through)

Bài viết đi vào mô hình thực hiện ở cách thức kết nối SSL theo cách thức SSL Termination.

<p align="center"> 
<img src="../images/haproxy-ssl.png" />
</p>

## <a name="selfsigned-cert">1. Tự tạo self-signed certificate</a>

Đây là certificate mà ta sẽ tự tạo ra trên chính server. Certificate này không được xác thực bởi các nhà cung cấp chứng chỉ số (CA). Mục đích tạo self-signed certificate là để kiểm tra hoặc sử dụng trong môi trường mạng local.

Các bước tạo self-signed certificate và cấu hình HAProxy sử dụng SSL như sau:

### <a name="private-key">Step1: Tạo private key</a>

Thực hiện tạo key cho local domain "example.local".

- Tạo thư mục chứa certificate

        mkdir -p /etc/ssl/example.local
        cd /etc/ssl/example.local

- Tạo key với mã hóa RSA

`openssl genrsa -des3 -out example.key 2048`

>root@vnsys:/etc/ssl/example.local# openssl genrsa -des3 -out example.key 2048
Generating RSA private key, 2048 bit long modulus
.........................................................+++
...................................+++
e is 65537 (0x10001)
Enter pass phrase for example.key:
Verifying - Enter pass phrase for example.key:

Quá trình tạo key ở trên yêu cầu nhập pass phrase. Để remove passphrase (mục đích là bỏ qua quá trình hỏi pass phrase) thực hiện như sau:

`openssl rsa -in example.key -out example.key`

>root@vnsys:/etc/ssl/example.local# openssl rsa -in example.key -out example.key
Enter pass phrase for example.key:
writing RSA key

### <a name="csr">Step2: Đăng ký certificate (Certificate Signing Request -CSR)</a>

Dựa vào key đã tạo ở Step1, chúng ta thực hiện đăng ký certificate

`openssl req -new -key example.key -out example.csr`

>root@vnsys:/etc/ssl/example.local# openssl req -new -key example.key -out example.csr
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
>Country Name (2 letter code) [AU]:VN
State or Province Name (full name) [Some-State]:HN
Locality Name (eg, city) []:CG
Organization Name (eg, company) [Internet Widgits Pty Ltd]:IT
Organizational Unit Name (eg, section) []:Example Inc
Common Name (e.g. server FQDN or YOUR name) []:example.local
Email Address []:

>Please enter the following 'extra' attributes
to be sent with your certificate request
A challenge password []:
An optional company name []:

### <a name="crt">Step3: Tạo certificate - CRT</a>

Dựa vào CSR ở trên, chúng ta tạo một self-signed certificate, với hiệu lực 365 ngày

`openssl x509 -req -days 365 -in example.csr -signkey example.key -out example.crt`

>root@vnsys:/etc/ssl/example.local# openssl x509 -req -days 365 -in example.csr -signkey example.key -out example.crt
Signature ok
subject=/C=VN/ST=HN/L=CG/O=IT/OU=Example Inc/CN=example.local
Getting Private key

### <a name="append-pem">Step4: Mở rộng key và cert thành tệp pem</a>

Tệp pem là tệp tin chứa định dạng có thể chỉ public certificate hoặc có thể gồm tập public key, private key và root certificate kết hợp với nhau.

Chúng ta thực hiện nối private key và certificate ở trên để tạo thành tệp pem

`cat example.key example.crt >>example.pem`

### <a name="config-ssl">Step5: Cấu hình HAProxy với SSL cho website</a>

Sau khi đã có tệp pem, chúng ta cấu hình HAProxy để cho phép xử lý luồng kết nối với SSL.

**Phần frontend**

Chúng ta gán listen port cho https với port default là 443, không sử dụng giao thức sslv3, và chỉ định vị trí tệp pem “example.pem”.

- Sử dụng đồng thời cả 02 giao thức HTTP và HTTPS

```
#Frontend Section
frontend http-in
        bind *:80
	  bind *:443 ssl no-sslv3 crt /etc/ssl/example.local/example.pem 
        acl example-acl hdr(host) -i example.local
        use_backend example if example-acl
```

- Chỉ sử dụng HTTPS

Khi đó chúng ta cần thêm tùy chọn redirect khi truy cập http đến https

  - Redirect toàn bộ các site trong cấu hình HAProxy, thì sử dụng:

`redirect scheme https code 301 if !{ ssl_fc }`

  - Redirect với site chỉ định

`redirect scheme https if { hdr(Host) -i example.local } !{ ssl_fc }`

Khi đó, cấu hình frontend như sau:

```
#Frontend section
frontend http-in
        bind *:80
	  bind *:443 ssl no-sslv3 crt /etc/ssl/example.local/example.pem
	  redirect scheme https if { hdr(Host) -i example.local } !{ ssl_fc } 
        acl example-acl hdr(host) -i example.local
        use_backend example if example-acl
```

**Note**: Thay vì sử dụng default port cho https là 443, chúng ta muốn redirect đến https với một cổng tùy chọn, chẳng hạn 8443. Khi đó cấu hình tùy chọn như sau:

```
## Frontend section
frontend http-in
        bind *:80
	  bind *:8443 ssl no-sslv3 crt /etc/ssl/example.local/example.pem
	  http-request replace-value Host (.*):80 \1
        http-request redirect location https://%[req.hdr(Host)]:8443%[capture.req.uri] if !{ ssl_fc }
        acl example-acl hdr(host) -i   example.local
        use_backend example if example-acl
```

**Phần Backend**

Phần này, chúng ta sẽ khai báo thông tin thuật toán load balancing sẽ sử dụng, các thông tin web server , các tùy chọn về log và thiết lập tùy chọn header.

```
backend example
        balance roundrobin
        server server1 192.168.1.111:8080 weight 1 check
        server server2 192.168.1.112:8080 weight 1 chec
        server server3 192.168.1.113:8080 weight 1 check
        option httplog
        option forwardfor
        http-request set-header X-Forwarded-Port %[dst_port]
        http-request add-header X-Forwarded-Proto https if { ssl_fc }
```


Ở đây, chúng ta có một số tùy chọn:

**option forwardfor** : Được sử dụng để thêm header “X-Forwarded-For”, vì vậy backend có thể nhận được địa chỉ IP thực của client truy cập. Nếu không có tùy chọn này thì backend sẽ chỉ nhận được thông tin IP của HAProxy.

**http-request set-header X-Forwarded-Port %[dst_port]** : thiết lập một header “X-Forwarded-Port” vì vậy mà backend biết được port nào để sử dụng khi redirect URLs.

**http-request add-header X-Forwarded-Proto https if { ssl_fc }** : Thêm header X-Forwarded-Proto với thiết lập scheme là https nếu yêu cầu truy cập https. Cái này, cho phép backend xác định được scheme để sử dụng khi gửi URL lúc redirect

Khi đó, nội dung tệp cấu hình HAProxy đầy đủ cho site **example.local** sử dụng SSL như sau:

        # Global settings
        global
                log 127.0.0.1   local0
                pidfile     /var/run/haproxy.pid
                stats socket /var/lib/haproxy/stats
                maxconn 100000
                user haproxy
                group haproxy
                daemon
                quiet
                tune.ssl.default-dh-param 2048
                ssl-server-verify none

        # Proxies settings
        ## Defaults section
        defaults
                log     global
                mode    http
                option  httplog
                option  dontlognull
                retries 3
                option      redispatch
                maxconn     100000
                retries                 3
                timeout http-request    5s
                timeout queue           30s
                timeout connect         30s
                timeout client          30s
                timeout server          30s
                timeout http-keep-alive 30s
                timeout check           30s
        ## Frontend section
        frontend http-in
                bind *:80
                bind *:443 ssl no-sslv3 crt /etc/ssl/example.local/example.pem
                redirect scheme https if { hdr(Host) -i example.local } !{ ssl_fc } 
                acl example-acl hdr(host) -i example.local
                use_backend example if example-acl
        backend example
                balance roundrobin
                server server1 192.168.1.111:8080 weight 1 check
                server server2 192.168.1.112:8080 weight 1 chec
                server server3 192.168.1.113:8080 weight 1 check
                option httplog
                option forwardfor
                http-request set-header X-Forwarded-Port %[dst_port]
                http-request add-header X-Forwarded-Proto https if { ssl_fc }
        ## Statistics settings
        listen statistics
                bind *:1986
                stats enable
            stats admin if TRUE
                stats hide-version
                stats realm Haproxy\ Statistics
                stats uri /stats
                stats refresh 30s
                stats auth keepwalking86:ILoveVietnam$

## <a name="letsencrypt">2. Sử SSL sử dụng LetsEncrypt</a>

Trong phần này, chúng ta sẽ sử dụng certificate được cung cấp bởi một nhà cung cấp certificate (certificate authority – CA). Sử dụng certificate này cho phép website được xác thực khi truy cập internet. Với điều kiện hạn chế, chúng ta có thể sử dụng certificate miễn phí của một số nhà cung cấp.

Trong phần cấu hình này, chúng ta sử dụng Let’s Encrypt để nhận certificate miễn phí với mỗi lần renew là 90 ngày.

Yêu cầu:

- Website publish với tên miền internet.

### <a name="install-certbot">Step1: Cài đặt Certbot</a>

Để lấy certificate từ Let’s Encrypt chúng ta sử dụng công cụ Certbot

- Cài đặt LetsEncrypt trên Ubuntu-16.04+

```
sudo add-apt-repository -y ppa:certbot/certbot
sudo apt-get update
sudo apt-get install -y certbot
```

- Cài đặt LetsEncrypt trên CentOS 7

```
yum -y install epel-release
yum -y install certbot
```

### <a name="haproxy-http">Step2: Cấu hình HAProxy khi chưa https</a>

Certbot có thể tự động lấy certificate, nhưng điều kiện cần là nó phải xác minh được domain hợp lệ. Tôi cấu hình haproxy cho website với tên miền mymusic.vn (thay mymusic.vn với thông tin website thực cần cấu hình) như sau:

        # Global settings
        global
                pidfile     /var/run/haproxy.pid
                maxconn 100000
                user haproxy
                group haproxy
                daemon
                quiet
                stats socket /var/lib/haproxy/stats
                log 127.0.0.1   local0

        # Proxies settings
        ## Defaults section
        defaults
                log     global
                mode    http
                option  httplog
            option  forwardfor
                option  dontlognull
                retries 3
                option      redispatch
                maxconn     100000
                retries                 3
                timeout http-request    5s
                timeout queue           10s
                timeout connect         10s
                timeout client          10s
                timeout server          10s
                timeout http-keep-alive 10s
                timeout check           10s

        ## Frontend section
        frontend http-in
                bind *:80
                acl mymusic-acl hdr(host) -i mymusic.vn
                use_backend mymusic if mymusic-acl
        ## Backend section
        backend mymusic
                balance roundrobin
                server server1 192.168.10.111:8080 weight 1 check
                server server2 192.168.10.112:8080 weight 1 check
                server server3 192.168.10.113:8080 weight 1 check
        ## Statistics settings
        listen statistics
                bind *:1986
                stats enable
            stats admin if TRUE
                stats hide-version
                stats realm Haproxy\ Statistics
                stats uri /stats
                stats refresh 30s
                stats auth keepwalking86:ILoveVietnam$

### <a name="create-letsencrypt">Step3: Tạo New letsencrypt certificate bằng certbot</a>

Nếu muốn tạo certificate và cấu hình haproxy, chúng ta cần cấp phép cho LetsEncrypt. Khi đó cần thiết lập một site stand-alone để listen khi ủy quyền cho LetsEncrypt.

Khi yêu cầu một certificate từ LetsEncrypt, nó sẽ yêu cầu được truy cập vào tệp tin được ủy quyền theo dạng đường dẫn “http://your-domain/well-known/acme-challenge/” và đường dẫn này bind đến cổng 80 cho yêu cầu http và 443 cho https. Khi đó chúng ta thực hiện yêu cầu certificate với một trong hai cách sau:

**Cách 1: Stop HAProxy**

Chẳng hạn haproxy đang listen ở port 80, khi đó stop haproxy và thực hiện chạy dòng lệnh sau để yêu cầu certificate từ LetsEncrypt

```
systemctl stop haproxy
certbot certonly --standalone -d mymusic.vn --non-interactive --agree-tos --email keepwalking86@mymusic.vn
```

>root@vnsys:/home/keepwalking# certbot certonly --standalone -d mymusic.vn --non-interactive --agree-tos --email keepwalking86@mymusic.vn
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Plugins selected: Authenticator standalone, Installer None
Starting new HTTPS connection (1): acme-v02.api.letsencrypt.org
Obtaining a new certificate
Performing the following challenges:
http-01 challenge for mymusic.vn
Waiting for verification...
Cleaning up challenges

>IMPORTANT NOTES:
> - Congratulations! Your certificate and chain have been saved at:
   /etc/letsencrypt/live/mymusic.vn/fullchain.pem
   Your key file has been saved at:
   /etc/letsencrypt/live/mymusic.vn/privkey.pem
   Your cert will expire on 2019-04-29. To obtain a new or tweaked
   version of this certificate in the future, simply run certbot
   again. To non-interactively renew *all* of your certificates, run
   "certbot renew"
 >- Your account credentials have been saved in your Certbot
   configuration directory at /etc/letsencrypt. You should make a
   secure backup of this folder now. This configuration directory will
   also contain certificates and private keys obtained by Certbot so
   making regular backups of this folder is ideal.
 >- If you like Certbot, please consider supporting our work by:

>   Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
   Donating to EFF:                    https://eff.org/donate-le

Sau khi kết thúc quá trình nhận certificate cho site **mymusic.vn** từ LetsEncrypt thành công, khi đó thư mục chứa các tệp certificate, key nằm ở /etc/letsencrypt/live/mymusic.vn/

**Cách 2: Haproxy vẫn hoạt động trên port 80**

Để tránh xung đột port 80 với HAProxy, chúng ta sẽ cấu hình haproxy để bảo cho LetsEncrypt listen với một port khác, chẳng hạn 8080. Thực hiện cấu hình haproxy như sau:

- Thêm tùy chọn acl trong phần frontend

Sử dụng cổng 80 cùng với site mymusic.vn nhưng khi đó, cần tạo acl để truy cập URL mà chứa chuỗi “/.well-known/acme-challenge/”

                acl letsencrypt-acl path_beg /.well-known/acme-challenge/
                use_backend letsencrypt if letsencrypt-acl

- Cấu hình phần backend

Khai báo cổng listen local sẽ sử dụng

        backend letsencrypt
                server letsencrypt 127.0.0.1:8080

Khi đó reload haproxy và thực hiện tạo certificate như sau:

`certbot certonly --standalone -d mymusic.vn --non-interactive --agree-tos --email keepwalking86@mymusic.vn --http-01-port=8080`

>root@vnsys:/home/keepwalking# certbot certonly --standalone -d mymusic.vn --non-interactive --agree-tos --email keepwalking86@mymusic.vn --http-01-port=8080
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Plugins selected: Authenticator standalone, Installer None
Starting new HTTPS connection (1): acme-v02.api.letsencrypt.org
Obtaining a new certificate
Performing the following challenges:
http-01 challenge for mymusic.vn
Waiting for verification...
Cleaning up challenges

>IMPORTANT NOTES:
 >- Congratulations! Your certificate and chain have been saved at:
   /etc/letsencrypt/live/mymusic.vn/fullchain.pem
   Your key file has been saved at:
   /etc/letsencrypt/live/mymusic.vn/privkey.pem
   Your cert will expire on 2019-04-29. To obtain a new or tweaked
   version of this certificate in the future, simply run certbot
   again. To non-interactively renew *all* of your certificates, run
   "certbot renew"
 >- If you like Certbot, please consider supporting our work by:

   >Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
   Donating to EFF:                    https://eff.org/donate-le

Trong đó, thuộc tính các tham số truyền vào như sau:

**--standalone**: Sử dụng chế độ standalone để đạt một certificate khi chúng ta không muốn sử dụng hoặc không có web server đang tồn tại. Sử dụng standalone, chúng ta kết hợp gồm lệnh “certonly”

**-d mymusic.vn**: chỉ định public domain hợp lệ “mymusic.vn” mà trỏ bản ghi “A” vào địa chỉ IP Public của haproxy. Tùy chọn “-d” có thể được sử dụng cho nhiều domain và yêu cầu cùng một certificate.

**--non-interactive --agree-tos --email keepwalking86@mymusic.vn**: Cho phép xác nhận các điều khoản, cũng như vào thông tin email tự động khi LetsEncrypt yêu cầu

**--http-01-port=8080**: Cái này bảo cho stand-alone server sẽ listen trên port 8080 của một request HTTP.

### <a name="letsencrypt-pem">Step4: Mở rộng key và cert thành tệp pem</a>

Tệp pem là tệp tin chứa định dạng có thể chỉ public certificate hoặc có thể gồm tập public key, private key và root certificate kết hợp với nhau.

Chúng ta thực hiện nối private key và certificate ở trên để tạo thành tệp pem. 

```
cd /etc/letsencrypt/live/mymusic.vn/
cat fullchain.pem privkey.pem | tee mymusic.vn.pem
```

### <a name="haproxy-https">Step5: Cấu hình HAProxy sử dụng LetsEncrypt SSL</a>

Sau khi đã có tệp pem, chúng ta cấu hình HAProxy để cho phép xử lý luồng kết nối với SSL.

**Phần frontend**

Chúng ta gán listen port cho https với port default là 443, không sử dụng giao thức sslv3, và chỉ định vị trí tệp pem “mymusic.vn.pem”.

- Nếu HAProxy sử dụng đồng thời cả HTTP và HTTPS, khi đó cấu hình như sau:

```
##Frontend section
frontend http-in
        bind *:80
        bind *:443 ssl no-sslv3 crt /etc/letsencrypt/live/mymusic.vn/mymusic.vn.pem
        acl mymusic-acl hdr(host) -i mymusic.vn
        use_backend mymusic if mymusic-acl
```

- HAProxy chỉ sử dụng HTTPS

Khi đó chúng ta cần thêm tùy chọn redirect khi truy cập http đến https

  - Redirect với site mymusic.vn

`redirect scheme https if { hdr(Host) -i mymusic.vn } !{ ssl_fc }`

Khi đó, cấu hình frontend như sau:

```
##Frontend section
frontend http-in
        bind *:80
        bind *:443 ssl no-sslv3 crt /etc/letsencrypt/live/mymusic.vn/mymusic.vn.pem
        redirect scheme https if { hdr(Host) -i mymusic.vn } !{ ssl_fc } 
        acl mymusic-acl hdr(host) -i mymusic.vn
        use_backend mymusic if mymusic-acl
```

**Phần Backend**

Chúng ta sẽ khai báo thông tin thuật toán load balancing sẽ sử dụng, các thông tin web server , các tùy chọn về log và thiết lập tùy chọn header.

```
backend mymusic
        balance roundrobin
        server server1 192.168.10.111:8080 weight 1 check
        server server2 192.168.10.112:8080 weight 1 chec
        server server3 192.168.10.113:8080 weight 1 check
        option httplog
        option forwardfor
        http-request set-header X-Forwarded-Port %[dst_port]
        http-request add-header X-Forwarded-Proto https if { ssl_fc }
```

Ở đây, chúng ta có một số tùy chọn:

**option forwardfor** : Được sử dụng để thêm header “X-Forwarded-For”, vì vậy backend có thể nhận được địa chỉ IP thực của client truy cập. Nếu không có tùy chọn này thì backend sẽ chỉ nhận được thông tin IP của HAProxy.

**http-request set-header X-Forwarded-Port %[dst_port]** : thiết lập một header “X-Forwarded-Port” vì vậy mà backend biết được port nào để sử dụng khi redirect URLs.

**http-request add-header X-Forwarded-Proto https if { ssl_fc }** : Thêm header X-Forwarded-Proto với thiết lập scheme là https nếu yêu cầu truy cập https. Cái này, cho phép backend xác định được scheme để sử dụng khi gửi URL lúc redirect

Khi đó, nội dung tệp cấu hình HAProxy đầy đủ cho site mymusic.vn sử dụng SSL như sau:

        # Global settings
        global
                log 127.0.0.1   local0
                pidfile     /var/run/haproxy.pid
                stats socket /var/lib/haproxy/stats
                maxconn 100000
                user haproxy
                group haproxy
                daemon
                quiet
        # Proxies settings
        ## Defaults section
        defaults
                log     global
                mode    http
                option  httplog
                option  dontlognull
                retries 3
                option      redispatch
                maxconn     100000
                retries                 3
                timeout http-request    5s
                timeout queue           30s
                timeout connect         30s
                timeout client          30s
                timeout server          30s
                timeout http-keep-alive 30s
                timeout check           30s
        ## Frontend section
        frontend http-in
                bind *:80
                bind *:443 ssl no-sslv3 crt /etc/letsencrypt/live/mymusic.vn/mymusic.vn.pem
                redirect scheme https if { hdr(Host) -i mymusic.vn } !{ ssl_fc } 
                acl mymusic-acl hdr(host) -i mymusic.vn
                use_backend mymusic if mymusic-acl
        backend mymusic
                balance roundrobin
                server server1 192.168.10.111:8080 weight 1 check
                server server2 192.168.10.112:8080 weight 1 chec
                server server3 192.168.10.113:8080 weight 1 check
                option httplog
                option forwardfor
                http-request set-header X-Forwarded-Port %[dst_port]
                http-request add-header X-Forwarded-Proto https if { ssl_fc }
        ## Statistics settings
        listen statistics
                bind *:1986
                stats enable
            stats admin if TRUE
                stats hide-version
                stats realm Haproxy\ Statistics
                stats uri /stats
                stats refresh 30s
                stats auth keepwalking86:ILoveVietnam$

Tham khảo thêm về [LetsEncrypt](https://certbot.eff.org/docs/using.html)
