#!/bin/sh
set -eux

set -a  # Auto-export for --exec option
[ -e ".local-conf" ] && . ./.local-conf
PROJECT_PATH="${PROJECT_PATH-$(dirname "$(readlink -f "$0")")}"  # The full project path, e.g. /srv/tutor-web
PROJECT_NAME="${PROJECT_NAME-$(basename ${PROJECT_PATH})}"  # The project directory name, e.g. tutor-web
PROJECT_MODE="${PROJECT_MODE-development}"  # The project mode, development or production

SERVER_NAME="${SERVER_NAME-$(hostname --fqdn)}"  # The server_name NGINX responds to
SERVER_ALIASES="${SERVER_ALIASES-}"  # Additional names for NGINX to respond to
SERVER_CERT_PATH="${SERVER_CERT_PATH-}"  # e.g. /etc/nginx/ssl/certs
CORDOVA_APP_ORIGINS="${CORDOVA_APP_ORIGINS-}"  # Space-separated origins the Cordova app may be served from, for cross-domain JWT auth, e.g. "https://ui-tutorweb-app.example.com https://localhost:8100"

# One "<origin>" \$http_origin; line per entry in CORDOVA_APP_ORIGINS, for the CORS map below
CORS_MAP_ENTRIES=""
for origin in ${CORDOVA_APP_ORIGINS}; do
    CORS_MAP_ENTRIES="${CORS_MAP_ENTRIES}    \"${origin}\" \$http_origin;
"
done

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

SSL_CHAIN="/var/lib/dehydrated/certs/${SERVER_NAME}/fullchain.pem"
[ -e "${SSL_CHAIN}" ] || SSL_CHAIN="/etc/ssl/certs/ssl-cert-snakeoil.pem"
SSL_KEY="/var/lib/dehydrated/certs/${SERVER_NAME}/privkey.pem"
[ -e "${SSL_KEY}" ] || SSL_KEY="/etc/ssl/private/ssl-cert-snakeoil.key"
[ -f "/etc/ssl/certs/dhparam.pem" ] || openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

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
[ "$PROJECT_MODE" = "production" ] && systemctl enable ${PROJECT_NAME}-zeo.service


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
[ "$PROJECT_MODE" = "production" ] && systemctl enable ${PROJECT_NAME}-zeopack.timer
[ "$PROJECT_MODE" = "production" ] && systemctl start ${PROJECT_NAME}-zeopack.timer

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
[ "$PROJECT_MODE" = "production" ] && systemctl enable ${PROJECT_NAME}-backup.timer
[ "$PROJECT_MODE" = "production" ] && systemctl start ${PROJECT_NAME}-backup.timer

cat <<EOF > /etc/systemd/system/${PROJECT_NAME}-instance@.service
[Unit]
Description=${PROJECT_NAME}: Instance %I
PartOf=${PROJECT_NAME}-zeo.service
After=${PROJECT_NAME}-zeo.service

[Service]
Slice=${PROJECT_NAME}.slice
Type=simple
ExecStart=${PROJECT_PATH}/bin/instance%i console
WorkingDirectory=${PROJECT_PATH}/bin
User=${APP_USER}
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=${PROJECT_NAME}-zeo.service
EOF
[ "$PROJECT_MODE" = "production" ] && systemctl enable \
    ${PROJECT_NAME}-instance@1.service \
    ${PROJECT_NAME}-instance@2.service \
    ${PROJECT_NAME}-instance@3.service \
    ${PROJECT_NAME}-instance@4.service

systemctl daemon-reload
systemctl restart ${PROJECT_NAME}.slice

mkdir -p /etc/nginx/sites-available ; cat <<EOF > /etc/nginx/sites-available/${PROJECT_NAME}
# Only ever resolves to one of CORDOVA_APP_ORIGINS (or empty, for no match) -
# never reflects an arbitrary Origin verbatim.
map \$http_origin \$cors_origin {
    default "";
${CORS_MAP_ENTRIES}}

# Throttle password-guessing against the JSON login endpoint - JWTLoginView
# has no lockout of its own. nginx can't see inside the POST body, so this
# is per client IP rather than per account. The key is empty (meaning: not
# rate limited, per limit_req_zone's own docs) for every URI except one
# ending in /@@jwt-login - it's a suffix match, not an exact one, because
# the view is registered for="*" in configure.zcml and so is reachable
# under any traversal path, not just the bare one the app itself calls.
map \$uri \$jwtlogin_limit_key {
    default "";
    "~*/@@jwt-login\$" \$binary_remote_addr;
}
limit_req_zone \$jwtlogin_limit_key zone=${PROJECT_NAME}_jwtlogin:10m rate=5r/m;
limit_req_status 429;

upstream ${PROJECT_NAME} {
  # TODO: nginx doesn't support this yet(need 1.7.2) hash \$remote_addr\$cookie___ac consistent;
  ip_hash;

  server 127.0.0.1:8181;  # Can be marked as "down"
  server 127.0.0.1:8182;
  server 127.0.0.1:8183;
  server 127.0.0.1:8184;
}

server {
    listen 80;
    listen [::]:80;
    listen [::]:443 ssl;
    listen      443 ssl;
    server_name ${SERVER_NAME} ${SERVER_ALIASES};

    ssl_certificate      ${SSL_CHAIN};
    ssl_certificate_key  ${SSL_KEY};
    ssl_trusted_certificate ${SSL_CHAIN};
    ssl_dhparam /etc/ssl/certs/dhparam.pem;

    # https://mozilla.github.io/server-side-tls/ssl-config-generator/
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    # intermediate configuration. tweak to your needs.
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # Add HSTS valid for a week
    add_header Strict-Transport-Security "max-age=604800; includeSubDomains; preload" always;

    location /.well-known/acme-challenge {
        alias /var/lib/dehydrated/acme-challenges;
    }

    if (\$scheme != "https") {
        return 301 https://\$server_name\$request_uri;
    }
    if (\$host != \$server_name) {
        return 301 \$scheme://\$server_name\$request_uri;
    }

    location ~ ^/manage {
      deny all;
    }

    location / {
      # Rate-limit login attempts (\$jwtlogin_limit_key, set above, is
      # empty - i.e. not limited - for every URI except /@@jwt-login).
      # burst=10 nodelay: allow a small burst, then reject outright rather
      # than queueing/delaying requests past it.
      limit_req zone=${PROJECT_NAME}_jwtlogin burst=10 nodelay;

      # Cross-domain access for the Cordova app, which runs on its own
      # origin(s) (CORDOVA_APP_ORIGINS) and authenticates via JWT bearer
      # token (see tutorweb.quiz's jwt-login view) rather than the __ac
      # session cookie, so every call it makes here is cross-origin and
      # gets a CORS preflight. \$cors_origin (set by the map above) is
      # empty for a non-matching Origin, so this is a no-op for anyone else.
      #
      # NB: add_header does NOT inherit from the server block, we have to re-add headers
      add_header Strict-Transport-Security "max-age=604800; includeSubDomains; preload" always;
      add_header Access-Control-Allow-Origin \$cors_origin always;
      add_header Vary Origin always;
      add_header Access-Control-Allow-Headers "Authorization, Content-Type" always;
      add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
      if (\$request_method = OPTIONS) {
        add_header Strict-Transport-Security "max-age=604800; includeSubDomains; preload" always;
        add_header Access-Control-Allow-Origin \$cors_origin always;
        add_header Vary Origin always;
        add_header Access-Control-Allow-Headers "Authorization, Content-Type" always;
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
        add_header Content-Length 0;
        return 204;
      }

      proxy_pass http://${PROJECT_NAME}/VirtualHostBase/\$scheme/\$host:\$server_port/tutor-web/VirtualHostRoot\$request_uri;
      proxy_cache off;
    }
}
EOF
mkdir -p /etc/nginx/sites-enabled ; ln -frs /etc/nginx/sites-available/${PROJECT_NAME} /etc/nginx/sites-enabled/${PROJECT_NAME}
nginx -t
systemctl restart nginx
