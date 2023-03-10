# Основы Docker

## Основные понятия

1) **Docker host** - это просто компьютер или виртуальный сервер, на котором установлен Docker
2) **Docker daemon** — центральный системный компонент, который управляет всеми процессами докера: создание образов, запуск и остановка контейнеров, скачивание образов. Работает **Docker daemon** как фоновый процесс (демон) и постоянно следит за состоянием других компонентов.
3) **Docker client** — это утилита, предоставляющая API к докер-демону. Клиент может быть консольным (*nix-системы) или графическим (Windows)
4) **Docker образ** — это шаблон (физически — исполняемый пакет), из которого создаются Docker-контейнеры. Образ хранит в себе всё необходимое для запуска приложения, помещенного в контейнер: код, среду выполнения, библиотеки, переменные окружения и конфигурационные файлы. Хранятся в специальных реестрах (DockerHub и др.) и локально.
5) **Контейнер** — это запущенный и изолированный образ с возможностью временного сохранения данных. Данные записываются в специальный слой «сверху» контейнера и при удалении контейнера данные также удаляются.

## Скачивание образа
1) Находим нужный образ в реестре - https://hub.docker.com/_/php 
2) На вкладке **Tags** находим тег "cli-alpine". CLI-версия PHP на легковесной версии Linux Alpine.
3) Копируем команду для скачивания образа `docker pull php:cli-alpine` и исполняем
4) Получаем список локальных образов `docker images`. Если образов много, то можно получить список образов, содержащих "PHP": `docker images | grep php`

## Управление контейнерами
### Запуск контейнера
```bash
docker run php:cli-alpine
```

### Список запущенных контейнеров
```bash
docker ps
```
Если контейнеров много - `docker ps | grep php:cli-alpine`. Как видим, запущенного нами контейнера в списке нет.

### Список всех контейнеров
```bash
docker ps -a --no-trunc --filter="ancestor=php:cli-alpine"
``` 
`-a` - список всех контейнеров, в т.ч. остановленных. 

`--no-trunc` - выводит полное содержимое колонок не обрезая длинные строки

`--filter="ancestor=php:cli-alpine"` - фильтрует контейнеры, оставляя только те, которые основаны на образе `php:cli-alpine`.

Получаем талицу со следующими колонками: ID контейнера, название образа, выполненная команда, время создания, статус, порты, имя контейнера. 

Как видим, была выполнена команда, `php -a` (запуск интерактивной оболочки) и контейнер был остановлен.

### Удаление контейнера
`docker rm {containerId}` - Удалить контейнер по его ID или имени. 

### Переопределение команды при запуске контейнера
```bash
docker run --rm php:cli-alpine php -v
```  

`--rm` - флаг для автоматического удаления контейнера после его остановки. 

`php -v` - команда, которая будет выполнена после запуска контейнера. 

Команду для контейнера пишем после названия образа, а флаги команды `run` - до.

### Запустить и войти в контейнер
```bash
docker run --rm -it php:cli-alpine
```  

`-i` - запуск контейнера в интерактивном режиме (позволяет осуществлять ввод данных). 

`-t` - создает псевдо-терминал, который перенаправляет стандартный ввод и вывод на пользовательский терминал.

Т.к. по умолчанию исполняется команда запуска оболочки PHP (`php -a`), то мы сразу в нее и попадаем. Можем выполнить различные команды в PHP. 

Для выхода и остановки контейнера - `CTRL+D`.

## Запуск постоянно работающего контейнера

Т.к. версия образа `cli-alpine` останавливается сразу после запуска, то теперь будем использовать `php:fpm-alpine`. Предварительно скачивать образ необязательно - он скачается автоматически при первом запуске

```bash
docker run --rm --name test-php-fpm php:fpm-alpine
``` 
`--name test-php` - задает имя контейнеру **test-php-fpm**. По имени будем обращаться к контейнеру.

Контейнер запустился и продолжает работать, но терминал заблокирован пока работает контейнер.

Для остановки нажимаем `CTRL+C`.

```bash
docker run --name test-php-fpm -d php:fpm-alpine
```  

`-d` - запускает контейнер в режиме "демона", отсоединяя его от терминала

В результате получим ID контейнера.

### Проверим, что контейнер запущен:
```bash
docker ps --filter="NAME=test-php-fpm"
```

`--filter="NAME=test-php-fpm"` - покажет контейнер с заданным именем

### Запуск команды в запущенном контейнере:

```bash
docker exec test-php-fpm php -v
```

`exec` - исполняет новую команду в уже запущенном контейнере.

`php -v` - собственно команда

### Войдем в запущенный контейнер:

```bash
docker exec -it test-php-fpm sh
```

`-it` - интерактивный режим + терминал.

`sh` - shell

Можно выполнять произвольные действия внутри контейнера, но они будут сохранены, пока контейнер не будет уничтожен.

Создадим простейший скрипт:
```bash
echo "<?php echo 'Hello World'.PHP_EOL ?>" > hello.php
```

Выполним его с помощью PHP:
```bash
php hello.php
```

### Выйти из контейнера:
```bash
exit
```
или `Ctrl+D`

### Запуск созданного внутри контейнера скрипта

```bash
docker exec test-php-fpm php hello.php
```
Скрипт отрабатывает, как и раньше.

### Перезапуск контейнера:
```bash
docker stop test-php-fpm
docker start test-php-fpm
docker exec test-php-fpm php hello.php
```
Как видим, скрипт все еще работает.

### Удаление и запуск
```bash
docker stop test-php-fpm
docker rm test-php-fpm
docker run --name test-php-fpm -d php:fpm-alpine
docker exec test-php-fpm php hello.php
```
Теперь же получаем ошибку из-за того, что файл `hello.php` отсутствует.

## Очистка неиспользуемых образов и контейнеров

Даже остановленные контейнеры занимают место на диске, поэтому необходимо не забывать их удалять с помощью команды `docker rm` или запускать контейнеры с флагом `--rm`.

Чтобы массово освобождать ресурсы есть специальная команда: 
```bash
docker system prune
```
Удалит образы, сети и тома, которые не связаны с контейнерами.

```bash
docker system prune -a
```
Удалит также остановленные контейнеры и образы, которые не используются в запущенных контейнерах.

## Домашнее задание:
1) Ознакомиться со списком опций `docker run` (`docker run --help`) и рассказать о наиболее интересном для Вас
2) Запустить в интерактивном режиме контейнер на основе образа для Node.js, создать внутри скрипт и запустить его.
3) Ознакомиться с [фильтрами](https://docs.docker.com/engine/reference/commandline/ps/#-filtering---filter) списка контейнеров и рассказать о наиболее полезном по Вашему мнению