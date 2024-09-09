echo "Creating docker-compose.yml"
cat << EOF > $(dirname "$0")/docker-compose.yml
name: "${COMPOSITION_NAME}"
networks:
  ${COMPOSITION_NAME}-network:
    driver: bridge
services:
    grafana:
        image: grafana/grafana-enterprise
        container_name: "${COMPOSITION_NAME}_grafana"
        restart: unless-stopped
        tty: true
        ports:
            - "\${GRAFANA_PORT}:3000"
        networks:
            - ${COMPOSITION_NAME}-network

    prometheus:
        image: prom/prometheus
        container_name: "${COMPOSITION_NAME}_prometheus"
        restart: unless-stopped
        tty: true
        ports:
            - "\${PROMETHEUS_PORT}:9090"
        networks:
            - ${COMPOSITION_NAME}-network

    nginx:
        image: nginx
        container_name: "${COMPOSITION_NAME}_nginx"
        restart: unless-stopped
        tty: true
        ports:
            - "\${NGINX_HTTP_PORT}:80"
            - "\${NGINX_HTTPS_PORT}:443"
            - "\${NGINX_STUB_STATUS_PORT}:8080"
        networks:
            - ${COMPOSITION_NAME}-network

    nginx-exporter:
        image: nginx/nginx-prometheus-exporter
        container_name: "${COMPOSITION_NAME}_nginx-exporter"
        restart: unless-stopped
        tty: true
        ports:
            - "\${NGINX_EXPORTER_PORT}:9113"
        command:
            - --nginx.scrape-uri=http://${COMPOSITION_NAME}_nginx:\${NGINX_STUB_STATUS_PORT}/stub_status
        networks:
            - ${COMPOSITION_NAME}-network

    postgres:
        image: postgres
        restart: unless-stopped
        container_name: "${COMPOSITION_NAME}_postgres"
        tty: true
        ports:
            - "\${PGSQL_PORT}:5432"
        networks:
            - ${COMPOSITION_NAME}-network
        environment:
            POSTGRES_USER: "\${PGSQL_USER}"
            POSTGRES_PASSWORD: "\${PGSQL_PASSWORD}"
            POSTGRES_DB: "\${PGSQL_DB_NAME}"
            PGDATA: "/var/lib/postgresql/data/pgdata"

    postgres-exporter:
        image: quay.io/prometheuscommunity/postgres-exporter
        restart: unless-stopped
        container_name: "${COMPOSITION_NAME}_postgres-exporter"
        tty: true
        ports:
            - "\${PGSQL_EXPORTER_PORT}:9187"
        networks:
            - ${COMPOSITION_NAME}-network
        environment:
            DATA_SOURCE_NAME: "postgresql://\${PGSQL_USER}:\${PGSQL_PASSWORD}@${COMPOSITION_NAME}_postgres:\${PGSQL_PORT}/postgres?sslmode=disable"
    aspnet-image:
        image: ${COMPOSITION_NAME}-aspnet-app
        restart: unless-stopped
        container_name: "${COMPOSITION_NAME}_aspnet-app"
        tty: true
        hostname: aspnet.image
        ports:
            - "\${ASPNET_PORT}:9000"
        networks:
            - ${COMPOSITION_NAME}-network
        environment:
            ASPNETCORE_URLS: "http://+:9000"
EOF
