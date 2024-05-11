#!/usr/bin/env bash
set -o errexit

SCRIPTPATH=$(realpath -s $BASH_SOURCE)
HELM_DIR=$(dirname $SCRIPTPATH)
PROJECT_SCRIPT="$HELM_DIR/.project-helm.sh"
SET_VARS=""

# defaults that can be overridden by passing opts at the commandline
IMAGE_TAG="latest"
ENVIRONMENT="local"
ACTION="dry-run"
DEPLOYMENT_SUFFIX=""
DATACENTER="nvan"
integration_environments=(qa stable integ1 perf3 alpha1 prev1 stg1 prod tmp-mbqa1 tmp-lisnap1)
environments=(dev perf local sandbox-1 sandbox-2 sandbox-3 user-sandbox)
dev_ocp_environments=(dev perf sandbox-1 sandbox-2 sandbox-3 user-sandbox tmp-mbqa1 tmp-lisnap1 qa stable)
actions=(dry-run install uninstall lint template grafana)
if [[ $OSTYPE == "linux-gnu"* ]]; then
    declare -A environments_shorthand
    environments_shorthand=(["s1"]="sandbox-1" ["s2"]="sandbox-2" ["s3"]="sandbox-3" ["usb"]="user-sandbox" ["l"]="local")
    declare -A actions_shorthand
    actions_shorthand=(["i"]="install" ["u"]="uninstall" ["d"]="dry-run" ["l"]="lint" ["t"]="template" ["g"]="grafana")
fi
INTERFACE=false


display_help() {
  echo "
------
This script will deploy resources to OpenShift using helm

Usage:
    $BASH_SOURCE -e [env] -t [image_tag] -a [action] -s [deployment_suffix] -m [true/false] -d [datacenter] -o [arg]=[val] -v [values file] -i

Environments:
    ${environments[@]}"

  if [[ $OSTYPE == "linux-gnu"* ]]; then
    echo "
    Shorthand (Linux only)
    -----------"
    for x in "${!environments_shorthand[@]}"; do echo "    $x - ${environments_shorthand[$x]}"; done;
  fi
  echo "
Integration Environments:
    ${integration_environments[@]}

Image-tag:
    For example 1.0.0-SNAPSHOT-200924.131019-01-319e15796b8

Actions:
    ${actions[@]}"
  if [[ $OSTYPE == "linux-gnu"* ]]; then
    echo "
    Shorthand (Linux only)
    -----------"

    for x in "${!actions_shorthand[@]}"; do echo "    $x - ${actions_shorthand[$x]}"; done;
  fi
  echo "
Deployment Suffix:
    Can be any arbitrary suffix. Must be used if manually deploying to dev or perf (not recommended)

Deploy Mocks
    To override the default mock deployment behaviour set in values files, pass
    '-m true' to deploy mocks or '-m false' to deploy no mocks

Datacenter:
    Choose between TOR, NVAN, CHI and SEA datacenter.

Release:
    Can be an arbitrary release name. Defaults to ${MICROSERVICE_NAME}

Override:
    Can be used to override any value. You can include multiple variables in one comma seperated
    command, or split them into multipe
    e.g.
       -o replicaCount=2,colour=red
       -o imagePullPolicy=Always

Values File:
    Can be used to pass a values file different to the environment being deployed / tested in.
    Only the environment is needed, not the full filename.

Interface:
    When passed (-i) the namespace is opened in chrome
"
}

exit_abnormal() {
    display_help
    exit 1
}

if [[ $# -eq 0 ]]; then
    exit_abnormal
fi

append_to_set_string() {
    if [[ -z $SET_VARS ]]; then
        SET_VARS=$1
    else
        SET_VARS="$SET_VARS,$1"
    fi
}

while getopts e:t:a:s:r:m:h:o:d:v:i opt; do
  case "${opt}" in
    e)
      ENVIRONMENT=${OPTARG}
      ;;
    t)
      IMAGE_TAG=${OPTARG};;
    a)
      ACTION=${OPTARG}
      ;;
    s)
      DEPLOYMENT_SUFFIX=${OPTARG};;
    m)
      if [[ " False false " =~ " ${OPTARG} " ]]; then
          DEPLOY_MOCKS=${OPTARG}
      elif [[ " True true " =~ " ${OPTARG} " ]]; then
          DEPLOY_MOCKS="True"
      fi
      ;;
    d)
      if [[ " TOR tor " =~ " ${OPTARG} " ]]; then
          DATACENTER="tor"
      elif [[ " CHI chi " =~ " ${OPTARG} " ]]; then
          DATACENTER="chi"
      elif [[ " SEA sea " =~ " ${OPTARG} " ]]; then
          DATACENTER="sea"
      fi
      ;;
    r)
      RELEASE=${OPTARG};;
    o)
      append_to_set_string ${OPTARG};;
    v)
      VALUES_FILE_OVERRIDE=${OPTARG};;
    i)
      INTERFACE=true;;
    h)
      exit_abnormal
      ;;
    *)
      exit_abnormal
      ;;

  esac
done

### functions ###
display_options() {
    echo
    echo "Running with the following options:"
    echo
    echo "environment: ${ENVIRONMENT}"
    echo "tag: ${IMAGE_TAG}"
    echo "action: ${ACTION}"
    echo "suffix: ${DEPLOYMENT_SUFFIX}"
    echo "namespace: ${NAMESPACE}"
    echo "datacenter: ${DATACENTER}"
    echo "release: ${RELEASE}"
    echo "deploy mocks: ${DEPLOY_MOCKS}"
    echo "values file: ${VALUES}"
    echo
}

validate_options_for_environment() {
    # Ignore checks for grafana deployments
    # This assumes you have removed any {{ .Values.global.deploymentSuffix }} from the dashboard
    if [[ $ACTION == "grafana" ]]; then
        return
    fi

    if [[ "${integration_environments[*]}" =~ "${ENVIRONMENT}" && "${ENVIRONMENT}" != "perf" && "${DEPLOYMENT_SUFFIX}" != "" ]]; then
        echo "A deploymentSuffix should not be used when deploying to: ${ENVIRONMENT}"
        exit 1
    elif [[ "${integration_environments[*]}" =~ "${ENVIRONMENT}" && "${ENVIRONMENT}" != "perf" && "${DEPLOY_MOCKS}" == "True" ]]; then
        echo "Mocks should not be deployed to: ${ENVIRONMENT}"
        exit 1
    fi

    if [[ ("${ENVIRONMENT}" == "prod" || "${ENVIRONMENT}" == "stg1") ]]; then
        branch=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD)
        if [ $branch == "master" ]; then
            echo "You are trying to deploy to stg1 or production from the master branch. Please checkout the target release branch locally to continue"
            exit 1
        fi
    fi
}

setup_helm_version() {
    cp "${HELM_DIR}/${MICROSERVICE_NAME}/Chart.yaml" "${HELM_DIR}/${MICROSERVICE_NAME}/Chart.yaml-bak"
    if [[ ${IMAGE_TAG} == "latest" ]]; then
        CURRENT_VERSION="$(date +%Y%m%d%H%M%S)-latest"
    else
        CURRENT_VERSION=${IMAGE_TAG}
    fi

    if [[ $OSTYPE == "darwin"* ]]; then
        sed -i '' s/__REPLACEAPPVERSION__/\"${CURRENT_VERSION}\"/g "${HELM_DIR}/${MICROSERVICE_NAME}/Chart.yaml"
    elif [[ $OSTYPE == "linux-gnu"* ]]; then
        sed -i s/__REPLACEAPPVERSION__/\"${CURRENT_VERSION}\"/g "${HELM_DIR}/${MICROSERVICE_NAME}/Chart.yaml"
    fi
}

check_prod() {
    if [[ ${ENVIRONMENT} == "prod" ]]; then
        while true; do
            read -r -e -p "You're trying to deploy to PROD. If you're sure you want to do this, please type 'YES': " RESPONSE
            case $RESPONSE in
                "YES")
                    echo "Continuing with deployment"
                    break;;
                *)
                    true
            esac
        done
    fi
}

check_project_exists() {
    CHECK_ENVIRONMENT=$(oc projects | grep "${NAMESPACE}"  || true)
    if [[ -z "${CHECK_ENVIRONMENT}" ]];  then
        echo "Check you are logged in the correct OCP cluster. If so you need to create the namespace ${NAMESPACE} manually, and ensure you add the secret server onboarding key as a secret, as per the REAME.md"
        exit 1
    else
        oc project "${NAMESPACE}"
    fi
}

set_string() {
    append_to_set_string "imageName=${MICROSERVICE_NAME}"
    append_to_set_string "imageTag=${IMAGE_TAG}"
    append_to_set_string "global.imageTag=${IMAGE_TAG}"
    append_to_set_string "global.environment=${VALUES_FILE_OVERRIDE:-${ENVIRONMENT}}"
    if [[ ! -z ${DEPLOYMENT_SUFFIX} ]]; then
        append_to_set_string "global.deploymentSuffix=${DEPLOYMENT_SUFFIX}"
    fi
    if [ ${DEPLOY_MOCKS} ]; then
        append_to_set_string "tags.mocks=${DEPLOY_MOCKS}"
    fi
}

delete_charts_dir() {
    rm -rf "${HELM_DIR}/${MICROSERVICE_NAME}/charts"
}

cleanup() {
    mv "${HELM_DIR}/${MICROSERVICE_NAME}/Chart.yaml-bak" "${HELM_DIR}/${MICROSERVICE_NAME}/Chart.yaml" 2>/dev/null
}
trap cleanup EXIT

check_valid_environment() {
    if [[ $OSTYPE == "linux-gnu"* ]]; then
        if [[ "${!environments_shorthand[@]}" =~ "${ENVIRONMENT}" ]]; then
            ENVIRONMENT="${environments_shorthand[${ENVIRONMENT}]}"
        fi
    fi
    if [[ ! " ${environments[@]} " =~ " ${ENVIRONMENT} " && ! " ${integration_environments[@]} " =~ " ${ENVIRONMENT} " ]]; then
        echo "ERROR: Environment must be one of: ${environments[@]}"
        echo "#####: OR"
        echo "#####: An integration environment: ${integration_environments[@]}"
        exit_abnormal
    fi
}

check_valid_action() {
    if [[ $OSTYPE == "linux-gnu"* ]]; then
        if [[ "${!actions_shorthand[@]}" =~ "${ACTION}" ]]; then
            ACTION="${actions_shorthand[${ACTION}]}"
        fi
    fi
    if [[ ! " ${actions[@]} " =~ " ${ACTION} " ]]; then
        echo "Action must be one of ${actions[@]}"
        exit_abnormal
    fi
}

set_namespace() {
    if [[ ${ENVIRONMENT} == "user-sandbox" ]]; then
        NAMESPACE="user-$(echo ${USER} | tr '.' '-')-sandbox"
        if [[ -f "${HELM_DIR}/${MICROSERVICE_NAME}/values-user-sandbox.yaml" ]]; then
            VALUES="user-sandbox"
        else
            VALUES="sandbox"
        fi
    elif [[ ${ENVIRONMENT} =~ "sandbox-" ]]; then
        if [[ -f "${HELM_DIR}/${MICROSERVICE_NAME}/values-${ENVIRONMENT}.yaml" ]]; then
            VALUES=${ENVIRONMENT}
        else
            VALUES="sandbox"
        fi
    elif [[ ${ENVIRONMENT} == "tmp-mbqa1" || ${ENVIRONMENT} == "tmp-lisnap1" ]]; then
        NAMESPACE="${ENVIRONMENT}"
    fi

    NAMESPACE="${NAMESPACE:-${MICROSERVICE_NAME}-${ENVIRONMENT}}"
}

check_project_script() {
    if [[ ! -f ${PROJECT_SCRIPT} ]]; then
        echo "Please create the ${PROJECT_SCRIPT} file with your microservice name."
        exit 1
    else
        source ${PROJECT_SCRIPT}
    fi
}

set_values() {
    if [[ ! -z $VALUES_FILE_OVERRIDE ]]; then
        VALUES=$VALUES_FILE_OVERRIDE
    fi

    VALUES="values-${VALUES:-${ENVIRONMENT}}.yaml"
}

set_image_tag(){
    if [ $ACTION == "install" ]; then
        if [[ ${ENVIRONMENT} == "user-sandbox" || ${ENVIRONMENT} =~ "sandbox-" ]]; then
            #### Custom image tag fetching for user sandbox deployments
            if [[ ${IMAGE_TAG} == "latest" || ${IMAGE_TAG} == "local" ]]; then
                tag_file="/tmp/.${MICROSERVICE_NAME}-usbTag.txt"
                if [[ -f $tag_file ]]; then
                    IMAGE_TAG=$(cat $tag_file)
                else
                    echo "ERROR: The image tag file - $tag_file - has not been generated for the sandbox deployment. Aborting."
                    exit
                fi
            fi
        fi
    fi

}

set_release() {
    RELEASE="${RELEASE:-${MICROSERVICE_NAME}${DEPLOYMENT_SUFFIX}}"
}

set_grafana_options() {
  RELEASE="$MICROSERVICE_NAME-grafana"
  MICROSERVICE_NAME="grafana"
  IMAGE_TAG="1.0.0"
}

set_default_suffix() {
    if [[ ("${ENVIRONMENT}" == "dev" || "${ENVIRONMENT}" == "perf") && "${DEPLOYMENT_SUFFIX}" == "" ]]; then
        DEPLOYMENT_SUFFIX="-$(echo $USER | cut -d. -f1 )"
    fi
}


oc_login() {
  if [[ " ${dev_ocp_environments[@]} " =~ " ${ENVIRONMENT} " ]]; then
      oc login --server=https://api.ocp-dev-nvan.dev-globalrelay.net:6443 -u $USER
  else
      oc login --server=https://api.ocp-prod-${DATACENTER}.globalrelay.net:6443 -u $USER
  fi
}

user_interface() {
  if $INTERFACE; then
    if [[ " ${dev_ocp_environments[@]} " =~ " ${ENVIRONMENT} " ]]; then
      ocp_url="https://console-openshift-console.apps.ocp-dev-nvan.dev-globalrelay.net"
    else
      ocp_url="https://console-openshift-console.apps.ocp-prod-${DATACENTER}.globalrelay.net"
    fi

    url="${ocp_url}/k8s/ns/${NAMESPACE}/pods"
    /usr/bin/google-chrome -new-tab -url ${url} --disable-gpu --disable-software-rasterizer &>/dev/null
  fi
}

# Empty func that can be overwritten for project specific tasks in $PROJECT_SCRIPT
project_custom() {
    :
}

# Empty func that can be overwritten for project specific tasks in $PROJECT_SCRIPT
pre_install() {
    :
}

# Helm Commands
lint() {
    helm dependency update "${HELM_DIR}/${MICROSERVICE_NAME}"
    helm lint \
        --debug \
        --set=${SET_VARS} \
        -f "${HELM_DIR}/${MICROSERVICE_NAME}/${VALUES}" \
        "${HELM_DIR}/${MICROSERVICE_NAME}"
}

template() {
    helm template \
         --dependency-update \
         --debug \
         --set=${SET_VARS} \
         -f "${HELM_DIR}/${MICROSERVICE_NAME}/${VALUES}" \
         "${RELEASE}" "${HELM_DIR}/${MICROSERVICE_NAME}"
}

install() {
    helm dependency update "${HELM_DIR}/${MICROSERVICE_NAME}"
    helm upgrade \
         --atomic \
         --wait \
         --wait-for-jobs \
         --timeout 20m \
         --install \
         $1 \
         --namespace="${NAMESPACE}" \
         --set=${SET_VARS} \
         -f "${HELM_DIR}/${MICROSERVICE_NAME}/${VALUES}" \
         "${RELEASE}" "${HELM_DIR}/${MICROSERVICE_NAME}"
}

uninstall() {
    helm uninstall $RELEASE || true
}

####### main ########
check_prod
check_project_script
check_valid_environment
check_valid_action
set_default_suffix
set_namespace
set_values
set_image_tag
set_release

if [[ ${ACTION} == "grafana" ]]; then
    set_grafana_options
fi

validate_options_for_environment
setup_helm_version
display_options

if ! [[ -z $USER ]]; then
  oc_login
fi

check_project_exists
set_string
delete_charts_dir
project_custom

echo "-------------------------------------"
echo "Generated --set: ${SET_VARS}"
echo "-------------------------------------"

user_interface

case "${ACTION}" in
    lint)
        lint;;
    dry-run)
        install "--dry-run --debug";;
    template)
        template;;
    install)
        pre_install
        install;;
    uninstall)
        uninstall;;
    grafana)
        install;;
esac

exit