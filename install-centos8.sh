#!/bin/bash

# Hỏi người dùng chọn phiên bản PHP
echo "Vui lòng chọn phiên bản PHP (ví dụ: 80 cho PHP 8.0, 81 cho PHP 8.1):"
read php_version

# Kiểm tra xem người dùng có nhập giá trị không
if [ -z "$php_version" ]; then
    echo "Bạn chưa nhập phiên bản PHP. Kết thúc script."
    exit 1
fi

# Hỏi người dùng nhập tổng RAM của máy chủ (MB)
echo "Vui lòng nhập tổng RAM của máy chủ (MB):"
read total_ram

# Kiểm tra xem người dùng có nhập giá trị không
if [ -z "$total_ram" ]; then
    echo "Bạn chưa nhập tổng RAM của máy chủ. Kết thúc script."
    exit 1
fi

# Yêu cầu người dùng nhập username và password cho LiteSpeed
echo "Nhập username cho quản trị viên của LiteSpeed:"
read ls_username
echo "Nhập password cho quản trị viên của LiteSpeed:"
read -s ls_password

# Kiểm tra xem người dùng có nhập giá trị không
if [ -z "$ls_username" ]; then
    echo "Bạn chưa nhập username cho LiteSpeed. Kết thúc script."
    exit 1
fi
if [ -z "$ls_password" ]; then
    echo "Bạn chưa nhập ls_password cho LiteSpeed. Kết thúc script."
    exit 1
fi


# Tính toán memory_limit bằng 70% của tổng RAM
memory_limit=$(echo "$total_ram * 0.7" | bc)
memory_limit="${memory_limit%.*}M" # Định dạng thành số nguyên và thêm "M"

# Cập nhật các mirrorlist thành comment
sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*

# Cập nhật baseurl để sử dụng vault.centos.org
sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

# Cài đặt các gói cần thiết
sudo yum install -y wget curl zip

# Thêm kho litespeed và cài đặt OpenLiteSpeed và phiên bản PHP đã chọn
sudo rpm -Uvh http://rpms.litespeedtech.com/centos/litespeed-repo-1.3-1.el8.noarch.rpm
sudo dnf install epel-release -y
sudo dnf update -y
sudo dnf install openlitespeed "lsphp${php_version}" -y
sudo yum -y install "lsphp${php_version}-common" "lsphp${php_version}-curl" "lsphp${php_version}-imap" "lsphp${php_version}-json" "lsphp${php_version}-mysqlnd" "lsphp${php_version}-opcache" "lsphp${php_version}-imagick" "lsphp${php_version}-memcached" "lsphp${php_version}-redis" "lsphp${php_version}-mbstring" "lsphp${php_version}-soap" "lsphp${php_version}-xml" "lsphp${php_version}-intl"

# Cấu hình tệp php.ini
cat <<EOT >> /usr/local/lsws/lsphp${php_version}/etc/php.ini
upload_max_filesize = 32M
post_max_size = 32M
memory_limit = ${memory_limit}
max_execution_time = 300
max_input_vars = 10000
max_input_time = 300
EOT

# Thực hiện cấu hình mật khẩu quản trị viên của LiteSpeed
echo "${ls_username}:${ls_password}" | sudo /usr/local/lsws/admin/misc/admpass.sh

# Khởi động lại OpenLiteSpeed
sudo systemctl restart lsws

# Cài đặt certbot
sudo dnf install certbot -y

# Cài đặt MariaDB
wget https://r.mariadb.com/downloads/mariadb_repo_setup
echo "26e5bf36846003c4fe455713777a4e4a613da0df3b7f74b6dad1cb901f324a84 mariadb_repo_setup" | sha256sum -c -
chmod +x mariadb_repo_setup
sudo ./mariadb_repo_setup --mariadb-server-version="mariadb-10.4"
sudo yum install MariaDB-server MariaDB-backup -y
sudo systemctl restart mariadb

# Cài đặt WP-CLI
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

# Cấu hình tường lửa
sudo firewall-cmd --add-service={http,https} --permanent
sudo firewall-cmd --add-port={8088/tcp,7080/tcp} --permanent
sudo firewall-cmd --reload

echo "Cấu hình hoàn tất với PHP ${php_version}, certbot, MariaDB, WP-CLI và mật khẩu quản trị viên của LiteSpeed đã được thay đổi."
