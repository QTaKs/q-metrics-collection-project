#!/bin/sh

export $(grep -v '^#' config.conf | xargs -d '\n')

# Should remove this)
# declare -A JOB_LIST=(
#    [aajob1] = "a set of arguments"
#    [bbjob2] = "another different list"
#    ...
# )
# sorted=($(printf '%s\n' "${!JOB_LIST[@]}"| /bin/sort))
# for job in "${sorted[@]}"; do
#    for args in "${job[@]}"; do
#      echo "Do something with ${arg} in ${job}"
#    done
# done

# This works
# declare -A JOB_LIST=(
#    ["aajob1"]="a set of arguments"
#    ["bbjob2"]="another different list"
# )
# for key in ${!JOB_LIST[@]}
# do
#     for args in ${JOB_LIST[${key}]}; do
#         echo "Do something with ${args} in ${key}"
#     done
# done




#Lazy to use yml parser, so fill those arrays manually if you add/change something
#Add path to directory here in format:
#["service_name"]= "elements separated by whitespace"
#Directory tree in DATA_PATH would be like this:
#{DATA_PATH}/{service_name}/path/to/directory/or/file
declare -A DATA_DIRS=(
    ["grafana"]="/var/lib/grafana"
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
              echo $DATA_PATH >> .gitignore; ;;
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
            - --nginx.scrape-uri=http://${COMPOSITION_NAME}nginx:\${NGINX_STUB_STATUS_PORT}/stub_status
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
            DATA_SOURCE_NAME: "postgresql://\${PGSQL_USER}:\${PGSQL_PASSWORD}@${COMPOSITION_NAME}postgres:\${PGSQL_PORT}/postgres?sslmode=disable"
EOF
}

data_filling_from_images(){
#     docker-compose up --abort-on-container-failure
    APPENDIX_NAME=-temporary-image-for-data-copy
    for SERVICE_NAME in ${!DATA_DIRS[@]}; do
        docker create --name ${COMPOSITION_NAME}${APPENDIX_NAME} ${DOCKER_IMAGES[${SERVICE_NAME}]}
        for BINDING_DIRECTORY in ${DATA_DIRS[${SERVICE_NAME}]}; do
            echo "Copying from image ${BINDING_DIRECTORY}"
            docker cp -a ${COMPOSITION_NAME}${APPENDIX_NAME}:${BINDING_DIRECTORY} \
                         ${DATA_PATH}/${SERVICE_NAME}$(dirname ${BINDING_DIRECTORY})/
        done
        docker rm ${COMPOSITION_NAME}${APPENDIX_NAME}
    done
#WIP
#For each
# Add in data array (DATA_DIRS) name of image. Iterate through it
# Get folders from docker-compose file and name of images

# cat ./docker-compose.yml | grep image | cut -d ':' -f 2
# docker create --name ${COMPOSITION_NAME}${APPENDIX_NAME} some-image
# docker cp -a ${COMPOSITION_NAME}${APPENDIX_NAME}:/some/dir/file.tmp file.tmp
# docker rm ${COMPOSITION_NAME}${APPENDIX_NAME}
}

env_create
gitignore_create
data_path_parse
data_make_dirs
docker_compose_create
data_filling_from_images
