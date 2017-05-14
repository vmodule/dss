QTSS_ServerState StartServer(
	XMLPrefsParser* inPrefsSource, PrefsSource* inMessagesSource,
	UInt16 inPortOverride, int statsUpdateInterval, 
	QTSS_ServerState inInitialState, Bool16 inDontFork,
	UInt32 debugLevel, UInt32 debugOptions)
{
    /* Start up the server's global tasks, and start listening
    The TimeoutTask mechanism is task based,
    we therefore must do this after adding task threads
    this be done before starting the sockets and server tasks*/
    TimeoutTask::Initialize();    
    
    if (sServer->GetServerState() != qtssFatalErrorState)
    {
        IdleTask::Initialize();
    }    
      
}
/**
系统创建三个ThreadTask之后在等待任务被添加进去,TimeoutTask作为global tasks
在StartServer过程中被启动
6.1.TimeoutTask::Initialize
**/
void TimeoutTask::Initialize()
{
    if (sThread == NULL)
    {
        sThread = NEW TimeoutTaskThread();
        sThread->Signal(Task::kStartEvent);
    }
    
}
/**
该函数主要就是创建了一个TimeoutTaskThread,然后回调其父类的
sThread->Signal(Task::kStartEvent)函数指派任务线程,Signal函数
会从TaskThreadPool的sTaskThreadArray数组中为TimeoutTask指派一个
线程,然后将TimeoutTaskThread作为一个OSQueueElem添加到fTaskQueue
队列末尾,这样对应线程的TaskThread::Entry()函数中调用的WaitForTask函数
会被唤醒从而会调用TimeoutTaskThread::Run()方法
**/
/**
6.2.认识TimeoutTaskThread类
**/
class TimeoutTaskThread : public IdleTask
{
public:
    //All timeout tasks get timed out from this thread
    TimeoutTaskThread() 
    : IdleTask(), fMutex() 
    {
    	this->SetTaskName("TimeoutTask");
	}
    virtual ~TimeoutTaskThread(){}
private:
    //this thread runs every minute and checks for timeouts
    enum
    {
        kIntervalSeconds = 60   //UInt32
    };
    virtual SInt64          Run();
    OSMutex                 fMutex;
    OSQueue                 fQueue;
    friend class TimeoutTask;
};
/**
TimeoutTaskThread类从IdleTask派生,而IdleTask由是Task的子类,TimeoutTaskThread
实现其父类的Run方法,同时自己也维护了一个fQueue的队列,该队列用于管理TimeoutTask
任务,当每一个TimeoutTask任务被创建的时候,会将任务以fQueueElem的形式加入到该队列
**/
/**
6.3.TimeoutTaskThread::Run()函数的实现
**/
SInt64 TimeoutTaskThread::Run()
{
    //ok, check for timeouts now. Go through the whole queue
    OSMutexLocker locker(&fMutex);
    SInt64 curTime = OS::Milliseconds();
    //always default to 60 seconds but adjust to smallest interval > 0
	SInt64 intervalMilli = kIntervalSeconds * 1000;
	SInt64 taskInterval = intervalMilli;
	
    for (OSQueueIter iter(&fQueue); !iter.IsDone(); iter.Next())
    {
        TimeoutTask* theTimeoutTask = 
			(TimeoutTask*)iter.GetCurrent()->GetEnclosingObject();
        
        //if it's time to time this task out, signal it
        if ((theTimeoutTask->fTimeoutAtThisTime > 0) && 
			(curTime >= theTimeoutTask->fTimeoutAtThisTime))
        {
			theTimeoutTask->fTask->Signal(Task::kTimeoutEvent);
		} else {
			taskInterval = theTimeoutTask->fTimeoutAtThisTime - curTime;
			if ( (taskInterval > 0) && 
			    (theTimeoutTask->fTimeoutInMilSecs > 0) && 
			    (intervalMilli > taskInterval) )
			    // set timeout to 1 second past this task's timeout
				intervalMilli = taskInterval + 1000; 

		}
	}
	//we must clear the event mask!
	(void)this->GetEvents();
	
	OSThread::ThreadYield();
	
    return intervalMilli;//don't delete me!
}
/**
该函数使用OSQueueIter对fQueue进行遍历,当检测到curTime大于或者等于
theTimeoutTask->fTimeoutAtThisTime的时候表示时间到了,此时需要唤醒
TimeoutTask对应的任务,否则进行计时操作
**/
/**
6.4.认识TimeoutTask
**/
class TimeoutTask
{
//TimeoutTask is not a derived object off of Task, to add flexibility as
//to how this object can be utilitized
public:
    //Call Initialize before using this class
    static  void Initialize();
    //Pass in the task you'd like to send timeouts to. 
    //Also pass in the timeout you'd like to use. By default, the timeout is 0 (NEVER).
    TimeoutTask(Task* inTask, SInt64 inTimeoutInMilSecs = 60);
    ~TimeoutTask();
    
    void  SetTask(Task* inTask) { fTask = inTask; }
private:
    Task*       fTask;
    SInt64      fTimeoutAtThisTime;
    SInt64      fTimeoutInMilSecs;
    //for putting on our global queue of timeout tasks
    OSQueueElem fQueueElem;
    
    static TimeoutTaskThread*   sThread;
    
    friend class TimeoutTaskThread;
};
/**
从TimeoutTask类的定义来看,TimeoutTask并不是Task的子类,它是通过构造
或者SetTask函数传递Task指针给成员变量fTask,然后通过调用
sThread->fQueue.EnQueue(&fQueueElem);将fTask加入到TimeoutTaskThread类
维护的fQueue当中,下面是它的构造和析构函数
**/

TimeoutTask::TimeoutTask(Task* inTask, SInt64 inTimeoutInMilSecs)
: fTask(inTask), fQueueElem()
{
	fQueueElem.SetEnclosingObject(this);
    this->SetTimeout(inTimeoutInMilSecs);
    if (NULL == inTask)
		fTask = (Task *) this;
    Assert(sThread != NULL); // this can happen if RunServer intializes tasks in the wrong order

    OSMutexLocker locker(&sThread->fMutex); 
    sThread->fQueue.EnQueue(&fQueueElem);
}

TimeoutTask::~TimeoutTask()
{
    OSMutexLocker locker(&sThread->fMutex);
    sThread->fQueue.Remove(&fQueueElem);
}
/**
那么TimeoutTask到底管理了那些Task后文分析
**/

/**
6.5.IdleTask::Initialize()初始化过程
*/
void IdleTask::Initialize()
{
    if (sIdleThread == NULL)
    {
        sIdleThread = NEW IdleTaskThread();
        sIdleThread->Start();
    }
}
/**
上述函数主要是创建IdleTaskThread并运行,其中IdleTaskThread
是OSThread的子类,它的定义如下
**/

class IdleTaskThread : private OSThread
{
private:

    IdleTaskThread() : OSThread(), fHeapMutex() {}
    virtual ~IdleTaskThread() 
    { 
        Assert(fIdleHeap.CurrentHeapSize() == 0);
    }
    void SetIdleTimer(IdleTask *idleObj, SInt64 msec);
    void CancelTimeout(IdleTask *idleObj);
    
    virtual void Entry();
    OSHeap  fIdleHeap;
    OSMutex fHeapMutex;
    OSCond  fHeapCond;
    friend class IdleTask;
};
/*sIdleThread->Start()会创建线程,并执行线程回调函数,由C++的多态关系
最终会调用IdleTaskThread::Entry函数,它的实现如下:
*/
void
IdleTaskThread::Entry()
{
    OSMutexLocker locker(&fHeapMutex);
    while (true)
    {
        //if there are no events to process, block.
        if (fIdleHeap.CurrentHeapSize() == 0)
            fHeapCond.Wait(&fHeapMutex);
        SInt64 msec = OS::Milliseconds();
        
        //pop elements out of the heap as long as their timeout time has arrived
        while ((fIdleHeap.CurrentHeapSize() > 0) 
			&& (fIdleHeap.PeekMin()->GetValue() <= msec))
        {
            IdleTask* elem = 
				(IdleTask*)fIdleHeap.ExtractMin()->GetEnclosingObject();
            Assert(elem != NULL);
            elem->Signal(Task::kIdleEvent);
        }
                        
        //we are done sending idle events. If there is a lowest tick count, then
        //we need to sleep until that time.
        if (fIdleHeap.CurrentHeapSize() > 0)
        {
            SInt64 timeoutTime = fIdleHeap.PeekMin()->GetValue();
            //because sleep takes a 32 bit number
            timeoutTime -= msec;
            Assert(timeoutTime > 0);
            UInt32 smallTime = (UInt32)timeoutTime;
            fHeapCond.Wait(&fHeapMutex, smallTime);
        }
    }   
}
/**
IdleTaskThread::Entry()函数的作用十分明了,如果fIdleHeap最小堆中没有数据
则等待有数据添加进来,如果最小堆有数据,说明有任务,如果该任务对应的时间戳
小于当前值的话则说明该任务需要调度,回调父类的Signal函数,为已就绪的任务准备
任务线程(从TaskThreadPool::sTaskThreadArray中取线程),然后将该任务添加到任
务线程对应的fTaskQueue当中,最终会触发TaskThread::Entry函数,进而回调其子类
的Run方法,这里将回调TimeoutTaskThread::Run()方法
对于周期性执行的任务将使用fHeapCond.Wait(&fHeapMutex, smallTime)进行等待?
**/


