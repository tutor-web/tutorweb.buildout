#!/bin/sh
set -eux

set -a  # Auto-export for --exec option
[ -e ".local-conf" ] && . ./.local-conf
PROJECT_PATH="${PROJECT_PATH-$(dirname "$(readlink -f "$0")")}"  # The full project path, e.g. /srv/tutor-web
PROJECT_NAME="${PROJECT_NAME-$(basename ${PROJECT_PATH})}"  # The project directory name, e.g. tutor-web
PROJECT_MODE="${PROJECT_MODE-development}"  # The project mode, development or production

SERVER_NAME="${SERVER_NAME-$(hostname --fqdn)}"  # The server_name(s) NGINX responds to
SERVER_CERT_PATH="${SERVER_CERT_PATH-}"  # e.g. /etc/nginx/ssl/certs

if [ "${PROJECT_MODE}" = "production" ]; then
    # Default to tutorweb
    APP_USER="${APP_USER-tutorweb}"
    APP_GROUP="${APP_GROUP-nogroup}"
    adduser --system "${APP_USER}"
else
    # Default to user that checked out code (i.e the developer)
    APP_USER="${APP_USER-$(stat -c '%U' ${PROJECT_PATH}/.git)}"
    APP_GROUP="${APP_GROUP-$(stat -c '%U' ${PROJECT_PATH}/.git)}"
fi
chown -R ${APP_USER}:${APP_GROUP} ./var

cat <<EOF > /etc/systemd/system/${PROJECT_NAME}.slice
[Unit]
Description=${PROJECT_NAME}

[Install]
WantedBy=multi-user.target
EOF
systemctl enable ${PROJECT_NAME}.slice

cat <<EOF > /etc/systemd/system/${PROJECT_NAME}-zeo.service
[Unit]
Description=${PROJECT_NAME}: ZEO server

[Service]
Slice=${PROJECT_NAME}.slice
Type=simple
ExecStart=${PROJECT_PATH}/bin/zeo fg
# Wait for ZEO port to be open
ExecStartPost=/usr/bin/timeout 30 sh -c 'while ! ss -H -t -l -n sport = :8180 | grep -q "^LISTEN.*:8180"; do sleep 1; done'
WorkingDirectory=${PROJECT_PATH}/bin
User=${APP_USER}
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=${PROJECT_NAME}.slice
EOF
systemctl enable ${PROJECT_NAME}-zeo.service


cat <<EOF > /etc/systemd/system/${PROJECT_NAME}-zeopack.service
[Unit]
Description=${PROJECT_NAME}: zeopack
Wants=${PROJECT_NAME}-zeopack.timer
Requires=${PROJECT_NAME}-zeo.service
After=${PROJECT_NAME}-zeo.service

[Service]
Slice=${PROJECT_NAME}.slice
Type=oneshot
ExecStart=${PROJECT_PATH}/bin/zeopack

EOF
cat <<EOF > /etc/systemd/system/${PROJECT_NAME}-zeopack.timer
[Unit]
Description=${PROJECT_NAME}: Run zeopack daily
Requires=${PROJECT_NAME}-zeopack.service
After=${PROJECT_NAME}-zeo.service

[Timer]
Unit=${PROJECT_NAME}-zeopack.service
OnCalendar=*-*-* 01:47:00

[Install]
WantedBy=timers.target
EOF
systemctl enable ${PROJECT_NAME}-zeopack.timer

cat <<EOF > /etc/systemd/system/${PROJECT_NAME}-backup.service
[Unit]
Description=${PROJECT_NAME}: backup

[Service]
Slice=${PROJECT_NAME}.slice
Type=oneshot
ExecStart=${PROJECT_PATH}/bin/backup
EOF
cat <<EOF > /etc/systemd/system/${PROJECT_NAME}-backup.timer
[Unit]
Description=${PROJECT_NAME}: Run backup daily
Requires=${PROJECT_NAME}-backup.service

[Timer]
Unit=${PROJECT_NAME}-backup.service
OnCalendar=*-*-* 02:37:00

[Install]
WantedBy=timers.target
EOF
systemctl enable ${PROJECT_NAME}-backup.timer

cat <<EOF > /etc/systemd/system/${PROJECT_NAME}-instance@.service
[Unit]
Description=${PROJECT_NAME}: Instance %I
PartOf=${PROJECT_NAME}-zeo.service
After=${PROJECT_NAME}-zeo.service

[Service]
Slice=${PROJECT_NAME}.slice
Type=simple
ExecStart=${PROJECT_PATH}/bin/instance%i fg
WorkingDirectory=${PROJECT_PATH}/bin
User=${APP_USER}
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=${PROJECT_NAME}-zeo.service
EOF
systemctl enable \
    ${PROJECT_NAME}-instance@1.service \
    ${PROJECT_NAME}-instance@2.service \
    ${PROJECT_NAME}-instance@3.service \
    ${PROJECT_NAME}-instance@4.service

systemctl daemon-reload
systemctl restart ${PROJECT_NAME}-'*'

mkdir -p /etc/nginx/sites-available ; cat <<EOF > /etc/nginx/sites-available/${PROJECT_NAME}
upstream ${PROJECT_NAME} {
  # TODO: nginx doesn't support this yet(need 1.7.2) hash \$remote_addr\$cookie___ac consistent;
  ip_hash;

  server 127.0.0.1:8181;  # Can be marked as "down"
  server 127.0.0.1:8182;
  server 127.0.0.1:8183;
  server 127.0.0.1:8184;
}

server {
  listen [::]:80;
  listen      80;
  server_name ${SERVER_NAME};

  location ~ ^/manage {
    deny all;
  }

  # Lets-encrypt
  location /.well-known/acme-challenge {
    root /tmp/acme-challenge;
  }

  location / {
    proxy_pass http://${PROJECT_NAME}/VirtualHostBase/\$scheme/\$host:\$server_port/tutor-web/VirtualHostRoot\$request_uri;
    proxy_cache off;
  }
}
EOF
mkdir -p /etc/nginx/sites-enabled ; ln -frs /etc/nginx/sites-available/${PROJECT_NAME} /etc/nginx/sites-enabled/${PROJECT_NAME}
nginx -t
systemctl restart nginx
