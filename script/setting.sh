#!/bin/bash

backendDir=/opt/backend/xrayr
frontendDir=/opt/frontend/sspanel


red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#Add some basic function here
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}
# check root
[[ $EUID -ne 0 ]] && LOGE "错误:  必须使用root用户运行此脚本!\n" && exit 1


function install_docker () {
	LOGI install docker...
	sudo apt-get update
	sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
	sudo mkdir -p /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	echo \
	"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
	$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
	service docker restart
}

function install_xrayr () {
	LOGI install xrayr....
	cd /opt/backend && git clone https://github.com/XrayR-project/XrayR-release xrayr && 	cd $backendDir

	curl -L https://raw.githubusercontent.com/sJus4Fun/configfile/main/backend/docker-compose.yml > docker-compose.yml
	# nginx
	mkdir nginx && touch ./nginx/nginx.conf
	curl -L https://raw.githubusercontent.com/sJus4Fun/configfile/main/backend/nginx.conf > ./nginx/nginx.conf
	# html 
	git clone https://github.com/sJus4Fun/html.git ./nginx/html
}

function apply_certification () {
	mkdir -p $1
	LOGI "stat apply certification..."
	service nginx stop
	curl https://get.acme.sh | sh
	apt install socat
	ln -s  /root/.acme.sh/acme.sh /usr/local/bin/acme.sh
	acme.sh --register-account -m my@example.com
	ufw allow 80
	read -p "enter your domain:" mydomain
	acme.sh  --issue -d $mydomain  --standalone -k ec-256 
	acme.sh --installcert -d $mydomain --ecc  --key-file   $1/privkey.pem   --fullchain-file $1/fullchain.pem
}

function install_bbr() {
    # temporary workaround for installing bbr
    bash < curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh
}

function init_setting() {
	# add heart beat to ssh connection
	LOGI "start add heart beat to ssh connection"
	
	sed -i  "s/#ClientAliveInterval 0/ClientAliveInterval 30/" /etc/ssh/sshd_config
	sed -i  "s/#ClientAliveCountMax 3/ClientAliveCountMax 3/" /etc/ssh/sshd_config
	service sshd restart
	
	
	# change default ssh port
	read -p "Input new ssh port:" sshPort
	LOGI "start change default ssh port"
	sed -i  "s/#Port 22/Port ${sshPort}/" /etc/ssh/sshd_config
	sed -i  "s/Port \([0-9]\{2,\}\)/Port ${sshPort}/" /etc/ssh/sshd_config
	
	# change vim setting
	echo "set ts=2 sw=2">> /etc/vim/vimrc 
	
	# do not record command history
	rm -f ~/.bash_history
	ln -s /dev/null ~/.bash_history
	
	# enable ufw
	#ufw enable
	#ufw allow from 127.0.0.1
	
	# alias
	echo alias cw=\'cd /opt/backend/xrayr/\' >>  ~/.bashrc
	echo alias nginxt=\'docker exec -it nginxt bash\' >>  ~/.bashrc

	LOGI "setting finished"
}

function install_frontend() {
	cd /opt/frontend && git clone https://github.com/BobCoderS9/SSPanel-Metron.git sspanel && cd $frontendDir 
	frontend_setting
	docker exec -i php sh -c 'exec php xcat Tool initQQWry'
}

function frontend_setting(){
	// todo
	scp -P 2222  root@test1.sjufun.tk:/root/SSPanel-Metron/config/.config.php ./config

	cp config/.metron_setting.example.php config/.metron_setting.php
	cp config/appprofile.example.php config/appprofile.php

	curl -L https://raw.githubusercontent.com/sJus4Fun/configfile/main/front/docker-compose.yaml > docker-compose.yaml
	mkdir nginx && touch ./nginx/nginx.conf
	curl -L https://raw.githubusercontent.com/sJus4Fun/configfile/main/front/nginx/nginx.conf > nginx/nginx.conf

	docker compose down
	docker compose up -d

	docker exec sspanel sh -c 'exec curl -SL https://getcomposer.org/installer -o composer.phar'
	docker exec sspanel sh -c 'exec php composer.phar'
	docker exec sspanel sh -c 'exec php composer.phar install'

	chmod -R 755 $frontendDir
	chown -R www-data:www-data $frontendDir

	setting_mysql
}

function setting_mysql(){
	docker exec -i mysql sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e"\
	SET NAMES utf8;
	CREATE DATABASE sspanel CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
	use sspanel;
	source /tmp/sql/db.sql;"'
}


function init(){
	init_setting
	install_docker
	install_bbr
}

function front_oneclick(){
	LOGI 前端一键开始
	init
	install_frontend
	certPath=$frontendDir/nginx/cert
	apply_certification $certPath
	docker compose up 
}

function backend_oneclick(){
	LOGI 后端一键开始
	init
	install_xrayr
	certPath=$backendDir/nginx/cert
	apply_certification $certPath
	docker compose up 
}


show_menu() {
  echo -e "
  ${green} Tom 一键面板管理脚本${plain}
  ${plain}
  ${green}0.${plain} 退出脚本
————————————————
  ${green}1.${plain} 前端一键
  ${green}2.${plain} 后端一键
  ${green}3.${plain} 更换后端端口
————————————————
  ${green}4.${plain} 重置用户名密码
  ${green}5.${plain} 重置面板设置
  ${green}6.${plain} 设置面板端口
  ${green}7.${plain} 查看当前面板设置
————————————————
 "
    echo && read -p "请输入选择 [0-16]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        front_oneclick
        ;;
    2)
        check_install && update
        ;;
    3)
        check_install && uninstall
        ;;
    4)
        check_install && reset_user
        ;;
    5)
        check_install && reset_config
        ;;
    *)
        LOGE "请输入正确的数字 [0-16]"
        ;;
    esac
}

show_menu
