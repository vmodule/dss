/**上文在分析QTSServer实例化及初始化分析一文的最后部分有创建RTSPListenerSocket且有
运行事件监听机制,DSS对每一个IP地址对应的不同的端口号都将创建一个RTSPListenerSocket
实例
**/

/**
 4.1.RTSPListenerSocket对象的创建
RTSPListenerSocket和Socket的类之间的关系请见
RTSPListenerSocket Class Diagram UML图以下贴出它的代码
**/
class RTSPListenerSocket : public TCPListenerSocket
{
public:
    RTSPListenerSocket() {}
    virtual ~RTSPListenerSocket() {}
    //sole job of this object is to implement this function
    virtual Task*   GetSessionTask(TCPSocket** outSocket);
    //check whether the Listener should be idling
    Bool16 OverMaxConnections(UInt32 buffer);
};

class TCPListenerSocket : public TCPSocket, public IdleTask
{
public:
    TCPListenerSocket() 
        : TCPSocket(NULL, Socket::kNonBlockingSocketType), IdleTask()
        , fAddr(0)
        , fPort(0)
        , fOutOfDescriptors(false)
        , fSleepBetweenAccepts(false) 
        {this->SetTaskName("TCPListenerSocket");}
    virtual ~TCPListenerSocket() {}
    //
    // Send a TCPListenerObject a Kill event to delete it.
            
    //addr = listening address. port = listening port. Automatically
    //starts listening
    OS_Error Initialize(UInt32 addr, UInt16 port);
};

OS_Error TCPListenerSocket::Listen(UInt32 queueLength)
{
    if (fFileDesc == EventContext::kInvalidFileDesc)
        return EBADF;
        
    int err = ::listen(fFileDesc, queueLength);
    if (err != 0)
        return (OS_Error)OSThread::GetErrno();
    return OS_NoErr;
}

OS_Error TCPListenerSocket::Initialize(UInt32 addr, UInt16 port)
{
    OS_Error err = this->TCPSocket::Open();
    if (0 == err) do
    {   
        err = this->Bind(addr, port);
        if (err != 0) break; // don't assert this is just a port already in use.

        //
        // Unfortunately we need to advertise a big buffer because our TCP sockets
        // can be used for incoming broadcast data. This could force the server
        // to run out of memory faster if it gets bogged down, but it is unavoidable.
        this->SetSocketRcvBufSize(96 * 1024);       
        err = this->Listen(kListenQueueLength);
        AssertV(err == 0, OSThread::GetErrno()); 
        if (err != 0) break;
        
    } while (false);
    
    return err;
}

class TCPSocket : public Socket
{
public:
    //TCPSocket takes an optional task object which will get notified when
    //certain events happen on this socket. Those events are:
    //
    //S_DATA:  Data is currently available on the socket.
    //S_CONNECTIONCLOSING:  Client is closing the connection. No longer necessary
    //                      to call Close or Disconnect, Snd & Rcv will fail.
    TCPSocket(Task *notifytask, UInt32 inSocketType)
        : Socket(notifytask, inSocketType),
            fRemoteStr(fRemoteBuffer, kIPAddrBufSize)  {}
    virtual ~TCPSocket() {}
    //Open
    OS_Error    Open() { return Socket::Open(SOCK_STREAM); }
};

class Socket : public EventContext
{
protected:
    static void Initialize() { sEventThread = new EventThread(); }
    //TCPSocket takes an optional task object which will get notified when
    //certain events happen on this socket. Those events are:
    //
    //S_DATA:               Data is currently available on the socket.
    //S_CONNECTIONCLOSING:  Client is closing the connection. No longer necessary
    //                      to call Close or Disconnect, Snd & Rcv will fail.
    Socket(Task *notifytask, UInt32 inSocketType);
    virtual ~Socket() {}

    //returns QTSS_NoErr, or appropriate posix error
    OS_Error    Open(int theType);
    static EventThread* sEventThread;    
};

OS_Error Socket::Open(int theType)
{
    Assert(fFileDesc == EventContext::kInvalidFileDesc);
    fFileDesc = ::socket(PF_INET, theType, 0);
    if (fFileDesc == EventContext::kInvalidFileDesc)
        return (OS_Error)OSThread::GetErrno();
            
    //
    // Setup this socket's event context
    if (fState & kNonBlockingSocketType)
        this->InitNonBlocking(fFileDesc);   

    return OS_NoErr;
}

Socket::Socket(Task *notifytask, UInt32 inSocketType)
:   EventContext(EventContext::kInvalidFileDesc, sEventThread),
    fState(inSocketType),
    fLocalAddrStrPtr(NULL),
    fLocalDNSStrPtr(NULL),
    fPortStr(fPortBuffer, kPortBufSizeInBytes)
{
    fLocalAddr.sin_addr.s_addr = 0;
    fLocalAddr.sin_port = 0;
    
    fDestAddr.sin_addr.s_addr = 0;
    fDestAddr.sin_port = 0;
    
    this->SetTask(notifytask);
}

class EventContext
{
public:
    //
    // Constructor. Pass in the EventThread you would like to receive
    // events for this context, and the fd that this context applies to
    EventContext(int inFileDesc, EventThread* inThread);
    virtual ~EventContext() { if (fAutoCleanup) this->Cleanup(); }
    
    //
    // InitNonBlocking
    //
    // Sets inFileDesc to be non-blocking. Once this is called, the
    // EventContext object "owns" the file descriptor, and will close it
    // when Cleanup is called. This is necessary because of some weird
    // select() behavior. DON'T CALL CLOSE ON THE FD ONCE THIS IS CALLED!!!!
    void  InitNonBlocking(int inFileDesc);
};    

EventContext::EventContext(int inFileDesc, EventThread* inThread)
:   fFileDesc(inFileDesc),
    fUniqueID(0),
    fUniqueIDStr((char*)&fUniqueID, sizeof(fUniqueID)),
    fEventThread(inThread),
    fWatchEventCalled(false),
    fAutoCleanup(true)
{}

/**
4.2.RTSPListenerSocket创建以及初始化简要分析
a).首先在2.3.Socket静态初始化过程中创建了sEventThread
b).在3.4.CreateListeners函数中开始创建RTSPListenerSocket实例
由C++的多态关系创建RTSPListenerSocket的同时会创建其父类
c).在3.4.CreateListeners函数中回调TCPListenerSocket::Initialize函数
该函数首先调用其父类TCPSocket的Open函数,而TCPSocket::Open函数会回调它本身的
父类Socket的Open函数创建socket文件句柄并将该句柄保存成fFileDesc
d)socket文件句柄创建成功后会使用Bind和Listen函数对其进行绑定和监听
e).在其父类的构造过程中将sEventThread指针变量保存到EventContext的成员变量
fEventThread
*/
//到此QTSServer::Initialize函数分析完毕



