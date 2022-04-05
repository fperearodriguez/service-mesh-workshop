#!/bin/bash

CURRENT_DIR=$(pwd)/config/util
set -e

echo "Creating htpasswd file"
rm -f $CURRENT_DIR/oauth/htpasswd

htpasswd -c -b -B $CURRENT_DIR/oauth/htpasswd admin redhat

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
  echo "Deleting roles from user $user"
  oc adm policy remove-role-from-user getingressdomain $user --role-namespace=openshift-ingress-operator -n openshift-ingress-operator
  oc adm policy remove-cluster-role-from-user view $user -n istio-system
  oc adm policy remove-role-from-user createsdssecrets $user --role-namespace=istio-system -n istio-system
  oc delete project $user-front
  oc delete project $user-back
done

echo "Deleting role"
oc delete -n openshift-ingress-operator -f ./config/util/role-getingressdomain.yaml --ignore-not-found=true
oc delete -n istio-system -f ./config/util/role-createsdssecrets.yaml --ignore-not-found=true

echo "Giving cluster-admin role to admin user"
oc adm policy add-cluster-role-to-user cluster-admin admin

echo "Remove kubeadmin user"
oc delete secrets kubeadmin -n kube-system --ignore-not-found=true