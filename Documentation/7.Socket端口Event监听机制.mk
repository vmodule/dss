QTSS_ServerState StartServer(
	XMLPrefsParser* inPrefsSource, PrefsSource* inMessagesSource,
	UInt16 inPortOverride, int statsUpdateInterval, 
	QTSS_ServerState inInitialState, Bool16 inDontFork,
	UInt32 debugLevel, UInt32 debugOptions)
{
    //initialize the select() implementation of the event queue

    ::select_startevents();
    if (sServer->GetServerState() != qtssFatalErrorState)
    {
        Socket::StartThread();
    }    
}

struct eventreq {
  int      er_type;
#define EV_FD 1    // file descriptor
  int      er_handle;
  void    *er_data;
  int      er_rcnt;
  int      er_wcnt;
  int      er_ecnt;
  int      er_eventbits;
#define EV_RE  1
#define EV_WR  2
#define EV_EX  4
#define EV_RM  8
};
/**
在分析Socket::StartThread之前,先分析select_startevents函数
7.1.select初始化分析
**/
static fd_set   sReadSet;
static fd_set   sWriteSet;
static fd_set   sReturnedReadSet;
static fd_set   sReturnedWriteSet;
static void**   sCookieArray = NULL;
static int*     sFDsToCloseArray = NULL;
static int      sPipes[2];

static int sCurrentFDPos = 0;
static int sMaxFDPos = 0;
static bool sInReadSet = true;
static int sNumFDsBackFromSelect = 0;
static UInt32 sNumFDsProcessed = 0;
static OSMutex sMaxFDPosMutex;
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
/**
select_startevents主要工作是初始化sReadSet,sWriteSet,sReturnedReadSet,sReturnedWriteSet
并且创建了sCookieArray数组,该数组是void*型,大小为8个fd_set，同时创建sFDsToCloseArray
用于管理从fdset线程移除的文件监听集合,重要的是创建了sPipes,并将sPipes[0]加入到sReadSet
可读时间集合当中,同时将sPipes[0]文件句柄赋值给sMaxFDPos
**/

/**
7.2.EventThread::Entry()分析
从Socket类的关系图可以看出Socket是由EventContext派生而来,而EventContext
又和EventThread相关联,所以在这里Socket::StartThread()函数最终调用
sEventThread->Start()最终调用OSThread::Start()函数来创建线程并执行
EventThread::Entry()函数,去掉相关调式信息和无用信息它的实现如下:
**/
void EventThread::Entry()
{
    struct eventreq theCurrentEvent;
    ::memset(&theCurrentEvent, '\0', sizeof(theCurrentEvent) );
    while (true)
    {
        int theErrno = EINTR;
        while (theErrno == EINTR) { //如果超时返回则继续进行等待
            int theReturnValue = select_waitevent(&theCurrentEvent, NULL);
            //Sort of a hack. In the POSIX version of the server, waitevent can return
            //an actual POSIX errorcode.
            if (theReturnValue >= 0)//如果等待成功将会为我们初始化一个eventreq
                theErrno = theReturnValue;
            else //如果超时则继续走while循环继续等待事件来临
                theErrno = OSThread::GetErrno();
        }
        AssertV(theErrno == 0, theErrno);
        //ok, there's data waiting on this socket. Send a wakeup.
        if (theCurrentEvent.er_data != NULL) {
            //The cookie in this event is an ObjectID. Resolve that objectID into
            //a pointer.
            StrPtrLen idStr((char*)&theCurrentEvent.er_data, 
            	sizeof(theCurrentEvent.er_data));
            OSRef* ref = fRefTable.Resolve(&idStr);
            if (ref != NULL)
            {
                EventContext* theContext = (EventContext*)ref->GetObject();
                theContext->ProcessEvent(theCurrentEvent.er_eventbits);
                fRefTable.Release(ref);
            }
        }
    }
}
/**
该函数首先调用select_waitevent进行阻塞等待事件,如果没有事件或超时,将一直等待在此
如果有事件发生,将会为我们初始化eventreq,然后通过fRefTable
**/
/**
7.3.1.select_waitevent首次被调用等待socket监听端口被加入到监听集合当中
程序首次被执行,当在StartServer函数中调用Socket::StartThread();
函数的时候,保存在Socket类中的静态sEventThread成员变量的Start()方法
将会被调用,该方法事实上就是为我们创建一个异步线程,线程创建成功后
调用其子类EventThread的Entry方法,该函数就是循环调用select_waitevent等待
socket事件来临,而当程序第一次执行的时候socket啥都没有通过FDSET监听的是一个
pipe文件句柄,socket端口并没有添加进去
**/
int select_waitevent(struct eventreq *req, void* /*onlyForMacOSX*/)
{
    //Check to see if we still have some select descriptors to process
    int theFDsProcessed = (int)sNumFDsProcessed;
    bool isSet = false;
    //程序第一次来sNumFDsBackFromSelect=0直接返回false
    while(!selecthasdata()) {
        {
            OSMutexLocker locker(&sMaxFDPosMutex);
            //Prepare to call select. Preserve the read and write sets by copying their contents
            //into the corresponding "returned" versions, and then pass those into select
            //将sReadSet和sWriteSet分别拷贝到sReturnedReadSet和sReturnedWriteSet
            //一开始sPipes[0]被加入到sReadSet当中
            ::memcpy(&sReturnedReadSet, &sReadSet, sizeof(fd_set));
            ::memcpy(&sReturnedWriteSet, &sWriteSet, sizeof(fd_set));
        }
        struct timeval  tv;
        tv.tv_usec = 0;
        tv.tv_sec = 15;
        sNumFDsBackFromSelect = ::select(sMaxFDPos+1, &sReturnedReadSet,
            &sReturnedWriteSet, NULL, &tv);
        //程序第一次执行会走这里,将sReturnedReadSet,sReturnedWriteSet加入到
        //select,sNumFDsBackFromSelect当被监听文件集合满足监听条件的文件数总和
        //当返回0时表示超时
        //所以程序第一次执行到select函数将等待sPipes[0]文件句柄被写
		//sNumFDsBackFromSelect返回满足条件的文件数之和sReturnedReadSet中可读的总数+sReturnedWriteSet
		//中可写的总数
    }
    //程序第一次执行,当没有往读写集合中添加文件句柄的时候,会超时返回
    //不过事实上当select函数被调用时马上会将socket服务端口文件句柄加入到sReadSet
    //并向pipe[0]写入值唤醒select函数
    if (sNumFDsBackFromSelect >= 0)
        return EINTR;   //either we've timed out or gotten some events. Either way, force caller
                        //to call waitevent again.
    return sNumFDsBackFromSelect;
}
/**
在EventThread::Entry()函数中调用select_waitevent函数进行等待,程序第一次来将调用select函数对sPipes[0]
进行超时监听,程序第一次来一直阻塞在select函数处,假设此时有客户端连接进来将会触发select函数可读事件
此时sNumFDsBackFromSelect的值将大于0并且select函数将返回,由于select函数在while(!selecthasdata())中执行
所以当select函数返回的时候将进入selecthasdata函数,它的定义如下
**/
bool selecthasdata()
{
    //sNumFDsBackFromSelect<0表示select监听失败
    if (sNumFDsBackFromSelect < 0)
    {
        int err=OSThread::GetErrno();
        
        if (      
            err == EBADF || //this might happen if a fd is closed right before calling select
            err == EINTR 
           ) // this might happen if select gets interrupted
           return false;
        return true;//if there is an error from select, we want to make sure and return to the caller
    }
        
    //超时处理或者程序第一次执行   
    if (sNumFDsBackFromSelect == 0)
        return false;//if select returns 0, we've simply timed out, so recall select
}
/**
7.3.2.QTSServer::StartTasks();将socket端口加入到set集合当中
**/
void QTSServer::StartTasks()
{
	fRTCPTask = new RTCPTask();
	fStatsTask = new RTPStatsUpdaterTask();
	//
	// Start listening
	for (UInt32 x = 0; x < fNumListeners; x++)
		fListeners[x]->RequestEvent(EV_RE);
}

void EventContext::RequestEvent(int theMask)
{
    if (!compare_and_store(10000000, 1, &sUniqueID))
	    fUniqueID = (PointerSizedInt) atomic_add(&sUniqueID, 1);
    else
	    fUniqueID = 1;
	//先生成hashvalue
    fRef.Set(fUniqueIDStr, this);
    fEventThread->fRefTable.Register(&fRef);

    //fill out the eventreq data structure
    ::memset(&fEventReq, '\0', sizeof(fEventReq));
    fEventReq.er_type = EV_FD;
    fEventReq.er_handle = fFileDesc;
    fEventReq.er_eventbits = theMask;
    fEventReq.er_data = (void*) fUniqueID;
    fWatchEventCalled = true;

    if (select_watchevent(&fEventReq, theMask) != 0)
	    //this should never fail, but if it does, cleanup.
	    AssertV(false, OSThread::GetErrno());
}
/**
在服务启动阶段,调用QTSServer::StartTasks()函数将要监听的socket端口文件描述符
封装成struct eventreq这里是fEventReq结构体,然后回调select_watchevent函数将其
加入到fdset.先看看select_watchevent函数的实现
**/
/*
7.3.3.select_watchevent函数的实现
*/
int select_watchevent(struct eventreq *req, int which)
{
	return select_modwatch(req, which);
}

int select_modwatch(struct eventreq *req, int which)
{
	{
		//Manipulating sMaxFDPos is not pre-emptive safe, so we have to wrap it in a mutex
		//I believe this is the only variable that is not preemptive safe....
		OSMutexLocker locker(&sMaxFDPosMutex);
		//Add or remove this fd from the specified sets
		if (which & EV_RE)//socket服务器端口的事件为EV_RE,监听是否可读
			FD_SET(req->er_handle, &sReadSet);
		else
			FD_CLR(req->er_handle, &sReadSet);
		
		if (which & EV_WR)
			FD_SET(req->er_handle, &sWriteSet);
		else
			FD_CLR(req->er_handle, &sWriteSet);
		
        //如果sMaxFDPos小于socket端口文件描述符则修改它
		if (req->er_handle > sMaxFDPos)
			sMaxFDPos = req->er_handle;
	    //用文件句柄描述符作为索引将er_data保存到sCookieArray数组当中
	    //对于socket服务器端口而言er_data保存的是socket对应的hash id
	    //fUniqueID
		sCookieArray[req->er_handle] = req->er_data;
	}
	//write to the pipe so that select wakes up 
	//and registers the new mask
	int theErr = ::write(sPipes[1], "p", 1);
	//将socket 端口添加到sReadSet后向sPipes[1]写入一个p用来唤醒上面的
	//select_waitevent函数
	return 0;
}

/**
7.3.4.select 唤醒分析
在上面的分析中当把socket文件句柄添加到sReadSet后通过向sPipes[1]写入字符串来唤醒
阻塞在select_waitevent函数中的select回调,所以这里再看select_waitevent函数
当select第一次被成功返回那么sNumFDsBackFromSelect的值肯定为1,因为一开始是pipe
加入到了sReturnedReadSet集合当中了,而在上一步又向sPipes[1]写入了数据,所以当pipe
可读事件将会被触发
**/
bool selecthasdata()
{
    if (FD_ISSET(sPipes[0], &sReturnedReadSet)) {//条件成立
        //we've gotten data on the pipe file descriptor. Clear the data.
        // increasing the select buffer fixes a hanging problem when the Darwin server is under heavy load
        // CISCO contribution
        char theBuffer[4096]; 
        (void)::read(sPipes[0], &theBuffer[0], 4096);
        //将sPipes[0]从sReturnedReadSet集合中移除,为何要移除呢?
        FD_CLR(sPipes[0], &sReturnedReadSet);
        sNumFDsBackFromSelect--;//这样又回到0了
        {
            //Check the fds to close array, and if there are any in it,
            // close those descriptors
            OSMutexLocker locker(&sMaxFDPosMutex);
            for (UInt32 theIndex = 0; 
                ((sFDsToCloseArray[theIndex] != -1)
                 && (theIndex < sizeof(fd_set) * 8)); theIndex++)
            {
                (void)::close(sFDsToCloseArray[theIndex]);
                sFDsToCloseArray[theIndex] = -1;
            }
            //对sFDsToCloseArray数组中的文件进行关闭并清空
        }
    }
    Assert(!FD_ISSET(sPipes[0], &sReturnedWriteSet));
    
    //if the pipe file descriptor is the ONLY data we've gotten, recall select
    if (sNumFDsBackFromSelect == 0)
        return false;
    else//we've gotten a real event, return that to the caller
        return true;

}
/**
从上面的分析我们可以知道,当我们只是将文件句柄添加到fdset中的时候,select端唤醒后会将
sPipes[0]文件句柄从sReturnedReadSet中移除掉,然后让sNumFDsBackFromSelect--
在这里sNumFDsBackFromSelect--后又会变成0,所以对于select_waitevent而言以及会
继续while(!selecthasdata)循环,继续从readset集合中拷贝要监听的文件集合到sReturnedReadSet
当中,再次调用select函数进行阻塞,但是此时readset和sReturnedReadSet集合中已经包含了socket
服务端文件句柄,此时当有新的客户端连接进来select会被触发
**/

int constructeventreq(struct eventreq* req, int fd, int event)
{
    Assert(fd < (int)(sizeof(fd_set) * 8));
    if (fd >=(int)(sizeof(fd_set) * 8) )
    {
        return 0;
    }        
    req->er_handle = fd;
    req->er_eventbits = event;
    req->er_data = sCookieArray[fd];
    sCurrentFDPos++;
    sNumFDsProcessed++;
    
    //don't want events on this fd until modwatch is called.
    FD_CLR(fd, &sWriteSet);
    FD_CLR(fd, &sReadSet);
    
    return 0;
}







