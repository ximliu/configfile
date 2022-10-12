#!/bin/bash

workspace=/opt/backend
xrayrPath=$workspace/XrayR-release
certPath=$workspace/XrayR-release/cert

mkdir -p $workspace

function install_docker () {
	echo "install docker"
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
	echo "install xrayr"
	cd $workspace
	git clone https://github.com/XrayR-project/XrayR-release && cd $xrayrPath

	curl -L https://raw.githubusercontent.com/sJus4Fun/configfile/main/docker-compose.yml > docker-compose.yml
	# nginx
	mkdir nginx && touch ./nginx/nginx.conf
	curl -L https://raw.githubusercontent.com/sJus4Fun/configfile/main/nginx.conf > ./nginx/nginx.conf
	# html 
	git clone https://github.com/sJus4Fun/html.git ./nginx/html
}

function apply_certification () {
	mkdir -p $certPath
	echo "stat apply certification..."
	service nginx stop
	curl https://get.acme.sh | sh
	apt install socat
	ln -s  /root/.acme.sh/acme.sh /usr/local/bin/acme.sh
	acme.sh --register-account -m my@example.com
	ufw allow 80
	read -p "enter your domain:" mydomain
	acme.sh  --issue -d $mydomain  --standalone -k ec-256 
	acme.sh --installcert -d $mydomain --ecc  --key-file   $certPath/privkey.pem   --fullchain-file $certPath/fullchain.pem
}



function install_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
}

function init_setting() {
	# add heart beat to ssh connection
	echo "start add heart beat to ssh connection"
	
	sed -i  "s/#ClientAliveInterval 0/ClientAliveInterval 30/" /etc/ssh/sshd_config
	sed -i  "s/#ClientAliveCountMax 3/ClientAliveCountMax 3/" /etc/ssh/sshd_config
	service sshd restart
	
	
	# change default ssh port
	read -p "Input new ssh port:" sshPort
	echo "start change default ssh port"
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
	echo alias cw=\'cd /opt/backend/XrayR-release/\' >>  ~/.bashrc
	echo alias nginxt=\'docker exec -it nginxt bash\' >>  ~/.bashrc

	echo"setting finished"

}


read -p "wanna init setting?[y/n]" arg

if [ $arg == 'y' ];
then
	init_setting
fi

read -p "wanna docker?[y/n]" arg

if [ $arg == 'y' ];
then
	install_docker
fi

read -p "wanna install xrayr?[y/n]" arg

if [ $arg == 'y' ];
then
	install_xrayr
fi

read -p "wanna apply certification?[y/n]" arg

if [ $arg == 'y' ];
then
	apply_certification
fi

read -p "wanna install bbr?[y/n]" arg

if [ $arg == 'y' ];
then
	install_bbr
fi


docker compose up 



