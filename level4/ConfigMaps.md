# Конфигурирование - ConfigMaps

При использовании Docker, когда нам необходимо было поместить внутрь контейнера какой-либо конфигурационный файл, то для этого использовалось монтирование тома (отдельного файла или целого каталога). K8s для этих целей использует свой примитив - **ConfigMaps**.

ConfigMaps используется для хранения несекретных данных в виде пар ключ-значение. Стручки (Pod) могут использовать эти данные в виде переменных окружения, аргументов командной строки или как конфигурационные файлы через тома (volume). 

ConfigMap имеет 2 опциональных поля, в которых и хранятся данные - `data` и `binaryData`. `data` используется для хранения UTF-8 строк, а `binaryData` - бинарные данные, закодированные в base64.

## Использование в переменных окружения
Допустим, что для React-приложения необходимо передать через переменные окружения тип окружения (development/production) и базовый хост.

ConfigMap будет следующим:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-conf
data:
  nodeEnv: "production"
  baseHost: "example.com"
```

Использование:
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
        - image: git.example.com:5050/project/webapp
          name: webapp
          env:
            - name: NODE_ENV # Название переменной окружения
              valueFrom:
                configMapKeyRef:
                  name: webapp-conf  # Название из metadata.name ConfigMap.
                  key: nodeEnv # ключ значения из ConfigMap.
                  
            - name: BASE_HOST # Название переменной окружения
              valueFrom:
                configMapKeyRef:
                  name: webapp-conf  # Название из metadata.name ConfigMap.
                  key: baseHost # ключ значения из ConfigMap.
```

## Использование в качестве конфигурационных файлов
Допустим, нам необходимо сконфигурировать Nginx и добавить 2 конфигурационных файла.

Создаем ConfigMap, в котором в качестве ключей будет указано название файла, а в качестве значения - его содержимое:
```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
    name: nginx-conf
data:
    default.conf: |            
        server {
            listen 80 default_server;
        
            server_tokens off;
            proxy_redirect off;
        
            client_max_body_size 128m;
            client_body_buffer_size 4m;
        
            error_page 502 /502.html;
            error_page 500 /500.html;
        
            location ~ ^/(?<error>500|502)\.html$ {
                try_files $uri /$error.html;
                root  /error_pages;
                internal;
            }
            
            location / {
                proxy_http_version 1.1;
                proxy_set_header Connection "upgrade";
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Host $host;
                proxy_set_header X-Forwarded-For $remote_addr;
                # Mitigate httpoxy attack
                proxy_set_header Proxy "";
                
                proxy_intercept_errors off;
                
                resolver 127.0.0.11 ipv6=off valid=10s;
                set $webapp_service webapp;
                proxy_pass http://$webapp_service:3000;
                
                access_log /var/log/nginx/common.access.filebeat.log filebeat;
            }
            
            location ~* ^/(api|bundles|_wdt|_profiler|static-images)/ {
                proxy_http_version 1.1;
                proxy_set_header Connection "upgrade";
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Host $host;
                proxy_set_header X-Forwarded-For $remote_addr;
                # Mitigate httpoxy attack
                proxy_set_header Proxy "";
                
                proxy_intercept_errors off;
                
                proxy_pass http://127.0.0.1:81;
                
                access_log /var/log/nginx/core.access.filebeat.log filebeat;
            }
        }
    00-core.conf: |
        server {
            listen 81 default_server;

            root /opt/project/public;

            client_max_body_size 128m;
            client_body_buffer_size 4m;

            location ~ \.(js|css)\.map$ {
                try_files $uri =404;
            }

            location / {
                try_files $uri /index.php$is_args$args;
                add_header "X-Accel-Buffering" "no";
            }

            location = /index.php {
                resolver 127.0.0.11 ipv6=off valid=10s;
                set $php_fpm_service php-fpm;
                fastcgi_pass $php_fpm_service:9000;
                fastcgi_split_path_info ^(.+\.php)(/.*)$;
                include fastcgi_params;                
                fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
                fastcgi_param DOCUMENT_ROOT $realpath_root;
                fastcgi_param HTTPS on;
                internal;
            }

            # return 404 for all other php files not matching the front controller
            # this prevents access to other php files you don't want to be accessible.
            location ~ \.php$ {
                return 404;
            }
        }
```

Монтировать можно каждый файл в отдельности. Для этого необходимо указать в свойстве `subPath` название файла. А в перечислении томов указать список файлов в свойстве `items`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
    name: nginx
    labels:
        name: nginx
spec:
    replicas: 1
    selector:
        matchLabels:
            app: "nginx"
    template:
        metadata:
            labels:
                app: "nginx"
        spec:
            containers:
                - image: "nginx:latest"
                  name: nginx
                  ports:
                      - containerPort: 80
                        hostPort: 8080
                        protocol: TCP
                  volumeMounts:
                      - name:  nginx-configuration # название тома в spec.template.spec.volumes[].name
                        mountPath: /etc/nginx/conf.d/default.conf
                        subPath: default.conf
                      - name:  nginx-configuration # название тома в spec.template.spec.volumes[].name
                        mountPath: /etc/nginx/conf.d/00-core.conf
                        subPath: 00-core.conf
            volumes:
                - name: nginx-configuration
                  configMap:
                      name: nginx-conf  # Название из metadata.name ConfigMap.                    
                      items:
                      - key: "default.conf"
                        path: "default.conf"
                      - key: "00-core.conf"
                        path: "00-core.conf"  
```

Так имеет смысл делать, если в ConfigMap есть не только файлы, но и простые значения. Но, т.к. наш ConfigMap содержит только файлы, то можно примонтировать сразу все файлы одной директорией:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
    name: nginx
    labels:
        name: nginx
spec:
    replicas: 1
    selector:
        matchLabels:
            app: "nginx"
    template:
        metadata:
            labels:
                app: "nginx"
        spec:
            containers:
                - image: "nginx:latest"
                  name: nginx
                  ports:
                      - containerPort: 80
                        hostPort: 8080
                        protocol: TCP
                  volumeMounts:
                      - name:  nginx-configuration # название тома в spec.template.spec.volumes[].name
                        mountPath: /etc/nginx/conf.d
                        readOnly: true
            volumes:
                - name: nginx-configuration
                  configMap:
                      name: nginx-conf # Название из metadata.name ConfigMap.  
```

## Автоматическое обновление данных при изменении ConfigMap

Если данные были смонтированы как директория (предыдущий пример), то данные в контейнере будут автоматически обновлены через некоторое время (время жизни кэша) без перезапуска контейнера. Но для Nginx это не актуально, т.к. для чтения конфигов, нужно перезапускать Nginx. Если же приложение умеет подхватывать изменения данных без перезапуска, то это может быть полезно.

Если данные были смонтированы отдельными файлами с использованием `subPath` или переданы как переменные окружения, то для обновления данных придется перезапускать контейнеры.

## Особенности

Название ключа может содержать только буквы (нижний регистр), цифры, дефис и точку.