echo "Please enter your Critical Stack API Key: "
read cs_api

read -p "Enter SMTP Host (smtp.gmail.com): " smtpHost
smtpHost=${smtpHost:-smtp.gmail.com}

read -p "Enter SMTP Port (587): " smtpPort
smtpPort=${smtpPort:-587}

read -p "Enter Email Address (email@gmail.com): " emailAddr
emailAddr=${emailAddr:-email@gmail.com}

IFS= read -p "Enter Email Password (P@55word): " emailPwd
emailPwd=${emailPwd:-P@55word}


home_path="/home/pi"
current_path=`pwd`
cd dirname $0
my_path=`pwd`


cd $home_path

echo "Installing Pre-Requisites..."
sudo apt-get update 
sudo apt-get install -y ntp git
sudo apt-get install -y --force-yes build-essential libpcre3-dev libdumbnet-dev zlib1g-dev liblzma-dev
sudo apt-get install -y --force-yes cmake make gcc g++ libpcap-dev libssl-dev python-dev cmake-data libarchive13 liblzo2-2
sudo apt-get install -y --force-yes swig ant zip nmap texinfo bison flex openssl
sudo apt-get install -y --force-yes openjdk-8-jdk
sudo apt-get install -y --force-yes arpwatch p0f
echo "export JAVA_HOME=\"/usr/lib/jvm/java-8-openjdk-armhf/jre/bin\"" |sudo tee -a /etc/bash.bashrc0
export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-armhf/jre/bin"


#Instal Snort
sudo apt-get install -y ethtool
#/etc/network/interfaces
#iface eth0 inet dhcp
#post-up ethtool -K eth0 gro off
#post-up ethtool -K eth0 lro off
sudo apt-get install -y snort libdaq0 oinkmaster snort-common snort-common-libraries snort-rules-default
sudo mkdir /var/log/snort/archived
sudo mkdir /etc/snort/rules/iplist
sudo touch black_list.rules
sudo touch white_list.rules
sudo chmod -R u+rw,g+r,o+r /etc/snort
sudo chmod -R u+rw,g+r,o+r /var/log/snort
sudo chmod -R u+rw,g+r,o+r /usr/lib/snort
sudo chown -R snort:snort /etc/snort
sudo chown -R snort:snort /var/log/snort
sudo chown -R snort:snort /usr/lib/snort


#Install ossec
cd $home_path
sudo wget https://bintray.com/artifact/download/ossec/ossec-hids/ossec-hids-2.8.3.tar.gz
sudo tar -zxvf ossec-hids-2.8.3.tar.gz
sudo ln -s /opt/ossec/etc /etc/ossec
sudo ln -s /opt/ossec/logs /var/log/ossec
sudo cp $my_path/preloaded-vars.conf $home_path/ossec-hids-2.8.3/etc
sudo sed -i -- "s/EMAIL_USER/$emailAddr/g" $home_path/ossec-hids-2.8.3/etc/preloaded-vars.conf
sudo sed -i -- "s/SMTP_HOST/$smtpHost/g" $home_path/ossec-hids-2.8.3/etc/preloaded-vars.conf
sudo sed -i -- "s/\(<email_to>\).*\(<\/email_to>\)/\1${emailAddr}\2/g" $home_path/ossec-hids-2.8.3/etc/ossec.conf
sudo sed -i -- "s/\(<smtp_server>\).*\(<\/smtp_server>\)/\1${smtpHost}\2/g" $home_path/ossec-hids-2.8.3/etc/ossec.conf
sudo sed -i -- "s/\(<email_from>\).*\(<\/email_from>\)/\1${emailAddr}\2/g" $home_path/ossec-hids-2.8.3/etc/ossec.conf

sudo $home_path/ossec-hids-2.8.3/install.sh
for x in $(sudo ls /var/ossec/etc); do sudo ln -s /var/ossec/etc/$x /etc/ossec/$x; done
sudo rm -rf ossec-hids-2.8.3
sudo rm -f ossec-hids-2.8.3.tar.gz
cd /etc/ossec
sudo sed -i -- '/.*windows.*$/Id' /etc/ossec/ossec.conf
#Add policy to monitor all snort, bro, logstash, elasticsearch and kibana configurations
sudo service ossec start
sudo update-rc.d ossec defaults

#Install Bro
echo "Installing Bro"
sudo apt-get -y install bro broctl
if [ $? != 0 ]; then
   sudo wget https://www.bro.org/downloads/bro-2.5.tar.gz
   sudo tar -xzf bro-2.5.tar.gz
   sudo mkdir -p /opt/nsm/bro
   sudo mkdir /etc/bro
   cd bro-2.5
   sudo ./configure --prefix=/opt/nsm/bro
   sudo make
   sudo make install
   cd ..
   sudo rm bro-2.5.tar.gz
   sudo rm -rf bro-2.5/
   for i in $(ls /opt/nsm/bro/etc/); do sudo ln -s /opt/nsm/bro/etc/$i /etc/bro/$i ; done
   sudo ln -s /opt/nsm/bro/bin/bro /usr/bin/bro
   sudo ln -s /opt/nsm/bro/bin/broctl /usr/bin/broctl
   sudo ln -s /opt/nsm/bro/share/bro/site /etc/bro/site
   sudo ln -s /opt/nsm/bro/logs /var/log/bro
   sudo sed -i -- 's,LogDir.*,LogDir = /var/log/bro,g' /etc/bro/broctl.cfg
   sudo sed -i -- 's,SpoolDir.*,SpoolDir = /var/spool/bro,g' /etc/bro/broctl.cfg
fi


#Install Critical Stack
echo "Installing Critical Stack Agent"
cs_package_url="https://intel.criticalstack.com/client/"
if [[ $(dpkg --print-architecture) = amd64 ]]; then
   cs_package="critical-stack-intel-amd64.deb"
fi
if [[ $(dpkg --print-architecture) = i386 ]]; then
   cs_package="critical-stack-intel-i386.deb"
fi
if [[ $(dpkg --print-architecture) = armrh ]] || [[ $(dpkg --print-architecture) = armhf ]]; then
   cs_package="critical-stack-intel-arm.deb"
fi
sudo wget ${cs_package_url}${cs_package} --no-check-certificate
sudo dpkg -i $cs_package
sudo -u critical-stack critical-stack-intel api $cs_api 
sudo rm $cs_package

cd $home_path

#Install ElasticSearch
echo "Installing Elastic Search"
if [[ $(dpkg --print-architecture) = armrh ]] || [[ $(dpkg --print-architecture) = armhf ]]; then
   es_package_url="https://download.elastic.co/elasticsearch/elasticsearch/"
   es_package="elasticsearch-2.3.2.deb"
else
   es_package_url="https://artifacts.elastic.co/downloads/elasticsearch/" 
   es_package="elasticsearch-5.2.1.deb"
fi
sudo wget ${es_package_url}${es_package}
sudo dpkg -i $es_package
sudo rm $es_package
if [[ $(dpkg --print-architecture) = armrh ]] || [[ $(dpkg --print-architecture) = armhf ]]; then
   #sudo ln -s /var/log/elasticsearch/ data
   #sudo ln -s /var/log/elasticsearch/ log
   #sudo ln -s /etc/elasticsearch/ config
   #sudo rm -f /var/log/elasticsearch/elasticsearch
   #sudo rm -f /etc/elasticsearch/elasticsearch
   sudo sed -i -- 's,# path\.logs.*, path\.logs: /var/log/elasticsearch/elasticsearch,g' /etc/elasticsearch/elasticsearch.yml
   sudo sed -i -- 's,# path\.data.*, path\.data: /var/log/elasticsearch/elasticsearch,g' /etc/elasticsearch/elasticsearch.yml
   sudo sed -i -- 's,# cluster\.name.*, cluster\.name: Wolverine,g' /etc/elasticsearch/elasticsearch.yml
fi
sudo service elasticsearch start
sudo update-rc.d elasticsearch defaults
#Test if Elastic search is working with the following command:
curl -X GET http://127.0.0.1:9100; if [ $? = 0 ]; then echo "ElasticSearch engine OK"; else echo "ElasticSearch engine KO"; fi


#Install LogStash
echo "Installing Logstash"
if [[ $(dpkg --print-architecture) = armrh ]] || [[ $(dpkg --print-architecture) = armhf ]]; then
   ls_package_url="https://download.elastic.co/logstash/logstash/packages/debian/"
   ls_package="logstash_2.3.2-1_all.deb"
else
   ls_package_url="https://artifacts.elastic.co/downloads/logstash/"
   ls_package="logstash-5.2.1.deb"
fi
sudo wget ${ls_package_url}${ls_package}
sudo dpkg -i $ls_package
sudo rm $ls_package
cd $home_path
if [[ $(dpkg --print-architecture) = armrh ]] || [[ $(dpkg --print-architecture) = armhf ]]; then
   sudo git clone https://github.com/jnr/jffi.git
   cd jffi
   sudo bash -c 'PATH="/usr/lib/jvm/java-8-openjdk-armhf/bin/:/usr/lib/jvm/java-8-openjdk-armhf/lib/:$PATH" && ant jar'
   sudo cp /opt/logstash/vendor/jruby/lib/jni/arm-Linux/libjffi-1.2.so /opt/logstash/vendor/jruby/lib/jni/arm-Linux/libjffi-1.2.so.original
   sudo cp build/jni/libjffi-1.2.so /opt/logstash/vendor/jruby/lib/jni/arm-Linux
   cd /opt/logstash/vendor/jruby/lib
   sudo wget https://s3.amazonaws.com/jruby.org/downloads/1.7.23/jruby-complete-1.7.23.jar
   sudo zip -g jruby.jar jni/arm-Linux/libjffi-1.2.so
   sudo mv jruby-complete-1.7.23.jar jruby.jar
   sudo zip -g jruby.jar jni/arm-Linux/libjffi-1.2.so
   cd $home_path
   sudo rm -rf jffi/
fi

sudo update-rc.d logstash defaults

if [[ $(dpkg --print-architecture) = armrh ]] || [[ $(dpkg --print-architecture) = armhf ]]; then
   sudo /opt/logstash/bin/logstash-plugin install logstash-filter-translate
   sudo /opt/logstash/bin/logstash-plugin install logstash-output-email
else
   sudo /usr/share/logstash/bin/logstash-plugin install logstash-filter-translate
   sudo /usr/share/logstash/bin/logstash-plugin install logstash-output-email
fi
sudo cp $my_path/logstash.conf /etc/logstash/conf.d
sudo mkdir /etc/logstash/custom_patterns
sudo cp $my_path/bro.rule /etc/logstash/custom_patterns
sudo mkdir /etc/logstash/translate

#Install Kibana
echo "Installing Kibana"
kb_package_url="https://artifacts.elastic.co/downloads/kibana/kibana-5.0.0-linux-x86_64.tar.gz"
kb_package="kibana-5.0.0-linux-x86_64.tar.gz"
kb_package_dir="kibana-5.0.0-linux-x86_64/"
#Switching to old kibana as 5.0 requires elasticsearch 5.0 as well
if [[ $(dpkg --print-architecture) = armrh ]] || [[ $(dpkg --print-architecture) = armhf ]]; then
   kb_package_url="https://download.elastic.co/kibana/kibana/kibana-4.5.0-linux-x86.tar.gz"
   kb_package="kibana-4.5.0-linux-x86.tar.gz"
   kb_package_dir="kibana-4.5.0-linux-x86"
fi
sudo wget $kb_package_url
sudo tar -xzf $kb_package
sudo mv $kb_package_dir /opt/kibana/
if [[ $(dpkg --print-architecture) = armrh ]] || [[ $(dpkg --print-architecture) = armhf ]]; then
   sudo apt-get -y remove nodejs-legacy nodejs nodered		#Remove nodejs on Pi3, if they exist
   sudo wget http://node-arm.herokuapp.com/node_latest_armhf.deb
   sudo dpkg -i node_latest_armhf.deb
   sudo mv /opt/kibana/node/bin/node /opt/kibana/node/bin/node.orig
   sudo mv /opt/kibana/node/bin/npm /opt/kibana/node/bin/npm.orig
   sudo ln -s /usr/local/bin/node /opt/kibana/node/bin/node
   sudo ln -s /usr/local/bin/npm /opt/kibana/node/bin/npm
   sudo rm node_latest_armhf.deb
fi
sudo cp $my_path/init.d/kibana /etc/init.d
sudo chmod 555 /etc/init.d/kibana
sudo update-rc.d kibana defaults

#Configure Scripts
sudo mkdir /opt/SweetSecurity
sudo cp $my_path/pullMaliciousIP.py /opt/SweetSecurity/
sudo cp $my_path/pullTorIP.py /opt/SweetSecurity/
#Run scripts for the first time
sudo python /opt/SweetSecurity/pullTorIP.py
sudo python /opt/SweetSecurity/pullMaliciousIP.py

#Configure Logstash Conf File
sudo sed -i -- 's/SMTP_HOST/"$smtpHost"/g' /etc/logstash/conf.d/logstash.conf
sudo sed -i -- 's/SMTP_PORT/"$smtpPort"/g' /etc/logstash/conf.d/logstash.conf
sudo sed -i -- 's/EMAIL_USER/"$emailAddr"/g' /etc/logstash/conf.d/logstash.conf
sudo sed -i -- 's/EMAIL_PASS/"$emailPwd"/g' /etc/logstash/conf.d/logstash.conf


cd $my_path
sudo cp networkDiscovery.py /opt/SweetSecurity/networkDiscovery.py
sudo cp SweetSecurityDB.py /opt/SweetSecurity/SweetSecurityDB.py
#Configure Network Discovery Scripts
sudo sed -i -- 's/SMTP_HOST/"$smtpHost"/g' /opt/SweetSecurity/networkDiscovery.py
sudo sed -i -- 's/SMTP_PORT/"$smtpPort"/g' /opt/SweetSecurity/networkDiscovery.py
sudo sed -i -- 's/EMAIL_USER/"$emailAddr"/g' /opt/SweetSecurity/networkDiscovery.py
sudo sed -i -- 's/EMAIL_PASS/"$emailPwd"/g' /opt/SweetSecurity/networkDiscovery.py
sudo chmod +x /opt/SweetSecurity/networkDiscovery.py
sudo chmod +x /opt/SweetSecurity/SweetSecurityDB.py
sudo chmod +x /opt/SweetSecurity/pullTorIP.py
sudo chmod +x /opt/SweetSecurity/pullMaliciousIP.py

sudo sed -i -- 's/--no-warnings//g' /opt/kibana/bin/kibana

#Restart services
echo "Restarting ELK services"
sudo service elasticsearch restart
sudo service kibana restart
sudo service logstash restart


#Deploy and start BroIDS
echo "Deploying and starting BroIDS"
sudo /usr/bin/broctl deploy
sudo /usr/bin/broctl start

cd $current_path
