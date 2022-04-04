#!/bin/bash

for user in $(cat ./users.txt);do
  echo "Adding $user to the mesh-user role"
  oc policy add-role-to-user -n istio-system --role-namespace istio-system mesh-user $user
done

exit