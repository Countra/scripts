# Self-use script collection

## python3.8

```shell
wget https://raw.githubusercontent.com/Countra/scripts/master/python/install_py38.sh && chmod +x install_py38.sh && bash install_py38.sh
```

## v2+ws+nginx+tls(vmess)

```shell
wget -N --no-check-certificate -q -O install.sh "https://raw.githubusercontent.com/Countra/scripts/master/v2ray/v2.sh" && chmod +x install.sh && bash install.sh **domain**
```

## Server initialization settings

```shell
wget -N --no-check-certificate -q -O init.sh "https://raw.githubusercontent.com/Countra/scripts/master/init/init_ra.sh" && chmod +x init.sh && bash init.sh
```

## Raspberry Pi

```shell
https://github.com/Countra/scripts/raspberrypi
```

## Add linux swap size

> *Test environment: debian*

```shell
wget -N --no-check-certificate -q -O addSwap.sh "https://raw.githubusercontent.com/Countra/scripts/master/linuxUtil/addSwap/addSwap.sh" && chmod +x addSwap.sh && bash addSwap.sh ** Fill in the size you need to increase /G **
```
