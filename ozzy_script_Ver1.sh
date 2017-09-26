#! /bin/bash


echo "Shell script to install Wordpress into an EC2 instance of Amazon AMI Linux."

	if ! [ $(id -u) = 0 ]; then
	   echo "Please be root before running!"
	   exit 1
	fi
	
		
echo "Would you like to install Apache Web Server (Press 1) or Nginx Web Server (Press 2)? "
read -e WP_SERVER_CHECK

#Not Sure if -z check is neccesary in the next conditions

if [[ -z $WP_SERVER_CHECK ]] || [[ $WP_SERVER_CHECK != "1" ]] || [[ $WP_SERVER_CHECK != "2" ]]; then
	echo “please choose valid option (1 for Apache / 2 for Nginx)....”
fi

echo "Would you like to install EC2 - MYSQL (locally) (Press 1) or RDS MYSQL (Press 2)? "
read -e WP_MYSQL
if [[ -z $WP_MYSQL]] || [[$WP_MYSQL != "1"]] || [[$WP_MYSQL != "2"]]; then
	echo “please choose valid option (1 for EC2 MYSQL / 2 for RDS MYSQL)....”
fi

echo "Would you like to install Wordpress on File System (Press 1) or locally (Press 2)? "
read -e WP_EFS
if [[ -z $WP_EFS ]] || [[ $WP_EFS != "1" ]] || [[ $WP_EFS != "2" ]]; then
	echo “please choose valid option (1 for EFS / 2 for locally installation)....”
fi


echo "Would you like to Install Logz.io -  AWS analytics tools: (y/n) "
read -e LOGZ_IO
if [[ $LOGZ_IO != "y" || $LOGZ_IO != "n" ]]; then
	echo “please choose valid option (y/n)....”
fi

echo "Would you like to Install DataDog-agent: (y/n) "
read -e DATA_DOG
if [[ $LDATA_DOG != "y" || $LDATA_DOG != "n" ]]; then
	echo “please choose valid option (y/n)....”
fi


	echo "============================================"
	echo "Installing . . . . . . . . . . . . . . . . "
	echo "============================================"

# lets yum update 
yum -y update

#Checking if the chosen web server (apache/nginx)already installed
if [[ "$WP_SERVER_CHECK" == 1 ]] && [[ ! -f "/etc/init.d/httpd" ]] ; then
	echo “Installing APACHE....”
	yum install -y php56 php56-mysqlnd httpd
	chkconfig httpd on
	service start httpd
else
	echo "Installing nginx or Apache already installed"

fi
	
if [[ $WP_SERVER_CHECK == 2]] && [[ ! -f "/etc/init.d/nginx" ]] ; then

	echo “Installing Nginx ....”
		yum -y install nginx
		service nginx start
		chkconfig nginx on

		# NEED TO EDIT CONF FILES of NGINX/PHP-FPM  

		mv -v /etc/nginx/nginx.conf /etc/nginx/nginx-original.conf

		cat > /etc/nginx/conf.d/nginx.conf <<"EOF"
		# For more information on configuration, see:
		#   * Official English Documentation: http://nginx.org/en/docs/
		#   * Official Russian Documentation: http://nginx.org/ru/docs/

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

		    # Load modular configuration files from the /etc/nginx/conf.d directory.
		    # See http://nginx.org/en/docs/ngx_core_module.html#include
		    # for more information.
		    include /etc/nginx/conf.d/*.conf;

		    index   index.php;

		    server {
		        listen       80 default_server;
		        listen       [::]:80 default_server;
		        server_name  localhost;
		        root         /var/www/html;

		        # Load configuration files for the default server block.
		        include /etc/nginx/default.d/*.conf;

		        location / {
		        }

		        # redirect server error pages to the static page /40x.html
		        #
		        error_page 404 /404.html;
		            location = /40x.html {
		        }

		        # redirect server error pages to the static page /50x.html
		        #
		        error_page 500 502 503 504 /50x.html;
		            location = /50x.html {
		        }

		        # proxy the PHP scripts to Apache listening on 127.0.0.1:80
		        #
		        #location ~ \.php$ {
		        #    proxy_pass   http://127.0.0.1;
		        #}

		        # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
		        #
		        #location ~ \.php$ {
		        #    root           html;
		        #    fastcgi_pass   127.0.0.1:9000;
		        #    fastcgi_index  index.php;
		        #    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
		        #    include        fastcgi_params;
		        #}

		location ~ \.php$ {
		 fastcgi_pass 127.0.0.1:9000;
		 fastcgi_index index.php;
		 fastcgi_param SCRIPT_FILENAME /var/www/html$fastcgi_script_name;
		 include fastcgi_params;
		}
		        # deny access to .htaccess files, if Apache's document root
		        # concurs with nginx's one
		        #
		        #location ~ /\.ht {
		        #    deny  all;
		        #}
		    }

		# Settings for a TLS enabled server.
		#
		#    server {
		#        listen       443 ssl http2 default_server;
		#        listen       [::]:443 ssl http2 default_server;
		#        server_name  _;
		#        root         /usr/share/nginx/html;
		#
		#        ssl_certificate "/etc/pki/nginx/server.crt";
		#        ssl_certificate_key "/etc/pki/nginx/private/server.key";
		#        # It is *strongly* recommended to generate unique DH parameters
		#        # Generate them with: openssl dhparam -out /etc/pki/nginx/dhparams.pem 2048
		#        #ssl_dhparam "/etc/pki/nginx/dhparams.pem";
		#        ssl_session_cache shared:SSL:1m;
		#        ssl_session_timeout  10m;
		#        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
		#        ssl_ciphers HIGH:SEED:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!RSAPSK:!aDH:!aECDH:!EDH-DSS-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA:!SRP;
		#        ssl_prefer_server_ciphers on;
		#
		#        # Load configuration files for the default server block.
		#        include /etc/nginx/default.d/*.conf;
		#
		#        location / {
		#        }
		#
		#        error_page 404 /404.html;
		#            location = /40x.html {
		#        }
		#
		#        error_page 500 502 503 504 /50x.html;
		#            location = /50x.html {
		#        }
		#    }

		}

EOF
		
	else
		echo "nginx already installed"
		
fi
if [[ "$WP_SERVER_CHECK" == 2]] && [[ -f ! "/etc/init.d/$php-fpm"]] ; then
			yum -y install php-fpm php-mysql
			service php-fpm start
			chkconfig php-fpm on


# NEED TO EDIT CONF FILES PHP-FPM

mv -v /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf_original

cat > /etc/php-fpm.d/www.conf <<EOF
			; Start a new pool named 'www'.
			[www]

			; The address on which to accept FastCGI requests.
			; Valid syntaxes are:
			;   'ip.add.re.ss:port'    - to listen on a TCP socket to a specific address on
			;                            a specific port;
			;   'port'                 - to listen on a TCP socket to all addresses on a
			;                            specific port;
			;   '/path/to/unix/socket' - to listen on a unix socket.
			; Note: This value is mandatory.
			listen = 127.0.0.1:9000

			; Set listen(2) backlog. A value of '-1' means unlimited.
			; Default Value: -1
			;listen.backlog = -1

			; List of ipv4 addresses of FastCGI clients which are allowed to connect.
			; Equivalent to the FCGI_WEB_SERVER_ADDRS environment variable in the original
			; PHP FCGI (5.2.2+). Makes sense only with a tcp listening socket. Each address
			; must be separated by a comma. If this value is left blank, connections will be
			; accepted from any ip address.
			; Default Value: any
			listen.allowed_clients = 127.0.0.1

			; Set permissions for unix socket, if one is used. In Linux, read/write
			; permissions must be set in order to allow connections from a web server. Many
			; BSD-derived systems allow connections regardless of permissions.
			; Default Values: user and group are set as the running user
			;                 mode is set to 0666
			;listen.owner = nginx
			;listen.group = nginx
			;listen.mode = 0664

			; Unix user/group of processes
			; Note: The user is mandatory. If the group is not set, the default user's group
			;       will be used.
			; RPM: apache Choosed to be able to access some dir as httpd
			user = nginx
			; RPM: Keep a group allowed to write in log dir.
			group = nginx

			; Choose how the process manager will control the number of child processes.
			; Possible Values:
			;   static  - a fixed number (pm.max_children) of child processes;
			;   dynamic - the number of child processes are set dynamically based on the
			;             following directives:
			;             pm.max_children      - the maximum number of children that can
			;                                    be alive at the same time.
			;             pm.start_servers     - the number of children created on startup.
			;             pm.min_spare_servers - the minimum number of children in 'idle'
			;                                    state (waiting to process). If the number
			;                                    of 'idle' processes is less than this
			;                                    number then some children will be created.
			;             pm.max_spare_servers - the maximum number of children in 'idle'
			;                                    state (waiting to process). If the number
			;                                    of 'idle' processes is greater than this
			;                                    number then some children will be killed.
			; Note: This value is mandatory.
			pm = dynamic

			; The number of child processes to be created when pm is set to 'static' and the
			; maximum number of child processes to be created when pm is set to 'dynamic'.
			; This value sets the limit on the number of simultaneous requests that will be
			; served. Equivalent to the ApacheMaxClients directive with mpm_prefork.
			; Equivalent to the PHP_FCGI_CHILDREN environment variable in the original PHP
			; CGI.
			; Note: Used when pm is set to either 'static' or 'dynamic'
			; Note: This value is mandatory.
			pm.max_children = 50

			; The number of child processes created on startup.
			; Note: Used only when pm is set to 'dynamic'
			; Default Value: min_spare_servers + (max_spare_servers - min_spare_servers) / 2
			pm.start_servers = 5

			; The desired minimum number of idle server processes.
			; Note: Used only when pm is set to 'dynamic'
			; Note: Mandatory when pm is set to 'dynamic'
			pm.min_spare_servers = 5

			; The desired maximum number of idle server processes.
			; Note: Used only when pm is set to 'dynamic'
			; Note: Mandatory when pm is set to 'dynamic'
			pm.max_spare_servers = 35

			; The number of requests each child process should execute before respawning.
			; This can be useful to work around memory leaks in 3rd party libraries. For
			; endless request processing specify '0'. Equivalent to PHP_FCGI_MAX_REQUESTS.
			; Default Value: 0
			;pm.max_requests = 500

			; The URI to view the FPM status page. If this value is not set, no URI will be
			; recognized as a status page. By default, the status page shows the following
			; information:
			;   accepted conn    - the number of request accepted by the pool;
			;   pool             - the name of the pool;
			;   process manager  - static or dynamic;
			;   idle processes   - the number of idle processes;
			;   active processes - the number of active processes;
			;   total processes  - the number of idle + active processes.
			; The values of 'idle processes', 'active processes' and 'total processes' are
			; updated each second. The value of 'accepted conn' is updated in real time.
			; Example output:
			;   accepted conn:   12073
			;   pool:             www
			;   process manager:  static
			;   idle processes:   35
			;   active processes: 65
			;   total processes:  100
			; By default the status page output is formatted as text/plain. Passing either
			; 'html' or 'json' as a query string will return the corresponding output
			; syntax. Example:
			;   http://www.foo.bar/status
			;   http://www.foo.bar/status?json
			;   http://www.foo.bar/status?html
			; Note: The value must start with a leading slash (/). The value can be
			;       anything, but it may not be a good idea to use the .php extension or it
			;       may conflict with a real PHP file.
			; Default Value: not set
			;pm.status_path = /status

			; The ping URI to call the monitoring page of FPM. If this value is not set, no
			; URI will be recognized as a ping page. This could be used to test from outside
			; that FPM is alive and responding, or to
			; - create a graph of FPM availability (rrd or such);
			; - remove a server from a group if it is not responding (load balancing);
			; - trigger alerts for the operating team (24/7).
			; Note: The value must start with a leading slash (/). The value can be
			;       anything, but it may not be a good idea to use the .php extension or it
			;       may conflict with a real PHP file.
			; Default Value: not set
			;ping.path = /ping

			; This directive may be used to customize the response of a ping request. The
			; response is formatted as text/plain with a 200 response code.
			; Default Value: pong
			;ping.response = pong

			; The timeout for serving a single request after which the worker process will
			; be killed. This option should be used when the 'max_execution_time' ini option
			; does not stop script execution for some reason. A value of '0' means 'off'.
			; Available units: s(econds)(default), m(inutes), h(ours), or d(ays)
			; Default Value: 0
			;request_terminate_timeout = 0

			; The timeout for serving a single request after which a PHP backtrace will be
			; dumped to the 'slowlog' file. A value of '0s' means 'off'.
			; Available units: s(econds)(default), m(inutes), h(ours), or d(ays)
			; Default Value: 0
			;request_slowlog_timeout = 0

			; The log file for slow requests
			; Default Value: not set
			; Note: slowlog is mandatory if request_slowlog_timeout is set
			slowlog = /var/log/php-fpm/www-slow.log

			; Set open file descriptor rlimit.
			; Default Value: system defined value
			;rlimit_files = 1024

			; Set max core size rlimit.
			; Possible Values: 'unlimited' or an integer greater or equal to 0
			; Default Value: system defined value
			;rlimit_core = 0

			; Chroot to this directory at the start. This value must be defined as an
			; absolute path. When this value is not set, chroot is not used.
			; Note: chrooting is a great security feature and should be used whenever
			;       possible. However, all PHP paths will be relative to the chroot
			;       (error_log, sessions.save_path, ...).
			; Default Value: not set
			;chroot =

			; Chdir to this directory at the start. This value must be an absolute path.
			; Default Value: current directory or / when chroot
			;chdir = /var/www

			; Redirect worker stdout and stderr into main error log. If not set, stdout and
			; stderr will be redirected to /dev/null according to FastCGI specs.
			; Default Value: no
			;catch_workers_output = yes

			; Limits the extensions of the main script FPM will allow to parse. This can
			; prevent configuration mistakes on the web server side. You should only limit
			; FPM to .php extensions to prevent malicious users to use other extensions to
			; exectute php code.
			; Note: set an empty value to allow all extensions.
			; Default Value: .php
			#;security.limit_extensions = .php .php3 .php4 .php5
			; security.limit_extensions = 
			; Pass environment variables like LD_LIBRARY_PATH. All $VARIABLEs are taken from
			; the current environment.
			; Default Value: clean env
			;env[HOSTNAME] = $HOSTNAME
			;env[PATH] = /usr/local/bin:/usr/bin:/bin
			;env[TMP] = /tmp
			;env[TMPDIR] = /tmp
			;env[TEMP] = /tmp

			; Additional php.ini defines, specific to this pool of workers. These settings
			; overwrite the values previously defined in the php.ini. The directives are the
			; same as the PHP SAPI:
			;   php_value/php_flag             - you can set classic ini defines which can
			;                                    be overwritten from PHP call 'ini_set'.
			;   php_admin_value/php_admin_flag - these directives won't be overwritten by
			;                                     PHP call 'ini_set'
			; For php_*flag, valid values are on, off, 1, 0, true, false, yes or no.

			; Defining 'extension' will load the corresponding shared extension from
			; extension_dir. Defining 'disable_functions' or 'disable_classes' will not
			; overwrite previously defined php.ini values, but will append the new value
			; instead.

			; Default Value: nothing is defined by default except the values in php.ini and
			;                specified at startup with the -d argument
			;php_admin_value[sendmail_path] = /usr/sbin/sendmail -t -i -f www@my.domain.com
			;php_flag[display_errors] = off
			php_admin_value[error_log] = /var/log/php-fpm/www-error.log
			php_admin_flag[log_errors] = on
			;php_admin_value[memory_limit] = 32M

EOF
			
		else
			
		echo "php-fpm already installed"
		fi
fi	


if [ $WP_EFS == 1 ] then;

	echo "Please enter mount path to get WP files from EFS"
	read -e mpdir
	echo "Please enter EFS url (press Enter for existing EFS url)"
	read -e EFS_URL	
	EFS_URL=${EFS_URL:-fs-7ea24b07.efs.us-east-2.amazonaws.com}

	while [[ true ]]
	do
	

		MOUNTPOINT_LIST="$(cat /etc/fstab | awk -F' ' '{print $2}')"
		if [[! -z $mpdir]] && [["$(echo $MOUNTPOINT_LIST | grep -ow "$mpdir")"]]; then
			mkdir $mpdir
			#Create Mount folder and Connect to EFS
			echo "$EFS_URL:/ $mpdir nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 0 0" >> /etc/fstab
			mount -a -t nfs4
			#symoblic link sot to mount folder
			mkdir -p /var/www/
			sudo ln -s $mpdir /var/www/html
		break
		else
			echo "path $mpdir exists in fstab or no input was specified"
		fi
	done
	
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


if [ "$MYSQL" == 1 ]; then
	echo “Installing MYSQL locally....”
	yum install -y mysql55-server php56-mysqlnd 
	sudo service mysqld start
	sudo chkconfig mysqld on
	
	echo "MySQL Admin User: "
	read -e mysqluser
	echo "MySQL Admin Password: "
	read -s mysqlpass
	echo "MySQL Host (Enter for default 'localhost'): "
	read -e mysqlhost
		mysqlhost=${mysqlhost:-localhost}

		echo "WP Database Name: "
		read -e dbname
		echo "WP Database User: "
		read -e dbuser
		echo "WP Database Password: "
		read -s dbpass
		echo "WP Database Table Prefix [numbers, letters, and underscores only] (Enter for default 'wp_'): "
		read -e dbtable
		dbtable=${dbtable:-wp_}
		echo "Last chance - sure you want to run the mysql install? (y/n)"
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

	
else
	echo "Please enter RDS url (or Enter for existing RDS URL)"
	read -e RDS_URL	
	RDS_URL=${RDS_URL:-ozzydb.cr4vntkeippl.us-east-2.rds.amazonaws.com}
	sed -e “s/localhost/$RDS_URL/g” /var/www/http/wp-config.php
	echo "WP Database Name: "
	read -e DBNAME_RDS
	echo "WP Database User: "
	read -e DBUSER_RDS
	echo "WP Database Password: "
	read -s DBPASS_RDS
	#set database details with perl find and replace
	sed -e “s/database_name_here/$DBNAME_RDS/g” /var/www/http/wp-config.php
	sed -e “s/username_here/$DBUSER_RDS/g” /var/www/http/wp-config.php
	sed “s/password_here/$DBPASS_RDS/g” w/var/www/http/wp-config.php
fi



#
if [[ $LOGZ_IO == "y" ]]; then;
		echo "Please insert LOGZ.IO token (Enter for existing token)"
		read -e LOGZ_IO_TOKEN
		LOGZ_IO_TOKEN=${LOGZ_IO_TOKEN:-xvEpuAbRseXfkrQqwUuJfTRBSeSGVcxA}
		
        echo "Installing Filebeat..."
		curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-5.5.2-x86_64.rpm
		sudo rpm -vi filebeat-5.5.2-x86_64.rpm
		wget https://raw.githubusercontent.com/logzio/public-certificates/master/COMODORSADomainValidationSecureServerCA.crt
		sudo mkdir -p /etc/pki/tls/certs
		sudo cp COMODORSADomainValidationSecureServerCA.crt /etc/pki/tls/certs/
		mv -v /etc/filebeat/filebeat.yml /etc/filebeat/filebeat_original.yml
		
		if [ "WP_SERVER_CHECK" == 2 ] ; then

			#EDIT FILEBEAT CONF FILE - /etc/filebeat/filebeat.yml - nginx Logz

			cat > /etc/filebeat/filebeat.yml <<EOF
			############################# Filebeat #####################################
			filebeat:
			  prospectors:
			    -
			      paths:
			        - /var/log/nginx/access.log
			      fields:
			        logzio_codec: plain
			        token: $LOGZ_IO_TOKEN
			      fields_under_root: true
			      ignore_older: 3h
			      document_type: nginx
			    -
			      paths:
			        - /var/log/nginx/error.log
			      fields:
			        logzio_codec: plain
			        token: $LOGZ_IO_TOKEN
			      fields_under_root: true
			      ignore_older: 3h
			      document_type: nginx-error
			  registry_file: /var/lib/filebeat/registry
			############################# Output ##########################################
			output:
			  logstash:
			    hosts: ["listener.logz.io:5015"]

			#########  The below configuration is used for Filebeat 1.3 or lower
			    tls:
			      certificate_authorities: ['/etc/pki/tls/certs/COMODORSADomainValidationSecureServerCA.crt']   
      
			########  The below configuration is used for Filebeat 5.0 or higher      
			    ssl:
			      certificate_authorities: ['/etc/pki/tls/certs/COMODORSADomainValidationSecureServerCA.crt']

				  
EOF
		else
			#EDIT FILEBEAT CONF FILE - /etc/filebeat/filebeat.yml - Apache Logz

			mv -v /etc/filebeat/filebeat.yml /etc/filebeat/filebeat_original.yml
			cat > /etc/filebeat/filebeat.yml <<EOF
			############################# Filebeat #####################################
			filebeat:
			  prospectors:
			    -
			      paths:
			        - /var/log/apache2/access.log
			      fields:
			        logzio_codec: plain
			        token: $LOGZ_IO_TOKEN
			      fields_under_root: true
			      ignore_older: 3h
			      document_type: apache
			    -
			      paths:
			        - //var/log/apache2/error.log
			      fields:
			        logzio_codec: plain
			        token: $LOGZ_IO_TOKEN
			      fields_under_root: true
			      ignore_older: 3h
			      document_type: apache-error
			  registry_file: /var/lib/filebeat/registry
			############################# Output ##########################################
			output:
			  logstash:
			    hosts: ["listener.logz.io:5015"]

			#########  The below configuration is used for Filebeat 1.3 or lower
			    tls:
			      certificate_authorities: ['/etc/pki/tls/certs/COMODORSADomainValidationSecureServerCA.crt']   
      
			########  The below configuration is used for Filebeat 5.0 or higher      
			    ssl:
			      certificate_authorities: ['/etc/pki/tls/certs/COMODORSADomainValidationSecureServerCA.crt']
EOF			 
fi
				 
		
else
        echo "Ok, installation will continue without Logz.IO"
fi



#Install Datadog-Agent

if [[ $DATA_DOG == "y" ]]; then
	echo "Please insert DataDog API key (Enter for existing API key)"
	read -e DD_KEY
	DD_KEY=${DD_KEY:-45cd1449066136f4fe1355f4fc343d6a}
	DD_API_KEY=$DD_KEY bash -c "$(curl -L https://raw.githubusercontent.com/DataDog/dd-agent/master/packaging/datadog-agent/source/install_agent.sh)"
else
	echo "Ok, installation will continue without DataDog"
	

echo "Ready, go to http://'your ec2 url'/blog and enter the blog info to finish the WP installation."
fi
