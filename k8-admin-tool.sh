#!/bin/bash
###############################################################################
# REQUIRED THINGYS
###############################################################################
set -euo pipefail
IFS=$'\n'
###############################################################################
# COLORS
###############################################################################
gr=$(tput setaf 118) # GREEN GOOD
yl=$(tput setaf 3)   # YELLOW HEADER
rst=$(tput sgr0)     # RESET TO TERMINAL DEFAULT
clear
###############################################################################
#  GENERAL FUNCTIONS
###############################################################################
CLEAR_TERMINAL() {
  clear
  }

INVALID_SELECTION() {
  echo "INVALID SELECTION. PRESS ENTER TO TRY AGAIN: "
  read -r
  }

PRINT_FORMATED_OUTPUT() {
  tail -n +2 | awk '{print "[" NR "]", $1}'
  }
PRINT_BANNER(){
  echo "${yl}"
  echo ""
  echo "${gr}
  █▓▒▒░░░K-ADMIN-TOOL░░░▒▒▓█${yl}"
  echo ""
  paste <(echo "${yl}CURRENT CLUSTER:     ${rst}") <(CURRENT_CONTEXT | tr '@' $'\n' | head -1)
  paste <(echo "${yl}CLUSTERS:            ${rst}") <(NUMBER_OF_CLUSTERS)
  #paste <(echo "${yl}LOAD BALANCER IP:    ${rst}") <(GET_LOAD_BALANCER_IP)
  #paste <(echo "${yl}HEALTHY PODS:        ${rst}") <(HEALTHY_PODS)
  #paste <(echo "${yl}UNHEALTHY PODS:      ${rst}") <(UNHEALTHY_PODS)
  echo ""
  }
###############################################################################
# KUBERNETES COMMANDS AS FUNCTIONS
###############################################################################
GET_CONTEXTS() {
  kubectl config get-contexts
  }
CURRENT_CONTEXT() {
  kubectl config current-context
  }

USE_CONTEXT() {
  kubectl config use-context
  }

GET_NAMESPACES() {
  kubectl get ns
  }

GET_PODS() {
  kubectl get pods
  }

GET_SERVICES() {
  kubectl get service --all-namespaces
  }

HEALTHY_PODS() {
  kubectl get pods -A | grep -c "Running"
  }

UNHEALTHY_PODS() {
  kubectl get pods -A | grep -vc "Running"
  }

GET_LOAD_BALANCER_IP () {
  kubectl get all -A | grep LoadBalancer | awk '{print $4}'
  }

NUMBER_OF_CLUSTERS(){
  kubectl config get-contexts | wc -l
  }

#############################################################
# CARVEL SPECIFIC FUNCTIONS
#############################################################
KAPP_APPS () {
  kapp list -A | tail -3 | head -1
  }

############################################################
# COMBINED OR DEPENDANT FUNCTIONS
############################################################
PRINT_CLUSTER_LIST() {
  CLUSTER_LIST=$( GET_CONTEXTS | PRINT_FORMATED_OUTPUT )
  }

PRINT_NAMESPACE_LIST() {
  NAMESPACE_LIST=$( GET_NAMESPACES | PRINT_FORMATED_OUTPUT | pr -3 -t)
  }

PRINT_POD_LIST () {
  POD_LIST=$( GET_PODS -n "${SELECTED_NAMESPACE}" | PRINT_FORMATED_OUTPUT )
  }
GET_CERTS_LIST() {
  if [[ ${SELECTED_NAMESPACE} == 0 ]]; then
    MAIN_MENU
  else
    CLEAR_TERMINAL
    PRINT_BANNER
    paste <( echo "${yl}INSIDE NAMESPACE: ${rst}" ${SELECTED_NAMESPACE} )
    echo ""
    CERTS_LIST=$(kubectl get certificates -n ${SELECTED_NAMESPACE} | PRINT_FORMATED_OUTPUT )
    echo "${CERTS_LIST}" | column -t
    echo "[0] <-- GO BACK"
    echo "${yl}"
    read -r -p "ENTER THE CERT TO VIEW:${rst} " CERT_NUMBER
      if [[ ${CERT_NUMBER} == 0 ]]; then
        GET_APPS_CERTIFICATES
      else
        SELECTED_CERT=$( echo $CERTS_LIST | grep -w "${CERT_NUMBER}" | awk '{print $2}' )
        kubectl get certificates -n ${SELECTED_NAMESPACE} ${SELECTED_CERT} -o yaml
        read -n 1 -s -r -p "${yl}PRESS ENTER TO RETURN TO CERT LIST:${rst} "
        GET_APPS_CERTIFICATES
      fi
  fi
  }
GET_APPS_CERTIFICATES(){
  CLEAR_TERMINAL
  PRINT_BANNER
  SELECT_NAMESPACE
  GET_CERTS_LIST
  }

SELECT_CLUSTER() {
  CLEAR_TERMINAL
  PRINT_BANNER
  CLUSTER_LIST=$(kubectl config get-contexts | PRINT_FORMATED_OUTPUT )
    echo "${CLUSTER_LIST}" | column -t
    echo "[0] <-- GO BACK"
    echo
    read -r -p "ENTER CLUSTER NUMBER, OR [0] TO GO BACK: " CLUSTER_NUMBER
    case ${CLUSTER_NUMBER} in
      "0") clear && MAIN_MENU;;
        *) CLUSTER_NAME="$( GET_CONTEXTS \
            | PRINT_FORMATED_OUTPUT \
            | grep -w "${CLUSTER_NUMBER}" \
            | awk '{print $2}')"
          kubectl config use-context "${CLUSTER_NAME}" 1> /dev/null;;
    esac
  }

SELECT_NAMESPACE() {
  echo "${rst}"
  PRINT_NAMESPACE_LIST
  echo "${NAMESPACE_LIST}" | column -t
  echo "[0] <-- GO BACK"
  echo "${yl}"
  read -r -p "ENTER THE NAMESPACE USE:${rst} " NAMESPACE_NUMBER
  if [[ ${NAMESPACE_NUMBER} == 0 ]]; then
    MAIN_MENU
  else
  SELECTED_NAMESPACE=$( kubectl get ns | PRINT_FORMATED_OUTPUT \
    | grep -w "${NAMESPACE_NUMBER}" \
    | awk '{print $2}')
  fi
  }

SELECT_POD() {
  echo "${yl}CURRENT PODS IN NAMESPACE: ${rst}"
  echo "${gr}"
  echo "${SELECTED_NAMESPACE}"
  echo "${rst}"
  PRINT_POD_LIST
  echo "${POD_LIST}" | column -t
  echo
  echo "[0] <-- GO BACK"
  echo
  read -r -p "${yl}ENTER POD NUMBER TO VIEW ITS LOGS, OR [0] TO GO BACK:${rst} " POD_NUMBER
    if [[ "${POD_NUMBER}" == 0 ]]; then
    MAIN_MENU
  else
    POD_NAME=$( GET_PODS -n "${SELECTED_NAMESPACE}" | PRINT_FORMATED_OUTPUT \
      | grep -w "${POD_NUMBER}" \
      | awk '{print $2}')
  fi
  }

VIEW_LOGS() {
  CLEAR_TERMINAL
  PRINT_BANNER
  echo "${yl}LIST OF NAMESPACES IN CURRENT CLUSTER: ${rst}"
  echo ""
  NAMESPACE_LIST=$( GET_NAMESPACES | PRINT_FORMATED_OUTPUT | pr -3 -t)
  echo "${NAMESPACE_LIST}" | column -t
  echo "[0] <-- GO BACK"
  echo "${yl}"
  read -r -p "ENTER THE NAMESPACE USE:${rst} " NAMESPACE_NUMBER
  if [[ "${NAMESPACE_NUMBER}" == 0 ]]; then
    MAIN_MENU
  else
    SELECTED_NAMESPACE=$( GET_NAMESPACES | PRINT_FORMATED_OUTPUT \
      | grep -w "${NAMESPACE_NUMBER}" \
      | awk '{print $2}')
  fi

  CLEAR_TERMINAL
  PRINT_BANNER
  paste <(echo "${yl}CURRENT PODS IN NAMESPACE: ${rst}") <(echo "${gr}""${SELECTED_NAMESPACE}""${rst}")
  echo ""
  # GET A LIST OF PODS
  POD_LIST=$( kubectl get pods -n contour | tail -n +2 | awk '{print "[" NR "]", $1, $3}' | column -t )
  echo "${POD_LIST}"
  echo ""
  echo "[0] <-- GO BACK"
  echo ""
  # SELECT A POD
  read -r -p "${yl}ENTER POD NUMBER TO VIEW ITS LOGS, OR [0] TO GO BACK:${rst} " POD_NUMBER
    if [[ "${POD_NUMBER}" == 0 ]]; then
      MAIN_MENU
    else
      # GET CONTAINER LIST
      POD_NAME=$( kubectl get pods -n "${SELECTED_NAMESPACE}" | PRINT_FORMATED_OUTPUT \
        | grep -w "${POD_NUMBER}" \
        | awk '{print $2}')
      echo ""
      CONTAINER_LIST=$(kubectl get pod -n "${SELECTED_NAMESPACE}" "${POD_NAME}" \
      -o="custom-columns=NAME:.metadata.name,INIT-CONTAINERS:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name" \
        | awk '{print $3}' \
        | tail -n +2 \
        | tr "," "\n" \
        | awk '{print "[" NR "]", $1}')
      echo "${CONTAINER_LIST}"
      echo ""
        # SELECT A CONTAINER
        read -r -p "${yl}ENTER CONTAINER NUMBER TO VIEW ITS LOGS, OR [0] TO GO BACK:${rst} " CONTAINER_NUMBER
          if [[ "${CONTAINER_NUMBER}" == 0 ]]; then
            MAIN_MENU
          else
            CONTAINER_SELECTION=$( echo ${CONTAINER_LIST} \
            | grep -w "${CONTAINER_NUMBER}" \
            | awk '{print $2}')
            kubectl logs -n "${SELECTED_NAMESPACE}" "${POD_NAME}" "${CONTAINER_SELECTION}" | less
            read -r -p "DO YOU WANT TO VIEW MORE LOGS? " YN
            case "$YN" in
              [yY]*) VIEW_LOGS;;
              [nN]*) MAIN_MENU;;
              *)  INVALID_SELECTION;;
            esac
          fi
    fi
    }

GET_SECRETS_LIST() {
  CLEAR_TERMINAL
  PRINT_BANNER
  SELECT_NAMESPACE
  CLEAR_TERMINAL
  PRINT_BANNER
  paste <( echo "${yl}SECRETS INSIDE NAMESPACE: ${rst}" ${SELECTED_NAMESPACE} )
  echo ""
  SECRETS_LIST=$(kubectl get secrets -n ${SELECTED_NAMESPACE} | tail -n +2 | awk '{print "[" NR "]", $1}' )
  echo "${SECRETS_LIST}" | column -t
  echo "[0] <-- GO BACK"
  echo "${yl}"
  read -r -p "ENTER THE SECRET TO VIEW:${rst} " SECRET_NUMBER
    if [[ ${SECRET_NUMBER} == 0 ]]; then
      GET_SECRETS_LIST
    else
      SELECTED_SECRET=$( echo ${SECRETS_LIST} | grep -w "${SECRET_NUMBER}" | awk '{print $2}' )
    echo ${SELECTED_SECRET}
      kubectl get secret -n ${SELECTED_NAMESPACE} ${SELECTED_SECRET} -o \
      go-template='{{range $k,$v := .data}}{{"### "}}{{$k}}{{"\n"}}{{$v|base64decode}}{{"\n\n"}}{{end}}'
      read -r -p  "${yl}PRESS ENTER TO RETURN TO LAST MENU:${rst} "
      CLEAR_TERMINAL
      GET_SECRETS_LIST
    fi
  }

EXEC_INTO_CONTAINER() {
  CLEAR_TERMINAL
  PRINT_BANNER
  echo "${yl}LIST OF NAMESPACES IN CURRENT CLUSTER: ${rst}"
  echo ""
  NAMESPACE_LIST=$( GET_NAMESPACES | PRINT_FORMATED_OUTPUT | pr -3 -t)
  echo "${NAMESPACE_LIST}" | column -t
  echo "[0] <-- GO BACK"
  echo "${yl}"
  read -r -p "ENTER THE NAMESPACE USE:${rst} " NAMESPACE_NUMBER
  if [[ "${NAMESPACE_NUMBER}" == 0 ]]; then
    MAIN_MENU
  else
    SELECTED_NAMESPACE=$( GET_NAMESPACES | PRINT_FORMATED_OUTPUT \
      | grep -w "${NAMESPACE_NUMBER}" \
      | awk '{print $2}')
  fi

  CLEAR_TERMINAL
  PRINT_BANNER
  paste <(echo "${yl}CURRENT PODS IN NAMESPACE: ${rst}") <(echo "${gr}""${SELECTED_NAMESPACE}""${rst}")
  echo ""
  # GET A LIST OF PODS
  POD_LIST=$( kubectl get pods -n "${SELECTED_NAMESPACE}" | tail -n +2 | awk '{print "[" NR "]", $1, $3}' | column -t )
  echo "${POD_LIST}"
  echo ""
  echo "[0] <-- GO BACK"
  echo ""
  # SELECT A POD
  read -r -p "${yl}ENTER POD NUMBER TO VIEW ITS LOGS, OR [0] TO GO BACK:${rst} " POD_NUMBER
    if [[ "${POD_NUMBER}" == 0 ]]; then
      MAIN_MENU
    else
      # GET CONTAINER LIST
      POD_NAME=$( kubectl get pods -n "${SELECTED_NAMESPACE}" | PRINT_FORMATED_OUTPUT \
        | grep -w "${POD_NUMBER}" \
        | awk '{print $2}')
      echo ""
      CONTAINER_LIST=$(kubectl get pod -n "${SELECTED_NAMESPACE}" "${POD_NAME}" \
      -o="custom-columns=NAME:.metadata.name,INIT-CONTAINERS:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name" \
        | awk '{print $3}' \
        | tail -n +2 \
        | tr "," "\n" \
        | awk '{print "[" NR "]", $1}')
      echo "${CONTAINER_LIST}"
      echo ""
        # SELECT A CONTAINER
        read -r -p "${yl}ENTER CONTAINER NUMBER TO EXEC INTO, OR [0] TO GO BACK:${rst} " CONTAINER_NUMBER
          if [[ "${CONTAINER_NUMBER}" == 0 ]]; then
            MAIN_MENU
          else
            CONTAINER_SELECTION=$( echo ${CONTAINER_LIST} \
            | grep -w "${CONTAINER_NUMBER}" \
            | awk '{print $2}')
            kubectl exec -it -n "${SELECTED_NAMESPACE}" "${POD_NAME}" "${CONTAINER_SELECTION}" -- bash
            read -r -p "DO YOU WANT TO EXEC INTO ANOTHER CONTAINER? " YN
            case "$YN" in
              [yY]*) VIEW_LOGS;;
              [nN]*) MAIN_MENU;;
              *)  INVALID_SELECTION;;
            esac
          fi
    fi
    }

#########################################################################################
# MENU FUNCTIONS
#########################################################################################
SELECT_CLUSTER_MENU() {
  CLEAR_TERMINAL
  PRINT_BANNER
  echo "
  [0] EXIT
  [1] RETURN TO MAIN MENU
  [2] SWITCH CLUSTERS
  "
  read -r -p "${yl}SELECT AN OPTION TO CONTINUE:${rst} " START_MENU
  case "${START_MENU}" in
      0)  clear && exit 0 ;;
      1)  clear && MAIN_MENU;;
      2)  clear && SELECT_CLUSTER && MAIN_MENU;;
      *)  INVALID_SELECTION
      ;;
      esac
  }
MAIN_MENU() {
  CLEAR_TERMINAL
  PRINT_BANNER
  echo "
  [0] EXIT
  [1] CHANGE CLUSTER CONTEXT
  [2] VIEW LOGS
  [3] SECRETS
  [4] GET CERTIFICATES
  [5] EXEC INTO CONTAINER
  "
  read -r -p "${yl}SELECT A CLUSTER TO CONTINUE:${rst} " MAIN_SELECTIONS
  case "${MAIN_SELECTIONS}" in
      0)  clear && exit 0 ;;
      1)  SELECT_CLUSTER_MENU;;
      2)  VIEW_LOGS;;
      3)  GET_SECRETS_LIST;;
      4)  GET_APPS_CERTIFICATES;;
      5)  EXEC_INTO_CONTAINER;;
      *)  INVALID_SELECTION;;
      esac
      }
MAIN_MENU
