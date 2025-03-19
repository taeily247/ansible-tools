#!/bin/bash

# doc
# https://docs.docker.com/engine/install/ubuntu/

SCRIPT_DIR=$(dirname $(realpath $0))

for _FILE in $(ls ${SCRIPT_DIR}/lib); do
    source ${SCRIPT_DIR}/lib/${_FILE}
done

function help_usage() {
    cat <<EOF
Usage: $0 [Options]
Options:
-i, --install   : Install docker
-r, --remove    : Remove docker
EOF
    exit 0
}

function set_opts() {
    arguments=$(getopt --options irh \
    --longoptions install,remove,help \
    --name $(basename $0) \
    -- "$@")

    eval set -- "${arguments}"

    while true; do
        case "$1" in
            -i | --install ) MODE="install" ; shift   ;;
            -r | --remove )  MODE="remove"  ; shift   ;;
            -h | --help ) help_usage                  ;;
            --) shift ; break                         ;;
            *) help_usage                             ;;
        esac
    done

    shift $((OPTIND-1))
}


function uninstall_docker() {
    for _pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        remove_pkg "${_pkg}"
        if [ $? -eq 1 ]; then
            exit 1
        fi
    done
}

function install_docker_pre() {
    check_pkg "ca-certificates" "curl"

    if [ ! -f /etc/apt/keyrings/docker.asc ]; then
        _cmd_list=(
            "install -m 0755 -d /etc/apt/keyrings"
            "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc"
            "chmod a+r /etc/apt/keyrings/docker.asc"
        )
        for ((_idx=0 ; _idx < ${#_cmd_list[@]} ; _idx++)); do
            run_cmd "${_cmd_list[${_idx}]}"
            if [ $? -eq 0 ]; then
                continue
            else
                exit 1
            fi
        done
    else
        log_msg "SKIP" "Already docker.asc"
    fi

    if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
        run_cmd "cat <<EOF >/etc/apt/sources.list.d/docker.list
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable
EOF"
        if [ $? -eq 0 ]; then
            run_cmd "apt-get update"
            if [ $? -eq 0 ]; then
                return 0
            else
                exit 1
            fi
        else
            exit 1
        fi
    fi
}

function install_docker() {
    check_pkg "docker-ce" "docker-ce-cli" "containerd.io" "docker-buildx-plugin" "docker-compose-plugin"
    # docker-ce dependency에 아래 Package가 포함되는걸로 보임
    # "docker-ce-cli" "containerd.io" "docker-buildx-plugin" "docker-compose-plugin"
    if [ $? -eq 0 ]; then
        enable_svc "docker"
        if [ $? -eq 0 ]; then
            return 0
        else
            exit 1
        fi
    else
        exit 1
    fi
}

function install_awx_pre() {
    if [ ! -d ${SCRIPT_DIR}/awx_install ]; then
        run_cmd "git clone -b 17.1.0 https://github.com/Ansible/awx.git ${SCRIPT_DIR}/awx_install"
    fi

    if [ ! -f ./awx_install/installer/inventory.org ]; then
        run_cmd "cp -p ./awx_install/installer/inventory ./awx_install/installer/inventory.org"
    fi

    if ! grep -q '^docker_logger=journald' ./awx_install/installer/inventory; then
        run_cmd "sed -i'' -r -e '/^# docker_logger=journald/a\docker_logger=journald' ./awx_install/installer/inventory"
    fi

    if ! grep -q '^#pg_password=awxpass' ./awx_install/installer/inventory; then
        run_cmd "sed -i 's/^pg_password=awxpass/#&\npg_password=awxdbpass!365/g' ./awx_install/installer/inventory"
    fi

    if ! grep -q '^pg_admin_password=admindbpass!365' ./awx_install/installer/inventory; then
        run_cmd "sed -i'' -r -e '/^# pg_admin_password=postgrespass/a\pg_admin_password=admindbpass!365' ./awx_install/installer/inventory"
    fi

    if ! grep -q '^#admin_user=admin' ./awx_install/installer/inventory; then
        run_cmd "sed -i 's/^admin_user=admin/#&\nadmin_user=root/g' ./awx_install/installer/inventory"
    fi

    if ! grep -q '^admin_password=rootpass!365' ./awx_install/installer/inventory; then
        run_cmd "sed -i'' -r -e '/^# admin_password=password/a\admin_password=rootpass!365' ./awx_install/installer/inventory"
    fi

    if ! grep -q '^awx_official=false' ./awx_install/installer/inventory; then
        run_cmd "sed -i'' -r -e '/^# awx_official=false/a\awx_official=false' ./awx_install/installer/inventory"
    fi

    if ! grep -q '^custom_venv_dir' ./awx_install/installer/inventory; then
        run_cmd "sed -i'' -r -e '/^#custom_venv_dir/a\custom_venv_dir=\/data\/awx\/data\/venv' ./awx_install/installer/inventory"
    fi

    if ! grep -q '^#postgres_data_dir' ./awx_install/installer/inventory; then
        run_cmd "sed -i 's/^postgres_data_dir/#&/g' ./awx_install/installer/inventory"
        run_cmd "sed -i'' -r -e '/^#postgres_data_dir/a\postgres_data_dir=\/data\/awx\/data\/docker-postgres' ./awx_install/installer/inventory"
    fi

    if ! grep -q '^#docker_compose_dir' ./awx_install/installer/inventory; then
        run_cmd "sed -i 's/^docker_compose_dir/#&/g' ./awx_install/installer/inventory"
        run_cmd "sed -i'' -r -e '/^#docker_compose_dir/a\docker_compose_dir=\/data\/awx\/data\/docker-compose' ./awx_install/installer/inventory"
    fi

    if ! grep -q '^project_data_dir' ./awx_install/installer/inventory; then
        run_cmd "sed -i'' -r -e '/^#project_data_dir/a\project_data_dir=\/data\/awx\/project' ./awx_install/installer/inventory"
    fi
}

function install_awx() {
    run_cmd "ansible-playbook -i ./awx_install/installer/inventory ./awx_install/installer/install.yml -e 'ansible_python_interpreter=/usr/bin/python3'"
}
main() {
    [ $# -eq 0 ] && help_usage
    set_opts "$@"

    OS_NAME=$(grep '^NAME=' /etc/os-release |cut -d'=' -f2)
    OS_VERSION=$(grep '^VERSION_ID=' /etc/os-release |cut -d'=' -f2)

    case ${OS_NAME} in
        *centos* | *Centos* | *CentOS* | *rocky* | *Rocky* )
            PKG_CMD=('yum' 'rpm' "yum entos-release-openstack")
        ;;
        *ubuntu* | *Ubuntu* )
            PKG_CMD=('apt' 'dpkg' "add-apt-repository cloud-archive")
        ;;
    esac

    if [ ${MODE} == "install" ]; then
        # install_docker_pre
        # if [ $? -eq 0 ]; then
        #     install_docker
        # fi

        install_awx_pre
        install_awx

    elif [ ${MODE} == "renmove" ]; then
        remove_docker
    else
        log_msg "ERROR" "Bug abort."
        exit 1
    fi
}
main $*