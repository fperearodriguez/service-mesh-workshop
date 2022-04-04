# Service Mesh Workshop

Repository to store the Service Mesh Workshop for Iberia Customer Success Meetup on April 6

This repository contains the required tasks to install and configure Red Hat OpenShift Service Mesh in a OCP cluster, and deploy an example application.

## Prerequisites
 - OCP cluster up and running with version 4.6 or higher.
 - OC cli installed.

## Adding services to the mesh
### Openshift Service Mesh Member
Using this object, users who don't have privileges to add members to the *ServiceMeshMemberRoll* (e.g. users who can't access the Control Plane's namespace) can join their namespaces to the Service Mesh. But, these users need the *mesh-user* role.

First, replace the User variables:
```bash
export OCP_DOMAIN=$(oc -n openshift-ingress-operator get ingresscontrollers default -o json | jq -r '.status.domain')
export USER_NAMESPACE=$YOUR_USER
find ./labs/ -type f -print0 | xargs -0 sed -i "s/\$EXTERNAL_DOMAIN/$OCP_DOMAIN/g"
find ./labs/ -type f -print0 | xargs -0 sed -i "s/\$USER_NAMESPACE/user1/g"
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

### Deploy Custom Bookinfo application in separated Namespaces (productpage=front, reviews|ratings|details=back)

#### Default OSSM networking
First, create the Ingress Gateway and the OCP public route for the bookinfo application.

Replace the apps.fperod.cdd1.sandbox988.opentlc.com variable in the [Gateway object](./config/3-ossm-networking/gw-ingress-http.yaml) and [OpenShift route object](./config/3-ossm-networking/route-bookinfo.yaml). Create Gateway and OpenShift route.