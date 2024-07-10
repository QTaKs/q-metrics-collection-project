#!/bin/bash
export $(grep -v '^#' config.conf | xargs -d '\n')

TO_REMOVE_FILES=(
".gitignore"
".env"
"docker-compose.yml"
)

data_path_parse(){
    DATA_PATH=$(echo "$DATA_PATH" | sed 's:/*$::')
    case ${DATA_PATH} in
        /*)   echo "Absolute path for data directory. Delete It your-self."; ;;
        *)    echo "Detected relative path for data directory.";
              DATA_PATH=$( echo ${DATA_PATH} | sed -e "s/^\.\///g" );
              DATA_PATH=$(dirname "$0")/${DATA_PATH};
              TO_REMOVE_FILES+=( ${DATA_PATH} ) ;;
    esac
}

data_path_parse
for TO_REMOVE in ${TO_REMOVE_FILES[@]}; do
    rm -rv ${TO_REMOVE}
done
