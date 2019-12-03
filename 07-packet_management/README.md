## Packet management
* Create RPM packet - customize nginx with openssl
* Setup own repository and host result RPM from step 1

### Create custom nginx package
* Install required tools
````
yum install redhat-lsb-core wget rpmdevtools rpm-build createrepo yum-utils -y
````

* Download nginx SRPM
````
wget https://nginx.org/packages/centos/7/SRPMS/nginx-1.14.1-1.el7_4.ngx.src.rpm
````

* Install procedure will create necessary for build dir structure
````
rpm -i nginx-1.14.1-1.el7_4.ngx.src.rpm
````

* Get openssl
````
wget https://www.openssl.org/source/latest.tar.gz
tar -xvf latest.tar.gz
````

* Build dependicies
````
sudo yum-builddep rpmbuild/SPECS/nginx.spec
````

* Look into available build options for [nginx](https://nginx.org/ru/docs/configure.html)

* Update spec file `rpmbuild/SPECS/nginx.spec` with openssl. Path to downloaded latest openssl sources is /home/vagrant/openssl-1.1.1d. Beware, subject to change.
````
...
%build
./configure %{BASE_CONFIGURE_ARGS} \
    --with-cc-opt="%{WITH_CC_OPT}" \
    --with-ld-opt="%{WITH_LD_OPT}" \
    --with-debug \
    --with-openssl=/home/vagrant/openssl-1.1.1d
make %{?_smp_mflags}
%{__mv} %{bdir}/objs/nginx \
    %{bdir}/objs/nginx-debug
./configure %{BASE_CONFIGURE_ARGS} \
    --with-cc-opt="%{WITH_CC_OPT}" \
    --with-ld-opt="%{WITH_LD_OPT}" \
    --with-openssl=/home/vagrant/openssl-1.1.1d
make %{?_smp_mflags}
...
````

* Build new package (with srmps)
````
rpmbuild -bb rpmbuild/SPECS/nginx.spec
...
Executing(%clean): /bin/sh -e /var/tmp/rpm-tmp.V3P11d
+ umask 022
+ cd /home/vagrant/rpmbuild/BUILD
+ cd nginx-1.14.1
+ /usr/bin/rm -rf /home/vagrant/rpmbuild/BUILDROOT/nginx-1.14.1-1.el7_4.ngx.x86_64
+ exit 0
````

* Check results
````
ll rpmbuild/RPMS/x86_64/
total 6048
-rw-rw-r-- 1 vagrant vagrant 3637480 Dec  3 05:27 nginx-1.14.1-1.el7_4.ngx.x86_64.rpm
-rw-rw-r-- 1 vagrant vagrant 2548600 Dec  3 05:27 nginx-debuginfo-1.14.1-1.el7_4.ngx.x86_64.rpm
````

* Install it (as root)
````
yum localinstall rpmbuild/RPMS/x86_64/nginx-1.14.1-1.el7_4.ngx.x86_64.rpm -y
...
systemctl start nginx
systemctl status nginx
● nginx.service - nginx - high performance web server
   Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
   Active: active (running) since Tue 2019-12-03 05:32:11 UTC; 5s ago
     Docs: http://nginx.org/en/docs/
  Process: 11499 ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx.conf (code=exited, status=0/SUCCESS)
 Main PID: 11500 (nginx)
   CGroup: /system.slice/nginx.service
           ├─11500 nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx.conf
           └─11501 nginx: worker process

Dec 03 05:32:11 asdatarius-packet-management systemd[1]: Starting nginx - high performance web server...
Dec 03 05:32:11 asdatarius-packet-management systemd[1]: Started nginx - high performance web server.
````

### Setup own repository
* Prepare dir for repo with packages
````
mkdir -p /var/www/repo
cp rpmbuild/RPMS/x86_64/nginx-1.14.1-1.el7_4.ngx.x86_64.rpm /var/www/repo/
# + additional packages which could be used in our own repo
wget http://www.percona.com/downloads/percona-release/redhat/0.1-6/percona-release-0.1-6.noarch.rpm -O /var/www/repo/percona-release-0.1-6.noarch.rpm
````

* Init repo
````
createrepo /var/www/repo/
Spawning worker 0 with 1 pkgs
Spawning worker 1 with 1 pkgs
Spawning worker 2 with 0 pkgs
Spawning worker 3 with 0 pkgs
Workers Finished
Saving Primary metadata
Saving file lists metadata
Saving other metadata
Generating sqlite DBs
Sqlite DBs complete
````

* Update nginx config (/etc/nginx/conf.d/default.conf), root location
````
...
    location / {
        root   /var/www;
        index  index.html index.htm;
        autoindex on;
    }
...
````

* Test config and reload nginx
````
nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful

nginx -s reload

curl -a http://localhost/repo/
<html>
<head><title>Index of /repo/</title></head>
<body bgcolor="white">
<h1>Index of /repo/</h1><hr><pre><a href="../">../</a>
<a href="repodata/">repodata/</a>                                          03-Dec-2019 05:39                   -
<a href="nginx-1.14.1-1.el7_4.ngx.x86_64.rpm">nginx-1.14.1-1.el7_4.ngx.x86_64.rpm</a>                03-Dec-2019 05:38             3637480
<a href="percona-release-0.1-6.noarch.rpm">percona-release-0.1-6.noarch.rpm</a>                   13-Jun-2018 06:34               14520
</pre><hr></body>
</html>
````

* Add repo to `/etc/yum.repos.d`
````
cat >> /etc/yum.repos.d/asdatarius.repo << EOF
[asdatarius]
name=asdatarius
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
EOF

# check result
yum repolist enabled | grep asdatarius
asdatarius                          asdatarius

# nginx installed from local rpm, so missed from the list
yum list | grep asdatarius
percona-release.noarch                      0.1-6                      asdatarius
````

* Test install
````
yum install percona-release -y
````

### Use nginx from docker
* Install docker
````
yum install docker -y
systemctl start docker
````

* Clean up
````
nginx -s stop
# check
curl -a http://localhost/repo/
curl: (7) Failed connect to localhost:80; Connection refused

# remove packeges (nginx config and www root still here)
yum remove percona-release nginx
````

* Run nginx with local config and custom www root
````
# mount /var/www and /etc/nginx
docker run --name nginx -v /var/www:/var/www -v /etc/nginx:/etc/nginx -p 80:80 -d nginx

#check
curl -a http://localhost/repo/
<html>
<head><title>Index of /repo/</title></head>
<body>
<h1>Index of /repo/</h1><hr><pre><a href="../">../</a>
<a href="repodata/">repodata/</a>                                          03-Dec-2019 05:54                   -
<a href="nginx-1.14.1-1.el7_4.ngx.x86_64.rpm">nginx-1.14.1-1.el7_4.ngx.x86_64.rpm</a>                03-Dec-2019 05:38             3637480
<a href="percona-release-0.1-6.noarch.rpm">percona-release-0.1-6.noarch.rpm</a>                   13-Jun-2018 06:34               14520
</pre><hr></body>
</html>

# check if repo still ok
yum list | grep asdatarius
nginx.x86_64                                1:1.14.1-1.el7_4.ngx       asdatarius
percona-release.noarch                      0.1-6                      asdatarius

# install percona-release once more time
yum install percona-release -y
````