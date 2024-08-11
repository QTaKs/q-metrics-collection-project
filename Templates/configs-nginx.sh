echo "Creating stub page for Nginx"
cat << 'EOF' > ${DATA_PATH}/nginx/etc/nginx/conf.d/stub_status.conf
server {
    listen       8080;
    server_name  stub_stat;

    #access_log  /var/log/nginx/host.access.log  main;
    #error_page  404              /404.html;
    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

    location = /stub_status {
        stub_status;
    }

}
EOF
