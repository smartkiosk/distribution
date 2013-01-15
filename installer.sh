#!/bin/bash
# Smartkiosk Installer
PATH=/bin:/sbin:/usr/bin:/usr/sbin

RPMS="\
kernel-headers \
glibc-headers \
glibc-devel \
ppl \
cloog-ppl \
mpfr \
cpp \
libgomp \
gcc-4.4.6 \
libstdc++-devel \
gcc-c++ \
make \
libyaml \
ruby \
redis \
nodejs \
lcms-libs \
openjpeg-libs \
poppler-data \
poppler-0.12.4 \
poppler-utils \
tmpwatch \
portreserve \
cups \
urw-fonts \
xorg-x11-font-utils \
ghostscript-fonts \
ghostscript-8.70 \
libusb1 \
cmuxcontrold \
libpcap \
ppp \
postgresql-libs \
postgresql-8.4.11 \
postgresql-server \
postgresql-devel \
sqlite-devel \
nginx \
libXpm \
libXaw \
xterm \
xorg-x11-server-utils \
xinput_calibrator \
x11vnc \
xulrunner-last \
redhat-bookmarks \
firefox \
flash-plugin \
"

TMPD=`mktemp -d /tmp/rdlk.XXXXXX`
ARCH=`awk '/^___ARCHIVE_BELOW___/ { print NR + 1; exit 0; }' $0`

EX=false;FC=false;NM=false;PR=false;VB=false
EM="An error has occured, exiting. Use '--force' option to avoid this behaviour."

for i in $1 $2 $3 $4 $5 $6; do
    if [ "$i" == "-e" -o "$i" == "--extract" ]; then EX=true; fi
    if [ "$i" == "-f" -o "$i" == "--force" ]; then FC=true; fi
    if [ "$i" == "-h" -o "$i" == "--help" ]; then
        echo "Smartkiosk Installer"
        echo
        echo "Command line options:"
        echo "-e, --extract	  extract distribution tree and exit"
        echo "-f, --force	  continue installation process if any error occurs"
        echo "-h, --help	  print this help message and exit"
        echo "-m, --nomodem	  don't configure modem (don't replace default resolv.conf)"
        echo "-p, --prereqs	  install prerequisites only"
        echo "-v, --verbose	  be verbose while operating (produces LOTS of messages!)"
		exit 0
    fi
    if [ "$i" == "-m" -o "$i" == "--nomodem" ]; then NM=true; fi
    if [ "$i" == "-p" -o "$i" == "--prereqs" ]; then PR=true; fi
    if [ "$i" == "-v" -o "$i" == "--verbose" ]; then VB=true; fi
done

if ! "$VB"; then
    echo -n "Unpacking archive..."
    tail -n+$ARCH $0 | tar xzm -C $TMPD > /dev/null 2>&1
    ER=$?; if [ "$ER" -ne 0 ] && ! "$FC"; then echo $EM; rm -rf $TMPD; exit $ER; fi
    echo "OK"
else
    echo "Unpacking archive:"
    tail -n+$ARCH $0 | tar xzmv -C $TMPD
    ER=$?; if [ "$ER" -ne 0 ] && ! "$FC"; then echo $EM; rm -rf $TMPD; exit $ER; fi
fi

if "$EX"; then
    echo
    echo "Distribution tree has been extracted to $TMPD"
    exit 0
fi

if [ $UID -ne 0 ]; then
    echo "The Installer needs to be run as root"
    exit 11
fi

if [ "`head -n 1 /etc/issue`" != "Red Hat Enterprise Linux Server release 6.3 (Santiago)" ] && ! "$FC"; then
    echo "Sorry, automatic installation of Smartkiosk is not supported for this Linux distribution, exiting. You can try to use '--force' option though."
    exit 12
fi

if [ -d /home/terminal/www/smartkiosk-mkb ] && ! "$FC" && ! "$PR"; then
    echo "Looks like Smartkiosk is already installed, exiting. You can try to use '--force' option though."
    exit 13
fi

. $TMPD/gems.list

if ! "$VB"; then
    echo -n "Installing prerequisites"
    cd $TMPD/rpms
    for i in $RPMS; do
        rpm -U --nodeps --nosignature $i*.rpm > /dev/null 2>&1
        echo -n "."
    done
    chkconfig nginx on
    chkconfig redis on
    chkconfig postgresql on
    cd $TMPD/gems
    for i in $GEMS; do
        gem install $i*.gem --local --no-rdoc --no-ri > /dev/null 2>&1
        echo -n "."
    done
    mkdir /usr/share/cups/model/Custom
    cp $TMPD/printer/TG2480-H.ppd.gz /usr/share/cups/model/Custom
    cp $TMPD/printer/rastertotg2480H /usr/lib/cups/filter
    echo "OK"
else
    echo "Installing prerequisites:"
    cd $TMPD/rpms
    for i in $RPMS; do
        rpm -Uvh --nodeps --nosignature $i*.rpm
    done
    chkconfig nginx on
    chkconfig redis on
    chkconfig postgresql on
    cd $TMPD/gems
    for i in $GEMS; do
        gem install $i*.gem --local --no-rdoc --no-ri
    done
    mkdir /usr/share/cups/model/Custom
    cp $TMPD/printer/TG2480-H.ppd.gz /usr/share/cups/model/Custom
    cp $TMPD/printer/rastertotg2480H /usr/lib/cups/filter
fi

if "$PR"; then
    rm -rf $TMPD
    exit 0
fi

if ! "$VB"; then
    echo -n "Configuring printer..."
    service cups restart > /dev/null 2>&1
    lpadmin -p TG2480-H -P /usr/share/cups/model/Custom/TG2480-H.ppd.gz -E -v serial:/dev/ttyS4?baud=115200
    lpadmin -d TG2480-H
    echo "OK"
else
    echo "Configuring printer:"
    service cups restart
    lpadmin -p TG2480-H -P /usr/share/cups/model/Custom/TG2480-H.ppd.gz -E -v serial:/dev/ttyS4?baud=115200
    lpadmin -d TG2480-H
fi

echo << EOF > /etc/ppp/options
noipdefault
ipcp-accept-local
ipcp-accept-remote
defaultroute
noauth
EOF

if [ -z "`grep "10.75.0.14" /etc/hosts`" ]; then echo "10.75.0.14 kiosk-app.mcb.ru kiosk-app" >> /etc/hosts; fi
if [ -z "`grep "10.0.222.222" /etc/resolv.conf`" ]; then echo "nameserver 10.0.222.222" > /etc/resolv.conf; fi

if [ -z "`grep terminal /etc/passwd`" ]; then
    echo -n "Creating terminal user..."
    useradd -G dialout,lock terminal
    echo "OK"
else
    if [ -z "`grep dialout /etc/group | grep terminal`" ]; then
        if $VB; then echo "Adding terminal user to dialout group"; fi
        usermod -a -G dialout terminal
    fi
    if [ -z "`grep lock /etc/group | grep terminal`" ]; then
        if $VB; then echo "Adding terminal user to lock group"; fi
        usermod -a -G lock terminal
    fi
fi

cp $TMPD/.xinitrc /home/terminal
chown terminal:terminal /home/terminal/.xinitrc

if ! "$VB"; then
    cp -R $TMPD/kioskui /home/terminal
else
    cp -Rv $TMPD/kioskui /home/terminal
fi;
chown -R terminal:terminal /home/terminal/kioskui

if "$VB"; then grep terminal /etc/group; fi

if ! "$VB"; then
    echo -n "Installing Smartkiosk..."
    mkdir -p /home/terminal/www/smartkiosk-mkb/head; cp -dfPR $TMPD/smartkiosk-mkb/* /home/terminal/www/smartkiosk-mkb/head
    echo "OK"
else
    echo "Installing Smartkiosk:"
    mkdir -p /home/terminal/www/smartkiosk-mkb/head; cp -dfPRv $TMPD/smartkiosk-mkb/* /home/terminal/www/smartkiosk-mkb/head
fi

rm -rf /home/terminal/www/smartkiosk-mkb/head/config/services
mkdir -p /home/terminal/www/smartkiosk-mkb/head/tmp/pids
mkdir -p /home/terminal/www/smartkiosk-mkb/head/log
mkdir -p /home/terminal/www/smartkiosk-mkb/shared/uploads
mkdir -p /home/terminal/www/smartkiosk-mkb/shared/config
ln -s /home/terminal/www/smartkiosk-mkb/head /home/terminal/www/smartkiosk-mkb/current
ln -s /home/terminal/www/smartkiosk-mkb/shared/uploads /home/terminal/www/smartkiosk-mkb/head/public
ln -s /home/terminal/www/smartkiosk-mkb/shared/config /home/terminal/www/smartkiosk-mkb/head/config/services

cat << EOF > /home/terminal/www/smartkiosk-mkb/shared/config/application.yml
keyword: SAD6
host: http://admin.smartkiosk-mkb.rdlk.biz
smartguard_host: druby://localhost:10000
EOF
cat << EOF > /home/terminal/www/smartkiosk-mkb/shared/config/database.yml
production:
  adapter: postgresql
  host: localhost
  port: 5432
  username: smartkiosk-prd
  password: smartkiosk-prd
  database: smartkiosk-prd
  schema_search_path: public
  encoding: utf8
  pool: 30
EOF
cat << EOF > /home/terminal/www/smartkiosk-mkb/shared/config/smartware.yml
cash_acceptor_port: /dev/ttyS0
cash_acceptor_driver: CCNET
printer_port: /dev/ttyS4
printer_driver: TG24XX
modem_driver: Standard
modem_config:
  device: /dev/ttyS1
  status_channel: 1
  ppp_channel: 2
  poll_interval: 2
  balance_interval: 300
  balance_ussd: "*100#"
  apn: "internet.mts.ru"
EOF

chown -R terminal:terminal /home/terminal/www

cat << EOF > /etc/rc.d/init.d/smartguard
#!/bin/sh
# chkconfig: - 99 01
### BEGIN INIT INFO
# Provides: smartguard
# Required-Start: \$local_fs \$syslog
# Required-Stop: \$local_fs \$syslog
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: start/stop Smartguard facility
### END INIT INFO

case "\$1" in
    start)
        /usr/bin/smartguard --app smartkiosk --path /home/terminal/www/smartkiosk-mkb --pid /var/run/smartguard.pid --log /var/log/smartguard.log --daemon
        ;;
    stop)
        /usr/bin/smartguard --pid /var/run/smartguard.pid --kill
        ;;
    restart)
        /usr/bin/smartguard --pid /var/run/smartguard.pid --kill
        /usr/bin/smartguard --app smartkiosk --path /home/terminal/www/smartkiosk-mkb --pid /var/run/smartguard.pid --log /var/log/smartguard.log --daemon
        ;;
    *)
        echo "Usage smartguard {start|stop|restart}"
        ;;
esac
EOF

chmod +x /etc/rc.d/init.d/smartguard
chkconfig --add smartguard
chkconfig smartguard on

sed --in-place 's/user  nginx/user  terminal/' /etc/nginx/nginx.conf
sed --in-place 's,/etc/nginx/conf.d/\*\.conf,/home/terminal/www/smartkiosk-mkb/current/nginx\.conf,' /etc/nginx/nginx.conf

if ! "$VB"; then
    echo -n "Starting services..."
    service redis start > /dev/null 2>&1
    service nginx start > /dev/null 2>&1
    service postgresql initdb > /dev/null 2>&1
cat << EOF > /var/lib/pgsql/data/pg_hba.conf
local all all ident
host all all 127.0.0.1/32 md5
host all all ::1/128 md5
EOF
    service postgresql start > /dev/null 2>&1
    echo "OK"
else
    echo "Starting services:"
    service redis start
    service nginx start
    service postgresql initdb
cat << EOF > /var/lib/pgsql/data/pg_hba.conf
local all all ident
host all all 127.0.0.1/32 md5
host all all ::1/128 md5
EOF
    service postgresql start
fi

if ! "$VB"; then
	echo -n "Creating database..."
	sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'fwwrbq,fyrjvfn'" > /dev/null 2>&1
	sudo -u postgres psql -c "CREATE ROLE \"smartkiosk-prd\" LOGIN PASSWORD 'smartkiosk-prd' NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE" > /dev/null 2>&1
	sudo -u postgres psql -c "CREATE DATABASE \"smartkiosk-prd\" WITH OWNER = \"smartkiosk-prd\" ENCODING = 'UTF8' LC_COLLATE = 'ru_RU.UTF-8' LC_CTYPE = 'ru_RU.UTF-8' TEMPLATE = template0 CONNECTION LIMIT = -1;" > /dev/null 2>&1
	echo "OK"
else
	echo "Creating database:"
	sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'fwwrbq,fyrjvfn'"
	sudo -u postgres psql -c "CREATE ROLE \"smartkiosk-prd\" LOGIN PASSWORD 'smartkiosk-prd' NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE"
	sudo -u postgres psql -c "CREATE DATABASE \"smartkiosk-prd\" WITH OWNER = \"smartkiosk-prd\" ENCODING = 'UTF8' LC_COLLATE = 'ru_RU.UTF-8' LC_CTYPE = 'ru_RU.UTF-8' TEMPLATE = template0 CONNECTION LIMIT = -1;"
fi

if ! "$VB"; then
    echo -n "Populating database (takes about 10 minutes)..."
    cd /home/terminal/www/smartkiosk-mkb/current
    sudo -u terminal bundle install --local > /dev/null 2>&1
    sudo -u terminal bundle exec rake db:install RAILS_ENV=production > /dev/null 2>&1
    sudo -u terminal bundle exec rake assets:precompile RAILS_ENV=production > /dev/null 2>&1
    echo "OK"

else
    echo "Populating database:"
    cd /home/terminal/www/smartkiosk-mkb/current
    sudo -u terminal bundle install --local
    sudo -u terminal bundle exec rake db:install RAILS_ENV=production
    sudo -u terminal bundle exec rake assets:precompile RAILS_ENV=production
fi

rm -rf $TMPD
exit 0

___ARCHIVE_BELOW___
