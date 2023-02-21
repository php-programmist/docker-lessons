# Docker Swarm

Docker Compose идеально подходит для целей разработки и для продакшена небольших проектов с низкой нагрузкой. Но при увеличении нагрузки на сайт может не хватать ресурсов сервера. И тогда есть 2 выхода: 
1) Перенести приложение на более мощный сервер
2) Разделить приложение между несколькими серверами

Первый вариант очевиден, но имеет ограничения, т.к. мы не сможем бесконечно наращивать ресурсы на одном сервере. К тому же, если этот сервер упадет, то весь сайт станет недоступен.

Второй же вариант является идеальным для высоко нагруженных проектов, т.к. теоретически мы можем добавить в кластер сколько угодно серверов. А также выход из строя одного или нескольких серверов не приведет к серьезным последствиям.

Для управления Docker-контейнерами на нескольких серверах (нодах) используются оркестраторы: **Docker Swarm** или **Kubernetes**.

Сегодня мы рассмотрим **Docker Swarm**, который доступен из "коробки", и является дефолтным оркестратором.

## Основные понятия

### Сервис

Service является описанием того, какие контейнеры и в каком количестве будут создаваться. В отличие от сервисов Docker Compose поддерживает ряд дополнительных полей , большинство из которых находятся внутри секции [deploy](https://docs.docker.com/compose/compose-file/compose-file-v3/#deploy).

### Стек
Stack - это набор сервисов, которые логически связаны между собой. По сути это набор сервисов, которые описываются в обычном compose-файле.

### Нода

Node - это виртуальная машина, на которой установлен docker.

### Кластер

Cluster - это совокупность нод, объединенных в одну сеть. Состоит из одной **manager**-ноды и нескольких **worker**-нод (хотя можно обойтись из без **worker**-нод). **Manager**-нода управляет **worker**-нодами. Она отвечает за создание/обновление/удаление сервисов на **worker**-нодах, а также за их масштабирование и поддержку в требуемом состоянии. **Worker**-ноды используются только для выполнения поставленных задач и не могут управлять кластером.

## Создание кластера

В облаке создал 3 ВМ с названиями: **manager**, **worker-1** и **worker-2**

Установил на них Docker Engine согласно [инструкции](https://docs.docker.com/engine/install/ubuntu/)

На ноде **manager** выполняем команду инициализации кластера:
```bash
docker swarm init
```
Получим сообщение такого вида:
```
Swarm initialized: current node (wlcc3dy4ucbvm2x6lafueqr4i) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-5wfawqq1ouz0x57ou2h0mvh9uyy6143sz2fq8qf4gvlbv3zejg-1sluf5p8c3x067rcahck7j53u 10.129.0.16:2377

To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.
```
В сообщении содержится команда, которую необходимо будет выполнить на каждой **worker**-ноде:
```bash
docker swarm join --token SWMTKN-1-5wfawqq1ouz0x57ou2h0mvh9uyy6143sz2fq8qf4gvlbv3zejg-1sluf5p8c3x067rcahck7j53u 10.129.0.16:2377
```
Получим сообщение: `This node joined a swarm as a worker.`

Теперь на ноде **manager** можно получить список всех нод кластера:
```bash
docker node ls

# ID                            HOSTNAME   STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
# wlcc3dy4ucbvm2x6lafueqr4i *   manager    Ready     Active         Leader           23.0.1
# bmsrvqgmtn5p5qli61kyjubnl     worker-1   Ready     Active                          23.0.1
# fqhhzof1ya27wb5k7ea9s9h5t     worker-2   Ready     Active                          23.0.1

```
В первой колонке звездочкой отмечен **Manager**, а также в колонке **MANAGER STATUS** указано `Leader`.

**Внимание!** Все последующие команды необходимо выполнять на **Manager**-ноде!

## Создание сети с драйвером Overlay
Для того чтобы контейнеры могли взаимодействовать друг с другом, необходимо, чтобы они находились в одной сети. Но т.к. контейнеры могут находиться на разных нодах, то драйвер `bridge` для этих целей не подойдет. Воспользуемся драйвером `overlay`, который позволяет создать распределенную сеть на нескольких нодах:
```bash
docker network create -d overlay lemp-overlay
```
Проверим, что сеть добавилась:
```bash
docker network ls
# NETWORK ID     NAME              DRIVER    SCOPE
# ...
# 16bkoy9twt81   lemp-overlay      overlay   swarm
```

## Развертывание стеков
Необходимо скопировать на все ноды содержимое папки `level6`.

Переходим в папку `/opt/docker-lessons/level6/lemp1/compose`.

В ней есть 3 файла, каждый из которых будет отвечать за один стек. В данном примере стеки будут включать в себя по одному сервису.

Рассмотрим файлы стеков подробнее.

[edge.yaml](lemp1/compose/edge.yaml)
```yaml
version: "3.9"

services:
    gateway:
        image: nginx:1.23-alpine
        hostname: "gateway-{{.Node.Hostname}}" # Шаблон для формирования названия хоста
        deploy:
            mode: global # на каждой ноде будет поднята одна реплика
            restart_policy:
                condition: any # перезапускать при остановке всегда
        networks:
            - lemp-overlay # Сеть также нужно указать дополнительно в корневом поле networks (внизу файла)
        ports:
            -   mode: host # Режим. "host" - публикует порт на каждой ноде. "ingress" - использует балансировщик нагрузки
                target: 80 # Порт контейнера
                published: 80 # Порт хост-машин
                protocol: tcp # Протокол: tcp или udp
        volumes: # Развернутый синтаксис монтирования
            -   type: bind
                source: ../config/edge/nginx.conf
                target: /etc/nginx/nginx.conf
            -   type: bind
                source: ../config/edge/default.conf
                target: /etc/nginx/conf.d/default.conf
            -   type: bind
                source: ../core
                target: /var/www/html
# Указываем созданную вручную сеть
networks:
    lemp-overlay:
        external: true # Отметка о том, что сеть создается вручную
```

[core.yaml](lemp1/compose/core.yaml):
```yaml
version: "3.9"

services:
    php-fpm:
        image: phpprogrammist/php:8.1-fpm-dev-mysql
        hostname: "php-fpm-{{.Node.Hostname}}"
        deploy:
            mode: replicated # будет создано столько реплик, сколько указано ниже.
            replicas: 6 # создастся 6 контейнеров и будут равномерно распределены по надом
            restart_policy:
                condition: any # перезапускать при остановке всегда
        networks:
            - lemp-overlay # Сеть также нужно указать дополнительно в корневом поле networks (внизу файла)
        volumes:
            -   type: bind
                source: ../config/php-fpm/local.ini
                target: /usr/local/etc/php/conf.d/local.ini
            -   type: bind
                source: ../core
                target: /var/www/html

networks:
    lemp-overlay:
        external: true
```

[storage.yaml](lemp1/compose/storage.yaml):
```yaml
version: "3.9"

services:
    db:
        image: mysql:5.7
        hostname: "db-{{.Node.Hostname}}"
        deploy:
            mode: replicated
            replicas: 1 # Одна реплика потому, что в противном случае у каждой ноды будет своя БД и данные между ними не будут синхронизироваться
            restart_policy:
                condition: any
        environment:
            - MYSQL_ROOT_PASSWORD=lemp-pass
            - MYSQL_DATABASE=lemp-db
        networks:
            - lemp-overlay # Сеть также нужно указать дополнительно в корневом поле networks (внизу файла)
        volumes: # Развернутый синтаксис монтирования
            -   type: volume
                source: db_volume # название тома.
                # "db_volume" нужно обязательно указать в корневом элементе "volumes" (в конце файла)
                target: /var/lib/mysql

        healthcheck: # Проверка работоспособности сервиса.
            test: mysqladmin ping -h 127.0.0.1 -u root --password=$$MYSQL_ROOT_PASSWORD
            interval: 5s
            retries: 10

volumes: # Именованные Docker тома, которые используются в сервисах, должны быть перечислены здесь
    db_volume:

networks:
    lemp-overlay:
        external: true
```

Запускаем стек `edge`:
```bash
docker stack deploy -c ./edge.yaml --with-registry-auth edge
```
`-c ./edge.yaml` - путь к compose-файлу стека

`--with-registry-auth` - позволяет передать авторизационные данные на worker ноды, для того чтобы использовался один и тот же образ из реестра. Нужно для образов, размещенных в приватных реестрах.

`edge` - название стека

Просмотрим список сервисов:
```bash
docker service ls
# ID             NAME          MODE      REPLICAS   IMAGE               PORTS
# kbdgd8wydc0e   edge_gateway  global    0/1      nginx:1.23-alpine
```
Название сервиса (`edge_gateway`) состоит из названия стека и названия, указанного в compose-файле.

В колонке `REPLICAS` видим, что запущено 0 реплик из одной. Значит, контейнер не запущен.

Выясняем причину:
```bash
docker service ps --no-trunc edge_gateway
# ID             NAME                                      IMAGE               NODE       DESIRED STATE   CURRENT STATE          ERROR                       PORTS
# 9x1oafqi6c2y   edge_gateway.bmsrvqgmtn5p5qli61kyjubnl       nginx:1.23-alpine   worker-1   Ready           Ready 2 seconds ago                                
# wdfegca9h7bj    \_ edge_gateway.bmsrvqgmtn5p5qli61kyjubnl   nginx:1.23-alpine   worker-1   Shutdown        Failed 3 seconds ago   "task: non-zero exit (1)"   
# t1y7m7sro9ci   edge_gateway.fqhhzof1ya27wb5k7ea9s9h5t       nginx:1.23-alpine   worker-2   Ready           Ready 3 seconds ago                                
# y8vqvujt8n0p    \_ edge_gateway.fqhhzof1ya27wb5k7ea9s9h5t   nginx:1.23-alpine   worker-2   Shutdown        Failed 4 seconds ago   "task: non-zero exit (1)"   
# gl22cs6pckhn   edge_gateway.wlcc3dy4ucbvm2x6lafueqr4i       nginx:1.23-alpine   manager    Ready           Ready 2 seconds ago                                
# jkcvp78r4tvr    \_ edge_gateway.wlcc3dy4ucbvm2x6lafueqr4i   nginx:1.23-alpine   manager    Shutdown        Failed 3 seconds ago   "task: non-zero exit (1)" 
```
Как видим, сервис пытается запустить контейнер на всех трех нодах, но возникает ошибка "task: non-zero exit (1)". Согласно настроек в compose-файле `services.gateway.deploy.restart_policy.condition=any` сервис будет "вечно" пытаться запустить контейнеры. Поэтому не оставляйте без внимания на долго такие проблемы, иначе будут проблемы с нагрузкой на процессор и увеличится износ диска.

Копаем глубже - смотрим логи сервиса:
```bash
docker service logs edge_gateway
```
И в конце лога увидим строчки:
```log
edge_edge.0.qfzeecpuwewm@manager    | 2023/02/19 16:22:37 [emerg] 1#1: host not found in upstream "php-fpm" in /etc/gateway/conf.d/default.conf:11
edge_edge.0.qfzeecpuwewm@manager    | gateway: [emerg] host not found in upstream "php-fpm" in /etc/nginx/conf.d/default.conf:11
```
Из лога можно понять, что проблема из-за того, что невозможно найти хост "php-fpm", который указан, в конфигурационном файле. Что вполне логично, т.к. мы не запустили стек с "php-fpm".

Запускаем этот стек:
```bash
docker stack deploy -c ./core.yaml --with-registry-auth core
```

Проверяем список сервисов:
```bash
docker service ls
# ID             NAME           MODE         REPLICAS   IMAGE                                  PORTS
# 9cp6ujclcam6   core_php-fpm   replicated   6/6        phpprogrammist/php:8.1-fpm-dev-mysql   
# sm4iynzkp4km   edge_gateway   global       3/3        nginx:1.23-alpine                      
```

Как видим, сервис `edge_gateway` "починился" автоматически, т.к. после запуска сервиса `php-fpm` после очередной попытки запустить `edge_gateway` в сети появился нужный сервис.

Смотрим подробности сервиса `core_php-fpm`:
```bash
docker service ps core_php-fpm
# ID             NAME             IMAGE                                  NODE       DESIRED STATE   CURRENT STATE            ERROR     PORTS
# ya78k59ukvw0   core_php-fpm.1   phpprogrammist/php:8.1-fpm-dev-mysql   worker-2   Running         Running 25 seconds ago             
# oyv6ogbgcglu   core_php-fpm.2   phpprogrammist/php:8.1-fpm-dev-mysql   manager    Running         Running 25 seconds ago             
# yg9a69jz3i5o   core_php-fpm.3   phpprogrammist/php:8.1-fpm-dev-mysql   worker-1   Running         Running 25 seconds ago             
# yruuka4t464s   core_php-fpm.4   phpprogrammist/php:8.1-fpm-dev-mysql   worker-2   Running         Running 25 seconds ago             
# pqe95cy9z4cu   core_php-fpm.5   phpprogrammist/php:8.1-fpm-dev-mysql   manager    Running         Running 25 seconds ago             
# t5dxc6qoeb7k   core_php-fpm.6   phpprogrammist/php:8.1-fpm-dev-mysql   worker-1   Running         Running 25 seconds ago
```
Как видим, было запущено 6 реплик - по 2 на каждой ноде.

Развернем последний стек - с базой данных:
```bash
docker stack deploy -c ./storage.yaml --with-registry-auth storage
```

Проверяем список сервисов:
```bash
docker service ls
# ID             NAME           MODE         REPLICAS   IMAGE                                  PORTS
# hkcutarqolj3   core_php-fpm   replicated   6/6        phpprogrammist/php:8.1-fpm-dev-mysql   
# sm4iynzkp4km   edge_gateway   global       3/3        nginx:1.23-alpine                      
# 163oxysumb7z   storage_db     replicated   1/1        mysql:5.7                    
```
Поднялась 1 реплика БД (если быстро запросить список сервисов, то можно увидеть 0/1, т.к. для запуска БД требуется несколько больше времени)

Смотрим подробности по сервису `storage_db`
```bash
docker service ps storage_db

# ID             NAME           IMAGE       NODE       DESIRED STATE   CURRENT STATE            ERROR     PORTS
# li1znapciinx   storage_db.1   mysql:5.7   worker-2   Running         Running 20 seconds ago 
```
Видим, что создалась реплика на одной из нод.

---
Просмотреть список стеков:
```bash
docker stack ls
# NAME      SERVICES
# core      1
# edge      1
# storage   1
```
---
Просмотреть список процессов в стеке:
```bash
docker stack ps edge

# ID             NAME                                     IMAGE               NODE       DESIRED STATE   CURRENT STATE            ERROR     PORTS
# io8aaj5zskmi   edge_gateway.fqhhzof1ya27wb5k7ea9s9h5t   nginx:1.23-alpine   worker-2   Running         Running 11 minutes ago             *:80->80/tcp,*:80->80/tcp
# rfuk9jzdu0hr   edge_gateway.wlcc3dy4ucbvm2x6lafueqr4i   nginx:1.23-alpine   manager    Running         Running 11 minutes ago             *:80->80/tcp,*:80->80/tcp
# 6dqwn4pss38y   edge_gateway.x1frrpcgk6qwpo6j8h4eh70lk   nginx:1.23-alpine   worker-1   Running         Running 11 minutes ago             *:80->80/tcp,*:80->80/tcp
```
---
Список сервисов в стеке:
```bash
docker stack services edge
# ID             NAME           MODE      REPLICAS   IMAGE               PORTS
# q4pnbhx0xd9x   edge_gateway   global    3/3        nginx:1.23-alpine
```

## Инспектирование сети и взаимодействие между контейнерами
На ноде `manager` инспектируем сеть `lemp-overlay`:
```bash
docker network inspect lemp-overlay
```
В секции "Containers" мы увидим только контейнеры, которые запущены на этой ноде:
```json
{
  "Containers": {
    "5ae5279435facbb5cb1d6c44b935f07a7c3855a7bbbceb21f39d48d1aa38f86e": {
      "Name": "core_php-fpm.1.vaj0tlpkqj3iiksrtofvgr55g",
      "EndpointID": "1f8e4046d9bc181e687672063a693ec7320bbaddc8839e76137a1ab15378dbbc",
      "MacAddress": "02:42:0a:00:01:1b",
      "IPv4Address": "10.0.1.27/24",
      "IPv6Address": ""
    },
    "5d9fb58297608e2a293edc6082df42855e8085d4f5ad993c93e0608ba0a9c623": {
      "Name": "core_php-fpm.4.wow356usay9om2ggavgl0urgm",
      "EndpointID": "ada8e20265c79cd41bf673ac32f2d97476f9f8783301d2b960d27a664830b371",
      "MacAddress": "02:42:0a:00:01:1e",
      "IPv4Address": "10.0.1.30/24",
      "IPv6Address": ""
    },
    "c52cac51e19a76ef3e3e7fde6496407e753ceae84b6024f259c82f5977df10a7": {
      "Name": "edge_gateway.wlcc3dy4ucbvm2x6lafueqr4i.mmmgn84j0ggzk7em0r3xcdgze",
      "EndpointID": "aa252b8f60b94958104219d1455274c43ddb30549715be21cfa5531012e79453",
      "MacAddress": "02:42:0a:00:01:23",
      "IPv4Address": "10.0.1.35/24",
      "IPv6Address": ""
    },
    "lb-lemp-overlay": {
      "Name": "lemp-overlay-endpoint",
      "EndpointID": "17381336fce4599ba98c9573fbdee3995e78841e41e2a69c10d39e026797bcdf",
      "MacAddress": "02:42:0a:00:01:05",
      "IPv4Address": "10.0.1.5/24",
      "IPv6Address": ""
    }
  }
}
```

Теперь запустим эту же команду на ноде `worker-2`:
```json
{
  "Containers": {
    "02d1a7f874ff77bbb0d62b181583d994feb5d85697d96e8f3acac760f264bd96": {
      "Name": "edge_gateway.fqhhzof1ya27wb5k7ea9s9h5t.xhke46fn1ewr2sx9o14o1j5jt",
      "EndpointID": "a29a9bc229e4cfa7d05637fbc5ef645e4c57b8f9c1039ba4a49493e81a1ff78b",
      "MacAddress": "02:42:0a:00:01:22",
      "IPv4Address": "10.0.1.34/24",
      "IPv6Address": ""
    },
    "33a5f399e352ee3521506e789626bce7b82c8272c899a1b65406bdd63220d74d": {
      "Name": "core_php-fpm.3.pskyqcgrhvjhvkwzgo7h9d0dy",
      "EndpointID": "7f6c29ecff48435863abf6ca296b2664762a58faf1c801d607ec9e5a50928751",
      "MacAddress": "02:42:0a:00:01:1d",
      "IPv4Address": "10.0.1.29/24",
      "IPv6Address": ""
    },
    "b58fd52c14786c27af528f68e3479372c8e342d4f83c5bb644957e5a22a5d169": {
      "Name": "core_php-fpm.6.jku4vwu3y367pwr5bmasdb2b5",
      "EndpointID": "dc0eed137c64a1ceba6c42665704f54f6acf19c574bdadd51615788de63da0f6",
      "MacAddress": "02:42:0a:00:01:20",
      "IPv4Address": "10.0.1.32/24",
      "IPv6Address": ""
    },
    "c7d4f69f90cddc89aa39889461e958b20d53f51d73e99437f3af2fb49de378a1": {
      "Name": "storage_db.1.xksb93dqzxp7w5tkfpcgrc2kl",
      "EndpointID": "b9111d541686051148096f8a96ba63dccabe8dfca21adea5ec3aba72f8d82110",
      "MacAddress": "02:42:0a:00:01:26",
      "IPv4Address": "10.0.1.38/24",
      "IPv6Address": ""
    },
    "lb-lemp-overlay": {
      "Name": "lemp-overlay-endpoint",
      "EndpointID": "e810fa3a2d5c7e648f4d5a1ee8bb3d963aca98a667247d873e2779e9f591cbf5",
      "MacAddress": "02:42:0a:00:01:08",
      "IPv4Address": "10.0.1.8/24",
      "IPv6Address": ""
    }
  }
}
```
Здесь мы видим контейнеры этой ноды.

Из контейнера `edge_gateway...` на ноде `worker-2` пингуем по IP-адресу контейнер `core_php-fpm.5...`, который находится на ноде `manager`:

```bash
docker exec -it edge_gateway.fqhhzof1ya27wb5k7ea9s9h5t.xhke46fn1ewr2sx9o14o1j5jt ping -c 2 10.0.1.27

# PING 10.0.1.27 (10.0.1.27): 56 data bytes
# 64 bytes from 10.0.1.27: seq=0 ttl=64 time=0.596 ms
# 64 bytes from 10.0.1.27: seq=1 ttl=64 time=0.450 ms

# --- 10.0.1.27 ping statistics ---
# 2 packets transmitted, 2 packets received, 0% packet loss
# round-trip min/avg/max = 0.450/0.523/0.596 ms
```
Пинг был успешным несмотря на то, что контейнер находится на другой ноде.

А теперь выполним пинг из того же контейнера, но указав название сервиса вместо IP:
```bash
docker exec -it edge_gateway.fqhhzof1ya27wb5k7ea9s9h5t.xhke46fn1ewr2sx9o14o1j5jt ping -c 2 php-fpm

# PING php-fpm (10.0.1.26): 56 data bytes
# 64 bytes from 10.0.1.26: seq=0 ttl=64 time=0.104 ms
# 64 bytes from 10.0.1.26: seq=1 ttl=64 time=0.077 ms

# --- php-fpm ping statistics ---
# 2 packets transmitted, 2 packets received, 0% packet loss
# round-trip min/avg/max = 0.077/0.090/0.104 ms
```
Пинг прошел успешно и IP сервиса определен как `10.0.1.26`. Но если мы еще раз посмотрим на данные инспектирования сети на всех трех нодах, то не найдем контейнера с таким IP адресом.

Дело в том, что каждый сервис может включать в себя несколько контейнеров. Поэтому у каждого сервиса есть встроенный балансировщик нагрузки, который определяет в какой контейнер направить запрос. Балансировщик находится на так называемом виртуальном IP (VIP).

Чтобы узнать этот адрес, необходимо проинспектировать сервис:
```bash
docker inspect service core_php-fpm
```
В самом низу увидим поле **Endpoint**, в котором и указан виртуальный IP:
```json
{
  "Endpoint": {
    "Spec": {
      "Mode": "vip"
    },
    "VirtualIPs": [
      {
        "NetworkID": "16bkoy9twt814ub6le0y4epwx",
        "Addr": "10.0.1.26/24"
      }
    ]
  }
}
```

## Проверка работы через браузер
Сейчас 80-й порт Nginx связан с 80-м портом каждой ноды благодаря `mode: host` в настройках портов.

Поэтому можем взять публичный IP-адрес любой из нод и открыть его в браузере:

`http://158.160.30.163` - manager

`http://158.160.24.30` - worker-2

Сейчас список постов пуст на обеих нодах. Запустим скрипт инициализации на `manager`:
`http://158.160.30.163/init.php`

Проверим еще раз индексные страницы - данные появились на обеих нодах, т.к. все ноды подключены к одной базе данных.

Также обратите внимание на название хоста - оно все время меняется. Т.е. мы отправляем запросы на ноду `manager`, а запрос перенаправляется в контейнеры `php-fpm` разных нод. Так и работает балансировщик нагрузки.

Теперь можно удалить стеки и том БД:
```bash
docker stack rm edge core storage && docker volume rm storage_db_volume
```

Для удобства запуска, остановки и перезапуска добавил 3 bash-скрипта: [up.sh](lemp1/up.sh), [down.sh](lemp1/down.sh), [restart.sh](lemp1/restart.sh). Не забывайте добавлять права на исполнение (`chmod +x *.sh`) перед первым использованием.