## Install
- Centos 8
```bash
wget -O - https://raw.githubusercontent.com/huynhnd6/openlitespeed/main/install-centos8.sh | sudo bash -s -- --pass="password"
```
- Create site
```bash
wget -O - https://github.com/huynhnd6/openlitespeed/raw/main/create-site.sh | sudo bash -s -- --site="example.com" --dbpass="password" --wppass="password"
```
