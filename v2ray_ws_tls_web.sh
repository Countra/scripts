#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

cd "$(
    cd "$(dirname "$0")" || exit
    pwd
)" || exit

#fonts color
Green="\033[32m"
Red="\033[31m"
# Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

#notification information
# Info="${Green}[信息]${Font}"
OK="${Green}[OK]${Font}"
Error="${Red}[错误]${Font}"

domain=$1
shell_mode="ws"
github_branch="master"
version_cmp="/tmp/version_cmp.tmp"
v2ray_conf_dir="/etc/v2ray"
nginx_conf_dir="/etc/nginx/conf/conf.d"
v2ray_conf="${v2ray_conf_dir}/config.json"
nginx_conf="${nginx_conf_dir}/v2ray.conf"
nginx_dir="/etc/nginx"
web_dir="/home/wwwroot"
nginx_openssl_src="/usr/local/src"
v2ray_bin_dir="/usr/bin/v2ray"
v2ray_info_file="$HOME/v2ray_info.inf"
v2ray_qr_config_file="/usr/local/vmess_qr.json"
nginx_systemd_file="/etc/systemd/system/nginx.service"
v2ray_systemd_file="/etc/systemd/system/v2ray.service"
v2ray_access_log="/var/log/v2ray/access.log"
v2ray_error_log="/var/log/v2ray/error.log"
amce_sh_file="/root/.acme.sh/acme.sh"
ssl_update_file="/usr/bin/ssl_update.sh"
nginx_version="1.18.0"
openssl_version="1.1.1g"
jemalloc_version="5.2.1"
old_config_status="off"

#简易随机数
random_num=$((RANDOM%12+4))
#生成伪装路径
camouflage="/$(head -n 10 /dev/urandom | md5sum | head -c ${random_num})/"

THREAD=$(grep 'processor' /proc/cpuinfo | sort -u | wc -l)

source '/etc/os-release'
#从VERSION中提取发行版系统的英文名称，为了在debian/ubuntu下添加相对应的Nginx apt源
VERSION=$(echo "${VERSION}" | awk -F "[()]" '{print $2}')

check_system() {
    if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]]; then
        echo -e "${OK} ${GreenBG} 当前系统为 Centos ${VERSION_ID} ${VERSION} ${Font}"
        INS="yum"
    elif [[ "${ID}" == "debian" && ${VERSION_ID} -ge 8 ]]; then
        echo -e "${OK} ${GreenBG} 当前系统为 Debian ${VERSION_ID} ${VERSION} ${Font}"
        INS="apt"
        $INS update
        ## 添加 Nginx apt源
    elif [[ "${ID}" == "ubuntu" && $(echo "${VERSION_ID}" | cut -d '.' -f1) -ge 16 ]]; then
        echo -e "${OK} ${GreenBG} 当前系统为 Ubuntu ${VERSION_ID} ${UBUNTU_CODENAME} ${Font}"
        INS="apt"
        $INS update
    else
        echo -e "${Error} ${RedBG} 当前系统为 ${ID} ${VERSION_ID} 不在支持的系统列表内，安装中断 ${Font}"
        exit 1
    fi

    $INS install dbus -y

    systemctl stop firewalld
    systemctl disable firewalld
    echo -e "${OK} ${GreenBG} firewalld 已关闭 ${Font}"

    systemctl stop ufw
    systemctl disable ufw
    echo -e "${OK} ${GreenBG} ufw 已关闭 ${Font}"
}

is_root() {
    if [ 0 == $UID ]; then
        echo -e "${OK} ${GreenBG} 当前用户是root用户，进入安装流程 ${Font}"
        sleep 3
    else
        echo -e "${Error} ${RedBG} 当前用户不是root用户，请切换到root用户后重新执行脚本 ${Font}"
        exit 1
    fi
}
judge() {
    if [[ 0 -eq $? ]]; then
        echo -e "${OK} ${GreenBG} $1 完成 ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} $1 失败${Font}"
        exit 1
    fi
}

chrony_install() {
    ${INS} -y install chrony
    judge "安装 chrony 时间同步服务 "

    timedatectl set-ntp true

    if [[ "${ID}" == "centos" ]]; then
        systemctl enable chronyd && systemctl restart chronyd
    else
        systemctl enable chrony && systemctl restart chrony
    fi

    judge "chronyd 启动 "

    timedatectl set-timezone Asia/Shanghai

    echo -e "${OK} ${GreenBG} 等待时间同步 ${Font}"
    sleep 10

    chronyc sourcestats -v
    chronyc tracking -v
    date
    read -rp "请确认时间是否准确,误差范围±3分钟(Y/N): " chrony_install
    [[ -z ${chrony_install} ]] && chrony_install="Y"
    case $chrony_install in
    [yY][eE][sS] | [yY])
        echo -e "${GreenBG} 继续安装 ${Font}"
        sleep 2
        ;;
    *)
        echo -e "${RedBG} 安装终止 ${Font}"
        exit 2
        ;;
    esac
}

dependency_install() {
    ${INS} install wget git lsof -y

    if [[ "${ID}" == "centos" ]]; then
        ${INS} -y install crontabs
    else
        ${INS} -y install cron
    fi
    judge "安装 crontab"

    if [[ "${ID}" == "centos" ]]; then
        touch /var/spool/cron/root && chmod 600 /var/spool/cron/root
        systemctl start crond && systemctl enable crond
    else
        touch /var/spool/cron/crontabs/root && chmod 600 /var/spool/cron/crontabs/root
        systemctl start cron && systemctl enable cron

    fi
    judge "crontab 自启动配置 "

    ${INS} -y install bc
    judge "安装 bc"

    ${INS} -y install unzip
    judge "安装 unzip"

    ${INS} -y install qrencode
    judge "安装 qrencode"

    ${INS} -y install curl
    judge "安装 curl"

    if [[ "${ID}" == "centos" ]]; then
        ${INS} -y groupinstall "Development tools"
    else
        ${INS} -y install build-essential
    fi
    judge "编译工具包 安装"

    if [[ "${ID}" == "centos" ]]; then
        ${INS} -y install pcre pcre-devel zlib-devel epel-release
    else
        ${INS} -y install libpcre3 libpcre3-dev zlib1g-dev dbus
    fi

    #    ${INS} -y install rng-tools
    #    judge "rng-tools 安装"

    ${INS} -y install haveged
    #    judge "haveged 安装"

    #    sed -i -r '/^HRNGDEVICE/d;/#HRNGDEVICE=\/dev\/null/a HRNGDEVICE=/dev/urandom' /etc/default/rng-tools

    if [[ "${ID}" == "centos" ]]; then
        #       systemctl start rngd && systemctl enable rngd
        #       judge "rng-tools 启动"
        systemctl start haveged && systemctl enable haveged
        #       judge "haveged 启动"
    else
        #       systemctl start rng-tools && systemctl enable rng-tools
        #       judge "rng-tools 启动"
        systemctl start haveged && systemctl enable haveged
        #       judge "haveged 启动"
    fi
}

basic_optimization() {
    # 最大文件打开数
    sed -i '/^\*\ *soft\ *nofile\ *[[:digit:]]*/d' /etc/security/limits.conf
    sed -i '/^\*\ *hard\ *nofile\ *[[:digit:]]*/d' /etc/security/limits.conf
    echo '* soft nofile 65536' >>/etc/security/limits.conf
    echo '* hard nofile 65536' >>/etc/security/limits.conf

    # 关闭 Selinux
    if [[ "${ID}" == "centos" ]]; then
        sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
        setenforce 0
    fi

}

port_alterid_set() {
    if [[ "on" != "$old_config_status" ]]; then
        # 端口
        port="443"
        # alterID
        alterID="2"
    fi
}

modify_path() {
    if [[ "on" == "$old_config_status" ]]; then
        camouflage="$(grep '\"path\"' $v2ray_qr_config_file | awk -F '"' '{print $4}')"
    fi
    sed -i "/\"path\"/c \\\t  \"path\":\"${camouflage}\"" ${v2ray_conf}
    judge "V2ray 伪装路径 修改"
}

modify_alterid() {
    if [[ "on" == "$old_config_status" ]]; then
        alterID="$(grep '\"aid\"' $v2ray_qr_config_file | awk -F '"' '{print $4}')"
    fi
    sed -i "/\"alterId\"/c \\\t  \"alterId\":${alterID}" ${v2ray_conf}
    judge "V2ray alterid 修改"
    [ -f ${v2ray_qr_config_file} ] && sed -i "/\"aid\"/c \\  \"aid\": \"${alterID}\"," ${v2ray_qr_config_file}
    echo -e "${OK} ${GreenBG} alterID:${alterID} ${Font}"
}

modify_UUID() {
    [ -z "$UUID" ] && UUID=$(cat /proc/sys/kernel/random/uuid)
    if [[ "on" == "$old_config_status" ]]; then
        UUID="$(info_extraction '\"id\"')"
    fi
    sed -i "/\"id\"/c \\\t  \"id\":\"${UUID}\"," ${v2ray_conf}
    judge "V2ray UUID 修改"
    [ -f ${v2ray_qr_config_file} ] && sed -i "/\"id\"/c \\  \"id\": \"${UUID}\"," ${v2ray_qr_config_file}
    echo -e "${OK} ${GreenBG} UUID:${UUID} ${Font}"
}

modify_nginx_port() {
    if [[ "on" == "$old_config_status" ]]; then
        port="$(info_extraction '\"port\"')"
    fi
    sed -i "/ssl http2;$/c \\\tlisten ${port} ssl http2;" ${nginx_conf}
    sed -i "3c \\\tlisten [::]:${port} http2;" ${nginx_conf}
    judge "V2ray port 修改"
    [ -f ${v2ray_qr_config_file} ] && sed -i "/\"port\"/c \\  \"port\": \"${port}\"," ${v2ray_qr_config_file}
    echo -e "${OK} ${GreenBG} 端口号:${port} ${Font}"
}

modify_nginx_other() {
    sed -i "/server_name/c \\\tserver_name ${domain};" ${nginx_conf}
    sed -i "/location/c \\\tlocation ${camouflage}" ${nginx_conf}
    sed -i "/proxy_pass/c \\\tproxy_pass http://127.0.0.1:${PORT};" ${nginx_conf}
    sed -i "/return/c \\\treturn 301 https://${domain}\$request_uri;" ${nginx_conf}
    #sed -i "27i \\\tproxy_intercept_errors on;"  ${nginx_dir}/conf/nginx.conf
}

web_camouflage() {
    ##请注意 这里和LNMP脚本的默认路径冲突，千万不要在安装了LNMP的环境下使用本脚本，否则后果自负
    rm -rf /home/wwwroot
    mkdir -p /home/wwwroot
    cd /home/wwwroot || exit
    git clone https://github.com/Countra/html_pic.git
    judge "web 站点伪装"
}

modify_inbound_port() {
    if [[ "on" == "$old_config_status" ]]; then
        port="$(info_extraction '\"port\"')"
    fi
    if [[ "$shell_mode" != "h2" ]]; then
        PORT=$((RANDOM + 10000))
        sed -i "/\"port\"/c  \    \"port\":${PORT}," ${v2ray_conf}
    else
        sed -i "/\"port\"/c  \    \"port\":${port}," ${v2ray_conf}
    fi
    judge "V2ray inbound_port 修改"
}

domain_check() {
    echo 域名：$domain
    domain_ip=$(ping "${domain}" -c 1 | sed '1{s/[^(]*(//;s/).*//;q}')
    echo -e "${OK} ${GreenBG} 正在获取 公网ip 信息，请耐心等待 ${Font}"
    local_ip=$(curl https://api-ipv4.ip.sb/ip)
    echo -e "域名dns解析IP：${domain_ip}"
    echo -e "本机IP: ${local_ip}"
    sleep 2
    if [[ $(echo "${local_ip}" | tr '.' '+' | bc) -eq $(echo "${domain_ip}" | tr '.' '+' | bc) ]]; then
        echo -e "${OK} ${GreenBG} 域名dns解析IP 与 本机IP 匹配 ${Font}"
        sleep 2
    else
        echo -e "${Error} ${RedBG} 请确保域名添加了正确的 A 记录，否则将无法正常使用 V2ray ${Font}"
        echo -e "${Error} ${RedBG} 域名dns解析IP 与 本机IP 不匹配 是否继续安装？（y/n）${Font}" && read -r install
        case $install in
        [yY][eE][sS] | [yY])
            echo -e "${GreenBG} 继续安装 ${Font}"
            sleep 2
            ;;
        *)
            echo -e "${RedBG} 安装终止 ${Font}"
            exit 2
            ;;
        esac
    fi
}


old_config_exist_check() {
    if [[ -f $v2ray_qr_config_file ]]; then
        echo -e "${OK} ${GreenBG} 检测到旧配置文件，是否读取旧文件配置 [Y/N]? ${Font}"
        read -r ssl_delete
        case $ssl_delete in
        [yY][eE][sS] | [yY])
            echo -e "${OK} ${GreenBG} 已保留旧配置  ${Font}"
            old_config_status="on"
            port=$(info_extraction '\"port\"')
            ;;
        *)
            rm -rf $v2ray_qr_config_file
            echo -e "${OK} ${GreenBG} 已删除旧配置  ${Font}"
            ;;
        esac
    fi
}

nginx_conf_add() {
    touch ${nginx_conf_dir}/v2ray.conf
    cat >${nginx_conf_dir}/v2ray.conf <<EOF
    server {
        listen 443 ssl http2;
        listen [::]:443 http2;
        ssl_certificate       /data/v2ray.crt;
        ssl_certificate_key   /data/v2ray.key;
        ssl_protocols         TLSv1.3;
        ssl_ciphers           TLS13-AES-256-GCM-SHA384:TLS13-CHACHA20-POLY1305-SHA256:TLS13-AES-128-GCM-SHA256:TLS13-AES-128-CCM-8-SHA256:TLS13-AES-128-CCM-SHA256:EECDH+CHACHA20:EECDH+CHACHA20-draft:EECDH+ECDSA+AES128:EECDH+aRSA+AES128:RSA+AES128:EECDH+ECDSA+AES256:EECDH+aRSA+AES256:RSA+AES256:EECDH+ECDSA+3DES:EECDH+aRSA+3DES:RSA+3DES:!MD5;
        server_name           serveraddr.com;
        index index.html index.htm;
        root  /home/wwwroot/3DCEList;
        error_page 400 = /400.html;

        # Config for 0-RTT in TLSv1.3
        ssl_early_data on;
        ssl_stapling on;
        ssl_stapling_verify on;
        add_header Strict-Transport-Security "max-age=31536000";

        location /ray/
        {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;

        # Config for 0-RTT in TLSv1.3
        proxy_set_header Early-Data \$ssl_early_data;
        }
}
    server {
        listen 80;
        listen [::]:80;
        server_name serveraddr.com;
        return 301 https://use.shadowsocksr.win\$request_uri;
    }
EOF

    modify_nginx_port
    modify_nginx_other
    judge "Nginx 配置修改"

}

start_process_systemd() {
    systemctl daemon-reload
    if [[ "$shell_mode" != "h2" ]]; then
        systemctl restart nginx
        judge "Nginx 启动"
    fi
    systemctl restart v2ray
    judge "V2ray 启动"
}

enable_process_systemd() {
    systemctl enable v2ray
    judge "设置 v2ray 开机自启"
    if [[ "$shell_mode" != "h2" ]]; then
        systemctl enable nginx
        judge "设置 Nginx 开机自启"
    fi

}

v2ray_install() {
    if [[ -d /root/v2ray ]]; then
        rm -rf /root/v2ray
    fi
    if [[ -d /etc/v2ray ]]; then
        rm -rf /etc/v2ray
    fi
    mkdir -p /root/v2ray
    cd /root/v2ray || exit
    wget -N --no-check-certificate https://raw.githubusercontent.com/Countra/scripts/${github_branch}/v2ray.sh

    if [[ -f v2ray.sh ]]; then
        rm -rf $v2ray_systemd_file
        systemctl daemon-reload
        bash v2ray.sh --force
        judge "安装 V2ray"
    else
        echo -e "${Error} ${RedBG} V2ray 安装文件下载失败，请检查下载地址是否可用 ${Font}"
        exit 4
    fi
    # 清除临时文件
    rm -rf /root/v2ray
}


nginx_install() {
    #    if [[ -d "/etc/nginx" ]];then
    #        rm -rf /etc/nginx
    #    fi

    wget -nc --no-check-certificate http://nginx.org/download/nginx-${nginx_version}.tar.gz -P ${nginx_openssl_src}
    judge "Nginx 下载"
    wget -nc --no-check-certificate https://www.openssl.org/source/openssl-${openssl_version}.tar.gz -P ${nginx_openssl_src}
    judge "openssl 下载"
    wget -nc --no-check-certificate https://github.com/jemalloc/jemalloc/releases/download/${jemalloc_version}/jemalloc-${jemalloc_version}.tar.bz2 -P ${nginx_openssl_src}
    judge "jemalloc 下载"

    cd ${nginx_openssl_src} || exit

    [[ -d nginx-"$nginx_version" ]] && rm -rf nginx-"$nginx_version"
    tar -zxvf nginx-"$nginx_version".tar.gz

    [[ -d openssl-"$openssl_version" ]] && rm -rf openssl-"$openssl_version"
    tar -zxvf openssl-"$openssl_version".tar.gz

    [[ -d jemalloc-"${jemalloc_version}" ]] && rm -rf jemalloc-"${jemalloc_version}"
    tar -xvf jemalloc-"${jemalloc_version}".tar.bz2

    [[ -d "$nginx_dir" ]] && rm -rf ${nginx_dir}

    echo -e "${OK} ${GreenBG} 即将开始编译安装 jemalloc ${Font}"
    sleep 2

    cd jemalloc-${jemalloc_version} || exit
    ./configure
    judge "编译检查"
    make -j "${THREAD}" && make install
    judge "jemalloc 编译安装"
    echo '/usr/local/lib' >/etc/ld.so.conf.d/local.conf
    ldconfig

    echo -e "${OK} ${GreenBG} 即将开始编译安装 Nginx, 过程稍久，请耐心等待 ${Font}"
    sleep 4

    cd ../nginx-${nginx_version} || exit

    ./configure --prefix="${nginx_dir}" \
        --with-http_ssl_module \
        --with-http_gzip_static_module \
        --with-http_stub_status_module \
        --with-pcre \
        --with-http_realip_module \
        --with-http_flv_module \
        --with-http_mp4_module \
        --with-http_secure_link_module \
        --with-http_v2_module \
        --with-cc-opt='-O3' \
        --with-ld-opt="-ljemalloc" \
        --with-openssl=../openssl-"$openssl_version"
    judge "编译检查"
    make -j "${THREAD}" && make install
    judge "Nginx 编译安装"

    # 修改基本配置
    sed -i 's/#user  nobody;/user  root;/' ${nginx_dir}/conf/nginx.conf
    sed -i 's/worker_processes  1;/worker_processes  3;/' ${nginx_dir}/conf/nginx.conf
    sed -i 's/    worker_connections  1024;/    worker_connections  4096;/' ${nginx_dir}/conf/nginx.conf
    sed -i '$i include conf.d/*.conf;' ${nginx_dir}/conf/nginx.conf

    # 删除临时文件
    rm -rf ../nginx-"${nginx_version}"
    rm -rf ../openssl-"${openssl_version}"
    rm -rf ../nginx-"${nginx_version}".tar.gz
    rm -rf ../openssl-"${openssl_version}".tar.gz

    # 添加配置文件夹，适配旧版脚本
    mkdir ${nginx_dir}/conf/conf.d
}

acme() {
    if "$HOME"/.acme.sh/acme.sh --issue -d "${domain}" --standalone -k ec-256 --force --test; then
        echo -e "${OK} ${GreenBG} SSL 证书测试签发成功，开始正式签发 ${Font}"
        rm -rf "$HOME/.acme.sh/${domain}_ecc"
        sleep 2
    else
        echo -e "${Error} ${RedBG} SSL 证书测试签发失败 ${Font}"
        rm -rf "$HOME/.acme.sh/${domain}_ecc"
        exit 1
    fi

    if "$HOME"/.acme.sh/acme.sh --issue -d "${domain}" --standalone -k ec-256 --force; then
        echo -e "${OK} ${GreenBG} SSL 证书生成成功 ${Font}"
        sleep 2
        mkdir /data
        if "$HOME"/.acme.sh/acme.sh --installcert -d "${domain}" --fullchainpath /data/v2ray.crt --keypath /data/v2ray.key --ecc --force; then
            echo -e "${OK} ${GreenBG} 证书配置成功 ${Font}"
            sleep 2
        fi
    else
        echo -e "${Error} ${RedBG} SSL 证书生成失败 ${Font}"
        rm -rf "$HOME/.acme.sh/${domain}_ecc"
        exit 1
    fi
}

ssl_install() {
    if [[ "${ID}" == "centos" ]]; then
        ${INS} install socat nc -y
    else
        ${INS} install socat netcat -y
    fi
    judge "安装 SSL 证书生成脚本依赖"

    curl https://get.acme.sh | sh
    judge "安装 SSL 证书生成脚本"
}

nginx_exist_check() {
    if [[ -f "/etc/nginx/sbin/nginx" ]]; then
        echo -e "${OK} ${GreenBG} Nginx已存在，跳过编译安装过程 ${Font}"
        sleep 2
    elif [[ -d "/usr/local/nginx/" ]]; then
        echo -e "${OK} ${GreenBG} 检测到其他套件安装的Nginx，继续安装会造成冲突，请处理后安装${Font}"
        exit 1
    else
        nginx_install
    fi
}

v2ray_conf_add_tls() {
    cd /etc/v2ray || exit
    wget --no-check-certificate https://raw.githubusercontent.com/Countra/scripts/${github_branch}/tls/config.json -O config.json
    modify_path
    modify_alterid
    modify_inbound_port
    modify_UUID
}


ssl_judge_and_install() {
    if [[ -f "/data/v2ray.key" || -f "/data/v2ray.crt" ]]; then
        echo "/data 目录下证书文件已存在"
        echo -e "${OK} ${GreenBG} 是否删除 [Y/N]? ${Font}"
        read -r ssl_delete
        case $ssl_delete in
        [yY][eE][sS] | [yY])
            rm -rf /data/*
            echo -e "${OK} ${GreenBG} 已删除 ${Font}"
            ;;
        *) ;;

        esac
    fi

    if [[ -f "/data/v2ray.key" || -f "/data/v2ray.crt" ]]; then
        echo "证书文件已存在"
    elif [[ -f "$HOME/.acme.sh/${domain}_ecc/${domain}.key" && -f "$HOME/.acme.sh/${domain}_ecc/${domain}.cer" ]]; then
        echo "证书文件已存在"
        "$HOME"/.acme.sh/acme.sh --installcert -d "${domain}" --fullchainpath /data/v2ray.crt --keypath /data/v2ray.key --ecc
        judge "证书应用"
    else
        ssl_install
        acme
    fi
}

nginx_systemd() {
    cat >$nginx_systemd_file <<EOF
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/etc/nginx/logs/nginx.pid
ExecStartPre=/etc/nginx/sbin/nginx -t
ExecStart=/etc/nginx/sbin/nginx -c ${nginx_dir}/conf/nginx.conf
ExecReload=/etc/nginx/sbin/nginx -s reload
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    judge "Nginx systemd ServerFile 添加"
    systemctl daemon-reload
}

tls_type() {
    if [[ -f "/etc/nginx/sbin/nginx" ]] && [[ -f "$nginx_conf" ]] && [[ "$shell_mode" == "ws" ]]; then
        echo "请选择支持的 TLS 版本（default:3）:"
        echo "请注意,如果你使用 Quantaumlt X / 路由器 / 旧版 Shadowrocket / 低于 4.18.1 版本的 V2ray core 请选择 兼容模式"
        echo "1: TLS1.1 TLS1.2 and TLS1.3（兼容模式）"
        echo "2: TLS1.2 and TLS1.3 (兼容模式)"
        echo "3: TLS1.3 only"
        tls_version=3
        if [[ $tls_version == 3 ]]; then
            sed -i 's/ssl_protocols.*/ssl_protocols         TLSv1.3;/' $nginx_conf
            echo -e "${OK} ${GreenBG} 已切换至 TLS1.3 only ${Font}"
        elif [[ $tls_version == 1 ]]; then
            sed -i 's/ssl_protocols.*/ssl_protocols         TLSv1.1 TLSv1.2 TLSv1.3;/' $nginx_conf
            echo -e "${OK} ${GreenBG} 已切换至 TLS1.1 TLS1.2 and TLS1.3 ${Font}"
        else
            sed -i 's/ssl_protocols.*/ssl_protocols         TLSv1.2 TLSv1.3;/' $nginx_conf
            echo -e "${OK} ${GreenBG} 已切换至 TLS1.2 and TLS1.3 ${Font}"
        fi
        systemctl restart nginx
        judge "Nginx 重启"
    else
        echo -e "${Error} ${RedBG} Nginx 或 配置文件不存在 或当前安装版本为 h2 ，请正确安装脚本后执行${Font}"
    fi
}

vmess_qr_link_image() {
    vmess_link="vmess://$(base64 -w 0 $v2ray_qr_config_file)"
    {
        echo -e "$Red 二维码: $Font"
        echo -n "${vmess_link}" | qrencode -o - -t utf8
        echo -e "${Red} URL导入链接:${vmess_link} ${Font}"
    } >>"${v2ray_info_file}"
}

vmess_qr_config_tls_ws() {
    cat >$v2ray_qr_config_file <<-EOF
{
  "v": "2",
  "ps": "CountRa_${domain}",
  "add": "${domain}",
  "port": "${port}",
  "id": "${UUID}",
  "aid": "${alterID}",
  "net": "ws",
  "type": "none",
  "host": "${domain}",
  "path": "${camouflage}",
  "tls": "tls"
}
EOF
}

show_information() {
    cat "${v2ray_info_file}"
}

vmess_link_image_choice() {
        link_version=1
        if [[ $link_version == 1 ]]; then
            vmess_qr_link_image
        elif [[ $link_version == 2 ]]; then
            vmess_quan_link_image
        else
            vmess_qr_link_image
        fi
}

basic_information() {
    {
        echo -e "${OK} ${GreenBG} V2ray+ws+tls 安装成功"
        echo -e "${Red} V2ray 配置信息 ${Font}"
        echo -e "${Red} 地址（address）:${Font} $(info_extraction '\"add\"') "
        echo -e "${Red} 端口（port）：${Font} $(info_extraction '\"port\"') "
        echo -e "${Red} 用户id（UUID）：${Font} $(info_extraction '\"id\"')"
        echo -e "${Red} 额外id（alterId）：${Font} $(info_extraction '\"aid\"')"
        echo -e "${Red} 加密方式（security）：${Font} 自适应 "
        echo -e "${Red} 传输协议（network）：${Font} $(info_extraction '\"net\"') "
        echo -e "${Red} 伪装类型（type）：${Font} none "
        echo -e "${Red} 路径（不要落下/）：${Font} $(info_extraction '\"path\"') "
        echo -e "${Red} 底层传输安全：${Font} tls "
    } >"${v2ray_info_file}"
}

acme_cron_update() {
    wget -N -P /usr/bin --no-check-certificate "https://raw.githubusercontent.com/Countra/scripts/${github_branch}/ssl_update.sh"
    if [[ $(crontab -l | grep -c "ssl_update.sh") -lt 1 ]]; then
      if [[ "${ID}" == "centos" ]]; then
          #        sed -i "/acme.sh/c 0 3 * * 0 \"/root/.acme.sh\"/acme.sh --cron --home \"/root/.acme.sh\" \
          #        &> /dev/null" /var/spool/cron/root
          sed -i "/acme.sh/c 0 3 * * 0 bash ${ssl_update_file}" /var/spool/cron/root
      else
          #        sed -i "/acme.sh/c 0 3 * * 0 \"/root/.acme.sh\"/acme.sh --cron --home \"/root/.acme.sh\" \
          #        &> /dev/null" /var/spool/cron/crontabs/root
          sed -i "/acme.sh/c 0 3 * * 0 bash ${ssl_update_file}" /var/spool/cron/crontabs/root
      fi
    fi
    judge "cron 计划任务更新"
}

install_v2ray_ws_tls() {
    is_root
    check_system
    chrony_install
    dependency_install
    basic_optimization
    domain_check
    old_config_exist_check
    port_alterid_set
    v2ray_install
    nginx_exist_check
    v2ray_conf_add_tls
    nginx_conf_add
    web_camouflage
    ssl_judge_and_install
    nginx_systemd
    vmess_qr_config_tls_ws
    basic_information
    vmess_link_image_choice
    tls_type
    show_information
    start_process_systemd
    enable_process_systemd
    acme_cron_update
}

install_v2ray_ws_tls