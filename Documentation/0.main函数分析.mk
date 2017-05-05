

int main(int argc, char * argv[]) 
{
    extern char* optarg;

	1、设置资源上限
#if __solaris__ || __linux__ || __hpux__
    //grow our pool of file descriptors to the max!
    struct rlimit rl;
    // set it to the absolute maximum that the operating system allows - have to be superuser to do this
    rl.rlim_cur = RLIM_INFINITY;
    rl.rlim_max = RLIM_INFINITY;
    setrlimit (RLIMIT_NOFILE, &rl);
#endif

	2、端口有效性检测
    // 端口检测端口可以由用户通过-p参数传入,端口号0~65535,
	//如果用户没传入参数则通过解析/etc/streaming/streamingserver.xml文件获得
    if (thePort < 0 || thePort > 65535)
    { 
        qtss_printf("Invalid port value = %d max value = 65535\n",thePort);
        exit (-1);
    }

	3、通过配置文件(默认为/etc/streaming/streamingserver.xml)构造XMLPrefsParser解析器
    XMLPrefsParser theXMLParser(theXMLFilePath);
    if (theXMLParser.DoesFileExistAsDirectory())
    {
        qtss_printf("Directory located at location where streaming server prefs file should be.\n");
        exit(-1);
    }
    
    //3.1、配置文件是否可写
    // Check to see if we can write to the file
    if (!theXMLParser.CanWriteFile())
    {
        qtss_printf("Cannot write to the streaming server prefs file.\n");
        exit(-1);
    }

    // If we aren't forced to create a new XML prefs file, whether
    // we do or not depends solely on whether the XML prefs file exists currently.
    if (theXMLPrefsExist)
        theXMLPrefsExist = theXMLParser.DoesFileExist();
	//3.2 
    //如果用户没有默认xml或者用户也没有指定xml文件路径则
	//老版本通过/etc/streamingserver.conf文件来
    if (!theXMLPrefsExist)
    {
        //
        // The XML prefs file doesn't exist, so let's create an old-style
        // prefs source in order to generate a fresh XML prefs file.
        
        if (theConfigFilePath != NULL)
        {   
            FilePrefsSource* filePrefsSource = new FilePrefsSource(true); // Allow dups
            
            if ( filePrefsSource->InitFromConfigFile(theConfigFilePath) )
            { 
               qtss_printf("Generating a new prefs file at %s\n", theXMLFilePath);
            }

            if (GenerateAllXMLPrefs(filePrefsSource, &theXMLParser))
            {
                qtss_printf("Fatal Error: Could not create new prefs file at: %s. (%d)\n", theXMLFilePath, OSThread::GetErrno());
                ::exit(-1);
            }
        }
    }

    4、对xml(默认/etc/streaming/streamingserver.xml)文件进行解析
    // Parse the configs from the XML file
    int xmlParseErr = theXMLParser.Parse();
    if (xmlParseErr)
    {
        qtss_printf("Fatal Error: Could not load configuration file at %s. (%d)\n", theXMLFilePath, OSThread::GetErrno());
        ::exit(-1);
    }
	
    5、如果用户没有设置前端运行该进程则fork一个子进程,这个进程用来干嘛?对标准输入输出出错文件句柄进行丢弃
    //Unless the command line option is set, fork & daemonize the process at this point
    if (!dontFork){
        if (daemon(0,0) != 0)

        {
            exit(-1);
        }
    }
    
    //Construct a Prefs Source object to get server text messages
    FilePrefsSource theMessagesSource;
    theMessagesSource.InitFromConfigFile("qtssmessages.txt");
    
    int status = 0;
    int pid = 0;
    pid_t processID = 0;
	
	6、创建子进程
    if ( !dontFork) // if (fork) 
    {
        //loop until the server exits normally. If the server doesn't exit
        //normally, then restart it.
        // normal exit means the following
        // the child quit 
        do // fork at least once but stop on the status conditions returned by wait or if autoStart pref is false
        {
            processID = fork(); //创建子进程
            Assert(processID >= 0);
            if (processID > 0) // this is the parent and we have a child
            {
                sChildPID = processID;
                status = 0;
                while (status == 0) //loop on wait until status is != 0;
                {	
					/*wait()会暂时停止目前进程的执行, 直到有信号来到或子进程结束. 
						如果在调用wait()时子进程已经结束, 则wait()会立即返回子进程结束状态值. 
						子进程的结束状态值会由参数status 返回, 而子进程的进程识别码也会一快返回. 
						如果不在意结束状态值, 则参数status可以设成NULL. 子进程的结束状态值请参考waitpid().
					*/
                 	pid =::wait(&status); //父进程进入等待..
                 	SInt8 exitStatus = (SInt8) WEXITSTATUS(status);
                	//qtss_printf("Child Process %d wait exited with pid=%d status=%d exit status=%d\n", processID, pid, status, exitStatus);
                	
					if (WIFEXITED(status) && pid > 0 && status != 0) // child exited with status -2 restart or -1 don't restart 
					{
						//qtss_printf("child exited with status=%d\n", exitStatus);
						
						if ( exitStatus == -1) // child couldn't run don't try again
						{
							qtss_printf("child exited with -1 fatal error so parent is exiting too.\n");
							exit (EXIT_FAILURE); 
						}
						break; // restart the child
							
					}
					
					if (WIFSIGNALED(status)) // child exited on an unhandled signal (maybe a bus error or seg fault)
					{	
						//qtss_printf("child was signalled\n");
						break; // restart the child
					}

                 		
                	if (pid == -1 && status == 0) // parent woken up by a handled signal
                   	{
						//qtss_printf("handled signal continue waiting\n");
                   		continue;
                   	}
                   	
                 	if (pid > 0 && status == 0)
                 	{
                 		//qtss_printf("child exited cleanly so parent is exiting\n");
                 		exit(EXIT_SUCCESS);                		
                	}
                	
                	//qtss_printf("child died for unknown reasons parent is exiting\n");
                	exit (EXIT_FAILURE);
                }
            }
            else if (processID == 0) // must be the child
				//对于子进程来说将直接跳出循环了。
				break;
            else
            	exit(EXIT_FAILURE);
            //eek. If you auto-restart too fast, you might start the new one before the OS has
            //cleaned up from the old one, resulting in startup errors when you create the new
            //one. Waiting for a second seems to work
            sleep(1);
        } while (RestartServer(theXMLFilePath)); // fork again based on pref if server dies
        if (processID != 0) //the parent is quitting
        	exit(EXIT_SUCCESS);   
    }
    sChildPID = 0;

	printf("start StartServer here....\n");
    //This function starts, runs, and shuts down the server
	7、调用StartServer创建并初始化各个模块,请查看DSS_Main_Sequence_Diagram_01 - DSS_Main_Sequence_Diagram_03流程图
    if (::StartServer(&theXMLParser, &theMessagesSource, thePort, 
		statsUpdateInterval, theInitialState, dontFork, debugLevel, 
		debugOptions) != qtssFatalErrorState)
    {  
	8、启动服务	
		::RunServer();
         CleanPid(false);
         exit (EXIT_SUCCESS);
    }
    else
    	exit(-1); //Cant start server don't try again
		
	//打印信息使用
	//QTSServerInterface::LogError(qtssMessageVerbosity, msgStr);
		
}
