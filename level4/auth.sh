#!/usr/bin/env bash

microk8s kubectl create secret docker-registry test-secret \
    --docker-username=test-user \
    --docker-password="test-password" \
    --docker-server=git.example.com:5050

microk8s kubectl get secret test-secret --output=yaml