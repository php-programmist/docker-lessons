# Секреты

Для того чтобы можно было использовать образы из приватного реестра, необходимо создать Секрет и использовать его в спецификации **deployment**.

Допустим, у нас есть приватный реестр `git.example.com:5050`. Необходимо создать Project Access Token для проекта с реестром образов:
1) Settings -> Access Tokens.
2) Token name - **project-registry**
3) Expiration date - убираем дату, чтобы токен действовал бессрочно
4) Select a role - **Developer**, 
5) Ставим галочку возле **read_registry**.

Полученный токен записываем. Допустим это `abcd123456`

Для создания секрета удобно будет использовать bash-скрипт - [auth.sh](auth.sh):
```bash
#!/usr/bin/env bash

microk8s kubectl create secret docker-registry test-secret \
    --docker-username="project-registry" \
    --docker-password="abcd123456" \
    --docker-server=git.example.com:5050

microk8s kubectl get secret test-secret --output=yaml
```

Скрипт создаст секрет с названием `test-secret` и выведет yaml-конфигурацию для него:
```yaml
apiVersion: v1
data:
    .dockerconfigjson: eyJhdXRocyI6eyJnaXQuZXhhbXBsZS5jb206NTA1MCI6eyJ1c2VybmFtZSI6InByb2plY3QtcmVnaXN0cnkiLCJwYXNzd29yZCI6ImFiY2QxMjM0NTYiLCJhdXRoIjoiY0hKdmFtVmpkQzF5WldkcGMzUnllVHBoWW1Oa01USXpORFUyIn19fQ==
kind: Secret
metadata:
    creationTimestamp: "2023-01-16T17:13:23Z"
    name: test-secret
    namespace: default
    resourceVersion: "7162"
    uid: 909bdb4a-3df1-4ae5-83a8-7bba014c19c1
type: kubernetes.io/dockerconfigjson
```

В папке `level7/base/secret/` создаем файл `test-secret.yaml` с вышеуказанным содержимым.

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