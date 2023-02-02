#!/usr/bin/env bash

microk8s kubectl create secret docker-registry test-secret \
    --docker-username="project-registry" \
    --docker-password="abcd123456" \
    --docker-server=git.example.com:5050

microk8s kubectl get secret test-secret --output=yaml