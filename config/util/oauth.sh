#!/bin/bash

set -e

CURRENT_DIR=$(pwd)/config/util

# echo "Exporting admin TLS credentials..."
# export KUBECONFIG=$HOME/.kube/config_otlc

echo "Creating cluster role"
oc create role getingressdomain --verb=get --resource=ingresscontrollers.operator.openshift.io -n openshift-ingress-operator
oc create role createsdssecret --verb=create --resource=secrets -n istio-system

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
  oc adm policy add-cluster-role-to-user view $user -n istio-system
  oc adm policy add-role-to-user createsdssecrets $user --role-namespace=istio-system -n istio-system
  oc adm new-project $user-front --display-name=$user-front --description=$user-front --admin=$user
  oc adm new-project $user-back --display-name=$user-back --description=$user-back --admin=$user
done

echo "Giving cluster-admin role to admin user"
oc adm policy add-cluster-role-to-user cluster-admin admin

echo "Remove kubeadmin user"
oc delete secrets kubeadmin -n kube-system --ignore-not-found=true