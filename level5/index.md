# Docker Compose

## Назначение
На прошлом уроке мы научились поднимать стек из трех контейнеров. И это уже была не самая тривиальная задача. Нужно было предварительно создать сеть, сложными командами запустить 3 контейнера, а также имеет значение порядок запуска (как Вы могли убедиться, выполняя 3-й пункт домашнего задания).

А если учесть, что в реальных сложных проектах используется более десяти контейнеров, то управлять ими всеми вручную становится невозможно.

Docker Compose - инструмент для запуска и управления мультиконтейнерными приложениями. Он считывает из специального YAML-файла настройки для запуска контейнеров. Одной командой он создает автоматически сеть и запускает все контейнеры, которые прописаны в YAML-файле. К тому же, у нас есть возможность влиять на очередность запуска контейнеров.

## Установка
Есть 2 версии:
1) 1-я версия написана на Python в 2014. Уже включена в дистрибутив Docker. В команде используется так - `docker-compose`. Чтобы проверить наличие, можно проверить версию: `docker-compose -v`. Но данную версию не рекомендуется уже использовать, т.к. в июне 2023 она будет удалена из дистрибутива Docker Desktop.
2) 2-я версия написана на Go и выпушена в середине 2020. В команде используется так - `docker compose` (без дефиса, просто как команда `docker`). Чтобы проверить наличие, можно проверить версию: `docker compose version`. Именно ее мы и будем использовать.

Если команда `docker compose version` выдает ошибку `docker: 'compose' is not a docker command.`, значит Вам необходимо установить CLI плагин.

Для Ubuntu:
```bash
sudo apt-get update && apt-get install docker-compose-plugin
```

Еще раз проверяем версию - `docker compose version`. Должны получить сообщение типа `Docker Compose version v2.16.0`.

## Конфигурационный файл

Для того чтобы файл с настройками автоматически считывался он должен иметь название `docker-compose.yaml`. В противном случае нужно будет указывать файл в опции `-f` (Например, `-f my-file.yaml`).

Для начала давайте перенесем все опции команд `docker run`, которые мы использовали для запуска LEMP-стека на прошлом уроке, в файл `docker-compose.yaml`.

Перейдите в папку `level5/lemp1` и откройте файл [docker-compose.yaml](lemp1/docker-compose.yaml):
```yaml
version: "3.9" # Версия синтаксиса файла

services: # Сервис - это некая обертка над контейнером.
    # Эта задача, которая создает один или несколько контейнеров и контролирует их состояние.
    # В большинстве команд используются именно названия сервисов, а не контейнеров.
    db: # Название сервиса. Оно используется для автоматического определения IP сервиса, а также в секции "depends_on"
        image: mysql:8.0 # Название образа
        environment: # Переменные окружения
            - MYSQL_ROOT_PASSWORD=lemp-pass
            - MYSQL_DATABASE=lemp-db
        volumes: #Тома. Именованный Docker том "db_volume" нужно обязательно указать в корневом элементе "volumes" (в конце файла)
            - db_volume:/var/lib/mysql # Сокращенная запись для Volume mount.
            #Сначала указано название тома, а после двоеточия - абсолютный путь в контейнере

    php-fpm: # Название сервиса.
        image: phpprogrammist/php:8.1-fpm-dev-mysql
        volumes:
            - ./config/php-fpm/local.ini:/usr/local/etc/php/conf.d/local.ini
            - ./core:/var/www/html # Сокращенная запись для Bind mount. 
            #Сначала указан относительный путь на хост-машине, а после двоеточия - абсолютный путь в контейнере
        depends_on: # Зависимости сервиса. Данный сервис будет запущен после запуска сервиса "db"
            - db

    edge: # Название сервиса.
        image: nginx:1.23-alpine
        ports:
            - '8000:80' # Сокращенная запись маппинга портов. 
            # Сначала указывается порт хост-машины, а после двоеточия - порт контейнера.
        volumes:
            - ./config/edge/nginx.conf:/etc/nginx/nginx.conf
            - ./config/edge/php.conf:/etc/nginx/conf.d/php.conf
            - ./core:/var/www/html
        depends_on: # Зависимости сервиса. Данный сервис будет запущен после запуска сервиса "php-fpm"
            - php-fpm

volumes: # Именованные Docker тома, которые используются в сервисах, должны быть перечислены здесь
    db_volume:
```

Из нового - секция `depends_on`, которая помогает запускать сервисы в определенной последовательности.

Также мы нигде не указывали сеть - она создастся автоматически.

## Запуск
Для запуска стека:
```bash
docker compose up -d
```
`-d` указываем, чтобы команда запустилась в фоне. В противном случае в терминал будут выводится логи всех сервисов.

После запуска увидим сообщение о создании сети `lemp1_default`, а также трех контейнеров: `lemp1-db-1`, `lemp1-php-fpm-1`, `lemp1-edge-1`. 

Название контейнера состоит из названия проекта `lemp1` (по названию папки, можно переопределить, указа при запуске проекта в опции `-p` альтернативное название), названия сервиса (указан в `docker-compose.yaml`) и порядкового номера контейнера в сервисе.

Теперь через CURL можно проверить работу стека:
```bash
curl 0.0.0.0:8000/init.php
curl 0.0.0.0:8000
```

И проинспектировать сеть, чтобы увидеть список контейнеров и их IP-адреса:
```bash
docker network inspect lemp1_default
```

## Изолированная среда проекта
Docker Compose помимо всего прочего предоставляет нам изолированную среду в рамках проекта.

Получим список всех запущенных проектов:
```bash
docker compose ls
# NAME                STATUS              CONFIG FILES
# lemp1               running(3)          /opt/docker-lessons/level5/lemp1/docker-compose.yaml
```
Мы можем в командах указывать конкретный проект и взаимодействовать с ним. Для этого используется флаг `-p` или `--project-name`. Флаг указывается сразу после слова `compose`.

Например, для получения списка контейнеров проекта:
```bash
docker compose -p lemp1 ps
```
Мы видим исключительно контейнеры проекта, а не все, запущенные на хосте:
```
NAME                IMAGE                                  COMMAND                  SERVICE             CREATED             STATUS              PORTS
lemp1-db-1          mysql:8.0                              "docker-entrypoint.s…"   db                  8 minutes ago       Up 8 minutes        3306/tcp, 33060/tcp
lemp1-edge-1        nginx:1.23-alpine                      "/docker-entrypoint.…"   edge                8 minutes ago       Up 8 minutes        0.0.0.0:8000->80/tcp, :::8000->80/tcp
```

Когда мы находимся в папке проекта, можно не указывать название проекта в командах:
```bash
docker compose ps
```
Результат такой же, как и выше.

С помощью команды `docker ps` Вы увидите абсолютно все запущенные контейнеры на хосте, в т.ч. и контейнеры проекта `lemp1`.

---
Список образов проекта:
```bash
docker compose images
# CONTAINER           REPOSITORY           TAG                 IMAGE ID            SIZE
# lemp1-db-1          mysql                8.0                 05b458cc32b9        517MB
# lemp1-edge-1        nginx                1.23-alpine         c433c51bbd66        40.7MB
# lemp1-php-fpm-1     phpprogrammist/php   8.1-fpm-dev-mysql   424b604c14f8        112MB
```
---
Список процессов в контейнерах:
```bash
docker compose top
```
---
Публичный порт сервиса:
```bash
docker compose port edge 80
0.0.0.0:8000
```
--- 
Просмотр логов.

Все сервисы:
```bash
docker compose logs
```
Только сервис `php-fpm`:
```bash
docker compose logs php-fpm
```
В последних строчках вы должны увидеть запросы, которые мы делали через CURL.
```
lemp1-php-fpm-1  | 172.31.0.4 -  10/Feb/2023:14:43:17 +0000 "GET /init.php" 200
lemp1-php-fpm-1  | 172.31.0.4 -  10/Feb/2023:14:43:19 +0000 "GET /index.php" 200
```

Логи можно запустить в режиме "слежения", добавив флаг `-f`:
```bash
docker compose logs -f php-fpm
```
Для выхода нажимаем `CTRL+C`.

---
Рестарт контейнеров:
```bash
docker compose restart
```
или перезапустить только контейнер сервиса `edge`:
```bash
docker compose restart edge
```
---
Выполнение команд в контейнере сервиса:
```bash
docker compose exec -it -w /var/www/html php-fpm ash
```
`-w /var/www/html` - устанавливает рабочую папку.
---
Остановка и удаление контейнеров и сетей проекта:
```bash
docker compose down --remove-orphans
```
`--remove-orphans` - удаляет также сервисы, которые не определены в Compose-файле, но были запущены в этом проекте. Обычно такое бывает при переименовании сервисов в Compose-файле.

Если же необходимо удалить и именованные Docker тома, то необходимо добавить флаг `-v`.

## Развернутый синтаксис и сборка образов
В предыдущем примере мы использовали сокращенный синтаксис для некоторых полей (`ports` и `volumes`). Но есть также и развернутый синтаксис, который мы используем в следующем файле. А также рассмотрим еше несколько нововведений.

Перейдем в папку `level5/lemp2` и рассмотрим файл [docker-compose.yaml](lemp2/docker-compose.yaml):
```yaml
version: "3.9"

services:
    db:
        image: mysql:5.7
        environment:
            - MYSQL_ROOT_PASSWORD=lemp-pass
            - MYSQL_DATABASE=lemp-db
        volumes: # Развернутый синтаксис монтирования
            -   type: volume # Тип монтирования
                source: db_volume # название тома.
                # "db_volume" нужно обязательно указать в корневом элементе "volumes" (в конце файла)
                target: /var/lib/mysql #абсолютный путь в контейнере

        healthcheck: # Проверка работоспособности сервиса.
            # Переопределяет инструкцию HEALTHCHECK в Dockerfile.
            # Если команда проверки выполнена успешно, то сервис получает статус HEALTHY.
            test: mysqladmin ping -h 127.0.0.1 -u root --password=$$MYSQL_ROOT_PASSWORD # Команада проверки.
            interval: 5s # Интервал проверки
            retries: 10 # Количество неуспешных попыток. Когда будет достигнуто, сервис получит статус UNHEALTHY

    php-fpm:
        image: phpprogrammist/php:8.1-fpm-dev-mysql
        build: images/php-fpm # Относительный путь к Dockerfile для сборки образа для данного контейнера.
        # Позволяет при использовании команды "docker compose build" произвести сборку всех образов, указанных в поле "build".
        # Либо можно запустить сборку для конкретного сервиса "docker compose build php-fpm"
        volumes:
            -   type: bind
                source: ./config/php-fpm/local.ini
                target: /usr/local/etc/php/conf.d/local.ini
            -   type: bind # Тип монтирование связыванием
                source: ./core # Папка хост-машины. Относительный путь. Должен начинаться с "." или ".."
                target: /var/www/html #абсолютный путь в контейнере
        depends_on:
            db:
                condition: service_healthy # сервис "php-fpm" будет запущен после сервиса "db",
                # но только после того, как он пройдет проверку на работоспособность

    edge:
        image: nginx:1.23-alpine
        networks:
            default: null
        ports: # Развернутый синтаксис маппинга портов
            -   mode: ingress # Режим. "host" - публикует порт на каждой ноде. "ingress" - использует балансировщик нагрузки
                target: 80 # Порт контейнера
                published: 8001 # Порт хост-машин
                protocol: tcp # Протокол: tcp или udp
        volumes: # Развернутый синтаксис монтирования
            -   type: bind
                source: ./config/edge/nginx.conf
                target: /etc/nginx/nginx.conf
            -   type: bind
                source: ./config/edge/php.conf
                target: /etc/nginx/conf.d/php.conf
            -   type: bind
                source: ./core
                target: /var/www/html
        depends_on:
            - php-fpm

volumes: # Именованные Docker тома, которые используются в сервисах, должны быть перечислены здесь
    db_volume:
```

Теперь запустим проект:
```bash
docker compose up -d
#[+] Running 4/4
# ⠿ Network lemp2_default      Created   0.2s
# ⠿ Container lemp2-db-1       Healthy   7.7s
# ⠿ Container lemp2-php-fpm-1  Started   9.0s
# ⠿ Container lemp2-edge-1     Started  10.3s
```
Как видим, пока у контейнера `lemp2-db-1` не появился статус `Healthy`, остальные контейнеры не стартуют.

## Домашнее задание
1) Познакомьтесь с полным списком команд Docker Compose (`docker compose --help`). И попробуйте использовать эти команды. Наиболее полезные запишите в свой конспект.
2) Поместите в папку `level5/lemp2/core` готовое приложение Symfony, настройте подключение к БД. В файле `level5/lemp2/config/edge/php.conf` необходимо будет немного изменить корневую директорию (6-я строка, директива `root`), т.к. Nginx должен отдавать в мир только папку `public`, а не всю директорию `core`. Запустите контейнеры, указав в Compose-файле для Nginx порт, который доступен из браузера для вашего стенда. Создайте bash-скрипты для установки зависимостей через Composer и выполнения миграций.
3) Поднимите стек [MERN](https://medium.com/mozilla-club-bbsr/dockerizing-a-mern-stack-web-application-ebf78babf136) (Mongo Express React Node). Обратите внимание, что в статье используется 1-я версия Docker Compose. Просто замените `docker-compose` на `docker compose` при выполнении команд.