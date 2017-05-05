1、打补丁
$ patch -p0 < dss-6.0.3.patch
$ patch -p0 < dss-hh-20080728-1.patch 
2、修改安装脚本Install
$ vi Install
    if [ $INSTALL_OS = "Linux" ]; then
        /usr/sbin/groupadd qtss > /dev/null 2>&1
        /usr/sbin/useradd -m qtss > /dev/null 2>&1
（原文：/usr/sbin/useradd -M qtss > /dev/null 2>&1）
    else
        /usr/sbin/groupadd qtss > /dev/null 2>&1
        /usr/sbin/useradd qtss > /dev/null 2>&1
    fi

3、添加qtss用户信息，添加后面安装会报错误提示
  chown: invalid user: `qtss'
  $ addgroup -system qtss  
  $ adduser -system -no-create-home -ingroup qtss qtss
4、./Buildit 编译
5、./buildtarball 提示出错，32位与64位出错一样，解决方法也一样，如下：
$vim Makefile.POSIX
LIBS = $(CORE_LINK_LIBS) -lCommonUtilitiesLib -lQTFileLib -ldl
$ vi QTFileTools/QTFileInfo.tproj/Makefile.POSIX
$ vi QTFileTools/QTFileTest.tproj/Makefile.POSIX
$ vi QTFileTools/QTSampleLister.tproj/Makefile.POSIX
以上三个文件都是添加：LIBS+ =  -lpthread
6、进入目录安装DarwinStreamingSrvr-Linux，./Install，提示输入用户名，密码，下面通过网页登录用.
$ cd DarwinStreamingSrvr-Linux/
$ ./Install
In order to administer the Darwin Streaming Server you must create an administrator user [Note: The administrator user name cannot contain spaces, or single or double quote characters, and cannot be more than 255 characters long].
Please enter a new administrator user name: ekin

You must also enter a password for the administrator user [Note: The administrator password cannot contain spaces, or quotes, either single or double, and cannot be more than 80 characters long].
Please enter a new administrator Password: 
Re-enter the new administrator password:
7、运行
/usr/local/sbin/DarwinStreamingServer
8、查看Darwin服务进程是否正确运行
ps -ef | grep Darwin
root      2249     1  0 16:47 ?        00:00:00 /usr/local/sbin/DarwinStreamingServer
qtss      2250  2249  0 16:47 ?        00:00:01 /usr/local/sbin/DarwinStreamingServer
root      2576  2141  0 17:15 pts/0    00:00:00 grep --color=auto Darwin
9、测试
网页：
http://serverIP:1220可以访问服务器,输入用户名，密码测试OK
VLC播放：
默认文件路径为/usr/local/movies/ 
打开VLC，输入rtsp://serverIP/sample_300kbit.mp4播放测试OK  





