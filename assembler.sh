#!/bin/sh
#
# this script fetches smartkiosk-mkb code and rubygems prerequisites,
# assemples smartkiosk.tar.gz and copies it to buld host
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
cd /root/assembler; git clone git@github.com:roundlake/smartkiosk-mkb.git

echo "Collecting gems:"
rpm -Uvg /root/assembler/rpms/ruby*.rpm
gem install bundler
cd /root/assembler/smartkiosk-mkb; bundle install

echo -n "Generating gems list..."
cp /usr/lib/ruby/gems/1.9.1/cache/* /root/assembler/gems
echo 'GEMS="\' > /root/assembler/gems.list
bundle install --local | cut -d" " -f 2,3 | sed 's/ (/-/' | sed 's/)/ \\/' | grep -v "bundle is" >> /root/assembler/gems.list
echo '"' >> /root/assembler/gems.list
echo "OK"

echo -n "Compressing smartkiosk.tar.gz..."
cd /root/assembler; tar czf ../smartguard.tar.gz .
echo "OK"

echo "Copying smartkiosk.tar.gz to build host:"
scp -P 1046 /root/smartkiosk.tar.gz alex@cawok.pro:.

echo; echo "All done!"
