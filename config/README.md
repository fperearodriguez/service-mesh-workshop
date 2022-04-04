# Service Mesh Workshop

OCP cluster configuration.

## Prerequisites
 - OCP cluster up and running with version 4.6 or higher.
 - OC cli installed.

### Installing the operators:

Jaeger
```bash
oc apply -f ./1-operators/jaeger-operator.yaml
```

Kiali
```bash
oc apply -f ./1-operators/kiali-operator.yaml
```

OSSM
```bash
oc apply -f ./1-operators/ossm-operator.yaml
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
Now, the operators are installed and it is time to install the Service Mesh Control Plane with the configuration desired. For this, set the [SMCP Configuration](./2-ossm/basic.yaml) file up with your preferences and install it.

Create the istio-system namespace
```bash
oc new-project istio-system
```

Install the Service Mesh Control Plane
```bash
oc apply -f ./2-ossm/basic.yaml
```

You can check the installation by executing
```
oc get smcp -n istio-system
----
NAME    READY   STATUS            PROFILES      VERSION   AGE
basic   10/10   ComponentsReady   ["default"]   2.1.1     2m10s
```

### OpenShift Service Mesh member roll (SMMR)

The *ServiceMeshMemberRoll* object lists the projects that belong to the Control Plane. Any project that is not set in this object, is treated as external to the Service Mesh. This object must exist in the Service Mesh with the name *default*.

This object can not be created empty, at least must contain an existing namespace. Let's create a dummy project:

Create the dummy project called *my-awesome-project*
```bash
oc new-project my-awesome-project
```

Create the SMMR
```bash
oc apply -f ./2-ossm/smmr.yaml
```

A namespace called *my-awesome-project* exists in the OCP cluster and it will be joined to the Service Mesh:
```bash
oc get smmr default -n istio-system -oyaml
---
NAME      READY   STATUS       AGE
default   1/1     Configured   5s
```

### Configuring OCP oauth
Add the users to the file [Oauth File](././util/users.txt) and execute from the root path:
```bash
./util/oauth.sh
```

