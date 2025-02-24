#!/bin/bash

set -e

CURRENT_DIR=$(pwd)/config/util

echo "Creating roles"
oc apply -n openshift-ingress-operator -f ./config/util/role-getingressdomain.yaml
oc apply -n istio-system -f ./config/util/role-createsdssecrets.yaml
oc apply -n istio-system -f ./config/util/role-getsvcandroute.yaml
oc apply -n istio-system -f ./config/util/role-createroutes.yaml

echo "Creating htpasswd file"
rm -f $CURRENT_DIR/oauth/htpasswd

htpasswd -c -b -B $CURRENT_DIR/oauth/htpasswd admin redhat

for user in $(cat $CURRENT_DIR/users.txt);do
  echo "Creating $user username"
  htpasswd -b -B $CURRENT_DIR/oauth/htpasswd $user $user
done

echo "Creating HTPasswd Secret"
oc delete secret htpass-secret -n openshift-config
oc create secret generic htpass-secret --from-file=htpasswd=$CURRENT_DIR/oauth/htpasswd -n openshift-config --dry-run=client -o yaml | oc apply -f -

echo "Configuring HTPassw identity provider"
cat > $CURRENT_DIR/oauth/cluster-oauth.yaml << EOF_IP
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: my_htpasswd_provider 
    mappingMethod: claim 
    type: HTPasswd
    htpasswd:
      fileData:
        name: htpass-secret
EOF_IP
oc apply -f $CURRENT_DIR/oauth/cluster-oauth.yaml

for user in $(cat $CURRENT_DIR/users.txt);do
  echo "Adding roles to user $user"
  oc adm policy add-role-to-user getingressdomain $user --role-namespace=openshift-ingress-operator -n openshift-ingress-operator
  oc adm policy add-role-to-user createsdssecrets $user --role-namespace=istio-system -n istio-system
  oc adm policy add-role-to-user getsvcandroute $user --role-namespace=istio-system -n istio-system
  oc adm policy add-role-to-user createroutes $user --role-namespace=istio-system -n istio-system
  oc adm policy add-cluster-role-to-user manage-host-routes $user
  oc adm new-project $user-front --display-name=$user-front --description=$user-front --admin=$user
  oc label namespace $user-front istio-injection=enabled
  oc adm new-project $user-back --display-name=$user-back --description=$user-back --admin=$user
  oc label namespace $user-back istio-injection=enabled
done

echo "Giving cluster-admin role to admin user"
oc adm policy add-cluster-role-to-user cluster-admin admin

echo "Remove kubeadmin user"
oc delete secrets kubeadmin -n kube-system --ignore-not-found=true