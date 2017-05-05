

int main(int argc, char * argv[]) 
{
    extern char* optarg;

	1��������Դ����
#if __solaris__ || __linux__ || __hpux__
    //grow our pool of file descriptors to the max!
    struct rlimit rl;
    // set it to the absolute maximum that the operating system allows - have to be superuser to do this
    rl.rlim_cur = RLIM_INFINITY;
    rl.rlim_max = RLIM_INFINITY;
    setrlimit (RLIMIT_NOFILE, &rl);
#endif

	2���˿���Ч�Լ��
    // �˿ڼ��˿ڿ������û�ͨ��-p��������,�˿ں�0~65535,
	//����û�û���������ͨ������/etc/streaming/streamingserver.xml�ļ����
    if (thePort < 0 || thePort > 65535)
    { 
        qtss_printf("Invalid port value = %d max value = 65535\n",thePort);
        exit (-1);
    }

	3��ͨ�������ļ�(Ĭ��Ϊ/etc/streaming/streamingserver.xml)����XMLPrefsParser������
    XMLPrefsParser theXMLParser(theXMLFilePath);
    if (theXMLParser.DoesFileExistAsDirectory())
    {
        qtss_printf("Directory located at location where streaming server prefs file should be.\n");
        exit(-1);
    }
    
    //3.1�������ļ��Ƿ��д
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
    //����û�û��Ĭ��xml�����û�Ҳû��ָ��xml�ļ�·����
	//�ϰ汾ͨ��/etc/streamingserver.conf�ļ���
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

    4����xml(Ĭ��/etc/streaming/streamingserver.xml)�ļ����н���
    // Parse the configs from the XML file
    int xmlParseErr = theXMLParser.Parse();
    if (xmlParseErr)
    {
        qtss_printf("Fatal Error: Could not load configuration file at %s. (%d)\n", theXMLFilePath, OSThread::GetErrno());
        ::exit(-1);
    }
	
    5������û�û������ǰ�����иý�����forkһ���ӽ���,���������������?�Ա�׼������������ļ�������ж���
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
	
	6�������ӽ���
    if ( !dontFork) // if (fork) 
    {
        //loop until the server exits normally. If the server doesn't exit
        //normally, then restart it.
        // normal exit means the following
        // the child quit 
        do // fork at least once but stop on the status conditions returned by wait or if autoStart pref is false
        {
            processID = fork(); //�����ӽ���
            Assert(processID >= 0);
            if (processID > 0) // this is the parent and we have a child
            {
                sChildPID = processID;
                status = 0;
                while (status == 0) //loop on wait until status is != 0;
                {	
					/*wait()����ʱֹͣĿǰ���̵�ִ��, ֱ�����ź��������ӽ��̽���. 
						����ڵ���wait()ʱ�ӽ����Ѿ�����, ��wait()�����������ӽ��̽���״ֵ̬. 
						�ӽ��̵Ľ���״ֵ̬���ɲ���status ����, ���ӽ��̵Ľ���ʶ����Ҳ��һ�췵��. 
						������������״ֵ̬, �����status�������NULL. �ӽ��̵Ľ���״ֵ̬��ο�waitpid().
					*/
                 	pid =::wait(&status); //�����̽���ȴ�..
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
				//�����ӽ�����˵��ֱ������ѭ���ˡ�
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
	7������StartServer��������ʼ������ģ��,��鿴DSS_Main_Sequence_Diagram_01 - DSS_Main_Sequence_Diagram_03����ͼ
    if (::StartServer(&theXMLParser, &theMessagesSource, thePort, 
		statsUpdateInterval, theInitialState, dontFork, debugLevel, 
		debugOptions) != qtssFatalErrorState)
    {  
	8����������	
		::RunServer();
         CleanPid(false);
         exit (EXIT_SUCCESS);
    }
    else
    	exit(-1); //Cant start server don't try again
		
	//��ӡ��Ϣʹ��
	//QTSServerInterface::LogError(qtssMessageVerbosity, msgStr);
		
}
