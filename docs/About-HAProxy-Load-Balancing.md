Trong phần này, chúng ta sẽ giới thiệu về một số thuật toán cân bằng tải phổ biến trong HAProxy, và cách thức cố định session với sticky session

## 1. Các thuật toán cân bằng tải

HAProxy hỗ trợ các thuật toán sau: roundrobin, static-rr, leastconn, first, source, uri, url_parm, hdr, rdp-cookie. Ở đây, chúng ta sẽ giới thiệu một số thuật toán thường được sử dụng.

### 1.1 Roundrobin

Là thuật toán luân chuẩn theo vòng. Các server sẽ được sử dụng lần lượt theo vòng, phụ thuộc vào giá trị trọng số của nó. roundrobin là thuật toán được sử dụng mặc định load balancing khi không có thuật toán nào được chỉ định.

        backend web-backend
            option httplog
            option forwardfor
            server web1 192.168.1.110:8080 check
            server web2 192.168.1.111:8080 check
            server web3 192.168.1.112:8080 check

Dựa vào khả năng xử lý của từng server, chúng ta sẽ thay đổi giá trị trọng số của từng server để phân phối tải đến các server khác nhau. Sử dụng tham số “weight” để thay đổi trọng số. Tỷ lệ tải của các server sẽ tỷ lệ thuận trọng số của chúng so với tổng trọng số của tất cả server. Vì vậy mà server nào có trọng số càng cao, thì yêu cầu tải lên nó cũng sẽ cao. Ví dụ cân bằng tải khi thiết lập weight

        backend web-backend
            balance  roundrobin
            option httplog
            option forwardfor
            server web1 192.168.1.110:8080 check weight 2
            server web2 192.168.1.111:8080 check weight 2
            server web3 192.168.1.112:8080 check weight 1

Khi đó mỗi 05 request, 2 request đầu tiên sẽ được chuyển tiếp lần lượt đến server web1 và web2, 3 request sau sẽ thực hiện chuyển tiếp lần lượt đến server web1, web2 và web3.

Mặc định weight có giá trị là 1, giá trị tối đa của weight là 256. Nếu server giá trị weight là 0, khi đó nó sẽ không tham gia vào cụm server trong load balancing.

### 1.2 leastconn

Đây là thuật toán dựa trên tính toán số lượng kết nối để thực hiện cân bằng tải cho server, nó sẽ tự động lựa chọn server với số lượng kết nối đang hoạt động là nhỏ nhất, để lượng connection giữa các server là tương đương nhau.

Thuật toán này khắc phục được tình trạng một số server có lượng connection rất lớn (do duy trì trạng thái connection), trong khi một số server khác thì lượng tải hay connection thấp.

        backend web-backend
            leastconn
            option httplog
            option forwardfor
            server web1 192.168.1.110:8080 check
            server web2 192.168.1.111:8080 check
            server web3 192.168.1.112:8080 check

Thuật toán này hoạt động tốt khi mà hiệu suất và khả năng tải của các server là tương đương nhau.

## 2. Sticky session

Trong môi trường web, nhiều khi chúng ta cần cố định session của user, như để duy trì trạng thái login. Khi đó, chúng ta cần cố định session trên một server. HAProxy hỗ trợ một số thuật toán Load Balancing duy trì trạng thái kết nối mà cho phép cố định session như hdr, rdp-cookie, source, uri hoặc url_param. Chẳng hạn như:

        backend cms
            balance source
            hash-type consistent
            server web1 192.168.10.110:8080 check
            server web2 192.168.10.111:8080 check
            server web3 192.168.10.112:8080 check

Nếu chúng ta muốn cố định session mà vẫn sử dụng các thuật toán load balancing như: roundrobin, leastconn, hoặc static-rr, khi đó chúng ta sử dụng “Sticky Session”.
Sticky session cho phép cố định session của users mà sử dụng cookie, và HAProxy sẽ điều phối để luôn request từ một user đến cùng một server.

Để sử dụng sticky session trong HAProxy, chúng ta thêm tùy chọn `cookie cookie_name insert/prefix` vào trong phần backend.

### 2.1 Session cookie được thiết lập bởi HAProxy

Khi đó sử dụng `cookie cookie_name insert <options>`. "cookie_name" là giá trị mà HAProxy sẽ chèn vào (insert). Khi client quay lại (tức là cũng là client này và request tiếp theo), HAProxy sẽ biết được server nào để chọn cho client này. Ví dụ:

        cookie  WEB insert
        server web1 192.168.1.110:8080 cookie web1 check
        server web2 192.168.1.111:8080 cookie web2 check
        server web3 192.168.1.112:8080 cookie web3 check

Chúng ta check thử xem HAProxy sẽ response giá trị cookie như thế nào khi sử dụng insert
<img src="../images/session-cookie-setup-by-haproxy.jpg" />

Khi đó chúng ta thấy giá trị cookie mà HAProxy phản hồi cho client là `WEB=web1`

### 2.2 Sử dụng session cookie của ứng dụng

Khi đó sử dụng `cookie SESSION_ID prefix <option>`. “SESSION_ID” là tên cookie của application như PHPSESSID, JSESSID, laravel_session, … Khi đó, HAProxy sẽ sử dụng session id cookie mà được tạo bởi application để duy trì kết nối giữa một client và một server backend. Cách thức hoạt động, đó là HAProxy sẽ mở rộng cookie với một SESSION ID cookie hoặc cookie đang tồn tại, mà có đặt trước nó là giá trị cookie của server và dấu ~.

        cookie laravel_session prefix
        server web1 192.168.1.110:8080 cookie web1 check
        server web2 192.168.1.111:8080 cookie web2 check
        server web2 192.168.1.112:8080 cookie web3 check

Chúng ta check thử xem header của haproxy server và response của nó. Sử dụng: `curl -I http://haproxy-ip-address:80/`

<img src="../images/session-cookie-setup-by-app.jpg" />

Khi đó chúng ta thấy HAProxy server phản hồi với header như hình, với giá trị cookie được thay đổi là: `laravel_session=web1~eyJpdiI6InJuOUN…1Lc0E9PSIsInZhbH` với giá trị prefix là web1~ trước giá trị cookie của application mà HAProxy đã thêm vào.

Hạn chế của sticky session: với sticky session, việc các request từ một user sẽ chỉ cố định vào một server. Vì vậy mà sẽ không đảm bảo được tính điều phối nhiều request từ một users đến nhiều server. Để khắc phục điểm hạn chế này, thì hiện nay có một số phần mềm như redis, memcached, … cho phép lưu session của user, còn việc điều phối các request của user thì vẫn thực hiện bình thường đến các server.

Tham khảo thêm các bài viết về HAProxy tại: [Haproxy Blog](https://www.haproxy.com/blog/)
