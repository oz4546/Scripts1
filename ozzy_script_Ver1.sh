#! /bin/bash


echo "Shell script to install Wordpress into an EC2 instance of Amazon AMI Linux."
if ! [[ $(id -u) == 0 ]]; then
   echo "Please be root before running!"
   exit 1
fi

#RESULT=$(decision "y" "n")
#RETURN_VALUE=$?

# decision - input: $1 variable name, $2 first value, $3 second value
function decision {	

#local USER_SENT_VARIABLE=$1
local TEMP_VARIABLE
	while [ 1 ]
	do
		read -e TEMP_VARIABLE
	    if  [[ $TEMP_VARIABLE == $1 ]] || [[ $TEMP_VARIABLE == $2 ]]; then
	        echo "Ok, input is valid"
			break	
	    else
		    echo "please choose valid option - $1 or $2"
	    fi
	done
	#eval $USER_SENT_VARIABLE=$TEMP_VARIABLE
	echo -e "$TEMP_VARIABLE"
	return 0
}

function check_db_user_pass {	

if [[ "$1" =~ ^[A-Za-z0-9#$+*]{8,}$ ]]; then
    echo "Pass is valid"
	break
else
    echo "Pass is invalid"
fi
	
}

function path_check {	

if [[ -d "$1" ]] && [[ $1 =~ ^[A-Za-z0-9#$+*]{2,}$ ]]; then
	echo "Ok, input is valid"
	return	0	
else
	echo "please enter valid path ...."
	return 1
fi
	
}


echo "Would you like to install Apache Web Server (type 'apache') or Nginx Web Server (type 'nginx')?"
WP_SERVER_CHECK=$(decision "nginx" "apache")
			


echo "Would you like to install EC2 - MYSQL (type 'local) or RDS MYSQL (type 'rds')? "
WP_MY_SQL=$(decision "local" "rds" )



echo "Would you like to install Wordpress on File System (type 'fs') or locally (type 'local')? "
WP_EFS=$(decision "fs" "local" )



echo "Would you like to Install Logz.io -  AWS analytics tools: (y/n) "
LOGZ_IO=$(decision "y" "n" )



echo "Would you like to Install DataDog-agent: (y/n) "
DATADOG=$(decision "y" "n" )


echo "============================================"
echo "==============SUMMARY ======================"
echo "============================================"

echo "The following application will be installed: $1($WP_SERVER_CHECK, $WP_MY_SQL, $WP_EFS, $LOGZ_IO, $DATADOG) would you like to continue? (y/n)"

if [[ "$WP_SERVER_CHECK" == "apache" ]]; then
	echo "Apache Web Server will be installed"
else
	echo "nginx Web Server will be installed"
	
fi

if [[ "$WP_MY_SQL" == "local" ]]; then
	echo "MY SQL will be installed locally"
else
	echo "RDS will be installed"
	
fi



if [[ "$WP_EFS" == "fs" ]]; then
	echo "Wordpress will be installed on EFS (Amazon Elastic File System)"
else
	echo "Wordpress will be installed locally"
	
fi

if [[ "$LOGZ_IO" == "y" ]]; then
	echo "Logz.IO will be installed"
else
	echo "installation will continue without Logz.IO"
	
fi

if [[ "$DATADOG" == "y" ]]; then
	echo "Datadog be installed"
else
	echo "installation will continue without DATADOG"
	
fi

CONTINUE=$(decision "y" "n" )

if [[$CONTINUE == "n"]]; then
	exit1
else
	

	echo "============================================"
	echo "Installing . . . . . . . . . . . . . . . . "
	echo "============================================"


# lets yum update
yum -y update

#Checking if the chosen web server (apache/nginx)already installed
if [[ "$WP_SERVER_CHECK" == ״apache"" ]] && [[ ! -f "/etc/init.d/httpd" ]]; then
	echo "Installing APACHE...."
	yum install -y php56 php56-mysqlnd httpd
	chkconfig httpd on
	service start httpd
else
	echo "Installing nginx or Apache already installed"

fi

if [[ $WP_SERVER_CHECK == "nginx" ]] && [[ ! -f "/etc/init.d/nginx" ]] ; then

	echo "Installing Nginx ...."
		yum -y install nginx
		service nginx start
		chkconfig nginx on

		# NEED TO EDIT CONF FILES of NGINX/PHP-FPM

		mv -v /etc/nginx/nginx.conf /etc/nginx/nginx-original.conf

		cat > /etc/nginx/conf.d/nginx.conf <<"EOF"
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /var/run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    include /etc/nginx/conf.d/*.conf;

    index   index.php;

    server {
        listen       80 default_server;
        listen       [::]:80 default_server;
        server_name  localhost;
        root         /var/www/html;

        include /etc/nginx/default.d/*.conf;

        location / {
        }

        error_page 404 /404.html;
            location = /40x.html {
        }

	    error_page 500 502 503 504 /50x.html;
	        location = /50x.html {
	    }
	    location ~ \.php$ {
	        fastcgi_pass 127.0.0.1:9000;
	        fastcgi_index index.php;
	        fastcgi_param SCRIPT_FILENAME /var/www/html$fastcgi_script_name;
	        include fastcgi_params;
	    }
    }
}

EOF

	else
		echo "nginx already installed"

fi


if [[ "$WP_SERVER_CHECK" == 2 ]] && [[ ! -f "/etc/init.d/php-fpm" ]] ; then
	yum -y install php-fpm php-mysql
	service php-fpm start
	chkconfig php-fpm on

     # NEED TO EDIT CONF FILES PHP-FPM
    mv -v /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf_original
    cat > /etc/php-fpm.d/www.conf <<EOF
[www]
listen = 127.0.0.1:9000
listen.allowed_clients = 127.0.0.1
user = nginx
group = nginx
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
slowlog = /var/log/php-fpm/www-slow.log
php_admin_value[error_log] = /var/log/php-fpm/www-error.log
php_admin_flag[log_errors] = on
EOF

else
	echo "php-fpm already installed"
fi

if [ $WP_EFS == "fs" ]; then

	while [ 1 ]
	do
		echo 
		read -e mpdir "Please enter mount path to get WP files from EFS"
		echo "Please enter EFS url (press Enter for existing EFS url)"
		read -e EFS_ENDPOINT
		EFS_ENDPOINT="${EFS_ENDPOINT:-fs-7ea24b07.efs.us-east-2.amazonaws.com}"
		MOUNTPOINT_LIST="$(cat /etc/fstab | awk -F' ' '{print $2}')"
		if [[ ! -z $mpdir ]] && [[ -z "$(echo $MOUNTPOINT_LIST | grep -ow "$mpdir")" ]]; then
		        break
		else
			echo "path $mpdir exists in fstab or no input was specified"
		fi
	done
	mkdir $mpdir
	#Create Mount folder and Connect to EFS
	echo "$EFS_ENDPOINT:/ $mpdir nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 0 0" >> /etc/fstab
	mount -a -t nfs4
	#symoblic link sot to mount folder
	mkdir -p /var/www/
	sudo ln -s $mpdir /var/www/html

else

#Installing wordpresss locally


	echo "Installing WordPress"

	#download wordpress
	echo "Downloading..."
	curl -O https://wordpress.org/latest.tar.gz
	echo "Unpacking..."
	tar -zxf latest.tar.gz
	#move /wordpress/* files to  var/www/html
	echo "Moving..."
	mv wordpress/* /var/www/html
	echo "Configuring..."
	#create wp config
	mv /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

fi


if [ "$MYSQL" == "local" ]; then
	echo "Installing MYSQL locally...."
	yum install -y mysql55-server php56-mysqlnd
	sudo service mysqld start
	sudo chkconfig mysqld on

	echo "MySQL Admin User: "
	read -e mysqluser
	echo "MySQL Admin Password: "
	read -es mysqlpass
	echo 'MySQL Host (Enter for default "localhost"):'
	read -e mysqlhost
	mysqlhost=${mysqlhost:-localhost}

	echo "WP Database Name: "
	read -e dbname

while [ 1 ]
	do
		echo "WP Database User: "
		read -e dbuser
		check_db_user_pass $dbuser
	done

while [ 1 ]
	do
		echo "WP Database Password: "
		read -s dbpass
		check_db_user_pass $dbpass
	done
				
	echo 'WP Database Table Prefix [numbers, letters, and underscores only] (Enter for default "wp_"): '
	read -e dbtable
	dbtable=${dbtable:-wp_}
	echo "Last chance - sure you want to run the mysql install? y/n"
	read -e runsql
	if [ "$runsql" == y ]; then
	        echo "Setting up the database."
		#login to MySQL, add database, add user and grant permissions
		dbsetup="create database $dbname;GRANT ALL PRIVILEGES ON $dbname.* TO $dbuser@$mysqlhost IDENTIFIED BY '$dbpass';FLUSH PRIVILEGES;"
		mysql -u $mysqluser -p$mysqlpass -e "$dbsetup"
	        if [ $? != "0" ]; then
			echo "[Error]: Database creation failed. Aborting."
			exit 1
		fi
        fi
else
	echo "Please enter RDS url or Enter for existing RDS URL"
	read -e RDS_URL
	RDS_URL=${RDS_URL:-ozzydb.cr4vntkeippl.us-east-2.rds.amazonaws.com}
	sed -e "s/localhost/$RDS_URL/g" /var/www/http/wp-config.php
	echo "WP Database Name: "
	read -e DBNAME_RDS
	echo "WP Database User: "
	read -e DBUSER_RDS
	echo "WP Database Password: "
	read -s DBPASS_RDS
	#set database details with perl find and replace
	sed -e "s/database_name_here/$DBNAME_RDS/g" /var/www/http/wp-config.php
	sed -e "s/username_here/$DBUSER_RDS/g" /var/www/http/wp-config.php
	sed "s/password_here/$DBPASS_RDS/g" /var/www/http/wp-config.php
fi

if [[ $LOGZ_IO == "y" ]]; then
		echo "Please insert LOGZ.IO token Enter for existing token"
		read -e LOGZ_IO_TOKEN
		LOGZ_IO_TOKEN=${LOGZ_IO_TOKEN:-xvEpuAbRseXfkrQqwUuJfTRBSeSGVcxA}

        echo "Installing Filebeat..."
		yum -y install https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-5.5.2-x86_64.rpm
		mkdir -p /etc/pki/tls/certs
		wget https://raw.githubusercontent.com/logzio/public-certificates/master/COMODORSADomainValidationSecureServerCA.crt ### download directly to the directory
		#sudo cp COMODORSADomainValidationSecureServerCA.crt /etc/pki/tls/certs/
		mv -v /etc/filebeat/filebeat.yml /etc/filebeat/filebeat_original.yml

		cat > /etc/filebeat/filebeat.yml << EOF
		############################# Filebeat #####################################
		filebeat:
		  prospectors:
		    -
		      paths:
		        - <ACCESS_PATH>
		      fields:
		        logzio_codec: plain
		        token:<TOKEN>
		      fields_under_root: true
		      ignore_older: 3h
		      document_type: <DOC_TYPE_ACCESS>
		    -
		      paths:
		        - <ERROR_PATH>
		      fields:
		        logzio_codec: plain
		        token:<TOKEN>
		      fields_under_root: true
		      ignore_older: 3h
		      document_type: <DOC_TYPE_ERROR>
		  registry_file: /var/lib/filebeat/registry
		############################# Output ##########################################
		output:
		  logstash:
		    hosts: ["listener.logz.io:5015"]
			
		########  The below configuration is used for Filebeat 5.0 or higher
		    ssl:
		      certificate_authorities: ['/etc/pki/tls/certs/COMODORSADomainValidationSecureServerCA.crt']


EOF			  			  
if [ "$WP_SERVER_CHECK" == "apache" ]; then

			#EDIT FILEBEAT CONF FILE - /etc/filebeat/filebeat.yml - nginx Log			  
	sed -ie "s/<ACCESS_PATH>/ \/var\/log\/apache2\/access\.log /g" /etc/filebeat/filebeat.yml
	sed -ie "s/<TOKEN>/$LOGZ_IO_TOKEN/g" /etc/filebeat/filebeat.yml 
	sed -ie "s/<DOC_TYPE_ACCESS>/apache/g" /etc/filebeat/filebeat.yml 	  
	sed -ie "s/<ERROR_PATH>//var/log/apache2/error.log/g" /etc/filebeat/filebeat.yml 	  
	sed -ie "s/<TOKEN>/$LOGZ_IO_TOKEN/g" /etc/filebeat/filebeat.yml
	sed -ie "s/<DOC_TYPE_ERROR>/apache_error/g" /etc/filebeat/filebeat.yml 	  		
else
	sed -ie "s/<ACCESS_PATH>/ \/var/log/nginx/error.log /g" /etc/filebeat/filebeat.yml
	sed -ie "s/<TOKEN>/$LOGZ_IO_TOKEN/g" /etc/filebeat/filebeat.yml 
	sed -ie "s/<DOC_TYPE_ACCESS>/nginx-access/g" /etc/filebeat/filebeat.yml 	  
	sed -ie "s/<ERROR_PATH>/ \/var\/log\/nginx\/error\.log/g" /etc/filebeat/filebeat.yml 	  
	sed -ie "s/<TOKEN>/$LOGZ_IO_TOKEN/g" /etc/filebeat/filebeat.yml
	sed -ie "s/<DOC_TYPE_ERROR>/nginx-error/g" /etc/filebeat/filebeat.yml 	
fi

if [[ $LOGZ_IO == "n" ]]; then
	
        echo "Ok, installation will continue without Logz.IO"



#Install Datadog-Agent

if [[ $DATA_DOG == "y" ]]; then
	echo "Please insert DataDog API key or Enter for existing API key"
	read -e DD_KEY
	export DD_API_KEY=${DD_KEY:-45cd1449066136f4fe1355f4fc343d6a}
    bash -c "$(curl -L https://raw.githubusercontent.com/DataDog/dd-agent/master/packaging/datadog-agent/source/install_agent.sh)"
else
	echo "Ok, installation will continue without DataDog"
    echo "Ready, go to http://<your ec2 url>/blog and enter the blog info to finish the WP installation."
fi

fi
