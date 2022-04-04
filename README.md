# Service Mesh Workshop

Repository to store the Service Mesh Workshop for Iberia Customer Success Meetup on April 6

This repository contains the required tasks to install and configure Red Hat OpenShift Service Mesh in a OCP cluster, and deploy an example application.

## Prerequisites
 - OCP cluster up and running with version 4.6 or higher.
 - OC cli installed.

### Installing the operators:

Jaeger
```bash
oc apply -f config/1-operators/jaeger-operator.yaml
```

Kiali
```bash
oc apply -f config/1-operators/kiali-operator.yaml
```

OSSM
```bash
oc apply -f config/1-operators/ossm-operator.yaml
```

```bash
oc get clusterserviceversions.operators.coreos.com
---
NAME                         DISPLAY                                          VERSION   REPLACES                     PHASE
jaeger-operator.v1.28.0      Red Hat OpenShift distributed tracing platform   1.28.0                                 Succeeded
kiali-operator.v1.36.7       Kiali Operator                                   1.36.7    kiali-operator.v1.36.6       Succeeded
servicemeshoperator.v2.1.1   Red Hat OpenShift Service Mesh                   2.1.1-0   servicemeshoperator.v2.1.0   Succeeded
```

### Installing the Service Mesh Control Plane
Now, the operators are installed and it is time to install the Service Mesh Control Plane with the configuration desired. For this, set the [SMCP Configuration](./config/2-ossm/basic.yaml) file up with your preferences and install it.

Create the istio-system namespace
```bash
oc new-project istio-system
```

Install the Service Mesh Control Plane
```bash
oc apply -f config/2-ossm/basic.yaml
```

You can check the installation by executing
```
oc get smcp -n istio-system
----
NAME    READY   STATUS            PROFILES      VERSION   AGE
basic   10/10   ComponentsReady   ["default"]   2.1.1     2m10s
```

## Adding services to the mesh <mark> Here starts the meetup </mark>
There are two ways for joining namespaces to the Service Mesh: SMMR and SMM.

### OpenShift Service Mesh member roll (SMMR)

The *ServiceMeshMemberRoll* object lists the projects that belong to the Control Plane. Any project that is not set in this object, is treated as external to the Service Mesh. This object must exist in the Service Mesh with the name *default*.

This object can not be created empty, at least must contain an existing namespace. Let's create a dummy project:

Create the dummy project called *my-awesome-project*
```bash
oc new-project my-awesome-project
```

Create the SMMR
```bash
oc apply -f config/2-ossm/smmr.yaml
```

A namespace called *my-awesome-project* exists in the OCP cluster and it will be joined to the Service Mesh:
```bash
oc get smmr default -n istio-system -oyaml
---
NAME      READY   STATUS       AGE
default   1/1     Configured   5s
```

### Openshift Service Mesh member
Using this object, users who don't have privileges to add members to the *ServiceMeshMemberRoll* (e.g. users who can't access the Control Plane's namespace) can join their namespaces to the Service Mesh. But, these users need the *mesh-user* role.

First, replace the User variables:
```bash
OCP_DOMAIN=$(oc -n openshift-ingress-operator get ingresscontrollers default -o json | jq -r '.status.domain')
sed -i "s/\$EXTERNAL_DOMAIN/$OCP_DOMAIN/g" $CURRENT_DIR/greeter-grpc/certs/cert.conf
```

If you try to create the Service Mesh Member object, you will receive the following error:
```
oc apply -f config/2-ossm/smm.yaml
----
Error from server: error when creating "config/2-ossm/smm.yaml": admission webhook "smm.validation.maistra.io" denied the request: user '$user' does not have permission to use ServiceMeshControlPlane istio-system/basic
```

Grant user permissions to access the mesh by granting the *mesh-user* role:
```
oc policy add-role-to-user -n istio-system --role-namespace istio-system mesh-user $user
```

This use case will be use in the application deployment step with your user.

## Deploying the bookinfo example application
It is time to deploy the bookinfo sample application. The bookinfo sample application with external ratings database using an egress Gateway for routing TCP traffic. The bookinfo application will be deployed in two namespaces simulating front and back tiers.

Three MySQL instances are deployed outside the Mesh in the _ddbb_ project: mysql-1, mysql-2 and mysql-3. Each mysql instance has a different rating number that will be consumed by the ratings application:
* mysql-1: Ratings point equals 1.
* mysql-2: Ratings point equals 5.
* mysql-3: Ratings point equals 3.

Thus, the traffic will be balanced between the different MySQL instances.

### App diagram
The traffic flow is:
1. The sidecar intercept the request from the app container (ratings) to _mysql_.
2. The Virtual Service and Destination Rule objects route the request from the sidecar (back) to the egress Gateway (istio-system).
3. At this point, the Virtual Service and Kubernetes Services objects resolve the endpoints and route the traffic through the egress Gateway.

<img src="./config/full-application-flow.png" alt="Bookinfo app, front and back tiers" width=100%>

### Deploying the MySQL instances
<mark> This step is already done by the OSSM admins </mark><br/>
As cluster-admin
```bash
oc new-project ddbb
oc create -n ddbb secret generic mysql-credentials-1 --from-env-file=./mysql-deploy/params.env
oc create -n ddbb secret generic mysql-credentials-2 --from-env-file=./mysql-deploy/params-2.env
oc create -n ddbb secret generic mysql-credentials-3 --from-env-file=./mysql-deploy/params-3.env
oc process -f mysql-deploy/mysql-template.yaml --param-file=mysql-deploy/params.env | oc create -n ddbb -f -
oc process -f mysql-deploy/mysql-template.yaml --param-file=mysql-deploy/params-2.env | oc create -n ddbb -f -
oc process -f mysql-deploy/mysql-template.yaml --param-file=mysql-deploy/params-3.env | oc create -n ddbb -f -
```

All the MySQL instances should be running in _ddbb_ project.

### Deploy Custom Bookinfo application in separated Namespaces (productpage=front, reviews|ratings|details=back)

#### Default OSSM networking
First, create the Ingress Gateway and the OCP public route for the bookinfo application.

Get the default ingress controller domain
```bash
OCP_DOMAIN=$(oc -n openshift-ingress-operator get ingresscontrollers default -o json | jq -r '.status.domain')
```

Replace the $EXTERNAL_DOMAIN variable in the [Gateway object](./config/3-ossm-networking/gw-ingress-http.yaml) and [OpenShift route object](./config/3-ossm-networking/route-bookinfo.yaml). Create Gateway and OpenShift route.