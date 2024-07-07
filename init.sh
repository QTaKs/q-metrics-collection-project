#!/bin/sh

#Props
COMPOSITION_NAME=qmcp

#Add path to directory here
#If mount directory is "${DATA_PATH}/postgres/var/lib/postgresql/data"
#Insert "/postgres/var/lib/postgresql" so docker can handle own and mod rights
DATA_DIRS=(
"/postgres/var/lib/postgresql"
"/nginx/usr/share/nginx"
"/nginx/etc"
"/prometheus/etc"
"/prometheus"
"/grafana/var/lib"
)


#Functions

env_create(){
  echo "Creating .env file"
  cat << 'EOF' > $(dirname "$0")/.env
#GENERAL
DATA_PATH=./data

#Grafana
GRAFANA_PORT=3000

#Prometheus
PROMETHEUS_PORT=9090

#Nginx
NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443
NGINX_STUB_STATUS_PORT=8080

#Nginx-exporter
NGINX_EXPORTER_PORT=9113

#PgSQL
PGSQL_DB_NAME=serverDB
PGSQL_USER=default
PGSQL_PASSWORD=root
PGSQL_PORT=5432

#PgSQL-exporter
PGSQL_EXPORTER_PORT=9187
EOF
}
env_read(){
  echo "Reading .env file"
  export $(grep -v '^#' .env | xargs -d '\n')
}
gitignore_create(){
  echo "Creating .gitignore"
  cat << 'EOF' > $(dirname "$0")/.gitignore
.gitignore
.env
docker-compose.yml
EOF
}
data_path_parse(){
  case ${DATA_PATH} in
    /*)   echo "Detected absolute path for data directory" ;;
    *)    echo "Detected relative path for data directory. Hightly recomennded to make it absolute.";
          DATA_PATH=$( echo ${DATA_PATH} | sed -e "s/^\.\///g" );
          DATA_PATH=$(dirname "$0")/${DATA_PATH};
          echo $DATA_PATH >> .gitignore;
          ;;
  esac
}
data_make_dirs(){
  echo "Making dirs for state data"
  for t in ${DATA_DIRS[@]}; do
      mkdir -p ${DATA_PATH}${t}
  done
}
docker_compose_create(){
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
        volumes:
            - \${DATA_PATH}/grafana/var/lib/grafana:/var/lib/grafana

    prometheus:
        image: prom/prometheus
        container_name: "${COMPOSITION_NAME}_prometheus"
        restart: unless-stopped
        tty: true
        ports:
            - "\${PROMETHEUS_PORT}:9090"
        networks:
            - ${COMPOSITION_NAME}-network
        volumes:
            - \${DATA_PATH}/prometheus/etc/prometheus:/etc/prometheus
            - \${DATA_PATH}/prometheus/prometheus:/prometheus

    nginx:
        image: nginx
        container_name: "${COMPOSITION_NAME}_nginx"
        restart: unless-stopped
        tty: true
        ports:
            - "\${NGINX_HTTP_PORT}:80"
            - "\${NGINX_HTTPS_PORT}:443"
            - "\${NGINX_STUB_STATUS_PORT}:8080"
        volumes:
            - \${DATA_PATH}/nginx/usr/share/nginx/html:/usr/share/nginx/html
            - \${DATA_PATH}/nginx/etc/nginx:/etc/nginx
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
            - --nginx.scrape-uri=http://${COMPOSITION_NAME}nginx:\${NGINX_STUB_STATUS_PORT}/stub_status
        networks:
            - ${COMPOSITION_NAME}-network

    pgsql:
        image: postgres
        restart: unless-stopped
        container_name: "${COMPOSITION_NAME}_pgsql"
        tty: true
        ports:
            - "\${PGSQL_PORT}:5432"
        networks:
            - ${COMPOSITION_NAME}-network
        volumes:
            - \${DATA_PATH}/postgres/var/lib/postgresql/data:/var/lib/postgresql/data
        environment:
            POSTGRES_USER: "\${PGSQL_USER}"
            POSTGRES_PASSWORD: "\${PGSQL_PASSWORD}"
            POSTGRES_DB: "\${PGSQL_DB_NAME}"
            PGDATA: "/var/lib/postgresql/data/pgdata"

    pgsql-exporter:
        image: quay.io/prometheuscommunity/postgres-exporter
        restart: unless-stopped
        container_name: "${COMPOSITION_NAME}_pgsql-exporter"
        tty: true
        ports:
            - "\${PGSQL_EXPORTER_PORT}:9187"
        networks:
            - ${COMPOSITION_NAME}-network
        environment:
            DATA_SOURCE_NAME: "postgresql://\${PGSQL_USER}:\${PGSQL_PASSWORD}@${COMPOSITION_NAME}pgsql:\${PGSQL_PORT}/postgres?sslmode=disable"
EOF
}

env_create
env_read
gitignore_create
data_path_parse
data_make_dirs
docker_compose_create
