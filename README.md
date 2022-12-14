# Setup User Containers for LXC (for Debian/Ubuntu based systems)

If you've used LXC for quick test machines, or any other purpose, you will appreciate their usefulness.  If you have not, then you can see
an [Introduction Here](https://linuxcontainers.org/lxc/introduction/)

The tool in this repo, will help you with the configuration necessary to allow you to run LXC without
access to root.

It started out as a script I created for my own convenience, but it's been so useful a few people have asked to use it, so I've made it available here.  It's been tested it on Ubutnu 20.04 - 22.04, and on Debian 11, but YMMV.

Please do provide feedback/suggestions!

Usage:-
Run the script as the user you wish to have ability to use LXC containers, it will configure LXC as needed, and assign a range of high UID's to that user so that they can fully own at least 16 bits of UID namespace.


Here is an example of using LXC being used as a non-root user:-

```
james@neo:~ $ lxc-ls --fancy

james@neo:~ $ whoami
james

james@neo:~ $ lxc-create -n testhost -t download -- -d ubuntu -r jammy -a amd64
Using image from local cache
Unpacking the rootfs

---
You just created an Ubuntu jammy amd64 (20220731_07:43) container.

To enable SSH, run: apt install openssh-server
No default root or user password are set by LXC.

james@neo:~ $ lxc-start -n testhost

james@neo:~ $ lxc-attach -n testhost
root@testhost:/# more /etc/lsb-release 
DISTRIB_ID=Ubuntu
DISTRIB_RELEASE=22.04
DISTRIB_CODENAME=jammy
DISTRIB_DESCRIPTION="Ubuntu 22.04.1 LTS"
root@testhost:/# exit
exit

james@neo:~ $ lxc-ls --fancy
NAME     STATE   AUTOSTART GROUPS IPV4        IPV6 UNPRIVILEGED 
testhost RUNNING 0         -      10.0.33.212 -    true         

james@neo:~ $ cat .local/share/lxc/testhost/rootfs/etc/lsb-release 
DISTRIB_ID=Ubuntu
DISTRIB_RELEASE=22.04
DISTRIB_CODENAME=jammy
DISTRIB_DESCRIPTION="Ubuntu 22.04.1 LTS"

james@neo:~ $ ls -asl .local/share/lxc/testhost/rootfs/home/
total 12
4 drwxr-xr-x  3 100000000 100000000 4096 Jul 31 08:45 .
4 drwxr-xr-x 17 100000000 100000000 4096 Jul 31 08:47 ..
4 drwxr-x---  2 100001000 100001000 4096 Jul 31 08:45 ubuntu
james@neo:~ $ 
```
