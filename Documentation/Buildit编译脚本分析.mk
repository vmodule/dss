1��
VERSION=`grep kVersion revision.h | grep -o [:0123456789:].*[:0123456789:]`
##Build script for Darwin Streaming Server
if [ `uname` = "Darwin" ] ; then
    PLATFORM=dss
elif [ `uname` = "Linux" ] ; then
	#for our Linux platform
    PLATFORM=Linux
else
    PLATFORM=$VERSION
fi

echo "$PLATFORM"
2�����û�ʹ����������ʱ ���ӡ������Ϣ
$./Buildit -v
SHOW_HELP=0
if [ "$1" = "-v" ] ; then
   SHOW_HELP=1
   echo "show help enable"
fi

if [ "$1" = "-h" ] ; then
   SHOW_HELP=1
   echo "show help enable"
fi

if [ "$1" = "?" ] ; then
   SHOW_HELP=1
   echo "show help enable"
fi

if [ "$1" = "help" ] ; then
   SHOW_HELP=1
   echo "show help enable"
fi

if [ $SHOW_HELP = 1 ] ; then
    echo "start usage here..."
	if [ $PLATFORM = dss ] || [ $PLATFORM = Linux ]; then
		echo ""
		echo "OS X Darwin Streaming Server ($PLATFORM v$VERSION)"
		echo ""
		echo "buildit (builds target dss, symbols, build os, and cpu)"
		echo "buildit dss arg2 (builds target dss, symbols, build os, and cpu, passes to xcode optional arg2)"
		echo "buildit dssfat arg2 (builds target dss, symbols, build os, FAT i386+ppc, passes to xcode optional arg2)"
		echo "buildit dssfullfat arg2 (builds target dss, symbols, build os, FAT i386+x86_64+ppc+ppc64, passes to xcode optional arg2)"
		echo "buildit qtss arg2 (builds target qtss, stripped, build os, and cpu, passes to xcode optional arg2)"
		echo "buildit qtssfat arg2 (builds target qtss, stripped, build os, FAT i386+ppc, passes to xcode optional arg2)"	
		echo "buildit qtssfullfat arg2 (builds target qtss, stripped, build os, FAT i386+x86_64+ppc+ppc64, passes to xcode optional arg2)"
	fi
	exit 0
fi

3������û�ʹ����������
$./Buildit install
#����û�ʹ��./Buildit install ��ִ��./buildtarball Linux
if [ "$1" = "install" ] ; then
    if [ $PLATFORM = dss ] ; then
      echo "OS X Darwin Streaming Server"
      ./BuildOSXInstallerPkg $2 $3
      exit 0
    fi

    ./buildtarball $PLATFORM
	#��������˳�
    exit 0
fi

4�����ݲ�ͬƽ̨�Ƚ��б�����Linuxƽ̨Ϊ��
OSNAME=`uname` #Linux
HARDWARENAME=`uname -m` #x86_64
 
PLAT=$OSNAME.$HARDWARENAME

echo "Darwin Streaming Server"
echo "-----------------------"
echo "start compile in $PLAT"
echo "-----------------------"

case $PLAT in

	Linux.i586 | \
	Linux.i686 | \
	Linux.x86_64 )
        echo "Configuring for the "$OSNAME" "$HARDWARENAME" platform"
		CPLUS=gcc 		#Ĭ��C++ʹ��gcc������
		CCOMP=gcc		#Ĭ��Cʹ��gcc������
		LINKER='gcc'	#Ĭ�����ӹ���ʹ��gcc������
 		MAKE=make		#ʹ��make
 		
		#��������
		if [ "$PLAT" = "Linux.x86_64" ]; then
			COMPILER_FLAGS="-D_REENTRANT -D__USE_POSIX -D__linux__ -pipe -fPIC"
		else
			COMPILER_FLAGS="-D_REENTRANT -D__USE_POSIX -D__linux__ -pipe"
		fi
        INCLUDE_FLAG="-include"
		
		CORE_LINK_LIBS="-lpthread -ldl -lstdc++ -lm -lcrypt"

		SHARED=-shared
		MODULE_LIBS=
		
		#����ݴ���
		if [ -f /usr/include/socketbits.h ]; then
			NEED_SOCKETBITS=1
			export NEED_SOCKETBITS
		fi
		;;
esac

#��װ��ҪrootȨ��
if [ "$*" = "install" ] ; then

        if [ `uname` != "SunOS" ]; then
                USERID=`id -u`
        else
                USERID=`/usr/xpg4/bin/id -u`
        fi

        if [ $USERID != 0 ]; then
                echo "You must be root to perform an \"install\" build"
                exit 1
        fi
fi
echo "-----------------------"
echo "-----------------------"
echo Building for $PLAT with $CPLUS
echo "-----------------------"
echo "-----------------------"
5���Ա���ѡ�������Ӧ�����ú�������
if [ "${OSNAME}" = "Linux"  ]; then
	export CPLUS #gcc
	export CCOMP #gcc
	export LINKER #gcc
	export COMPILER_FLAGS "-D_REENTRANT -D__USE_POSIX -D__linux__ -pipe -fPIC"
	export INCLUDE_FLAG	#"-include"
	export CORE_LINK_LIBS  #"-lpthread -ldl -lstdc++ -lm -lcrypt"
	export SHARED	#-shared
	export MODULE_LIBS #
	
	#5.1 ����CommonUtilitiesLib
	echo Building CommonUtilitiesLib for $PLAT with $CPLUS
	cd CommonUtilitiesLib/
	$MAKE -f Makefile.POSIX $*

	#5.2 ����QTFileLib
	echo Building QTFileLib internal for $PLAT with $CPLUS
	cd ../QTFileLib/
	
	#����û�ʹ��Buildit clean ��ִ��make -f Makefile.POSIX clean
	#����ִ��make -f Makefile.POSIX all
	if [ "$*" = "clean" ] ; then
		$MAKE -f Makefile.POSIX $*
	else
		$MAKE -f Makefile.POSIX all $*
	fi
	
	# 5.3�ص���Ŀ¼���濪ʼ��StreamingServer ���б���
	echo Building StreamingServer for $PLAT with $CPLUS
	cd ..
	
	$MAKE -f Makefile.POSIX $*
	
	echo Building RefMovieModule for $PLAT with $CPLUS
	cd APIModules/QTSSRefMovieModule/
	$MAKE -f Makefile.POSIX $*
	
	echo Building DemoAuthorizationModule for $PLAT with $CPLUS
	cd ../QTSSDemoAuthorizationModule.bproj/
	$MAKE -f Makefile.POSIX $*
	
	echo Building RawFileModule for $PLAT with $CPLUS
	cd ../QTSSRawFileModule.bproj/
	$MAKE -f Makefile.POSIX $*
	
	echo Building SpamDefenseModule for $PLAT with $CPLUS
	cd ../QTSSSpamDefenseModule.bproj/
	$MAKE -f Makefile.POSIX $*

	echo Building HomeDirectoryModule for $PLAT with $CPLUS
	cd ../QTSSHomeDirectoryModule/
	$MAKE -f Makefile.POSIX $*
	
	cd ..
	
	echo Building StreamingProxy for $PLAT with $CPLUS
	cd ../StreamingProxy.tproj/
	$MAKE -f Makefile.POSIX $*
	
	echo Building qtpasswd for $PLAT with $CPLUS
	cd ../qtpasswd.tproj/
	$MAKE -f Makefile.POSIX $*

	echo Building PlaylistBroadcaster for $PLAT with $CPLUS
	cd ../PlaylistBroadcaster.tproj/
	$MAKE -f Makefile.POSIX $*
	
	echo Building MP3Broadcaster for $PLAT with $CPLUS
	cd ../MP3Broadcaster/
	$MAKE -f Makefile.POSIX $*
	
	echo Building QTFileTools for $PLAT with $CPLUS
        cd ../QTFileTools/

	echo Building QTBroadcaster for $PLAT with $CPLUS
	cd QTBroadcaster.tproj/
	$MAKE -f Makefile.POSIX $*

	echo Building QTFileInfo for $PLAT with $CPLUS
	cd ../QTFileInfo.tproj/
	$MAKE -f Makefile.POSIX $*

	echo Building QTFileTest for $PLAT with $CPLUS
	cd ../QTFileTest.tproj/
	$MAKE -f Makefile.POSIX $*

	echo Building QTRTPFileTest for $PLAT with $CPLUS
	cd ../QTRTPFileTest.tproj/
	$MAKE -f Makefile.POSIX $*

	echo Building QTRTPGen for $PLAT with $CPLUS
	cd ../QTRTPGen.tproj/
	$MAKE -f Makefile.POSIX $*

	echo Building QTSDPGen for $PLAT with $CPLUS
	cd ../QTSDPGen.tproj/
	$MAKE -f Makefile.POSIX $*

	echo Building QTSampleLister for $PLAT with $CPLUS
	cd ../QTSampleLister.tproj/
	$MAKE -f Makefile.POSIX $*

	echo Building QTTrackInfo for $PLAT with $CPLUS
	cd ../QTTrackInfo.tproj/
	$MAKE -f Makefile.POSIX $*
	
	cd ..
	
	if [ -d ../StreamingLoadTool ]; then
		echo Building StreamingLoadTool for $PLAT with $CPLUS
			cd ../StreamingLoadTool/
			$MAKE -f Makefile.POSIX $*
	fi

	if [ "$*" = "install" ] ; then
		cd ..
		pwdi
		echo
		./DSS_MakeRoot /
	fi

fi
