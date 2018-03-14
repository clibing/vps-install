#!/bin/bash

# env
INSTALL_DIR="/data/"
NGINX_VERSION="1.13.9-alpine"
DOMAINS="-d "

# joint domain for acme param
function jointDomain(){
  DOMAINS="-d "
  if [ "$#" -gt 1 ];then
    # fix me
    DOMAINS="${DOMAINS}`echo -e "$*" | sed 's/ / -d /g'`"
  else
    DOMAINS="-d $1 -d www.$1"
  fi
}

# init utc
function envInit(){
    echo -e "start env init..."
    sudo apt-get update
    sudo apt-get install -y lrzsz curl git openssl socat
    sudo cp -rf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime 
    sudo mkdir -p /data/ssl 
    cd ${INSTALL_DIR}
    if [ ! -d "${INSTALL_DIR}/install" ];then
        git clone https://github.com/clibing/vps-install.git install
    else
        cd ${INSTALL_DIR}/install
        git pull
    fi
    rm -rf /root/.acme.h
    mkdir -p /data/install/nginx/conf/backup
}

# install docker ce
function dockerInstall(){
    sudo apt-get remove docker docker-engine docker.io
    sudo apt-get update
    sudo apt-get install apt-transport-https ca-certificates curl software-properties-common
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo apt-key fingerprint 0EBFCD88 
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" 
    sudo apt-get update
    sudo apt-get install docker-ce -y
    sudo docker run --rm hello-world
}

# install nginx for verification acme
function installNginx(){
   echo -e "start install nginx domain: [$1]"
   ngxconf="/data/install/nginx/conf/nginx-`date +%Y%m%d%H%M%S`.conf"
   cp /data/install/nginx/conf/nginx.conf ${ngxconf}
   sed "s/DOMAIN_REPLACE/$1/g" -i ${ngxconf}
   docker stop acme-nginx
   docker rm acme-nginx
   docker run -d -v ${ngxconf}:/etc/nginx/nginx.conf -v /data/install/nginx/html:/usr/share/nginx/html --name "acme-nginx" -p 80:80 nginx:${NGINX_VERSION}
}

# install let's encrypt
function installLetSencrypt(){
    echo -e "start install let's encrypt: $1 ${DOMAINS}"
    rm -rf /root/.acme.sh
    sudo curl https://get.acme.sh | sh
    #echo -e "`/root/.acme.sh/acme.sh --debug --issue ${DOMAINS} -w /data/install/nginx/html -k 2048`"
    #rm -rf /data/install/nginx/html/.well-known
    echo -e "......................................."
    /root/.acme.sh/acme.sh --issue -d linuxcrypt.top -w /data/install/nginx/html/
    # cp ssl ca to nginx conf/ssl
            #--cert-file /data/ssl/$1.cert \
    mkdir -p /data/ssl/$1
    /root/.acme.sh/acme.sh --installcert -d $1 \
            --key-file /data/ssl/$1.key  \
            --fullchain-file /data/ssl/$1/fullchain.cer

    sudo openssl dhparam -out /data/ssl/dhparam.pem 2048
    #docker stop acme-nginx
}

# set www.aliyun.com dns
function updateDnsRecord(){
   domain="${1}"
   # only lo and eth0
   address="`ip address | grep 'inet' | grep -v 'inet6' | grep -v '127.0.0.1'|awk '{print $2}' | awk -F '/' '{print $1}'`"
   # update dns record by api
}

# update nginx for ssl
function updateNginx(){
   echo -e "start install nginx will set domain: $1"
   # run by docker 
   # must set ssl file and open 443, will the file share to github.com
   mv /data/install/nginx/conf/nginx-*.conf /data/install/nginx/conf/backup/
   ngxconf="/data/install/nginx/conf/nginx-`date +%Y%m%d%H%M%S`.conf"
   cp /data/install/nginx/conf/nginx.conf ${ngxconf} 
   sed 's/#ssl_protocols/ssl_protocols/g' -i ${ngxconf}
   sed 's/#ssl_prefer_server_ciphers/ssl_prefer_server_ciphers/g' -i ${ngxconf}
   sed "s/DOMAIN_REPLACE/$1/g" -i ${ngxconf}
   sed 's/#ssl_certificate/ssl_certificate/g' -i ${ngxconf}
   sed 's/#ssl_certificate_key/ssl_certificate_key/g' -i ${ngxconf} 
   sed 's/#ssl_dhparam/ssl_dhparam/g' -i ${ngxconf}
   
   # stop nginx-docker
   docker rm acme-nginx
   docker run -d -v ${ngxconf}:/etc/nginx/nginx.conf \
              -v /data/install/nginx/html:/usr/share/nginx/html \
              -v /data/ssl:/etc/nginx/ssl \
              -v /data/acme/linuxcrypt.top/ssl/$1.key:/etc/nginx/ssl/$1.key \
              -v /data/acme/linuxcrypt.top/ssl/$1.pem:/etc/nginx/ssl/$1.pem \
              -v /data/acme/linuxcrypt.top/ssl/dhparam.pem:/etc/nginx/ssl/dhparam.pem \
              --name "acme-nginx" -p 80:80 -p 443:443 nginx:${NGINX_VERSION}
}

domain="linuxcrypt.top"

# init env
#envInit

# install docker ce
#dockerInstall

# add domain
#jointDomain ${domain}

# add http for domain
#installNginx ${domain}

# create ssl ca
#echo -e "${DOMAINS}"
#installLetSencrypt ${domain}

# create nginx-.conf from nginx-template.conf
updateNginx ${domain}



