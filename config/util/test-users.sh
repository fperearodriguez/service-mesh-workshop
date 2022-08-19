#/bin/bash

set -e
CURRENT_DIR=$(pwd)
OCP_API_SERVER=$1

if [ -z "$1" ]
then
    echo "ERROR: No OCP Api Server indicated as argument"
    echo "Usage: config/util/test-users.sh https://API_SERVER:6443"
    exit 1
fi

check_pod() {
    POD=$1
    NS=$2
    while true;do echo -n "Checking $POD pod in namespace $NS...";sleep 1;done &
    while [ -z $POD_TO_CHECK ];do
      local POD_TO_CHECK=$(oc get pod -n $NS --no-headers | grep $POD | awk '{print $1}')
    done
    kill $!; trap 'kill $!' SIGTERM
    echo " "
    
    oc -n $NS wait --for=condition=Ready pod/$POD_TO_CHECK --timeout=-1s

}

for user in $(cat $CURRENT_DIR/config/util/users.txt);do
    echo "-- Testing User $user --"
    sleep 1
    oc login -u $user -p $user --server=$OCP_API_SERVER
    export EXTERNAL_DOMAIN=$(oc -n openshift-ingress-operator get ingresscontrollers default -o json | jq -r '.status.domain')
    export USER_NAMESPACE=$(oc whoami)
    export MYSQL_CLUSTER_IP=$(oc get svc mysql -n istio-system -o json | jq -r '.spec.clusterIP')
    find ./labs/ -type f -print0 | xargs -0 sed -i "s/\$EXTERNAL_DOMAIN/$EXTERNAL_DOMAIN/g"
    find ./labs/ -type f -print0 | xargs -0 sed -i "s/\$USER_NAMESPACE/$USER_NAMESPACE/g"
    find ./labs/4-ratings-egress/ -type f -print0 | xargs -0 sed -i "s/\$MYSQL_CLUSTER_IP/$MYSQL_CLUSTER_IP/g"
    find ./labs/0-certs/ -type f -print0 | xargs -0 sed -i "s/\$HOSTNAME/$HOSTNAME/g"

    echo "Creating TLS certificates"
    labs/0-certs/certs.sh
    oc create secret generic $USER_NAMESPACE-ingress-gateway-certs -n istio-system --from-file=tls.crt=./labs/0-certs/server.pem --from-file=tls.key=./labs/0-certs/server.key --from-file=ca.crt=./labs/0-certs/ca.pem

    echo "Deploying the bookinfo application"
    oc apply -f ./labs/1-ossm-networking/gw-ingress-http-https.yaml
    oc apply -f ./labs/2-front/ -n $USER_NAMESPACE-front
    oc apply -f ./labs/3-back/ -n $USER_NAMESPACE-back
    oc process -f ./labs/3-back/bookinfo-ratings-mysql.yaml --param-file=./labs/3-back/params.env | oc apply -n $USER_NAMESPACE-back -f -
    
    echo "Creating Istio objects to reach the external database"
    oc apply -n $USER_NAMESPACE-back -f ./labs/4-ratings-egress/dr-ratings-egress.yaml
    oc apply -n $USER_NAMESPACE-back -f ./labs/4-ratings-egress/vs-ratings-egress.yaml

    check_pod productpage $USER_NAMESPACE-front
    check_pod ratings $USER_NAMESPACE-back
    check_pod details $USER_NAMESPACE-back
    check_pod reviews-v1 $USER_NAMESPACE-back
    check_pod reviews-v2 $USER_NAMESPACE-back
    check_pod reviews-v3 $USER_NAMESPACE-back

    echo "Accessing the application via HTTP"
    sleep 1
    for num in $(seq 1 5)
        do
        curl -I http://bookinfo-$USER_NAMESPACE.$EXTERNAL_DOMAIN/productpage
        sleep 1
    done

    echo "Accessing the application via Mutual HTTPS"
    sleep 1
    for num in $(seq 1 5)
        do
        curl -I https://bookinfo-$USER_NAMESPACE.secure.$EXTERNAL_DOMAIN/productpage --cacert labs/0-certs/ca.pem --cert labs/0-certs/client.pem --key labs/0-certs/client.key
        sleep 1
    done

    find ./labs/ -type f -print0 | xargs -0 sed -i "s/$EXTERNAL_DOMAIN/\$EXTERNAL_DOMAIN/g"
    find ./labs/ -type f -print0 | xargs -0 sed -i "s/$USER_NAMESPACE/\$USER_NAMESPACE/g"
    find ./labs/4-ratings-egress/ -type f -print0 | xargs -0 sed -i "s/$MYSQL_CLUSTER_IP/\$MYSQL_CLUSTER_IP/g"
    find ./labs/0-certs/ -type f -print0 | xargs -0 sed -i "s/$HOSTNAME/\$HOSTNAME/g"
    echo "User $user done..."
    echo " "
    sleep 1
done