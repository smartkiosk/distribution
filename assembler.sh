#!/bin/sh
#
# this script fetches smartkiosk-mkb code and rubygems prerequisites,
# assembles smartkiosk.tar.gz
#

echo -n "Cleaning things up..."
if [ -f /root/smartkiosk.tar.gz ]; then rm -f /root/smartkiosk.tar.gz; fi
if [ -d /root/assembler/smartkiosk-mkb ]; then rm -rf /root/assembler/smartkiosk-mkb; fi
if [ -n "`ls /root/assembler/gems`" ]; then rm -rf /root/assembler/gems/*; fi
if [ -n "`rpm -qa | grep ruby`" ]; then
  rpm -e ruby
  rm -rf /usr/lib/ruby
fi
echo "OK"

echo "Fetching recent smartkiosk-mkb code:"
cd /root/assembler; git clone git@github.com:roundlake/smartkiosk-client-mkb.git; mv smartkiosk-client-mkb smartkiosk-mkb

echo "Collecting gems:"
rpm -Uvh /root/assembler/rpms/ruby*.rpm
gem install bundler
cd /root/assembler/smartkiosk-mkb; bundle install

echo -n "Generating gems list..."
cp /usr/lib/ruby/gems/1.9.1/cache/* /root/assembler/gems
echo 'GEMS="\' > /root/assembler/gems.list
bundle install --local | cut -d" " -f 2,3 | sed 's/ (/-/' | sed 's/)/ \\/' | grep -v "bundle is" >> /root/assembler/gems.list
echo '"' >> /root/assembler/gems.list
echo "OK"

echo -n "Compressing smartkiosk.tar.gz..."
cd /root/assembler; tar czf ../smartkiosk.tar.gz .
echo "OK"

echo; echo "All done!"
