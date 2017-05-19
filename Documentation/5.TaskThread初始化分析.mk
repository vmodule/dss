/**
经过前面几篇文章的分,当socket监听端口创建成功后开始创建任务线程
**/
QTSS_ServerState StartServer(
	XMLPrefsParser* inPrefsSource, PrefsSource* inMessagesSource,
	UInt16 inPortOverride, int statsUpdateInterval, 
	QTSS_ServerState inInitialState, Bool16 inDontFork,
	UInt32 debugLevel, UInt32 debugOptions)
{
    /*从xml文件中解析
    <PREF NAME="run_user_name" ></PREF>
    <PREF NAME="run_group_name" ></PREF> 
    默认系统帮初始化成qtss和qtss
	*/
    OSCharArrayDeleter runGroupName(sServer->GetPrefs()->GetRunGroupName());
    OSCharArrayDeleter runUserName(sServer->GetPrefs()->GetRunUserName());
    OSThread::SetPersonality(runUserName.GetObject(), runGroupName.GetObject());

    if (sServer->GetServerState() != qtssFatalErrorState)
    {
        UInt32 numShortTaskThreads = 0;
        UInt32 numBlockingThreads = 0;
        UInt32 numThreads = 0;
        UInt32 numProcessors = 0;
        
        if (OS::ThreadSafe()){//true...
            //run_num_threads 
            //if value is non-zero, will  create that many task threads; 
            //otherwise a thread will be created for each processor
            numShortTaskThreads = sServer->GetPrefs()->GetNumThreads(); // whatever the prefs say
            //默认得到应该为0
            if (numShortTaskThreads == 0) {
                //获取cpu是几核
               numProcessors = OS::GetNumProcessors();
                // 1 worker thread per processor, up to 2 threads.
                // Note: Limiting the number of worker threads to 2 on a MacOS X system with > 2 cores
                //     results in better performance on those systems, as of MacOS X 10.5.  Future
                //     improvements should make this limit unnecessary.
                if (numProcessors > 2)
                    numShortTaskThreads = 2;
                else
                    numShortTaskThreads = numProcessors;
                
            }
            //解析run_num_rtsp_threads
            numBlockingThreads = sServer->GetPrefs()->GetNumBlockingThreads(); // whatever the prefs say
            if (numBlockingThreads == 0)
                numBlockingThreads = 1;
                
        }
        if (numShortTaskThreads == 0)
            numShortTaskThreads = 1;

        if (numBlockingThreads == 0)
            numBlockingThreads = 1;

        numThreads = numShortTaskThreads + numBlockingThreads;
        //qtss_printf("Add threads shortask=%lu blocking=%lu\n",numShortTaskThreads, numBlockingThreads);
        TaskThreadPool::SetNumShortTaskThreads(numShortTaskThreads);
        TaskThreadPool::SetNumBlockingTaskThreads(numBlockingThreads);
        //使用线程池创建任务线程
        TaskThreadPool::AddThreads(numThreads);
        //初始化QTSServerInterface::fNumThreads成员
		sServer->InitNumThreads(numThreads);
     }
}

/**
4.1.默认线程任务配置
a).上述代码首先从xml文件run_num_threads字段获取用户配置的线程数量,如果为0则程序回去检测cpuinfo
获取cpu processor,如果CPU processor大于2,则numShortTaskThreads数量将等于2,否则对于cpu processor<=2
的默认numShortTaskThreads将等于cpu processor的数量,这有点在限制使用cpu processor的情况
b) 得到numShortTaskThreads后从xml文件中解析run_num_rtsp_threads,系统默认为1返回给numBlockingThreads
c).最后求和numShortTaskThreads和numBlockingThreads得到numThreads
d).将numShortTaskThreads保存到TaskThreadPool::sNumShortTaskThreads成员变量
e).将numBlockingThreads保存到TaskThreadPool::sNumBlockingTaskThreads成员变量
f).调用TaskThreadPool::AddThreads(numThreads)重头戏在这列吗?
**/
/**
4.2.使用线程池创建任务线程
@numToAdd:numBlockingThreads+numShortTaskThreads
**/
Bool16 TaskThreadPool::AddThreads(UInt32 numToAdd)
{
    Assert(sTaskThreadArray == NULL);
    //sTaskThreadArray为TaskThread**型的二级指针,也就是一个静态数组
    //这里先开辟空间
    sTaskThreadArray = new TaskThread*[numToAdd];    
    for (UInt32 x = 0; x < numToAdd; x++) {
        //逐个填充TaskThread到sTaskThreadArray数组
        //并调用TaskThread::Start()运行线程
        sTaskThreadArray[x] = NEW TaskThread();
        sTaskThreadArray[x]->Start();
    }
    //初始化sNumTaskThreads
    sNumTaskThreads = numToAdd;
    
    if (0 == sNumShortTaskThreads)
        sNumShortTaskThreads = numToAdd;
        
    return true;
}
/**
该函数首先分配一个sTaskThreadArray指针数组,数组的大小numThreads
然后创建sTaskThreadArray指针数组中的每个元素TaskThread指针,成功创建之后
运行这些TaskThread,接下来先看看TaskThread和它的父类之间的关系
**/
/**
4.3.TaskThread和它父类OSThread的构造函数和析构函数分析
**/
TaskThread::TaskThread()
    :OSThread(), 
    fTaskThreadPoolElem(){
    //每一个TaskThread也对应着一个OSQueueElem
    //这里将TaskThread保存到OSQueueElem的void*成员变量
    fTaskThreadPoolElem.SetEnclosingObject(this);
}
/**
每一个TaskThread维护着一个OSQueue_Blocking队列,该队列维护着若干
OSQueueElem,而TaskThread通过fTaskThreadPoolElem.SetEnclosingObject(this)
函数将TaskThread指针保存到OSQueueElem的void*成员变量,方便后面获取
**/

TaskThread::~TaskThread() {
 this->StopAndWaitForThread();
}

void OSThread::Join()
{
    // What we're trying to do is allow the thread we want to delete to complete
    // running. So we wait for it to stop.
    Assert(!fJoined);
    fJoined = true;
#ifdef __PTHREADS__
    void *retVal;
    pthread_join((pthread_t)fThreadID, &retVal);
#endif
}

void OSThread::StopAndWaitForThread() {
    fStopRequested = true;
    if (!fJoined)
        Join();
}

OSThread::OSThread()
:   fStopRequested(false),
    fJoined(false),
    fThreadData(NULL)
{
}

OSThread::~OSThread()
{
    this->StopAndWaitForThread();
}
/*
以上代码创建TaskThread和OSThread没做多少事情,就是对它的成员变量进行了一些初始化工作
4.4.start taskthread 开启任务线程
Start()函数定义在父类OSThread文件当中这里我们值分析Linux平台的
*/
void OSThread::Start()
{
#ifdef __PTHREADS__
    pthread_attr_t* theAttrP;
#ifdef _POSIX_THREAD_PRIORITY_SCHEDULING
    //theAttrP = &sThreadAttr;
    theAttrP = 0;
#else
    theAttrP = NULL;
#endif
    int err = pthread_create((pthread_t*)&fThreadID, theAttrP, _Entry, (void*)this);
    Assert(err == 0);
#endif
}
/*
Start()函数帮我们真正的创建了线程并执行了它的回调函数_Entry,它的定义如下:
*/
void* OSThread::_Entry(void *inThread)  //static
{
    OSThread* theThread = (OSThread*)inThread;
#ifdef __PTHREADS__
    theThread->fThreadID = (pthread_t)pthread_self();
    pthread_setspecific(OSThread::gMainKey, theThread);
#endif
    //
    theThread->SwitchPersonality();
    //
    // Run the thread
    theThread->Entry();//由子类实现
    return NULL;
}
/*
该函数调用pthread_setspecific(OSThread::gMainKey, theThread);
将子任务线程和主线程进行关联,同时又使得子线程在操作主线程的共享数据
的时候形成分离,OSThread::Initialize()中创建gMainKey
*/
/**
4.5.TaskThread线程循环分析
去掉相关的调式信息就只剩下下面的代码部分
由C++的多态TaskThread::Entry()函数将作为taskThread的threadloop
**/
void TaskThread::Entry()
{
    Task* theTask = NULL;
    
    while (true) 
    {
        theTask = this->WaitForTask();
        //
        // WaitForTask returns NULL when it is time to quit
        if (theTask == NULL || false == theTask->Valid() )
            return;
                    
        Bool16 doneProcessingEvent = false;
        while (!doneProcessingEvent)
        {
            //If a task holds locks when it returns from its Run function,
            //that would be catastrophic and certainly lead to a deadlock
            theTask->fUseThisThread = NULL; // Each invocation of Run must independently
                                            // request a specific thread.
            SInt64 theTimeout = 0;
            if (theTask->fWriteLock) {   
                OSMutexWriteLocker mutexLocker(&TaskThreadPool::sMutexRW);
                theTimeout = theTask->Run();
                theTask->fWriteLock = false;
            } else {
				//回调派生类的Run方法
                OSMutexReadLocker mutexLocker(&TaskThreadPool::sMutexRW);
                theTimeout = theTask->Run();
            }
            if (theTimeout < 0) {//表明任务执行完毕需要删掉该任务
                theTask->fTaskName[0] = 'D'; //mark as dead
                delete theTask;
                theTask = NULL;
                doneProcessingEvent = true;//break to WaitForTask
            }  else if (theTimeout == 0) {
                //We want to make sure that 100% definitely the task's Run function WILL
                //be invoked when another thread calls Signal. We also want to make sure
                //that if an event sneaks in right as the task is returning from Run()
                //(via Signal) that the Run function will be invoked again.
                doneProcessingEvent = 
                	compare_and_store(Task::kAlive, 0, &theTask->fEvents);
                //如果任务的状态为kAlive,则将任务状态清除成0
                if (doneProcessingEvent)
                    theTask = NULL; //break to WaitForTask
                //由于队列中的任务并没有被删除掉,所以下次调度时将立即执行
            } else {
                //将当前时间加上theTimeout的时间插入到最小堆
                //note that if we get here, we don't reset theTask,
                //so it will get passed into
                //WaitForTask
                theTask->fTimerHeapElem.SetValue(OS::Milliseconds() + theTimeout);
                fHeap.Insert(&theTask->fTimerHeapElem);
                (void)atomic_or(&theTask->fEvents, Task::kIdleEvent);
                doneProcessingEvent = true;
            }
	        this->ThreadYield();
        }
    }
}
/**
a)WaitForTask等待目标任务入队(OSQueue_Blocking fTaskQueue),在TaskThread类中
维护了一个fTaskQueue的成员变量,该成员为一个阻塞队列,当每一个任务需要被调度时
需要将目标Task加入到fTaskQueue当中,入队的过程主要是调用Task::Signal()函数
b)回调派生类的Run方法,每一个任务类都是Task的子类,必须实现Run方法,该方法有三个返回值
    b.1)返回负数,表明任务已经执行完毕
    b.2)返回0,表明任务希望在下次被调度时立即执行
    b.3)返回正数，表明任务希望在等待theTimeout时间后再次执行
**/
/**
4.6.TaskThread::WaitForTask()等待机制
**/
Task* TaskThread::WaitForTask()
{
    while (true)
    {
        SInt64 theCurrentTime = OS::Milliseconds();
        if ((fHeap.PeekMin() != NULL) && 
			(fHeap.PeekMin()->GetValue() <= theCurrentTime))
            return (Task*)fHeap.ExtractMin()->GetEnclosingObject();
		
        //if there is an element waiting for a timeout, 
        //figure out how long we should wait.
        SInt64 theTimeout = 0;
        if (fHeap.PeekMin() != NULL)
            theTimeout = fHeap.PeekMin()->GetValue() - theCurrentTime;
        Assert(theTimeout >= 0);
        //
        // Make sure we can't go to sleep for some ridiculously short
        // period of time
        // Do not allow a timeout below 10 ms without first verifying reliable udp 1-2mbit live streams. 
        // Test with streamingserver.xml pref reliablUDP printfs enabled and look 
        // for packet loss and check client for  buffer ahead recovery.
	    if (theTimeout < 10) 
           theTimeout = 10;
            
        //wait...
        OSQueueElem* theElem = 
        	fTaskQueue.DeQueueBlocking(this, 
        		(SInt32) theTimeout);
        if (theElem != NULL) 
            return (Task*)theElem->GetEnclosingObject();
        //
        // If we are supposed to stop, return NULL, which signals the caller to stop
        if (OSThread::GetCurrent()->IsStopRequested())
            return NULL;
    }   
}
/**
在TaskThread中维护了一个fHeap的数据结构它的类型是OSHeap,是一颗最小二叉树
从上述代码中应该是维护时间戳,同时还维护了一个fTaskQueue的阻塞队列,所有的Task
都将进入该队列
a).调用fHeap.PeekMin()判断fHeap最小堆上是否有数据,如果有数据则表示有任务被插入
然后使用fHeap.PeekMin()->GetValue()取出最小堆对应的数据和当前时间戳进行比较
在4.5中当Run函数返回值等于0的情况正好会<= theCurrentTime直接将任务取出返回
b).有任务,但是还没到执行的时间,则使用theTimeout = fHeap.PeekMin()->GetValue() 
    - theCurrentTime;计算多少秒后才执行任务,如4.5中当Run函数返回值>0的情况,假设
    Run()返回值为5,如果theTimeout<=10,则自动设成10s后再执行
c).调用fTaskQueue.DeQueueBlocking延时等待.时间到后将Task指针返回.
**/
/**
4.7.认识Task类
**/
class Task
{
public:
    typedef unsigned int EventFlags;
    enum
    {
        kKillEvent =    0x1 << 0x0, //these are all of type "EventFlags"
        kIdleEvent =    0x1 << 0x1,
        kStartEvent =   0x1 << 0x2,
        kTimeoutEvent = 0x1 << 0x3,
   
      //socket events
        kReadEvent =        0x1 << 0x4, //All of type "EventFlags"
        kWriteEvent =       0x1 << 0x5,
       
       //update event
        kUpdateEvent =      0x1 << 0x6
    };
	Task();
	virtual ~Task() {}
	/**
    return:
    >0 :invoke me after this number of MilSecs with a kIdleEvent
     0 :don't reinvoke me at all.
    -1 :delete me
    Suggested practice is that any task should be deleted by returning true from the
    Run function. That way, we know that the Task is not running at the time it is
    deleted. This object provides no protection against calling a method, such as Signal,
    at the same time the object is being deleted (because it can't really), so watch
    those dangling references!
    */
    virtual SInt64  Run() = 0;
    
    //Send an event to this task.
    void  Signal(EventFlags eventFlags);
private:
    enum
    {
        kAlive =            0x80000000, //EventFlags, again
        kAliveOff =         0x7fffffff
    };
    EventFlags      fEvents;
    TaskThread*     fUseThisThread;
    TaskThread*     fDefaultThread;
    Bool16          fWriteLock;    
    //This could later be optimized by using a timing wheel instead of a heap,
    //and that way we wouldn't need both a heap elem and a queue elem here (just queue elem)
    OSHeapElem      fTimerHeapElem;
    OSQueueElem     fTaskQueueElem;
    
    unsigned int *pickerToUse;
    //Variable used for assigning tasks to threads in a round-robin fashion
    static unsigned int sShortTaskThreadPicker; //default picker
    static unsigned int sBlockingTaskThreadPicker;
};
unsigned int Task::sShortTaskThreadPicker = 0;
unsigned int Task::sBlockingTaskThreadPicker = 0;
Task::Task()
: fEvents(0)//init task status to 0
, fUseThisThread(NULL)
, fDefaultThread(NULL)
, fWriteLock(false)
, fTimerHeapElem()
, fTaskQueueElem()
, pickerToUse(&Task::sShortTaskThreadPicker) {
	this->SetTaskName("unknown");
	//default pickerToUse point to sShortTaskThreadPicker
	fTaskQueueElem.SetEnclosingObject(this);
	fTimerHeapElem.SetEnclosingObject(this);
}
/**
Task类维护了两个重要的成员fTaskQueueElem和fTimerHeapElem,其中
fTaskQueueElem是任务队列的元素,而fTimerHeapElem是超时执行任务最小
堆的元素,这也说明了每一个Task任务都是TaskThread::fHeap和
TaskThread::fTaskQueue的一部分,另外Task::pickerToUse用来指派任务
从TaskThreadPool::sTaskThreadArray数组中的那个元素用来调度
**/
void Task::Signal(EventFlags events)
{
    if (!this->Valid())
        return;  
    //Fancy no mutex implementation. We atomically mask the new events into
    //the event mask. Because atomic_or returns the old state of the mask,
    //we only schedule this task once.
    events |= kAlive;
    EventFlags oldEvents = atomic_or(&fEvents, events);
    if ((!(oldEvents & kAlive)) && 
		(TaskThreadPool::sNumTaskThreads > 0)) {//default was not
        if (fDefaultThread != NULL 
			&& fUseThisThread == NULL)
            fUseThisThread = fDefaultThread;
        if (fUseThisThread != NULL){
            // Task needs to be placed on a particular thread.    
            fUseThisThread->fTaskQueue.EnQueue(&fTaskQueueElem);
        } else {//default here....
            //find a thread to put this task on
            unsigned int theThreadIndex = 
            	atomic_add((unsigned int *) pickerToUse, 1);
            //theThreadIndex = 1;
            if (&Task::sShortTaskThreadPicker == pickerToUse) {
                theThreadIndex %= TaskThreadPool::sNumShortTaskThreads;
            } else if (&Task::sBlockingTaskThreadPicker == pickerToUse) {
                theThreadIndex %= TaskThreadPool::sNumBlockingTaskThreads;
				//don't pick from lower non-blocking (short task) threads.
                theThreadIndex += TaskThreadPool::sNumShortTaskThreads; 
            } else {  
                return;
            }
            TaskThreadPool::sTaskThreadArray[theThreadIndex]->fTaskQueue.EnQueue(&fTaskQueueElem);
        }
    }
}
/**
pickerToUse默认被指向了Task::sShortTaskThreadPicker对应的内存,所以使用
theThreadIndex %= TaskThreadPool::sNumShortTaskThreads;
sNumShortTaskThreads的值依赖与配置文件中的run_num_threads,这里将环形从
TaskThreadPool::sTaskThreadArray中取出线程,然后调用fTaskQueue.EnQueue(&fTaskQueueElem)
将唤醒WaitForTask函数..
**/

