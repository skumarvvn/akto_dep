MICROSERVICE_NAME="csoc-api-akto"

project_custom() {

    # When deploying local to user-sandbox, use docker-ci-dev artifactory instead of docker-dev
    if [[ -f $tag_file ]]; then
        if [[ $IMAGE_TAG == $(cat $tag_file) ]]; then
            append_to_set_string "global.imageRegistry=docker-ci-dev.artifactory.globalrelay.net/com/globalrelay/project-pod"
        fi
    fi
}