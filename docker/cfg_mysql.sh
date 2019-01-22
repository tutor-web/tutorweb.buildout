#!/bin/sh
set -eu
ROOT_PWD=$1
TUTORWEB_PWD=$2

/etc/init.d/mysql start

until /usr/bin/mysqladmin --defaults-file=/etc/mysql/debian.cnf ping; do
    sleep 1
done

cat <<EOF | mysql -uroot -p"${ROOT_PWD}"
CREATE DATABASE tw_quizdb;
CREATE USER 'tw_quizdb'@'localhost' IDENTIFIED BY '${TUTORWEB_PWD}';
GRANT ALL PRIVILEGES ON tw_quizdb. * TO 'tw_quizdb'@'localhost';
EOF

/etc/init.d/mysql stop

# /usr/bin/mysql_install_db

# /usr/bin/mysqladmin --defaults-file=/etc/mysql/debian.cnf ping
# mysql_secure_installation

#cat /etc/mysql/debian.cnf
#cat <<EOF | mysql -u root -p
#GRANT ALL PRIVILEGES ON *.* TO 'debian-sys-maint'@'localhost'
#IDENTIFIED BY 'WsgJtZ8QfUd1oYRa';
#EOF
#echo "SELECT * FROM db;" |mysql -u root -D mysql -p

