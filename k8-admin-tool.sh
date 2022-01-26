#!/bin/bash
#===================================================================================
#
# FILE: k8s-admin-tool.sh
#
# USAGE: k8s-admin-tool.sh
#
# DESCRIPTION: Basic troubleshooting tool for Kubernetes Clusters.
#
# OPTIONS: see function ’usage’ below
# REQUIREMENTS: ---
# BUGS: ---
# NOTES: ---
# AUTHOR: Joshua Millett, Austin, TX
# COMPANY: Personal Project
# VERSION: 1.0
# CREATED: 1.25.2022
# REVISION: ---
#===================================================================================

set -euo pipefail
export TERM=xterm-256color
cy=$(tput setaf 118)
rst=$(tput sgr0)
IFS=$'\n'
printf "\033c"
INVALID_SELECTION() {
  echo "INVALID SELECTION. PRESS ENTER TO TRY AGAIN: "
  read -r
}
CHANGE_CLUSTER() {
CLUSTER_LIST=$(kubectl config get-contexts \
  | tail -n +2 \
  | awk '{print "[" NR "]", $1}')
CURRENT_CLUSTER="$(kubectl config current-context)"
echo "CURRENTLY ON CLUSTER: ${cy}${CURRENT_CLUSTER}${rst}"
echo "${cy}${CLUSTER_LIST}${rst}" | column -t
echo "[0] <-- GO BACK"
read -r -p "ENTER CLUSTER NUMBER, OR [0] TO GO BACK: " CLUSTER_NUMBER
case $CLUSTER_NUMBER in
"0") clear && LOG_MENU;;
*) CLUSTER_NAME="$(kubectl config get-contexts \
   | tail -n +2 \
   | awk '{print "[" NR$ "]", $1}' \
   | grep -w "${CLUSTER_NUMBER}" \
   | awk '{print $2}')"
   kubectl config use-context "${CLUSTER_NAME}";;
   esac                               
}
CHANGE_NAMESPACE() {
NAMESPACE_LIST="$(kubectl get ns \
  | tail -n +2 \
  | awk '{print "[" NR "]", $1}' \
  | pr -3 -t)"
echo "CURRENTLY VIEWING ${cy}${CURRENT_CLUSTER}${rst} NAMESPACES"
echo "${cy}${NAMESPACE_LIST}${rst}" | column -t
echo "[0] <-- GO BACK"                            
read -r -p "ENTER THE NAMESPACE NUMBER OR PRESS [0] TO GO BACK: " NAMESPACE_NUMBER
case "$NAMESPACE_NUMBER" in
  "0")  clear && CHANGE_CLUSTER;;    
    *)  NAMESPACE_NAME=$(kubectl get ns \
      | tail -n +2 \
      | awk '{print "[" NR "]", $1}' \
      | grep -w "${NAMESPACE_NUMBER}" \
      | awk '{print $2}');;
      esac
    }
VIEW_POD() {
POD_LIST=$(kubectl get pods -n "${NAMESPACE_NAME}" \
  | tail -n +2 \
  | awk '{print "[" NR "]", $1}')
echo "# CURRENT PODS IN NAMESPACE: ${cy}${NAMESPACE_NAME}${rst}"
echo "${cy}"            
echo "${POD_LIST}" | column -t
echo "${rst}"
echo "[0] <-- GO BACK"   
read -r -p "ENTER THE POD TO VIEW ITS LOGS, OR [0] TO GO BACK: " POD_NUMBER
case "$POD_NUMBER" in
"0")  clear && LOG_MENU;;
*)
POD_NAME=$(kubectl get pods -n "${NAMESPACE_NAME}" \
  | tail -n +2 \
  | awk '{print "[" NR "]", $1}' \
  | grep -w "${POD_NUMBER}" \
  | awk '{print $2}')                  
kubectl logs -n "${NAMESPACE_NAME}" "${POD_NAME}" | less
clear
read -r -p "DO YOU WANT TO VIEW MORE LOGS? " YN
case "$YN" in
  [yY]*)
    clear && VIEW_POD;;
  [nN]*) 
    clear && CHANGE_NAMESPACE
    clear && VIEW_POD
    return
  LOG_MENU;;
  *)  INVALID_SELECTION;;
  esac
esac
}
CLUSTER_NAVIGATION() {
CURRENT_CLUSTER=$(kubectl config current-context)
echo "YOU ARE CURRENTLY IN CLUSTER:"
echo "${cy}"
echo "${CURRENT_CLUSTER}"
echo "${rst}"
read -r -p "DO YOU WANT TO SWITCH TO ANOTHER CLUSTER? " YN
case "$YN" in
  [yY]*) 
    clear && CHANGE_CLUSTER
    clear && CHANGE_NAMESPACE
    clear && VIEW_POD;;
  [nN]*) 
    clear && CHANGE_NAMESPACE
    clear && VIEW_POD
    return
  LOG_MENU;;
  *)  INVALID_SELECTION;;
esac
}
HEALTHY_POD_CHECK() {
  if [[ $(kubectl get pods -A | grep -v "Running" | tail -n +2 | wc -l) == 0 ]]; then
    echo "${cy}"
    echo "NO UNHEALTHY PODS RUNNING"
    echo "${rst}"
  else
    echo "PODS NOT IN A RUNNING STATUS ARE BELOW:"
    echo "${cy}"
    kubectl get pods -A | grep -v "Running" | tail -n +2 | awk '{print $2, $4}' | column -t
    echo "${rst}"
  fi
  
}
BAD_POD_VIEWER() {
read -r -p "WOULD YOU LIKE TO VIEW BAD PODS STATUS IN ANOTHER CLUSTER? " YN
case "$YN" in
  [yY]*) 
    clear && CHANGE_CLUSTER && clear
    HEALTHY_POD_CHECK
    BAD_POD_VIEWER;;
  [nN]*) 
    LOG_MENU;;
  *) INVALID_SELECTION;;
  esac
}
MAIN_MENU() {
while :
do
clear
echo "MAIN MENU"
echo "${cy}
[0] EXIT
[1] RETURN TO MAIN MENU
[2] LOG MENU"
echo "${rst}"
read -r -p "SELECT AN OPTION TO CONTINUE: " MAIN_MENU
case "$MAIN_MENU" in
"0")  clear && exit 0;;    
"1")  clear && MAIN_MENU;;
"2")  clear && LOG_MENU;;
*)    INVALID_SELECTION;;
    esac
  done
}
LOG_MENU() {
while :
do
clear
echo "LOGS MENU"
echo "${cy}
[0] EXIT
[1] RETURN TO MAIN MENU
[2] VIEW A PODS LOGS
[3] VIEW ALL UNHEALTHY PODS"
echo "${rst}"
read -r -p "SELECT AN OPTION TO CONTINUE: " LOG_MENU
case "$LOG_MENU" in
"0") clear && exit 0;;
"1") clear && MAIN_MENU;;
"2") clear && CLUSTER_NAVIGATION;;
"3") clear && CHANGE_CLUSTER && clear
    HEALTHY_POD_CHECK
    BAD_POD_VIEWER;;
*) INVALID_SELECTION;;
  esac
done
}
MAIN_MENU
