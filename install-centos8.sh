#!/bin/bash

# Hỏi người dùng chọn phiên bản PHP
php_version=""
while [ -z "$php_version" ]; do
    echo "Please choose the PHP version (for example: 80 for PHP 8.0, 81 for PHP 8.1):"
    read php_version

    if [ -z "$php_version" ]; then
        echo "You haven't entered the PHP version. Please enter again."
    fi
done

# Yêu cầu người dùng nhập username và password cho LiteSpeed
ls_username="admin"
while [ -z "$ls_username" ]; do
    echo "Enter the username for the LiteSpeed administrator (default is admin):"
    read ls_username

    if [ -z "$ls_username" ]; then
        ls_username="admin"
    fi
done
ls_password=""
while [ -z "$ls_password" ] || [ ${#ls_password} -lt 6 ]; do
    echo "Enter password for the LiteSpeed administrator:"
    read ls_password

    if [ -z "$ls_password" ]; then
        echo "[ERROR] Sorry, password must be at least 6 charactors!"
    elif [ ${#ls_password} -lt 6 ]; then
        echo "[ERROR] Sorry, password must be at least 6 charactors!"
    fi
done

# Lấy tổng RAM của máy chủ (đơn vị KB)
total_ram=$(grep MemTotal /proc/meminfo | awk '{print $2}')
# Tính toán memory_limit bằng 70% của tổng RAM
memory_limit=$((total_ram * 7 / 10))
memory_limit="${memory_limit}K" # Định dạng thành KB

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

echo "Installation complete!"
