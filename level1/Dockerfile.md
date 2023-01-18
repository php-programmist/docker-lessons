# Dockerfile и создание образа

Не всегда готовый образ, полученный с Docker Hub, удовлетворит все наши требования. Например, образы PHP поставляются с минимальным набором расширений. Если же нам нужны дополнительные расширения, то необходимо создать новый образ на основе официального и добавить в него все необходимое. Об этом также написано на странице [официального образа](https://hub.docker.com/_/php)

Допустим на нашем проекте нам понадобятся расширения для работы с PostgreSQL, Imagemagick, Amqp, Redis и Composer.

Для этого создадим файл с названием [Dockerfile](images/php1/Dockerfile) (без расширения) и добавим в него следующее содержимое:
```Dockerfile
FROM php:8.1-fpm-alpine

RUN set -xe \
    && apk update \
    && apk add --no-cache \
        postgresql-dev \
        icu-dev \
        # Необходимо для imagick
        imagemagick \
        imagemagick-dev \
        libgomp \
        # Необходимо для AMQP
        rabbitmq-c \
        # Необходимо для AMQP
        rabbitmq-c-dev \
        # Необходимо для AMQP
        libssh-dev \
    && docker-php-ext-install \
        # Необходимо для AMQP
        bcmath \
        # Необходимо для AMQP
        sockets \
        intl \
        pdo_pgsql \
        pgsql

RUN  apk add --no-cache --virtual .redis-deps ${PHPIZE_DEPS} \
    && pecl install -o -f redis-5.3.4 \
    && pecl install amqp-1.11.0beta \
    && pecl install -o -f imagick \
    && docker-php-ext-enable \
        redis \
        opcache \
        amqp \
        imagick \
    && apk del ${PHPIZE_DEPS} .redis-deps

RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php --version 2.0.12 \
    && php -r "unlink('composer-setup.php');" \
    && mv composer.phar /usr/local/bin/composer
```

Данный файл содержит инструкции по созданию.

В первой строке указана инструкция `FROM`, которая задает базовый (родительский) образ.

А инструкции `RUN` позволяют выполнить на этапе сборки команды и записывает измененное состояние образа в новый слой. Каждый `RUN` создает новый слой, а каждый слой несет дополнительные накладные расходы на объем образа. Поэтому нужно стараться объединять несколько команд с помощью `&&`, а для переноса строки - `\`.

Для сборки образа на основе этого файла необходимо выполнить команду:
```bash
docker build \
    --pull \
    -t phpprogrammist/php:8.1-fpm-alpine-project \
    .
```
`--pull` - заставит сборщик скачать последнюю версию базового образа

`-t` - устанавливает тег для образа. 

`.` - устанавливает контекст сборки - текущую папку. В текущей папке будет осуществляться поиск `Dockerfile`, а также она будет базовой для копирования файлов с помощью инструкции `COPY`.

Сборка займет не менее 5 минут.

## Как составлять тег

Если Вы планируете публиковать образ в DockerHub, то в первой части метки указывается ваш Логин в DockerHub (например, `phpprogrammist`). Если же образ будет храниться в приватном репозитории (например, в Gitlab), то необходимо придерживаться определенной конвенции наименования. Например:

`git.example.com:5050/group/project/php:8.1-fpm-alpine-project`

`git.example.com:5050` - Это хост с коробочным Gitlab и портом.

`group` - тут указывается название группы

`project` - тут указывается название проекта.

## Публикация образа
После окончания сборки образа его сразу же можно использовать локально. Но чтобы другие участники Вашей команды могли использовать этот образ без необходимости сборки, образ необходимо разместить в реестре DockerHub или другом.

Для начала необходимо пройти авторизацию в реестре:
```bash
docker login
```
Потом ввести логин и пароль от аккаунта в DockerHub. Данные будут сохранены в папке пользователя `~/.docker/config.json`. Потому при последующих публикациях авторизоваться снова не понадобится.

При необходимости авторизоваться в другом аккаунте можно использовать опции `-u` и `-p` для указания логина и пароля.

Если же образ будет храниться в другом реестре, то необходимо указать домен реестра:
```bash
docker login git.example.com:5050
```

Публикуем образ, указав его тег:
```bash
docker push phpprogrammist/php:8.1-fpm-alpine-project
```
Теперь можем просмотреть образ в [Docker Hub](https://hub.docker.com/r/phpprogrammist/php/tags), а также просмотреть его [Dockerfile](https://hub.docker.com/layers/phpprogrammist/php/8.1-fpm-alpine-project/images/sha256-e749bb19a7750bf4a253fcfd7a903ee84fac44966512eb88c241fa147b111544?context=explore)

## Использование дополнительного образа в сборке
Составить `Dockerfile` для проекта может оказаться нетривиальной задачей, т.к. для каждого расширения нужно устанавливать нужные для него зависимости вручную.

Для упрощения этой задачи есть специальный проект для [легкой установки расширений](https://github.com/mlocati/docker-php-extension-installer).

Рассмотрим [Dockerfile](images/php2/Dockerfile) с использованием этого установщика:
```Dockerfile
FROM php:8.1-cli-alpine
# Import extension installer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/bin/

RUN install-php-extensions amqp apcu bcmath intl oauth opcache pdo_pgsql pgsql redis sockets zip @composer
```

Инструкция `COPY` копирует файлы внутрь собираемого образа.

`--from=mlocati/php-extension-installer` - здесь указано откуда берем файлы для копирования. В данном случае источником выступает другой образ - `mlocati/php-extension-installer`.

`/usr/bin/install-php-extensions` - это файл, который копируем

`/usr/bin/` - папка, куда происходит копирование

Далее инструкцией `RUN` вызываем скопированный установщик и в качестве аргументов указываем названия расширений. Доступные расширения и их версии указаны на странице проекта. 

## Домашнее задание
1) Изучить остальные [инструкции](https://kapeli.com/cheat_sheets/Dockerfile.docset/Contents/Resources/Documents/index) Dockerfile
2) Осуществить сборку образов, указанных в уроке, и опубликовать их в своем аккаунте DockerHub
3) Разобраться с инструкциями `CMD` и `ENTRYPOINT` - [https://habr.com/ru/company/southbridge/blog/329138/](https://habr.com/ru/company/southbridge/blog/329138/)