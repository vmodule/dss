2.1��os��ʼ��
void OS::Initialize()
{
    Assert (sInitialMsec == 0);  // do only once
    if (sInitialMsec != 0) return;
    ::tzset();
    //t.tv_sec is number of seconds since Jan 1, 1970. Convert to seconds since 1900    
    SInt64 the1900Sec = (SInt64) (24 * 60 * 60) * (SInt64) ((70 * 365) + 17) ;
    sMsecSince1900 = the1900Sec * 1000;
    
    sWrapTime = (SInt64) 0x00000001 << 32;
    sCompareWrap = (SInt64) 0xffffffff << 32;
    sLastTimeMilli = 0;
    
    sInitialMsec = OS::Milliseconds(); //Milliseconds uses sInitialMsec so this assignment is valid only once.

    sMsecSince1970 = ::time(NULL);  // POSIX time always returns seconds since 1970
    sMsecSince1970 *= 1000;         // Convert to msec
}
�ú�����ʼ�����ʱ��sInitialMsec��sMsecSince1970
2.2��OSThread��ʼ��
void OSThread::Initialize()
{
#ifdef __PTHREADS__
    pthread_key_create(&OSThread::gMainKey, NULL);
#endif
}
2.3.Socket ��̬��ʼ��
void Socket::Initialize() { 
	sEventThread = new EventThread();
}
����EventThreadʵ��������EventThread��OSThread�����������ڴ�ͬʱ������OSThread

2.4��SocketUtils��ʼ��
void SocketUtils::Initialize(Bool16 lookupDNSName)
{
    //Most of this code is similar to the SIOCGIFCONF code presented in Stevens,
    //Unix Network Programming, section 16.6
    
    //Use the SIOCGIFCONF ioctl call to iterate through the network interfaces
    static const UInt32 kMaxAddrBufferSize = 2048;
    struct ifconf ifc;
    ::memset(&ifc,0,sizeof(ifc));
    struct ifreq* ifr;
    char buffer[kMaxAddrBufferSize];
	//������ʱsocket..
    int tempSocket = ::socket(AF_INET, SOCK_DGRAM, 0);
    if (tempSocket == -1)
        return;
    ifc.ifc_len = kMaxAddrBufferSize;
    ifc.ifc_buf = buffer;
	
	//ͨ��SIOCGIFCONF��ȡϵͳ���е�����ӿ����ifconf�ṹ��
    int err = ::ioctl(tempSocket, SIOCGIFCONF, (char*)&ifc);
    if (err == -1)
        return;
	//�ر�socket..
    ::close(tempSocket);
    tempSocket = -1;

    //walk through the list of IP addrs twice. Once to find out how many,
    //the second time to actually grab their information
    char* ifReqIter = NULL;
    sNumIPAddrs = 0;
	
    for (ifReqIter = buffer; ifReqIter < (buffer + ifc.ifc_len);){
        ifr = (struct ifreq*)ifReqIter;
        if (!SocketUtils::IncrementIfReqIter(&ifReqIter, ifr))
            return;
        //Only count interfaces in the AF_INET family.
        if (ifr->ifr_addr.sa_family == AF_INET)
            sNumIPAddrs++;
    }

	//Ϊÿ������ӿڷ���һ��IPAddrInfo�ṹ��,��������������Щ�ṹ��ͳһ��ŵ�
	//sIPAddrInfoArray���鵱��
    //allocate the IPAddrInfo array. Unfortunately we can't allocate this
    //array the proper way due to a GCC bug
    UInt8* addrInfoMem = new UInt8[sizeof(IPAddrInfo) * sNumIPAddrs];
    ::memset(addrInfoMem, 0, sizeof(IPAddrInfo) * sNumIPAddrs);
    sIPAddrInfoArray = (IPAddrInfo*)addrInfoMem;
    
    //Now extract all the necessary information about each interface
    //and put it into the array
    UInt32 currentIndex = 0;

    for (ifReqIter = buffer; ifReqIter < (buffer + ifc.ifc_len);){
        ifr = (struct ifreq*)ifReqIter;
        if (!SocketUtils::IncrementIfReqIter(&ifReqIter, ifr)){
            Assert(0);//we should have already detected this error
            return;
        }
        //Only count interfaces in the AF_INET family
        if (ifr->ifr_addr.sa_family == AF_INET){
            struct sockaddr_in* addrPtr = (struct sockaddr_in*)&ifr->ifr_addr;  
            char* theAddrStr = ::inet_ntoa(addrPtr->sin_addr);

            //store the IP addr
            sIPAddrInfoArray[currentIndex].fIPAddr = ntohl(addrPtr->sin_addr.s_addr);
            
            //store the IP addr as a string
            sIPAddrInfoArray[currentIndex].fIPAddrStr.Len = ::strlen(theAddrStr);
            sIPAddrInfoArray[currentIndex].fIPAddrStr.Ptr = new char[sIPAddrInfoArray[currentIndex].fIPAddrStr.Len + 2];
            ::strcpy(sIPAddrInfoArray[currentIndex].fIPAddrStr.Ptr, theAddrStr);

            struct hostent* theDNSName = NULL;
            if (lookupDNSName) //convert this addr to a dns name, and store it
            {   theDNSName = ::gethostbyaddr((char *)&addrPtr->sin_addr, sizeof(addrPtr->sin_addr), AF_INET);
            }
            
            if (theDNSName != NULL){
                sIPAddrInfoArray[currentIndex].fDNSNameStr.Len = ::strlen(theDNSName->h_name);
                sIPAddrInfoArray[currentIndex].fDNSNameStr.Ptr = new char[sIPAddrInfoArray[currentIndex].fDNSNameStr.Len + 2];
                ::strcpy(sIPAddrInfoArray[currentIndex].fDNSNameStr.Ptr, theDNSName->h_name);
            }else{
                //if we failed to look up the DNS name, just store the IP addr as a string
                sIPAddrInfoArray[currentIndex].fDNSNameStr.Len = sIPAddrInfoArray[currentIndex].fIPAddrStr.Len;
                sIPAddrInfoArray[currentIndex].fDNSNameStr.Ptr = new char[sIPAddrInfoArray[currentIndex].fDNSNameStr.Len + 2];
                ::strcpy(sIPAddrInfoArray[currentIndex].fDNSNameStr.Ptr, sIPAddrInfoArray[currentIndex].fIPAddrStr.Ptr);
            }
            //move onto the next array index
            currentIndex++;
        }
    }
	//���ｫ��ЧIP��ַ�ŵ�sIPAddrInfoArray[0]
    if ((sNumIPAddrs > 1) && (::strcmp(sIPAddrInfoArray[0].fIPAddrStr.Ptr, "127.0.0.1") == 0)){
        UInt32 tempIP = sIPAddrInfoArray[1].fIPAddr;
        sIPAddrInfoArray[1].fIPAddr = sIPAddrInfoArray[0].fIPAddr;
        sIPAddrInfoArray[0].fIPAddr = tempIP;
        StrPtrLen tempIPStr(sIPAddrInfoArray[1].fIPAddrStr);
        sIPAddrInfoArray[1].fIPAddrStr = sIPAddrInfoArray[0].fIPAddrStr;
        sIPAddrInfoArray[0].fIPAddrStr = tempIPStr;
        StrPtrLen tempDNSStr(sIPAddrInfoArray[1].fDNSNameStr);
        sIPAddrInfoArray[1].fDNSNameStr = sIPAddrInfoArray[0].fDNSNameStr;
        sIPAddrInfoArray[0].fDNSNameStr = tempDNSStr;
    }
}
�ú�������Ҫ�ľ��Ǵ�ϵͳ�л�ȡ����ӿڲ�Ϊÿ������ӿڷ���һ��IPAddrInfo�ṹ���������,�����Щ�ṹ���浽
sIPAddrInfoArray���鵱��

2.5��ʹ��poll����ɶ��
//ev.cpp
void select_startevents()
{
    FD_ZERO(&sReadSet);
    FD_ZERO(&sWriteSet);
    FD_ZERO(&sReturnedReadSet);
    FD_ZERO(&sReturnedWriteSet);

    //qtss_printf("FD_SETSIZE=%d sizeof(fd_set) * 8 ==%ld\n", FD_SETSIZE, sizeof(fd_set) * 8);
    //We need to associate cookies (void*)'s with our file descriptors.
    //We do so by storing cookies in this cookie array. Because an fd_set is
    //a big array of bits, we should have as many entries in the array as
    //there are bits in the fd set  
    sCookieArray = new void*[sizeof(fd_set) * 8];
    ::memset(sCookieArray, 0, sizeof(void *) * sizeof(fd_set) * 8);
    
    //We need to close all fds from the select thread. Once an fd is passed into
    //removeevent, its added to this array so it may be deleted from the select thread
    sFDsToCloseArray = new int[sizeof(fd_set) * 8];
    for (int i = 0; i < (int) (sizeof(fd_set) * 8); i++)
        sFDsToCloseArray[i] = -1;
    
    //We need to wakeup select when the masks have changed. In order to do this,
    //we create a pipe that gets written to from modwatch, and read when select returns
    int theErr = ::pipe((int*)&sPipes);
    Assert(theErr == 0);
    
    //Add the read end of the pipe to the read mask
    FD_SET(sPipes[0], &sReadSet);
    sMaxFDPos = sPipes[0];
}



