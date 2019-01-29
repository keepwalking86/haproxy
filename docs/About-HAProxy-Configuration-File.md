# Cấu trúc tệp cấu hình HAProxy

____

# Nội dung

- [1. Phần global](#global)
  - [1.1 Giới thiệu](#about_global)
  - [1.2 Một số tham số/chỉ thị và cú pháp cần biết](#parameters_global)
  - [1.3 Một ví dụ về phần global](#example_global)
- [2. Phần proxies](#proxy)
  - [2.1 Về phần proxy](#about_proxy)
  - [2.2 Một số tham số/chỉ thị và cú pháp cần biết](#parameters_proxy)
  - [2.3 Ví dụ về phần proxy](#example_proxy)

==========================================================

Mặc định tệp cấu hình HAProxy là /etc/haproxy/haproxy.cfg

Chúng ta xem qua cấu hình tệp haproxy.cfg đơn giản sau:

        global
            daemon
            maxconn 256
        defaults
            mode http
            timeout connect 5000ms
            timeout client 50000ms
            timeout server 50000ms

        frontend http-in
            bind *:80
            default_backend servers

        backend servers
            server server1 127.0.0.1:8000 maxconn 32

Khi đó, chúng ta thấy rằng một tệp cấu hình của haproxy.cfg gồm 04 phần:

- global

- defaults

- frontend

- backend

Chúng ta có thể gộp lại phần frontend và backend, khi đó viết đơn giản tệp cấu hình trên với 03 phần (global, defaults và listen) như sau:

        global
            daemon
            maxconn 256

        defaults
            mode http
            timeout connect 5000ms
            timeout client 50000ms
            timeout server 50000ms

        listen http-in
            bind *:80
            server server1 127.0.0.1:8000 maxconn 32

Chúng ta lấy 02 ví dụ trên để thấy rằng tệp cấu hình HAProxy.conf không phải gồm 3 hay 4 phần như ở trên. Mà thực tế HAProxy gồm 02 phần cấu hình chính: global và proxies

## <a name="global">1. Phần global</a>

### <a name="about_global">1.1 Giới thiệu</a>

Đây là phần thiết lập các tham số chung của HAProxy, thường là các thiết lập liên quan đến hệ thống. Các tham số trong phần này chỉ cần thiết lập một lần và được áp dụng đến toàn bộ cấu hình. Các nội dung chính trong phần global gồm:

- Process management and security: gồm các thông tin như pidfile, user, group, log, daemon, stats, ..

- Performance tuning: gồm các thông tin về cấu hình hiệu suất như maxconn,

- Debugging: Các thông tin liên quan đến phần debug, có 02 tham số debug hoặc quiet.

### <a name="parameters_global">1.2 Một số tham số/chỉ thị và cú pháp cần biết</a>

- `daemon`:  tham số daemon được định nghĩa trong phần global. Nó được sử dụng thiết lập process haproxy ở chế độ chạy nền (background), tương đương tham số -D khi chạy dòng lệnh. Ở hệ thống systemd thì tùy chọn này không cần, nó là default.

- `user/group`: Thiết lập user/group để chạy haproxy

- `log <address> [len <length>] [format <format>] <facility> [max level [min level]]`: dùng để định nghĩa server global syslog, ghi lại thông tin log khi start hoặc exit, cũng như phần log trong phần proxy (phần proxy ta sẽ giới thiệu sau) mà có khai báo “log global”. Chỉ thị “log” có thể định nghĩa được 02 server global.
<address> là địa chỉ mà sẽ lưu log. Địa chỉ ở đây có thể là IP và port UDP đi kèm (mặc định syslog có port là 514) hoặc là đường dẫn Unix socket của log.
<facility> là thiết lập chuẩn của syslog. Nó gồm 24 chuẩn sau:
                 kern   user   mail   daemon auth   syslog lpr    news
                 uucp   cron   auth2  ftp    ntp    audit  alert  cron2
                 local0 local1 local2 local3 local4 local5 local6 local7

- `stats socket [<address:port>|<path>] [param*]`: Gán một Unix socket đến <path> hoặc một địa chỉ đến <address:port>. Kết nối đến socket này dùng để xuất các thông tin về thống kê hoạt động HAProxy.

- `maxconn <number>`: Thiết lập số kết nối đồng thời tối đa trên một process mà HAProxy chấp nhận xử lý. Proxy sẽ dừng chấp nhận kết nối khi đạt đến giới hạn này.
debug/quiet → Để bật hoặc tắt chế độ bug

### <a name="example_global">1.3 Một ví dụ về phần global</a>

        global
            pidfile     /var/run/haproxy.pid
            maxconn 100000
            user haproxy
            group haproxy
            daemon
            debug
            #quiet
            stats socket /var/lib/haproxy/stats
            log 127.0.0.1   local0

## <a name="proxy">2. Phần proxies </a>

### <a name="about_proxy">2.1 Về phần proxy</a>

Phần này chính là thiết lập proxy. Cấu hình proxy có thể được thiết lập ở một trong các phần sau:

#### defaults <name>

#### frontend <name>

#### backend  <name>

#### listen   <name>

- Phần "defaults" sẽ thiết lập các tham số mặc định cho các phần khác sau phần khai báo của nó. Những tham số trong phần defaults này sẽ được reset nếu có các thiết tùy chọn ở phần tiếp theo như frontend, backend hoặc listen.

- Một “frontend” là các thông tin cấu hình mà HAProxy chấp nhận các yêu cầu kết nối từ client.

- Một “backend” mô tả một nhóm các server mà proxy sẽ kết nối để chuyển tiếp kết nối incoming.
	Các thông tin cấu hình cơ bản trong phần này gồm: thông tin về thuật toán, địa chỉ IP hoặc tên, port của các server backend. Các thiết lập về forward 

- Một “listen” định nghĩa một proxy hoàn chỉnh với các phần frontend và backend mà được kết hợp gói gọn trong một phần.

- name trong phần proxy có thể gồm các ký tự: hoa, thường, số, gạch ngang ‘-’, gạch dưới ‘_’, dấu chấm ‘.’ và dấu hai chấm ‘:’.  Nó phân biệt chữ hoa và chữ thường trong proxy.

Note: Tại sao chúng ta lại gọi một phần defaults, frontend, backend, hay một listen??Tại vì, trong cấu hình haproxy, chúng ta có thể khai báo nhiều phần (section) như thế trong phần proxy.

### <a name="parameters_proxy">2.2 Một số tham số/chỉ thị và cú pháp cần biết</a>

Trong phần này thì các từ khóa, chỉ thị là rất nhiều (khoảng 200 keywords). Các từ khóa đó có thể ảnh hướng đến một số hoặc tất các phần như defaults, frontend, backend, listen . Vì vậy, chúng ta sẽ giới thiệu qua một số từ khóa phổ biến.

`acl <aclname> <criterion> [flags] [operator] <value> …` Dùng để khai báo access list. Nó được sử dụng trong phần: frontend, backend, listen. Chi tiết về ACL chúng ta sẽ nói ở phần sau.
Example:
        acl invalid_src  src          0.0.0.0/7 224.0.0.0/3
        acl invalid_src  src_port     0:1023
        acl local_dst    hdr(host) -i localhost

`balance <algorithm> [ <arguments> ]`
balance được sử dụng để khai báo thuật toán load balancing sẽ được dùng trong một backend. HAProxy hỗ trợ các thuật toán sau: roundrobin, static-rr, leastconn, first, source, uri, url_parm, hdr, rdp-cookie. Mặc định roundrobin là thuật toán cho loadbalancing.
Phần các thuật toán load balancing trong HAProxy chúng ta sẽ nói chi tiết hơn trong phần sau(2.1 Các thuật toán cân bằng tải)

>bind [<address>]:<port_range> [, ...] [param*]
>bind /<path> [, ...] [param*]

Bind được sử dụng để định nghĩa một hoặc nhiều địa chỉ trên server HAProxy sẽ listen (địa chỉ có thể là tên máy hoặc ip, hoặc thậm chí là path của Unix socker), có thể gồm cả port trong một frontend. bind có thể được dùng trong phần frontend hoặc listen.
Example :
        listen http_proxy
            bind :80,:443
            bind 10.0.0.1:10080,10.0.0.1:10443
            bind /var/run/ssl-frontend.sock user root mode 600 accept-proxy

        listen http_https_proxy
            bind :80
            bind :443 ssl crt /etc/haproxy/site1.pem crt /etc/haproxy/site2.pem

Ở ví dụ trên ta thấy có tùy chọn “crt” (certificate) trong bind. Thiết lập này được sử dụng khi cấu hình SSL khai báo sử dụng một tệp pem mà certificate và private key kết hợp. Tệp pem này có thể được sử dụng để kết hợp nhiều tệp pem vào làm một (ví dụ: cat cert.pem key.pem > combined.pem). 

>http-request { allow | auth [realm <realm>] | redirect <rule> | reject |
              tarpit [deny_status <status>] | deny [deny_status <status>] |
              add-header <name> <fmt> | set-header <name> <fmt> |
		…

http-request được sử dụng để kiểm soát việc truy cập. Nó định nghĩa tập các rule mà áp dụng trong các xử lý ở layer 7. http-request có thể được áp dụng trong phần frontend, backend hoặc listen.
Tùy chọn “add-header” được sử dụng để mở rộng trường HTTP header với tên được chỉ định trong <name> và giá trị được định nghĩa bởi <fmt> dựa vào tùy chọn rule của “log-format”. Ví dụ tùy chọn “add-header  X-Forwarded-Proto” dùng để xác định giao thức (http/https) trong phần request.
log global

`log <address> [len <length>] <facility> [<level> [<minlevel>]]`
Tùy chọn “log” có thể được áp dụng trong cả 4 phần: defaults, frontend, backend và listen. Một số tùy chọn chúng ta đã nói trên phần global.

- maxconn <number>: Thiết lập số kết nối đồng thời tối đa trên một process mà HAProxy chấp nhận xử lý mà ở phần global ta đã nói rồi. maxconn được sử dụng để thiết lập cho phần frontend. Tại sao chúng ta nhắc lại tùy chọn này. Bởi vị, chúng ta có thể thiết lập nhiều phần “frontend”, vì vậy mà có thể có các tùy chọn thiết lập maxconn khác nhau.

- mode { tcp|http} : Thiết lập chế độ mà HAProxy sẽ thực hiện. Nó có thể được áp dụng trong cả 4 phần của proxy. Vì vậy mà chúng ta có thể thiết lập mode chung trên phần global.
Hiện tại, HAProxy hỗ trợ 02 chế độ proxy chính:
tcp: được biết như layer 4. Trong chế độ layer 4, HAProxy đơn giản thực hiện chuyển tiếp traffic 2 chiều giữa 2 bên, mà không kiểm tra nội dung các gói dữ liệu. Nó đưa ra quyết định định tuyến bằng kiểm tra vài gói tin đầu tiên trong TCP.
http: được biết như layer 7.

- `option dontlognull`: Hủy bỏ log mà kết nối là null

`option forwardfor [ except <network> ] [ header <name> ] [ if-none ]` : Chèn header X-Forwarded-For cho các request tới servers. có thể được sử dụng trong phần cả 4 phần.

- `option  tcplog`: mặc định log xuất chỉ có thông tin đơn giản gồm địa chỉ source và destination. tùy chọn “option tcplog” cho phép xuất log trong kết nối TCP với nhiều thông tin bổ sung hơn như về status, time, … Nó có thể được áp dụng ở cả 04 phần.

- `option httplog`: Nó cũng giống như tùy chọn “option tcplog”, tuy nhiên “option httplog” được sử dụng xuất log trong các request http.

- `option redispatch`: Được sử dụng để phân phối session tiếp theo cho client trên server khi server trước bị lỗi. Khi server tiếp theo vẫn lỗi, nó có thể phân phối đến server tiếp theo nữa khi, phụ thuộc vào tùy chọn “retry” có giá trị là nonzero.

- stats: Dùng khai báo thống kê hoạt động của HAProxy. Ở trên chúng ta có nói qua về tùy chọn “stats socket” mà khai báo địa chỉ cho phần xuất thống kê. Chúng ta sẽ nói thêm về một số tùy chọn trong “stats”

- stats admin { if | unless } <cond> Sử dụng cấp độ admin trong thống kê if/unless gặp điều kiện đúng. Để đảm bảo được an toàn, thì mặc định trang thống kê ở chế độ read only. Nó có thể được áp dụng ở phần frontend, backend và listen.

- `stats auth <user>:<passwd>` Thiết lập chứng thực khi truy cập trang thống kê với thông tin tài khoản user/password được gán.

- `stats enable` Thiết lập báo cáo thông kê với các cài đặt mặc định.

- `stats hide-version` :dùng để dấu version HAProxy khi thống kê. Hạn chế được việc khai thác HAProxy khi có lỗ hổng ở version đang sử dụng.

- `stats realm <realm>` dùng thiết lập chứng thực realm cho xem thống kê. <realm> là tên được sử dụng cho chứng thực cơ bản HTTP. Trình duyệt sử dụng tên đó để hiện thị pop-up khi người dùng chứng thực. Nó sử dụng từ đơn, vì vậy  nếu có khoảng trắng trong tên <realm> thì dùng backslash (\)

- `stats refresh <delay>` Thời gian tự động refesh trang thống kê HAProxy

- `stats uri <prefix>` thêm URI (đường dẫn ảo) khi truy cập phần thống kê. Trong URI này có thể chứa dấu hỏi (?) để cho phép chỉ phần string cần truy vấn. 
Các tùy chọn ở “stats” để thống kê có thể được áp dụng ở cả 4 phần: defaults, frontend, backend và listen (Trừ tùy chọn “stats admin” ở trên)
Ví dụ về thiết lập thống kê:

        listen statistics
            bind *:1986
            mode http
            stats enable
            stats hide-version
            stats realm Haproxy\ Statistics
            stats uri /status
            stats refresh 30s
            stats auth keepwalking86:ILoveVietnam$

Khi đó chúng ta truy cập http://ip-address-haproxy:1986/status với thông tin chứng thực keepwalking86/IloveVietnam$

- `timeout` dùng để thiết lập khoảng thời gian sẽ kết thúc tương tác giữa client, haproxy server và backend servers. Một số tùy chọn với “timeout”

- `timeout check <time>` thiết lập kiểm tra timeout, sau khi một kết nối đã được thiết lập. Có thể được sử dụng trong phần defaults, backend, listen. Nếu timeout check không được thiết lập, khi đó HAProxy sẽ sử dụng giá trị “inter” trong tùy chọn khai báo server ở backend.

- `timeout client <time>`  thiết lập khoảng thời gian tối đa mà nhận HTTP request header từ client. Thường được sử dụng để giới hạn client khi mà tốc độ truy cập ở phía client là quá chậm. 

- `timeout connect <time>` thiết lập thời gian tối đa để chờ thiết lập kết nối server. Các server ở đây là phần backend. Khoảng thời gian connect giữa HAProxy và các backend servers phải đảm bảo đủ nhanh cho hệ thống hoạt động tốt.

- `timeout http-keep-alive <time>` thiết lập khoảng thời gian tối đa cho một yêu cầu HTTP mới 

- `timeout http-request <time>` thiết lập khoảng thời gian tối đa mà một request HTTP hoàn thành (Note: một page gồm nhiều request. Có thể sử dụng phím F12 trong browser để kiểm tra số request trong một trang). Lựa chọn thiết lập một giá trị thời gian phù hợp, thường là 2-3s để client nhận được packet, cũng như đảm bảo client không giữ request quá lâu làm server không chấp nhận được các request mới. (Tôi kiểm tra các site như thegioididong.com thì chưa thấy request quá 3s)

- `timeout queue <time>` Khi số kết nối đồng thời đến server đạt giá trị maxconn, khi đó nếu có yêu cầu mới đến server nó sẽ tạm được đưa vào queue. Khoảng thời gian queue tối đa này sẽ được thiết lập trong tùy chọn “timeout queue <timeout>”

- `timeout server <time>` thiết lập thời gian tối đa mà để nhận HTTP response header từ server. 
Thường các tùy chọn ở “timeout” được đặt trong phần default, với các giá trị được thiết lập mặc định cho toàn bộ cấu hình.

Ví dụ về các tùy chọn cho “timeout”

        defaults
            mode http
            log global
            option httplog
            option dontlognull
            option http-server-close
            option forwardfor except 127.0.0.0/8
            option redispatch
            retries 3
            timeout http-request 10s
            timeout queue 1m
            timeout connect 10s
            timeout client 1m
            timeout server 1m
            timeout http-keep-alive 10s
            timeout check 10s
            maxconn 3000

`server <name> <address>[:port] [settings …]` các thiết lập trong tùy chọn này được sử dụng để khai báo địa chỉ và các thiết lập của node backend.

Một số tùy chọn thiết lập trong server:
`check inter <time> rise <number> fall <number>` sử dụng để health check trên server, đảm bảo kết nối TCP từ HAProxy đến các server backend luôn có sẵn.
Thông tin kiểm tra dựa vào các tùy chọn `<name> <address>[:port]` ở khai báo server. Các thông số cho việc kiểm tra là được chỉ định ở `inter`, `rise` và `fall`.
Nếu tùy chọn “check” không có các tham số đi kèm như “inter, rise, fall” thì giá trị mặc định của inter, rise, fall trong mỗi node backend lần lượt là `2s,2,3`. Tham số “inter” định nghĩa khoảng thời gian giữa hai lần check liên tiếp. Tham số “rise” định nghĩa số lần một server backend được check thành công trước khi proxy xem server backend đó hoạt động và thực hiện request. Tham số fall định nghĩa số lần một server backend được check không thành công trước khi proxy xem backend đó ngừng hoạt động để không forward request vào backend đó nữa.

### <a name="example_proxy">2.3 Ví dụ về phần proxy</a>

        frontend https-in
            bind 0.0.0.0:80
            bind 0.0.0.0:443 ssl no-sslv3 crt /etc/cert/vnsys.pem crt
            mode http
            #redirect
            redirect scheme https if { hdr(Host) -i vnsys.wordpress.com } !{ ssl_fc }
            #:::ACL:::Define ACL for each Subdomain to terminate
            acl vnsys-acl hdr(host) -i  vnsys.wordpress.com
            acl api-acl hdr(host) -i api.vnsys.wordpress.com
            acl service-acl    path_beg  /service
            #:::BACKEND:::Use Backend Section
            use_backend vnsys-backend if vnsys-acl
            use_backend api-backend if api-acl
            default_backend web-backend

        backend web-backend
            balance  roundrobin
            option httplog
            option forwardfor
            server web1 172.16.1.7:8083 check inter 6000 rise 3 fall 3
            server web2 172.16.1.8:8083 check inter 6000 rise 3 fall 3
            http-request set-header X-Forwarded-Port %[dst_port]
            http-request add-header X-Forwarded-Proto https if { ssl_fc }

        backend service-backend
            balance  roundrobin
            option httplog
            option forwardfor
            server service1 172.16.1.7:8443 ssl check
            server service2 172.16.1.8:8443 ssl check
            http-request set-header X-Forwarded-Port %[dst_port]
            http-request add-header X-Forwarded-Proto https if { ssl_fc }

        backend www-backend
            balance  roundrobin
            option httplog
            option forwardfor
            server web1 172.16.1.7:8083 check inter 6000 rise 3 fall 3
            server web2 172.16.1.8:8083 check inter 6000 rise 3 fall 3
            http-request set-header X-Forwarded-Port %[dst_port]
            http-request add-header X-Forwarded-Proto https if { ssl_fc }

        backend api-backend
            balance  roundrobin
            option httplog
            option forwardfor
            server service1 172.16.1.7:8443 ssl check
            server service2 172.16.1.8:8443 ssl check
            http-request set-header X-Forwarded-Port %[dst_port]
            http-request add-header X-Forwarded-Proto https if { ssl_fc }
