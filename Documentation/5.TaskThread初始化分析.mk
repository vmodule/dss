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
a).上述代码首先从xml文件run_num_threads字段获取用户配置的线程数量,如果为0则程序回去检测cpuinfo
获取cpu processor,如果CPU processor大于2,则numShortTaskThreads数量将等于2,否则对于cpu processor<=2
的默认numShortTaskThreads将等于cpu processor的数量,这有点在限制使用cpu processor的情况
b)得到numShortTaskThreads后从xml文件中解析run_num_rtsp_threads,系统默认为1返回给numBlockingThreads
c).最后求和numShortTaskThreads和numBlockingThreads得到numThreads
d).将numShortTaskThreads保存到TaskThreadPool::sNumShortTaskThreads成员变量
e).将numBlockingThreads保存到TaskThreadPool::sNumBlockingTaskThreads成员变量
f).调用TaskThreadPool::AddThreads(numThreads)重头戏在这列吗?
**/
/**
4.1 使用线程池创建任务线程
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
4.2
TaskThread和它父类OSThread的构造函数和析构函数分析
**/
TaskThread::TaskThread()
:OSThread(), 
fTaskThreadPoolElem(){
    fTaskThreadPoolElem.SetEnclosingObject(this);
}

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
4.3 start taskthread 开启任务线程
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
4.4 TaskThread线程循环
由C++的多态TaskThread::Entry()函数将作为taskThread的threadloop
**/
void TaskThread::Entry(){
    Task* theTask = NULL;
    while (true) {
        theTask = this->WaitForTask();
        //
        // WaitForTask returns NULL when it is time to quit
        if (theTask == NULL || false == theTask->Valid() )
            return;
        Bool16 doneProcessingEvent = false;
        while (!doneProcessingEvent) {
            //If a task holds locks when it returns from its Run function,
            //that would be catastrophic and certainly lead to a deadlock

            theTask->fUseThisThread = NULL; // Each invocation of Run must independently
                                            // request a specific thread.
            SInt64 theTimeout = 0;
            
            if (theTask->fWriteLock)
            {   
                OSMutexWriteLocker mutexLocker(&TaskThreadPool::sMutexRW);                
                theTimeout = theTask->Run();
                theTask->fWriteLock = false;
            }
            else
            {
                OSMutexReadLocker mutexLocker(&TaskThreadPool::sMutexRW);
                theTimeout = theTask->Run();
            
            }
        
            if (theTimeout < 0)
            {
                theTask->fTaskName[0] = 'D'; //mark as dead
                delete theTask;
                theTask = NULL;
                doneProcessingEvent = true;

            }
            else if (theTimeout == 0)
            {
                //We want to make sure that 100% definitely the task's Run function WILL
                //be invoked when another thread calls Signal. We also want to make sure
                //that if an event sneaks in right as the task is returning from Run()
                //(via Signal) that the Run function will be invoked again.
                doneProcessingEvent = compare_and_store(Task::kAlive, 0, &theTask->fEvents);
                if (doneProcessingEvent)
                    theTask = NULL; 
            }
            else
            {
                //note that if we get here, we don't reset theTask, so it will get passed into
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

