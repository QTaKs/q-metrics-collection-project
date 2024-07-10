#!/bin/sh

export $(grep -v '^#' config.conf | xargs -d '\n')

#Lazy to use yml parser, so fill those arrays manually if you add/change something in yml
#Add path to directory here in format:
#["service_name"]= "elements separated by whitespace"
#Directory tree in DATA_PATH would be like this:
#{DATA_PATH}/{service_name}/path/to/directory/or/file
declare -A DATA_DIRS=(
    ["grafana"]="/var/lib/grafana /etc/grafana /var/lib/grafana /usr/share/grafana /var/log/grafana"
    ["prometheus"]="/etc/prometheus /prometheus"
    ["nginx"]="/usr/share/nginx/html /etc/nginx"
    ["postgres"]="/var/lib/postgresql/data"
)
#["service_name"]= "source of docker image from {image} section in docker-compose"
declare -A DOCKER_IMAGES=(
    ["grafana"]="grafana/grafana-enterprise"
    ["prometheus"]="prom/prometheus"
    ["nginx"]="nginx"
    ["postgres"]="postgres"
    ["nginx-exporter"]="nginx/nginx-prometheus-exporter"
    ["postgres-exporter"]="quay.io/prometheuscommunity/postgres-exporter"
)


#Functions

env_create(){
    echo "Creating .env file"
    cat << 'EOF' > $(dirname "$0")/.env
#GENERAL

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

#Postgres
PGSQL_DB_NAME=serverDB
PGSQL_USER=default
PGSQL_PASSWORD=root
PGSQL_PORT=5432

#Postgres-exporter
PGSQL_EXPORTER_PORT=9187
EOF
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
    DATA_PATH=$(echo "$DATA_PATH" | sed 's:/*$::')
    case ${DATA_PATH} in
        /*)   echo "Detected absolute path for data directory"; ;;
        *)    echo "Detected relative path for data directory. Highly recommended to make it absolute.";
              DATA_PATH=$( echo ${DATA_PATH} | sed -e "s/^\.\///g" );
              DATA_PATH=$(dirname "$0")/${DATA_PATH};
              echo $DATA_PATH | cut -d '/' -f 2 >> .gitignore; ;;
    esac
}
data_make_dirs(){
    echo "Making dirs for state data"
    for SERVICE_NAME in ${!DATA_DIRS[@]}; do
        for BINDING_DIRECTORY in ${DATA_DIRS[${SERVICE_NAME}]}; do
            echo "Creating ${DATA_PATH}/${SERVICE_NAME}$(dirname ${BINDING_DIRECTORY})"
            mkdir -p ${DATA_PATH}/${SERVICE_NAME}$(dirname ${BINDING_DIRECTORY})
        done
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
            - ${DATA_PATH}/grafana/var/lib/grafana:/var/lib/grafana
            - ${DATA_PATH}/grafana/etc/grafana:/etc/grafana
            - ${DATA_PATH}/grafana/var/lib/grafana:/var/lib/grafana
            - ${DATA_PATH}/grafana/usr/share/grafana:/usr/share/grafana
            - ${DATA_PATH}/grafana/var/log/grafana:/var/log/grafana

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
            - ${DATA_PATH}/prometheus/etc/prometheus:/etc/prometheus
            - ${DATA_PATH}/prometheus/prometheus:/prometheus

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
            - ${DATA_PATH}/nginx/usr/share/nginx/html:/usr/share/nginx/html
            - ${DATA_PATH}/nginx/etc/nginx:/etc/nginx
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
        volumes:
            - ${DATA_PATH}/postgres/var/lib/postgresql/data:/var/lib/postgresql/data
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
EOF
}
data_filling_from_images(){
    APPENDIX_NAME=-temporary-image-for-data-copy
    for SERVICE_NAME in ${!DATA_DIRS[@]}; do
        docker create --name ${COMPOSITION_NAME}${APPENDIX_NAME} ${DOCKER_IMAGES[${SERVICE_NAME}]}
        DOCKER_IMAGE_USER=$( docker inspect ${COMPOSITION_NAME}${APPENDIX_NAME} | grep \"User\"\:  | cut -d ':' -f 2 | tr -d \",\ )
        echo "User in container - $DOCKER_IMAGE_USER"
        for BINDING_DIRECTORY in ${DATA_DIRS[${SERVICE_NAME}]}; do
            echo "Copying from image ${BINDING_DIRECTORY}"
            docker cp --archive ${COMPOSITION_NAME}${APPENDIX_NAME}:${BINDING_DIRECTORY} \
                                ${DATA_PATH}/${SERVICE_NAME}$(dirname ${BINDING_DIRECTORY})/
            if [ ! -z "$DOCKER_IMAGE_USER" -a "$DOCKER_IMAGE_USER" != " " ]; then
                echo "DEBUG: chmod 777 ${DATA_PATH}/${SERVICE_NAME}${BINDING_DIRECTORY}"
                chmod 777 ${DATA_PATH}/${SERVICE_NAME}${BINDING_DIRECTORY}
            fi
        done
        docker rm ${COMPOSITION_NAME}${APPENDIX_NAME}
    done
}
filling_configs(){
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
    echo "Creating stub page for Nginx"
    cat << EOF > ${DATA_PATH}/prometheus/etc/prometheus/prometheus.yml
# my global config
global:
  scrape_interval: 15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
    - job_name: "prometheus"
    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.
      static_configs:
        - targets: ["${COMPOSITION_NAME}_prometheus:9090"]
    - job_name: "nginx"
      static_configs:
        - targets: ["${COMPOSITION_NAME}_nginx-exporter:9113"]
    - job_name: "postgres"
      static_configs:
        - targets: ["${COMPOSITION_NAME}_pgsql-exporter:9187"]
EOF

}
env_create
gitignore_create
data_path_parse
data_make_dirs
docker_compose_create
data_filling_from_images
filling_configs
docker-compose up --abort-on-container-failure
