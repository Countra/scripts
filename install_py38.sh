#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

OK="${Green}[OK]${Font}"
Error="${Red}[错误]${Font}"
RedBG="\033[41;37m"
GreenBG="\033[42;37m"
Font="\033[0m"
ID="None"
py3="/usr/local/python3"

# 判断版本
ID=$(cat /etc/*release | grep "^ID=" | sed 's/["ID=]//g')

if [[ "${ID}" == "centos" ]];then
        echo -e "${OK} ${GreenBG} 当前系统为 Centos${Font}"
        INS="yum"
        $INS install -y zlib zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gcc  libffi-devel
    elif [[ "${ID}" == "debian" ]];then
        echo -e "${OK} ${GreenBG} 当前系统为 Debian${Font}"
        INS="apt"
        $INS update
        $INS-get install -y zlib zlib1g-dev libbz2-dev  libsqlite3-dev gcc make build-essential libssl-dev openssl-devel
    elif [[ "${ID}" == "ubuntu" ]];then
        echo -e "${OK} ${GreenBG} 当前系统为 Ubuntu${Font}"
        INS="apt"
        $INS update
        $INS-get install -y zlib zlib1g-dev libbz2-dev  libsqlite3-dev gcc make build-essential libssl-dev openssl-devel
    else
        echo -e "${Error} ${RedBG} 当前系统为 ${ID} 不在支持的系统列表内 ${Font}"
        exit 1
    fi

# 开始下载安装
mkdir -p $py3
cd $py3
wget https://www.python.org/ftp/python/3.8.5/Python-3.8.5.tgz
tar -zxvf *.tgz
cd Python-3.8.5
./configure --prefix=/usr/local/python3
make && make install
ln -s /usr/local/python3/bin/python3 /usr/bin/python38
ln -s /usr/local/python3/bin/pip3 /usr/bin/pip38
echo 'export PATH=$PATH:$HOME/bin:/usr/local/python3/bin' >> ~/.bash_profile
source ~/.bash_profile

echo -e "${OK} ${GreenBG} 安装完成 测试如下${Font}"
echo -e "${OK} ${GreenBG}38版本的python和pip的命令分别为python38和pip38${Font}"
python38 -V
pip38 -V

# pip38安装一下一些必要的库
/usr/local/python3/bin/python3.8 -m pip install --upgrade pip
pip38 install httpx
pip38 install translate