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
    ::memset( &theCurrentEvent, '\0', sizeof(theCurrentEvent) );
    while (true)
    {
        int theErrno = EINTR;
        while (theErrno == EINTR)
        {//如果超时返回则继续进行等待
            int theReturnValue = select_waitevent(&theCurrentEvent, NULL);
            //Sort of a hack. In the POSIX version of the server, waitevent can return
            //an actual POSIX errorcode.
            if (theReturnValue >= 0)
                theErrno = theReturnValue;
            else
                theErrno = OSThread::GetErrno();
        }
        AssertV(theErrno == 0, theErrno);
        //ok, there's data waiting on this socket. Send a wakeup.
        if (theCurrentEvent.er_data != NULL)
        {
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
7.3.select_watchevent将文件句柄加入到相应的监听集合当中
**/
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
        if (which & EV_RE)
            FD_SET(req->er_handle, &sReadSet);
        else
            FD_CLR(req->er_handle, &sReadSet);

        if (which & EV_WR)
            FD_SET(req->er_handle, &sWriteSet);
        else
            FD_CLR(req->er_handle, &sWriteSet);

        //当要加入到select文件句柄描述符大于sMaxFDPos的时候
        //需要修改sMaxFDPos的值
        if (req->er_handle > sMaxFDPos)
            sMaxFDPos = req->er_handle;

        //
        // Also, modifying the cookie is not preemptive safe. This must be
        // done atomically wrt setting the fd in the set. Otherwise, it is
        // possible to have a NULL cookie on a fd.
        Assert(req->er_handle < (int)(sizeof(fd_set) * 8));
        Assert(req->er_data != NULL);
        //每一个文件句柄对应的void *data保存到sCookieArray数组
        //并且使用文件句柄作为索引,方便以后查找
        sCookieArray[req->er_handle] = req->er_data;
    }    
    //write to the pipe so that select wakes up and registers the new mask
    //唤醒select函数表示pipe可读取
    int theErr = ::write(sPipes[1], "p", 1);
    Assert(theErr == 1);

    return 0;
}
/**
7.4.select_waitevent时间等待机制
**/
int select_waitevent(struct eventreq *req, void* /*onlyForMacOSX*/)
{
    //Check to see if we still have some select descriptors to process
    int theFDsProcessed = (int)sNumFDsProcessed;
    bool isSet = false;
    
    if (theFDsProcessed < sNumFDsBackFromSelect)
    {//程序第一次进来不会走这里,所以第二次调用会进这里
        //如果sInReadSet为true
        if (sInReadSet) {
            OSMutexLocker locker(&sMaxFDPosMutex);
            while((!(isSet = FD_ISSET(sCurrentFDPos,
                 &sReturnedReadSet))) 
                && (sCurrentFDPos < sMaxFDPos)) 
                sCurrentFDPos++;
            //当sCurrentFDPos不在sReturnedReadSet集合当中并且
            //sCurrentFDPos<sMaxFDPos的时候会一直循环在此            
            if (isSet) {
                //如果sCurrentFDPos在sReturnedReadSet当中则将其从
                //sReturnedReadSetq清除掉
                FD_CLR(sCurrentFDPos, &sReturnedReadSet);
                return constructeventreq(req, sCurrentFDPos, EV_RE);
            } else {
                sInReadSet = false;
                sCurrentFDPos = 0;
            }
        }
        
        if (!sInReadSet) {
            OSMutexLocker locker(&sMaxFDPosMutex);

            while((!(isSet = FD_ISSET(sCurrentFDPos, &sReturnedWriteSet))) && (sCurrentFDPos < sMaxFDPos))
                sCurrentFDPos++;

            if (isSet){

                FD_CLR(sCurrentFDPos, &sReturnedWriteSet);
                return constructeventreq(req, sCurrentFDPos, EV_WR);
            } else {
                // This can happen if another thread calls select_removeevent at just the right
                // time, setting sMaxFDPos lower than it was when select() was last called.
                // Becase sMaxFDPos is used as the place to stop iterating over the read & write
                // masks, setting it lower can cause file descriptors in the mask to get skipped.
                // If they are skipped, that's ok, because those file descriptors were removed
                // by select_removeevent anyway. We need to make sure to finish iterating over
                // the masks and call select again, which is why we set sNumFDsProcessed
                // artificially here.
                sNumFDsProcessed = sNumFDsBackFromSelect;
                Assert(sNumFDsBackFromSelect > 0);
            }
        }
    }
    
    if (sNumFDsProcessed > 0)
    {
        OSMutexLocker locker(&sMaxFDPosMutex);
        //We've just cycled through one select result. Re-init all the counting states
        sNumFDsProcessed = 0;
        sNumFDsBackFromSelect = 0;
        sCurrentFDPos = 0;
        sInReadSet = true;
    }
    //第一次来返回false
    while(!selecthasdata())
    {
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
        //所以程序第一次执行到select函数将等待sPipes[0]文件句柄被写,当
    }
    //程序第一次执行,当没有往读写集合中添加文件句柄的时候,会超时返回
    //不过事实上当select函数被调用时马上会将socket服务端口文件句柄加入到sReadSet
    //并向pipe[0]写入值唤醒select函数
    if (sNumFDsBackFromSelect >= 0)
        return EINTR;   //either we've timed out or gotten some events. Either way, force caller
                        //to call waitevent again.
    return sNumFDsBackFromSelect;
}

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
        
    //超时处理   
    if (sNumFDsBackFromSelect == 0)
        return false;//if select returns 0, we've simply timed out, so recall select
    
    //如果sPipes[0]在sReturnedReadSet集合当中,首次执行完毕后该条件成立
    if (FD_ISSET(sPipes[0], &sReturnedReadSet))
    {
        //we've gotten data on the pipe file descriptor. Clear the data.
        // increasing the select buffer fixes a hanging problem when the Darwin server is under heavy load
        // CISCO contribution
        char theBuffer[4096]; 
        (void)::read(sPipes[0], &theBuffer[0], 4096);

        //将sPipes[0]从sReturnedReadSet集合中移除
        FD_CLR(sPipes[0], &sReturnedReadSet);
        sNumFDsBackFromSelect--;
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







