#!/bin/sh

. ./config.conf

#Functions
gitignore_create(){
    . ./Templates/gitignore.sh
}

docker_compose_create(){
    . ./Templates/docker-compose.sh
}

filling_configs(){
    . ./Templates/configs-nginx.sh
    . ./Templates/configs-prometheus.sh
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

gitignore_create
data_path_parse
data_make_dirs
docker_compose_create
data_filling_from_images
filling_configs
docker-compose up --abort-on-container-failure
