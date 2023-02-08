# Взаимодействие между контейнерами

## Сети

Если контейнеры находятся внутри одной сети, то нет необходимости публиковать порты контейнеров, т.к. они могут взаимодействовать напрямую с любым портом другого контейнера.

### Сети по-умолчанию

 Если мы не создавали ни одной сети, то по умолчанию их будет три.

Получить список сетей:
```bash
docker network ls

#NETWORK ID          NAME                DRIVER              SCOPE
#f1d002da9b57        bridge              bridge              local
#1ebafad80f59        host                host                local
#a85451f02880        none                null                local
```
ID сетей будут другие, но названия и драйверы должны быть такими.

На самом деле, `host` и `none` не являются полноценными сетями, но об этом поговорим позже.

Если контейнер запускается без указания конкретной сети, то он будет подключен к дефолтной сети `bridge`.

Запустим 2 контейнера:
```bash
docker run --rm -dit --name edge nginx:1.23-alpine ash
docker run --rm -dit --name php-fpm php:8.1-fpm-alpine ash
```
Оба контейнера будут запущены в интерактивном режиме, но в фоне. А также будет запущена оболочка alpine - `ash`.

Убедимся, что контейнеры запущены:
```bash
docker container ls

CONTAINER ID        IMAGE                COMMAND                  CREATED             STATUS              PORTS         NAMES
645d7cb06471        php:8.1-fpm-alpine   "docker-php-entrypoi…"   42 seconds ago      Up 41 seconds       9000/tcp      php-fpm
13a624fe9368        nginx:1.23-alpine          "/docker-entrypoint.…"   2 minutes ago       Up 2 minutes        80/tcp        edge

```

Инспектируем сеть `brige`:
```bash
docker network inspect bridge
```
Найдем секцию `Containers`:

```json
{
  "Containers": {
    "5b51e24930736aadd585194a53840aa09e48df95f1568c35f3fbcfdd54301742": {
      "Name": "edge",
      "EndpointID": "53daaf3cae336a888c812735fbf6b0ecf57e5440da866b8f776d025fa0f7616d",
      "MacAddress": "02:42:ac:11:00:02",
      "IPv4Address": "172.17.0.2/16",
      "IPv6Address": ""
    },
    "645d7cb0647116057d18c876fbaee07a7cd9ac6bec66398b5678f0bb75ecd138": {
      "Name": "php-fpm",
      "EndpointID": "a01f8dd8163ebbc3861f135bedf55cb716c2947a000939c88b953872a5c7a9df",
      "MacAddress": "02:42:ac:11:00:03",
      "IPv4Address": "172.17.0.3/16",
      "IPv6Address": ""
    }
  }
}
```
Видим наши 2 контейнера. У контейнера `edge` IP-адрес `172.17.0.2`, а у `php-fpm` - `172.17.0.3`.

Войдем в контейнер `edge`:
```bash
docker attach edge
```

`docker attach` извлекает контейнер из фона и присоединяет к нему терминал.

Теперь пробуем пинговать "свой" IP-адрес, IP контейнера `php-fpm` (`172.17.0.3`) и несуществующий в данной сети IP `172.17.0.4`.

```
/ # ping 172.17.0.2 -c 2
PING 172.17.0.2 (172.17.0.2): 56 data bytes
64 bytes from 172.17.0.2: seq=0 ttl=64 time=0.381 ms
64 bytes from 172.17.0.2: seq=1 ttl=64 time=0.129 ms

--- 172.17.0.2 ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.129/0.255/0.381 ms
/ # ping 172.17.0.3 -c 2
PING 172.17.0.3 (172.17.0.3): 56 data bytes
64 bytes from 172.17.0.3: seq=0 ttl=64 time=0.422 ms
64 bytes from 172.17.0.3: seq=1 ttl=64 time=0.246 ms

--- 172.17.0.3 ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.246/0.334/0.422 ms

/ # ping 172.17.0.4 -c 2
PING 172.17.0.4 (172.17.0.4): 56 data bytes

--- 172.17.0.4 ping statistics ---
2 packets transmitted, 0 packets received, 100% packet loss
```
Первые 2 пинга успешны, а третий - нет.

Попробуем сделать пинг по имени контейнера и получим ошибку:
```
/ # ping php-fpm -c 2
ping: bad address 'php-fpm'
```

Теперь можно обратно отправить контейнер `edge` в фон - для этого необходимо удерживая `CTRL`, нажать последовательно `p` и `q`. 

Из контейнера `php-fpm` можно сделать то же самое.

Теперь можно остановить контейнеры:
```bash
docker stop edge php-fpm
```

### Пользовательские сети

В режиме разработки рекомендуется для каждого проекта создавать свою отдельную сеть. Во-первых, это позволит изолировать контейнеры разных проектов друг от друга, а во вторых - в таких сетях можно будет обращаться к контейнерам по их именам!

Создадим сеть `first-net`:
```bash
docker network create --driver bridge first-net
```
В качестве драйвера указываем `bridge`.

Теперь найдем сеть в списке:
```bash
docker network ls
#NETWORK ID          NAME                DRIVER              SCOPE
#cf28e5a21500        first-net           bridge              local
```

Запустим контейнеры, указав им новую сеть в опции `--network`:
```bash
docker run --rm -dit --network first-net --name edge nginx:1.23-alpine ash
docker run --rm -dit --network first-net --name php-fpm php:8.1-fpm-alpine ash
```

Инспектируем сеть `first-net`:
```bash
docker network inspect first-net
```
Находим секцию "Containers":
```json
{
  "Containers": {
    "78e255a4828b1f447ddb0ffa00a6a7c3dd28e8b5c18f06a69b94db3048f55bb5": {
      "Name": "edge",
      "EndpointID": "2088d6fde3cb1db06bffae8ec83b5d2d87c53d4309ee03c670cebf4cf46f3fa4",
      "MacAddress": "02:42:ac:14:00:02",
      "IPv4Address": "172.20.0.2/16",
      "IPv6Address": ""
    },
    "df31d3cdbd51a304ee438a2093794ee53ce634761fa1aced4b20323f18424746": {
      "Name": "php-fpm",
      "EndpointID": "6273dc7831a53d8373fccda88aa19875dc015cf7172736e53b34f16dd984c1f2",
      "MacAddress": "02:42:ac:14:00:03",
      "IPv4Address": "172.20.0.3/16",
      "IPv6Address": ""
    }
  }
}
```
Обратите внимание, что теперь адреса в контейнере изменились:

`edge` - `172.20.0.2`, а в дефолтной сети было - `172.17.0.2`

`php-fpm` - `172.20.0.3`, а в дефолтной сети было - `172.17.0.3`

В вашем случае, число во втором октете может быть другим.

Войдем в контейнер `edge`:
```bash
docker attach edge
```
И произведем пинг по имени контейнеров:
```
/ # ping -c 2 edge
PING edge (172.20.0.2): 56 data bytes
64 bytes from 172.20.0.2: seq=0 ttl=64 time=0.258 ms
64 bytes from 172.20.0.2: seq=1 ttl=64 time=0.174 ms

--- edge ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.174/0.216/0.258 ms
/ # ping -c 2 php-fpm
PING php-fpm (172.20.0.3): 56 data bytes
64 bytes from 172.20.0.3: seq=0 ttl=64 time=0.898 ms
64 bytes from 172.20.0.3: seq=1 ttl=64 time=0.245 ms

--- php-fpm ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.245/0.571/0.898 ms
```

Как видим, IP адреса контейнеров определились автоматически. И это для нас очень важно, т.к. для организации взаимодействия между контейнерами мы будем использовать их названия!

Теперь можно выйти и остановить контейнеры, а также удалить сеть:
```bash
docker stop edge php-fpm && docker network rm first-net
```

## LEMP

Теперь настало время применить все знания предыдущих уроков, чтобы собрать полноценный LEMP-стек (Linux Enginx Mysql Php).

Создайте новую сеть:
```bash
docker network create --driver bridge lemp-net
```
Перейдите в папку `level4/lemp` и запустите контейнеры:
```bash
docker run --rm -d \
  --name db \
  --network lemp-net \
  -e MYSQL_ROOT_PASSWORD=lemp-pass \
  -e MYSQL_DATABASE=lemp-db \
  --mount type=volume,source=db_volume,target=/var/lib/mysql \
  mysql:8.0
  
docker run --rm -d \
  --name php-fpm \
  --network lemp-net \
  --mount type=bind,source="$(pwd)"/config/php-fpm/local.ini,target=/usr/local/etc/php/conf.d/local.ini \
  --mount type=bind,source="$(pwd)"/core,target=/var/www/html \
  phpprogrammist/php:8.1-fpm-dev-mysql
  
docker run --rm -d \
  --name edge \
  --network lemp-net \
  -p 8000:80 \
  --mount type=bind,source="$(pwd)"/config/edge/nginx.conf,target=/etc/nginx/nginx.conf \
  --mount type=bind,source="$(pwd)"/config/edge/php.conf,target=/etc/nginx/conf.d/php.conf \
  --mount type=bind,source="$(pwd)"/core,target=/var/www/html \
  nginx:1.23-alpine  
```
Обратите внимание, что мы публикуем порты только для `edge`, т.к. к нему мы будем обращаться из "внешнего" мира, а взаимодействие между другими контейнерами организовано благодаря сети `lemp-net`.

Также стоит обратить внимание на конфигурационный файл Nginx [php.conf](lemp/config/edge/php.conf). В нем указано слушать 80-й порт и все запросы, которые в адресе содержат расширение `.php` перенаправлять в контейнер `php-fpm` на 9000-й порт:

`fastcgi_pass php-fpm:9000`

9000-й порт мы не открывали, но он доступен благодаря общей сети. Обращаемся к контейнеру по его имени тоже благодаря пользовательской сети.

Внутрь контейнеров `php-fpm` и `edge` с помощью монтирования помимо конфигурационных файлов помещаем папку `./core`, в которой содержатся PHP-файлы:

[db.php](lemp/core/db.php) содержит подключение к БД MySQL:
```php
return new PDO('mysql:host=db:3306;dbname=lemp-db', 'root', 'lemp-pass');
```
Обратите внимание на хост: `db:3306` - здесь также идет обращение к контейнеру по имени и порту через пользовательскую сеть.

`lemp-db` - это название БД, которая была создана при запуске контейнера благодаря переменной окружения `MYSQL_DATABASE`.

`root` - это имя пользователя

`lemp-pass` - это пароль, который указан в переменной окружения `MYSQL_ROOT_PASSWORD`.

Файл [init.php](lemp/core/init.php) содержит скрипт, который создает таблицу `post`, если она еще не создана, а также добавляет в нее 3 записи:
```php
/** @var PDO $pdo */
$pdo = include "db.php";
$pdo->exec('CREATE TABLE IF NOT EXISTS `post` (
  `id` int(11) NOT NULL auto_increment,       
  `text` varchar(255)  NOT NULL default "",
   PRIMARY KEY  (`id`)
)');


$pdo->exec('INSERT INTO `post` (`text`) VALUES 
  ("Первый"),
  ("Второй"),
  ("Третий")
  ');

echo 'Инициализация завершена';
```

Файл [index.php](lemp/core/init.php) получает из БД список всех постов и генерирует HTML, который содержит этот список.
```php
<?php
/** @var PDO $pdo */
$pdo = include "db.php";
try {
    $stmt = $pdo->query('SELECT * from post order by id desc');
    $posts = $stmt->fetchAll(PDO::FETCH_ASSOC);
} catch (Exception $e) {
    $posts = [];
}

$title = 'Список постов';
?>

<html lang="en">
<head>
    <title><?php echo $title ?></title>
</head>
<body>
<h1><?php echo $title ?></h1>
<table>
    <tr>
        <th>ID</th>
        <th>Текст</th>
    </tr>
    <?php foreach ($posts as $post): ?>
        <tr>
            <td><?php echo $post['id'] ?></td>
            <td><?php echo $post['text'] ?></td>
        </tr>
    <?php endforeach; ?>
</table>
</body>
</html>
```

Убедимся, что контейнеры запущены:
```bash
docker container ls
```
Если мы сразу вызовем `index.php`, то получим HTML-страницу, которая не содержит список постов.

```bash
curl 0.0.0.0:8000
```

```html
<html lang="en">
<head>
    <title>Список постов</title>
</head>
<body>
<h1>Список постов</h1>
<table>
    <tr>
        <th>ID</th>
        <th>Текст</th>
    </tr>
    </table>
</body>
</html>
```

Теперь запустим скрипт инициализации:
```bash
curl 0.0.0.0:8000/init.php
```

Теперь снова запросим индексную страницу:
```bash
curl 0.0.0.0:8000
```
И теперь увидим в ней таблицу с тремя постами:

```html
<html lang="en">
<head>
    <title>Список постов</title>
</head>
<body>
<h1>Список постов</h1>
<table>
    <tr>
        <th>ID</th>
        <th>Текст</th>
    </tr>
            <tr>
            <td>3</td>
            <td>Третий</td>
        </tr>
            <tr>
            <td>2</td>
            <td>Второй</td>
        </tr>
            <tr>
            <td>1</td>
            <td>Первый</td>
        </tr>
    </table>
</body>
</html>
```

Если несколько раз вызвать скрипт инициализации, то каждый раз в БД будет добавляться 3 поста, которые можно увидит на индексной странице.

Итого, мы имеем жизнеспособный стек из трех контейнеров:
1) `db` - записывает, хранит и отдает данные по запросу контейнера `php-fpm`.
2) `php-fpm` - создает таблицу, записывает в нее данные, извлекает нужные данные и генерирует HTML.
3) `edge` - получает запрос от пользователя, перенаправляет запрос в контейнер `php-fpm`, ждет ответ от контейнера и отдает результат пользователю.

Теперь можно остановить стек, удалить том базы данных и сеть:

```bash
docker stop edge php-fpm db \
&& docker volume rm db_volume \
&& docker network rm lemp-net
```

## Домашнее задание
1) Ознакомиться со списком [драйверов сетей](https://docs.docker.com/network/)
2) Запустите LEMP-стек, указав для Nginx порт вашей хост-машины, который доступен при обращении через браузер. Вызовите скрипты инициализации и индексной страницы через браузер.
3) Попробуйте запустить контейнеры в обратном порядке (сначала `edge`, потом `php-fpm` и `db`). Выскажите предположение, почему сейчас не запустился контейнер `edge`.
4) Необязательно. Поместите в папку `level4/lemp/core` готовое приложение Symfony, настройте подключение к БД, выполните установку зависимостей и миграции (можно войти в контейнер для этого). В файле `level4/lemp/config/edge/php.conf` необходимо будет немного изменить корневую директорию (6-я строка, директива `root`), т.к. Nginx должен отдавать в мир только папку `public`, а не всю директорию `core`. Запустите контейнеры, указав для Nginx порт, который доступен из браузера для вашего стенда.