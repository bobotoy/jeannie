#!/bin/bash
RED="\033[0;31m"
NO_COLOR="\033[0m"
GREEN="\033[0;32m"
BLUE="\033[0;36m"
echo "export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:$PATH" >> ~/.bashrc
source ~/.bashrc
echo "等3秒……"
sleep 3
isRoot(){
  if [[ "$EUID" -ne 0 ]]; then
    echo "false"
  else
    echo "true"
  fi
}
init_release(){
  if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
  if [[ $release = "ubuntu" || $release = "debian" ]]; then
    PM='apt'
  elif [[ $release = "centos" ]]; then
    PM='yum'
  else
    exit 1
  fi
  # PM='apt'
}
tools_install(){
  PID=$(ps -ef |grep "nginx" |grep "v2ray"|grep -v "grep" |grep -v "init.d" |grep -v "service" |grep -v "caddy_install" |awk '{print $2}')
	[[ ! -z ${PID} ]] && kill -9 ${PID}
  init_release
  nginx -s stop
  if [ $PM = 'apt' ] ; then
    apt-get install -y dnsutils wget unzip zip curl tar git nginx certbot
  elif [ $PM = 'yum' ]; then
    yum -y install bind-utils wget unzip zip curl tar git nginx certbot
  fi
  systemctl enable nginx.service
}
web_get(){
  rm -rf /var/www
  mkdir /var/www
  git clone https://github.com/JeannieStudio/Programming.git /var/www
}
left_second(){
    seconds_left=30
    while [ $seconds_left -gt 0 ];do
      echo -n $seconds_left
      sleep 1
      seconds_left=$(($seconds_left - 1))
      echo -ne "\r     \r"
    done
}
 v2ray_install(){
   cp  /usr/share/zoneinfo/Asia/Shanghai  /etc/localtime
   service v2ray stop
   bash <(curl -L -s https://install.direct/go.sh)
 }

nginx_conf(){
  green "=========================================="
  green "       开始申请证书"
  green "=========================================="
  read -p "请输入您的域名：" domainname
  real_addr=`ping ${domainname} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
  local_addr=`curl ipv4.icanhazip.com`
  while [ "$real_addr" != "$local_addr" ]; do
     read -p "本机ip和绑定域名的IP不一致，请检查域名是否解析成功,并重新输入域名:" domainname
     real_addr=`ping ${domainname} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
     local_addr=`curl ipv4.icanhazip.com`
  done
  read -p "请输入您的邮箱：" emailname
  read -p "您输入的邮箱正确吗? [y/n]?" answer
    if [ $answer != "y" ]; then
       read -p "请重新输入您的邮箱：" emailname
    fi
  certbot certonly --standalone --email $emailname -d $domainname
  curl -s -o /etc/nginx/sites-available/default https://raw.githubusercontent.com/JeannieStudio/jeannie/master/v2ray_default
  sed -i "s/mydomain.me/$domainname/g" /etc/nginx/sites-available/default
  cd /etc/letsencrypt/live/$domainname
  \cp fullchain.pem /etc/v2ray 2>&1 | tee /etc/v2ray/log
  \cp privkey.pem /etc/v2ray 2>&1 | tee /etc/v2ray/log
}
genId(){
    id1=$(cat /proc/sys/kernel/random/uuid | md5sum |cut -c 1-8)
    id2=$(cat /proc/sys/kernel/random/uuid | md5sum |cut -c 1-4)
    id3=$(cat /proc/sys/kernel/random/uuid | md5sum |cut -c 1-4)
    id4=$(cat /proc/sys/kernel/random/uuid | md5sum |cut -c 1-4)
    id5=$(cat /proc/sys/kernel/random/uuid | md5sum |cut -c 1-12)
    id=$id1'-'$id2'-'$id3'-'$id4'-'$id5
    echo "$id"
}
v2ray_conf(){
  genId
  read -p  "已帮您随机产生一个uuid:
  $id，
  满意吗？（输入y表示不满意再生成一个，按其他键表示接受）" answer
  while [ $answer = "y" ]; do
      genId
      read -p  "uuid:$id，满意吗？（不满意输入y,按其他键表示接受）" answer
  done
  rm -f config.json
  curl -O https://raw.githubusercontent.com/JeannieStudio/jeannie/master/config.json
  sed -i "s/"b831381d-6324-4d53-ad4f-8cda48b30811"/$id/g" config.json
  \cp -rf config.json /etc/v2ray/config.json
}
main(){
   isRoot=$( isRoot )
  if [[ "${isRoot}" != "true" ]]; then
    echo -e "${RED_COLOR}error:${NO_COLOR}Please run this script as as root"
    exit 1
  else
  tools_install
  web_get
  nginx_conf
  echo "睡一会儿……"
  left_second
  nginx
  v2ray_install
  v2ray_conf
  echo "睡一会儿……"
  sleep 6
  service v2ray start
  grep "cp: cannot stat" /etc/v2ray/log >/dev/null
  if [ $? -eq 0 ]; then
        echo -e "
        $RED==========================================
	      $RED    很遗憾，v2ray配置失败
	      $RED ==========================================
${RED}由于证书申请失败，无法科学上网，请重装或更换一个域名重新安装， 详情：https://letsencrypt.org/docs/rate-limits/
进一步验证证书申请情况，参考：https://www.ssllabs.com/ssltest/ $NO_COLOR" 2>&1 | tee info
      else
    green "=========================================="
	  green "       恭喜你，Trojan安装和配置成功"
	  green "=========================================="
  echo -e "${GREEN}恭喜你，v2ray安装和配置成功
$BLUE域名:        ${GREEN}${domainname}
$BLUE端口:        ${GREEN}443
${BLUE}UUID:      ${GREEN}${id}
${BLUE}alterId:   ${GREEN}64
${BLUE}混淆:      ${GREEN}websocket
${BLUE}路径：     ${GREEN}/ray
${BLUE}伪装网站：${GREEN}https://${domainname}
${BLUE}Windows、Macos客户端下载v2ray-core： ${GREEN}https://github.com/v2ray/v2ray-core/releases
${BLUE}安卓客户端下载v2rayNG: ${GREEN}https://github.com/2dust/v2rayNG/releases
${BLUE}ios客户端请到应用商店下载：${GREEN}shadowrocket
${BLUE}喜欢的话记得视频点赞、分享或订阅jeannie studio：${GREEN}https://bit.ly/2X042ea ${NO_COLOR}" 2>&1 | tee info
      fi
  touch /etc/motd
  cat info > /etc/motd
  fi
}
main