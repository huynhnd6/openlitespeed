#!/bin/bash

# Kiểm tra đối số
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 --site=<site_name> --dbpass=<mysql_password> --wppass=<wp_admin_password>"
  exit 1
fi

# Lấy giá trị của site_name, mysql_password và wp_admin_password từ đối số
SITE_NAME=$(echo $1 | sed 's/--site=//')
MYSQL_PASS=$(echo $2 | sed 's/--dbpass=//')
WP_ADMIN_PASS=$(echo $3 | sed 's/--wppass=//')

# Định nghĩa file cấu hình
CONFIG_FILE="/usr/local/lsws/conf/httpd_config.conf"

# Lưu trữ quyền sở hữu ban đầu của file
ORIGINAL_OWNER=$(stat -c %u:%g "$CONFIG_FILE")

# Đọc nội dung file cấu hình vào biến tạm thời
TEMP_FILE=$(mktemp)
awk -v site="$SITE_NAME" '
    /vhTemplate www {/ {
        print
        in_template = 1
        next
    }
    in_template && /}/ {
        print "  member " site " {"
        print "    vhDomain              " site
        print "    vhAliases             www." site
        print "  }"
        in_template = 0
    }
    { print }
' "$CONFIG_FILE" > "$TEMP_FILE"

# Ghi lại nội dung đã chỉnh sửa vào file cấu hình
mv "$TEMP_FILE" "$CONFIG_FILE"

# Khôi phục quyền sở hữu ban đầu của file
chown $ORIGINAL_OWNER "$CONFIG_FILE"

# Tạo cơ sở dữ liệu và người dùng MySQL
DB_NAME=$(echo $SITE_NAME | tr . _)
mysql -e "CREATE DATABASE ${DB_NAME};"
mysql -e "CREATE USER ${DB_NAME}@localhost IDENTIFIED BY '${MYSQL_PASS}';"
mysql -e "GRANT ALL ON ${DB_NAME}.* TO ${DB_NAME}@localhost;"
mysql -e "FLUSH PRIVILEGES;"

# Tạo thư mục và cài đặt WordPress
SITE_DIR="/usr/local/lsws/${SITE_NAME}"
mkdir -p $SITE_DIR
/usr/local/bin/wp core download --path=$SITE_DIR --version="6.5.4"
/usr/local/bin/wp config create --path=$SITE_DIR --dbhost=localhost --dbname=${DB_NAME} --dbuser=${DB_NAME} --dbpass=${MYSQL_PASS} --force --skip-check
/usr/local/bin/wp config set FS_METHOD direct --path=$SITE_DIR
/usr/local/bin/wp core install --path=$SITE_DIR --url=https://${SITE_NAME} --title="${SITE_NAME}" --admin_user=webadmin --admin_password=${WP_ADMIN_PASS} --admin_email=support@${SITE_NAME}

# Thiết lập quyền cho các file và thư mục
find $SITE_DIR -type d -exec chmod 755 {} \;
find $SITE_DIR -type f -exec chmod 644 {} \;
chown -R nobody:nobody $SITE_DIR

sudo systemctl restart lsws

echo "Site $SITE_NAME created."
