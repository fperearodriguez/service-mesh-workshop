# Red Hat OpenShift Service Mesh Workshop

Repository to store a Red Hat OpenShift Service Mesh workshop.

This repository contains the required tasks to install and configure Red Hat OpenShift Service Mesh in a OCP cluster, and deploy an example application.

In the config folder, you will find the instructions to install and configure the OCP cluster with RHOSSM.

In the labs folder, you will find the workshop. This workshop contains:
1. Adding service to the mesh
2. Deploying the bookinfo example application
3. Expose the application through the Istio Ingress Gateway using mTLS
4. Accesing an external service using the Istio Egress Gateway
5. Traffic management labs:
   1. Request routing
   2. Traffic shifting and Weight balancing
   3. Fault injection
   4. Requests timeout
   5. Circuit breaking & Outlier detection
6. Security tasks

## OCP configuration
To prepare the environment, follow the guide: [OCP Configuration](./config/README.md)

## Red Hat OpenShift Service Mesh workshop
Let's do the workshop: [OSSM Workshop](./labs/README.md)

## Author

Fran Perea @RedHat<br/>
Kubernesto Gonzalez @RedHat