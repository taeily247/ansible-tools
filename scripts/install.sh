#!/bin/bash

##### document
# https://docs.docker.com/engine/install/ubuntu/
# https://jsonobject.tistory.com/8
# https://velog.io/@codingdaddy/Ansible-AWX-install-on-Ubuntu-20.04
# https://velog.io/@leesjpr/AnsibleAWX-%EA%B0%9C%EB%85%90-%EB%B0%8F-Install

##### Load variable
source "$(dirname $(realpath $0))/conf/color.cfg"
source "$(dirname $(realpath $0))/conf/common.cfg"

function help_usage() {
    cat <<EOF
Usage: $0 [Options]
Options:
-i, --install        [all, docker, ansible, awx]   : Install mode.
-r, --remove-install [all, docker, ansible, awx]   : Remove mode.
-h, --help                                         : script help.
EOF
    exit 0
}

function help_usage_install() {
    cat <<EOF
Usage: $0 [-i, --install] [all, docker, ansible]
detail:
Ex) $0 -i all
EOF
    exit 0
}

function help_usage_remove() {
    cat <<EOF
Usage: $0 [-r, --remove] [all, docker, ansible]
detail:
Ex) $0 -r all
EOF
    exit 0
}

function set_opts() {
    arguments=$(getopt --options i:r:h \
    --longoptions install:,remove-install:,help \
    --name $(basename $0) \
    -- "$@")

    eval set -- "${arguments}"

    while true; do
        case "$1" in
            ### install에서 "all, docker, ansible"에 따라서 필요힌 부분을 설치합니다.
            -i | --install)
                _install_method=$2
                case ${_install_method} in
                    all )
                        docker_install
                        docker_compose_install
                        ansible_install
                        awx_install
                    ;;
                    docker )
                        docker_install
                        docker_compose_install
                    ;;
                    ansible )
                        ansible_install
                    ;;
                    awx )
                        awx_install
                    ;;
                    * ) help_usage_install ; exit 1 ;;
                esac
            shift 2
            ;;
            
            ### install에서 "all, docker, ansible"에 따라서 필요힌 부분을 삭제합니다.
            -r | --remove-install )
                _remove_method=$2
                case ${_remove_method} in
                    all )
                        docker_remove
                        docker_compose_remove
                        ansible_remove
                    ;;
                    docker )
                        docker_remove
                        docker_compose_remove
                    ;;
                    ansible )
                        ansible_remove
                    ;;
                    * ) help_usage_remove ; exit 1 ;;
                esac
            shift 2
            ;;
            -h | --help) help_usage ;;
            --) shift ; break ;;
            *) help_usage ;;
        esac
    done

    shift $((OPTIND-1))
}

# dpkg-query -W --showformat='${db:Status-Status}' ${_pkg} |grep -q "not-installed" >/dev/null 2>&1
function install_pkg() {
    ##### dpkg를 통해 _pkg를 설치여부를 보고 설치
    ##### 만약 패키지 설치가 실패한다면 스크립트는 중단된다.
    _pkg=$1

    # if dpkg-query -l ${_pkg} |awk "/${_pkg}/ {print \"$1\"}" |grep -q rc >/dev/null 2>&1 ; then
    # dpkg-query -W --showformat='${db:Status-Status}' ${_pkg} |grep -wq "not-installed" >/dev/null 2>&1
    dpkg -l ${_pkg} |awk '/^rc/ {print }' |grep rc >/dev/null 2>&1
    if [ $? -eq 0 ] ; then
        Logging "INFO" "Install packages [ ${_pkg} ]"
        RunCmd "apt install -y ${_pkg}"
        if [ $? -ne 0 ]; then
            exit 1
        fi
    else
        Logging "SKIP" "Already installed [ ${_pkg} ]"
    fi
}

function remove_pkg() {
    ##### dpkg를 통해 _pkg를 설치여부를 보고 설치
    ##### 만약 패키지 설치가 실패한다면 스크립트는 중단된다.
    _pkg=$1

    # if dpkg-query -l ${_pkg} |awk "/${_pkg}/ {print \"$1\"}" |grep -q ii >/dev/null 2>&1 ; then
    # dpkg-query -W --showformat='${db:Status-Status}' ${_pkg} |grep -wq "installed" >/dev/null 2>&1
    dpkg -l ${_pkg} |awk '/^ii/ {print }' |grep ii >/dev/null 2>&1
    if [ $? -eq 0 ]  ; then
        Logging "SKIP" "Already removed [ ${_pkg} ]"
    else
        Logging "INFO" "Remove packages [ ${_pkg} ]"
        RunCmd "apt purge -y ${_pkg}"
        if [ $? -ne 0 ]; then
            exit 1
        fi
    fi
}

##### Docker 패키지 삭제
function docker_remove() {
    Logging "MENU" "Remove Docker start."
    _remove_pkgs=("docker-ce" "docker-ce-cli" "containerd.io" "docker-buildx-plugin" "docker-compose-plugin")
    for _pkg in ${_remove_pkgs[@]}; do
        remove_pkg ${_pkg}
    done

    if [ -f /etc/apt/sources.list.d/docker.list ]; then
        RunCmd "rm -f /etc/apt/sources.list.d/docker.list"
    fi
    
    if command -v 'docker' >/dev/null 2>&1; then
        Logging "CRT" "Remove Docker done."
        exit 1
    else
        Logging "MENU" "Remove Docker done."
        return 0
    fi
}

function docker_install() {
    ##### Docker 최시전 버전의 Commnunity version을 설치
    Logging "MENU" "Install Docker start"
    _install_pkgs=("ca-certificates" "curl")
    for _pkg in ${_install_pkgs[@]}; do
        install_pkg ${_pkg}
    done

    RunCmd "install -m 0755 -d /etc/apt/keyrings"
    RunCmd "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc"
    RunCmd "chmod a+r /etc/apt/keyrings/docker.asc"

    RunCmd "cat <<EOF >/etc/apt/sources.list.d/docker.list
deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \$(. /etc/os-release && echo \"\$VERSION_CODENAME\") stable
EOF"
    RunCmd "apt-get update"

    _install_pkgs=("docker-ce" "docker-ce-cli" "containerd.io" "docker-buildx-plugin" "docker-compose-plugin")
    for _pkg in ${_install_pkgs[@]}; do
        install_pkg ${_pkg}
    done
    
    if command -v 'docker' >/dev/null 2>&1; then
        Logging "MENU" "Install Docker done."
        return 0
    else
        Logging "CRT" "Install Docker done."
        exit 1
    fi
}

##### Docker-compose 패키지 삭제
function docker_compose_remove() {
    Logging "MENU" "Remove Docker-compose start."
    if [ -f /usr/local/bin/docker-compose ]; then
        RunCmd "rm -f /usr/local/bin/docker-compose"
        if [ $? -eq 0 ]; then
            Logging "MENU" "Remove Docker-compose done."
            return 0
        else
            Logging "CRT" "Fail remove file /usr/local/bin/docker-compose"
            exit 1
        fi
    else
        Logging "SKIP" "Already removed docker-compose"
        Logging "MENU" "Remove Docker-compose done."
        return 0
    fi
}

function docker_compose_install() {
    Logging "MENU" "Install Docker-compose start."
    if [ ! -f /usr/local/bin/docker-compose ]; then
        RunCmd "curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m) -o /usr/local/bin/docker-compose"
        RunCmd "chmod +x /usr/local/bin/docker-compose"
        if [ $? -eq 0 ]; then
            Logging "MENU" "Install Docker-compose done."
            return 0
        else
            Logging "CRT" "Fail install file /usr/local/bin/docker-compose"
            exit 1
        fi
    else
        Logging "SKIP" "Already installed docker-compose"
        Logging "MENU" "Install Docker-compose done."
        return 0
    fi
}

function ansible_install() {
    Logging "MENU" "Install ansible start."

    _install_pkgs=("ansible")
    for _pkg in ${_install_pkgs[@]}; do
        install_pkg ${_pkg}
    done
    
    if command -v 'ansible' >/dev/null 2>&1; then
        Logging "MENU" "Install ansible done."
        return 0
    else
        Logging "CRT" "Install ansible done."
        exit 1
    fi
}

function ansible_remove() {
    Logging "MENU" "Remove ansible start."

    _install_pkgs=("ansible")
    for _pkg in ${_install_pkgs[@]}; do
        remove_pkg ${_pkg}
    done

    if command -v 'ansible' >/dev/null 2>&1; then
        Logging "CRT" "Remove ansible done."
        exit 1
    else
        Logging "MENU" "Remove ansible done."
        return 0
    fi
}

##### ansible awx를 배포
function awx_install() {
    Logging "MENU" "Deploy ansible-awx start."

    _install_pkgs=("nodejs" "npm" "python3-pip" "git" "pwgen")
    for _pkg in ${_install_pkgs[@]}; do
        install_pkg ${_pkg}
    done

    if ! pip3 list |grep -w docker |grep  -q 6.1.3; then
        RunCmd "pip3 uninstall -y docker"
        RunCmd "pip3 install docker==6.1.3"
    fi

    if pip3 list |grep -w docker-compose |grep -q 1.29.2 ; then
        RunCmd "pip3 install docker-compose==1.29.2"
    fi

    ##### 기본적인 awx 폴더 존재 여부 확인 후 ansible을 통해 배포
    if [ ! -d /root/tool/ansible.d/awx-17.1.0 ]; then
        RunCmd "wget https://github.com/ansible/awx/archive/refs/tags/17.1.0.tar.gz -P /root/tool/ansible.d/."
        RunCmd "tar -zxf /root/tool/ansible.d/17.1.0.tar.gz -C /root/tool/ansible.d/."
        RunCmd "ansible-playbook -i inventory /root/tool/ansible.d/awx-17.1.0/installer/install.yml"
        _tmp_ansible_pass=$(pwgen -N 1 -s 30)
        RunCmd "sed -i 's/# admin_password=password/&\nadmin_password="${_tmp_ansible_pass}"/g' /root/tool/ansible.d/awx-17.1.0/installer/inventory"
        RunCmd "sed -i 's/#project_data_dir=\/var\/lib\/awx\/projects/&\nproject_data_dir=\/var\/lib\/awx\/projects/g' /root/tool/ansible.d/awx-17.1.0/installer/inventory"
        RunCmd "ansible-playbook -i /root/tool/ansible.d/awx-17.1.0/installer/inventory /root/tool/ansible.d/awx-17.1.0/installer/install.yml -b"
        if [ $? -eq 0 ]; then
            Logging "MENU" "Install ansible-awx done."
            return 0
        else
            Logging "CRT" "Fail deploy ansible-awx."
            Logging "MENU" "Deploy ansible-awx done."
            return 1
        fi
    else
        if docker ps -a |grep -q "ansible/awx:17.1.0" ; then
            Logging "CRT" "Already deploy ansible-awx."
            return 1
        else
            if ! grep -q '^admin_password' /root/tool/ansible.d/awx-17.1.0/installer/inventory; then
                _tmp_ansible_pass=$(pwgen -N 1 -s 30) 
                RunCmd "sed -i 's/# admin_password=password/&\nadmin_password="${_tmp_ansible_pass}"/g' /root/tool/ansible.d/awx-17.1.0/installer/inventory"
            fi

            if ! grep -q '^project_data_dir=/var/lib/awx/projects' /root/tool/ansible.d/awx-17.1.0/installer/inventory; then
                RunCmd "sed -i 's/#project_data_dir=\/var\/lib\/awx\/projects/&\nproject_data_dir=\/var\/lib\/awx\/projects/g' /root/tool/ansible.d/awx-17.1.0/installer/inventory"
            fi

            RunCmd "ansible-playbook -i /root/tool/ansible.d/awx-17.1.0/installer/inventory /root/tool/ansible.d/awx-17.1.0/installer/install.yml -b"
            if [ $? -eq 0 ]; then
                Logging "MENU" "Install ansible-awx done."
                return 0
            else
                Logging "CRT" "Fail deploy ansible-awx."
                Logging "MENU" "Deploy ansible-awx done."
                return 1
            fi
        fi
    fi
}

main() {
    [ $# -eq 0 ] && help_usage
    set_opts "$@"
}
main $*