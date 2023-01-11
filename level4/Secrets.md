# Секреты

Для того чтобы можно было использовать образы из приватного реестра, необходимо создать Секрет и использовать его в спецификации **deployment**.

Допустим, у нас есть приватный реестр `git.example.com:5050` и зарегистрированный пользователь с доступом к реестру. Логин - `test-user` и пароль - `test-password`.

Для создания секрета удобно будет использовать bash-скрипт - [auth.sh](auth.sh):
```bash
#!/usr/bin/env bash

microk8s kubectl create secret docker-registry test-secret \
    --docker-username=test-user \
    --docker-password="test-password" \
    --docker-server=git.example.com:5050

microk8s kubectl get secret test-secret --output=yaml
```

Скрипт создаст секрет с названием `test-secret` и выведет yaml-конфигурацию для него:
```yaml
apiVersion: v1
data:
  .dockerconfigjson: eyJhdXRocyI6eyJnaXQuZXhhbXBsZS5jb206NTA1MCI6eyJ1c2VybmFtZSI6InRlc3QtdXNlciIsInBhc3N3b3JkIjoidGVzdC1wYXNzd29yZCIsImF1dGgiOiJkR1Z6ZEMxMWMyVnlPblJsYzNRdGNHRnpjM2R2Y21RPSJ9fX0=
kind: Secret
metadata:
  creationTimestamp: "2023-01-11T15:24:50Z"
  name: test-secret
  namespace: default
  resourceVersion: "21988309"
  uid: 3a00335a-068c-418a-b0db-dce7b43b6812
type: kubernetes.io/dockerconfigjson
```

В папке `level4/base/secret/` создаем файл `test-secret.yaml` с вышеуказанным содержимым.

И добавляем новый файл в ресурсы в файле [lesson5/base/kustomization.yaml](base/kustomization.yaml):
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - secret/test-secret.yaml
```

После этого можно использовать этот секрет в [спецификации **deployment**](base/webapp/deployment.yaml) по ключу - `spec.template.spec.imagePullSecrets[0].name`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-deploy
  labels:
    name: webapp-deploy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
        - image: git.example.com:5050/test-project/webapp
          name: webapp
          env:
            - name: NODE_ENV
              value: production
          ports:
            - containerPort: 3000
              protocol: TCP

      imagePullSecrets:
        -   name: test-secret
```