#!/bin/bash
source vars

## INFO
# This script installs and configures NZBget
##

#######################
# Dependencies
#######################
wget rarlab.com/rar/unrarsrc-5.2.7.tar.gz
tar -xvf unrarsrc-5.2.7.tar.gz
cd unrar
make -j2 -f makefile
install -v -m755 unrar /usr/bin
cd ..
rm -R unrar
rm unrarsrc-5.2.7.tar.gz

#######################
# Install
#######################
NZBGETLATEST=$(wget http://nzbget.net/download/ -O - | grep run | awk -F "[\"]" '{print $4}' | head -n1)
wget $NZBGETLATEST -O nzbget-latest-bin-linux.run
sh nzbget-latest-bin-linux.run --destdir /opt/nzbget
rm nzbget-latest-bin-linux.run

ln -sf /usr/bin/python2.7 /usr/bin/python2

#######################
# Configure
#######################
## Tell nzbget to start as the default user
sed -i "/DaemonUsername=/c\DaemonUsername=$username" /opt/nzbget/nzbget.conf

### Modify config file
## PATHS
sed -i "s/^MainDir=.*/MainDir=/home/$username/nzbget/g" /opt/nzbget/nzbget.conf
sed -i 's|^DestDir=.*|DestDir=${MainDir}/completed|g' /opt/nzbget/nzbget.conf
sed -i 's|^InterDir=.*|InterDir=${MainDir}/intermediate|g' /opt/nzbget/nzbget.conf

## NEWS-SERVERS
sed -i "s/^Server1.Active=.*/Server1.Active=yes/g" /opt/nzbget/nzbget.conf
sed -i "s/^Server1.Name=.*/Server1.Name=$newsServer/g" /opt/nzbget/nzbget.conf
sed -i "s/^Server1.Host=.*/Server1.Host=$nsHostname/g" /opt/nzbget/nzbget.conf
sed -i "s/^Server1.Port=.*/Server1.Port=$nsPort/g" /opt/nzbget/nzbget.conf
sed -i "s/^Server1.Username=.*/Server1.Username=$nsUsername/g" /opt/nzbget/nzbget.conf
sed -i "s/^Server1.Password=.*/Server1.Password=$nsPassword/g" /opt/nzbget/nzbget.conf
sed -i "s/^Server1.Encryption=.*/Server1.Encryption=$nsEncryption/g" /opt/nzbget/nzbget.conf
sed -i "s/^Server1.Connections=.*/Server1.Connections=$nsConnections/g" /opt/nzbget/nzbget.conf
sed -i "s/^Server1.Retention=.*/Server1.Retention=$nsRetention/g" /opt/nzbget/nzbget.conf

## SECURITy
sed -i "s/^ControlUsername=.*/ControlUsername=$username/g" /opt/nzbget/nzbget.conf
sed -i "s/^ControlPassword=.*/ControlPassword=$passwd/g" /opt/nzbget/nzbget.conf
sed -i "s/^DaemonUsername=.*/DaemonUsername=$username/g" /opt/nzbget/nzbget.conf## Copy default config file
cp /home/$username/nzbget/scripts/autoProcessMedia.cfg.spec /home/$username/nzbget/scripts/autoProcessMedia.cfg

## DOWNLOAD QUEUE
sed -i "s/^ArticleCache=.*/ArticleCache=1900/g" /opt/nzbget/nzbget.conf
sed -i "s/^WriteBuffer=.*/WriteBuffer=1024/g" /opt/nzbget/nzbget.conf

## LOGGING
sed -i "s/^WriteLog=.*/WriteLog=rotate/g" /opt/nzbget/nzbget.conf

## UNPACK
sed -i 's|^UnrarCmd=.*|UnrarCmd=${AppDir}/unrar|g' /opt/nzbget/nzbget.conf
sed -i 's|^SevenZipCmd=.*|SevenZipCmd=${AppDir}/7za|g' /opt/nzbget/nzbget.conf

## EXTENSTION SCRIPTS
sed -i 's/^ScriptOrder=.*/ScriptOrder=nzbToMedia*.py, Email.py, Logger.py, upload*.sh/g' /opt/nzbget/nzbget.conf

#######################
# Structure
#######################
mkdir -p /home/$username/nzbget
mkdir -p /home/$username/nzbget/completed
mkdir -p /home/$username/nzbget/intermediate
mkdir -p /home/$username/nzbget/nzb 
mkdir -p /home/$username/nzbget/queue
mkdir -p /home/$username/nzbget/tmp
mkdir -p /home/$username/nzbget/scripts

#######################
# Systemd Service File
#######################
tee "/etc/systemd/system/nzbget.service" > /dev/null <<EOF
[Unit]
Description=NZBGet Daemon
Documentation=http://nzbget.net/Documentation
After=rcloneMount.service
RequiresMountsFor=/mnt/usbstorage

[Service]
User=$username
Group=$username
Type=forking
ExecStart=/opt/nzbget/nzbget -c /opt/nzbget/nzbget.conf -D
ExecStop=/opt/nzbget/nzbget -Q
ExecReload=/opt/nzbget/nzbget -O
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

#######################
# Permissions
#######################
chown -R $username:$username /opt/nzbget

systemctl stop rcloneMount.service
chown -R $username:$username /home/$username
systemctl start rcloneMount.service

#######################
# Autostart
#######################
systemctl daemon-reload
systemctl start nzbget
systemctl enable nzbget

#######################
# Remote Access
#######################
echo ''
echo "Do you want to allow remote access to NZBget?"
echo "If so, you need to tell UFW to open the port."
echo "Otherwise, you can use SSH port forwarding."
echo ''
echo "Would you like us to open the port in UFW?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) ufw allow 6789; echo ''; echo "Port 6789 open, NZBget is now available over the internet."; echo ''; break;;
        No ) echo "Port 6789 left closed. You can still access it on your local machine by issuing the following command: ssh $username@$ipaddr -L 6789:localhost:6789"; echo "and then open localhost:6789 on your browser."; exit;;
    esac
done



