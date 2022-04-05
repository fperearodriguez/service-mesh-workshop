# Service Mesh Workshop

OCP cluster configuration.

## Prerequisites
 - OCP cluster up and running with version 4.6 or higher.
 - OC cli installed.

### Installing the operators:

Jaeger
```bash
oc apply -f ./config/1-operators/jaeger-operator.yaml
```

Kiali
```bash
oc apply -f ./config/1-operators/kiali-operator.yaml
```

OSSM
```bash
oc apply -f ./config/1-operators/ossm-operator.yaml
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
oc apply -f ./config/2-ossm/basic.yaml
```

You can check the installation by executing
```
oc get smcp -n istio-system
----
NAME    READY   STATUS            PROFILES      VERSION   AGE
basic   10/10   ComponentsReady   ["default"]   2.1.1     2m10s
```

### Configuring OCP oauth
Add the users to the file [Oauth File](./config/util/users.txt) and execute from the root path:
```bash
config/util/oauth.sh
```

### OpenShift Service Mesh member roll (SMMR)

The *ServiceMeshMemberRoll* object lists the projects that belong to the Control Plane. Any project that is not set in this object, is treated as external to the Service Mesh. This object must exist in the Service Mesh with the name *default*.

Create the SMMR
```bash
oc apply -f ./config/2-ossm/smmr.yaml
```

A namespace called *my-awesome-project* exists in the OCP cluster and it will be joined to the Service Mesh:
```bash
oc get smmr default -n istio-system -oyaml
---
NAME      READY   STATUS       AGE
default   1/1     Configured   5s
```

### Deploying the MySQL instances
As cluster-admin:
```bash
oc new-project ddbb
oc create -n ddbb secret generic mysql-credentials-1 --from-env-file=./config/3-mysql-deploy/params.env
oc create -n ddbb secret generic mysql-credentials-2 --from-env-file=./config/3-mysql-deploy/params-2.env
oc create -n ddbb secret generic mysql-credentials-3 --from-env-file=./config/3-mysql-deploy/params-3.env
oc process -f ./config/3-mysql-deploy/mysql-template.yaml --param-file=./config/3-mysql-deploy/params.env | oc create -n ddbb -f -
oc process -f ./config/3-mysql-deploy/mysql-template.yaml --param-file=./config/3-mysql-deploy/params-2.env | oc create -n ddbb -f -
oc process -f ./config/3-mysql-deploy/mysql-template.yaml --param-file=./config/3-mysql-deploy/params-3.env | oc create -n ddbb -f -
oc create -n istio-system -f ./config/3-mysql-deploy/svc-mysql.yaml
```

All the MySQL instances should be running in _ddbb_ project.

### Create the Istio objects to route the traffic from the Egress Gateway to the external Mysql databases
As cluster-admin:
```bash
oc create -n istio-system -f ./config/4-istio-system-egress/
```

### Simulate users
To simulate real users generating objects and traffic in the OCP cluster:
```bash
config/util/test-users.sh
```