#!/usr/bin/env bash

compose_files=(
    $(find "./compose" -maxdepth 1 -type f -name "*.yaml" | sed -Ern "s/^\.\/compose\/([-a-z]+)\.yaml/\1/p" | sort)
)

cd $(realpath .)

execute_docker_command() {
    if [[ "$1" == "up" ]]; then
        docker stack deploy $2 \
            --compose-file ./compose/$2.yaml \
            --with-registry-auth
        if [[ $? != 0 ]]; then
            exit 1
        fi
    fi

    if [[ "$1" == "down" ]]; then
        docker stack remove $2
        if [[ $? != 0 ]]; then
            exit 1
        fi
    fi

    if [[ "$1" == "restart" ]]; then
        docker stack remove $2
        if [[ $? != 0 ]]; then
            exit 1
        fi
        docker stack deploy $2 \
            --compose-file ./compose/$2.yaml \
            --with-registry-auth
        if [[ $? != 0 ]]; then
            exit 1
        fi
    fi
}

if [[ -z $2 ]]; then
    PS3='Выберите стек: '
    options=("Все" "${compose_files[@]}")
    select opt in "${options[@]}"; do
        case "$opt" in
        "Все")
            selected="all"
            break
            ;;
        *)
            selected=${opt}
            break
            ;;
        esac
    done
else
    selected=$2
fi

if [[ ${selected} == "all" ]]; then
    for compose_file in "${compose_files[@]}"; do
        execute_docker_command $1 ${compose_file}
    done
else
    execute_docker_command $1 ${selected}
fi
