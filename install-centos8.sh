#!/bin/bash

# php version supported
valid_php_values=("53" "54" "55" "56" "70" "71" "72" "73" "74" "80" "81" "82")
# default php version
php_version="81"
ls_user="admin"
ls_pass="password"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -php=*|--php=*)
            php_version="${1#*=}"
            shift
            ;;
        -user=*|--user=*)
            ls_user="${1#*=}"
            shift
            ;;
        -pass=*|--pass=*)
            ls_pass="${1#*=}"
            shift
            ;;
        *)
            echo "The input variable is invalid."
            exit 1
            ;;
    esac
    shift
done

if [[ ! " ${valid_php_values[@]} " =~ " ${php_version} " ]]; then
    echo "The PHP version is not supported. Version supported: ${valid_php_values[@]}"
    exit 1
fi

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
sudo ln -s /usr/local/lsws/lsphp${php_version}/bin/php /usr/bin/php
# Config OpenLiteSpeed
sudo wget -O /usr/local/lsws/conf/templates/www.conf https://raw.githubusercontent.com/huynhnd6/openlitespeed/main/conf/templates/www.conf
sudo wget -O /usr/local/lsws/conf/httpd_config.conf https://raw.githubusercontent.com/huynhnd6/openlitespeed/main/conf/httpd_config.conf
sudo sed -i 's/lsphp81/lsphp${php_version}/g' /usr/local/lsws/conf/httpd_config.conf
# change pass admin
ENCRYPT_PASS=`/usr/local/lsws/admin/fcgi-bin/admin_php -q /usr/local/lsws/admin/misc/htpasswd.php $ls_pass`
echo "$ls_user:$ENCRYPT_PASS" > /usr/local/lsws/admin/conf/htpasswd 

# Khởi động lại OpenLiteSpeed
sudo systemctl restart lsws

# Cập nhật các mirrorlist thành comment
sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*

# Cập nhật baseurl để sử dụng vault.centos.org
sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

# Cài đặt certbot
sudo dnf install certbot -y

# Cài đặt MariaDB
wget -O - https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version="mariadb-10.4"
sudo yum install MariaDB-server MariaDB-backup -y
sudo systemctl restart mariadb
echo -e "\nn\nn\nY\nY\nY\nY\n" | mysql_secure_installation

# Cài đặt WP-CLI
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

# Cấu hình tường lửa
sudo firewall-cmd --add-service={http,https} --permanent
sudo firewall-cmd --add-port={8088/tcp,7080/tcp} --permanent
sudo firewall-cmd --reload

echo "Installation complete!"
