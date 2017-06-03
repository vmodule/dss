

/**
在socket thread运行之前,需要先初始化模块,
**/
QTSS_ServerState StartServer(
	XMLPrefsParser* inPrefsSource, PrefsSource* inMessagesSource,
	UInt16 inPortOverride, int statsUpdateInterval, 
	QTSS_ServerState inInitialState, Bool16 inDontFork,
	UInt32 debugLevel, UInt32 debugOptions)
{
    if (sServer->GetServerState() != qtssFatalErrorState) {
        sServer->InitModules(inInitialState);
    }	
}
/**
在StartServer函数中回调QTSServer::InitModules来加载并初始化模块
**/

void QTSServer::InitModules(QTSS_ServerState inEndState)
{

	LoadModules (fSrvrPrefs);
	LoadCompiledInModules();
	this->BuildModuleRoleArrays();
	// INVOKE INITIALIZE ROLE
	this->DoInitRole();

	if (fServerState != qtssFatalErrorState)
		fServerState = inEndState; // Server is done starting up!

	fSrvrPrefs->SetErrorLogVerbosity(serverLevel); // reset the server's verbosity back to the original prefs level.
}
/**
8.1 LoadModules从指定路径加载模块,默认指定路径定义在streamingserver.xml文件当中定义如下:
<PREF NAME="module_folder">/usr/local/sbin/StreamingServerModules</PREF>
默认编译完后在安装文件中我们可以看到StreamingServerModules目录,该目录下默认有两个二进制文件
分别为QTSSHomeDirectoryModule和QTSSRefMovieModule两个模块,现在来分析LoadModules函数
**/
void QTSServer::LoadModules(QTSServerPrefs* inPrefs)
{
	// Fetch the name of the module directory and open it.
	// 这里就是根据/usr/local/sbin/StreamingServerModules创建的
	OSCharArrayDeleter theModDirName(inPrefs->GetModuleDirectory());
	DIR* theDir = ::opendir(theModDirName.GetObject());
	while (true)
	{
		struct dirent* theFile = ::readdir(theDir);
		if (theFile == NULL)
			break;
		this->CreateModule(theModDirName.GetObject(), theFile->d_name);
	}
	(void) ::closedir(theDir);
}
/**
LoadModules函数就是根据指定的StreamingServerModules路径,在这里为/usr/local/sbin/StreamingServerModules
去循环读取该目录,然后根据该目录下的源文件的名字创建回调CreateModule来创建模块,默认情况下该目录下有
QTSSHomeDirectoryModule和QTSSRefMovieModule两个模块,再分析CreateModule函数的实现
**/
void QTSServer::CreateModule(char* inModuleFolderPath, char* inModuleName)
{
	//
	// Construct a full path to this module
	//构建全路径如:/usr/local/sbin/StreamingServerModules/QTSSRefMovieModule
	UInt32 totPathLen = ::strlen(inModuleFolderPath) + ::strlen(inModuleName);
	OSCharArrayDeleter theModPath(NEW char[totPathLen + 4]);
	
	::strcpy(theModPath.GetObject(), inModuleFolderPath);
	::strcat(theModPath.GetObject(), kPathDelimiterString);
	::strcat(theModPath.GetObject(), inModuleName);

	//
	// Construct a QTSSModule object, and attempt to initialize the module
	// 8.1.1 根据模块路径信息构造QTSSModule实例
	QTSSModule* theNewModule = NEW 
						QTSSModule(inModuleName, theModPath.GetObject());
	
	// 8.1.2 配置QTSSModule
	QTSS_Error theErr = theNewModule->SetupModule(&sCallbacks);

	if (theErr != QTSS_NoErr)
	{
		QTSSModuleUtils::LogError(qtssWarningVerbosity, qtssMsgBadModule,
				theErr, inModuleName);
		delete theNewModule;
	}
	// 8.1.3 将刚刚构造的QTSSModule添加到哪？
	// If the module was successfully initialized, add it to our module queue
	else if (!this->AddModule(theNewModule))
	{
		QTSSModuleUtils::LogError(qtssWarningVerbosity, qtssMsgRegFailed,
				theErr, inModuleName);
		delete theNewModule;
	}
}
/**
QTSServer::CreateModule分成3步完成对模块的加载和初始化工作
8.1.1)根据模块路径信息构造QTSSModule实例
8.1.2)配置QTSSModule
8.1.3)将初始化好的QTSSModule添加到哪？
**/

/*
8.1.1 根据模块路径信息构造QTSSModule实例	
*/
QTSSModule::QTSSModule(char* inName, char* inPath) 
	: QTSSDictionary(QTSSDictionaryMap::GetMap(QTSSDictionaryMap::kModuleDictIndex))
	, fQueueElem(NULL)
	, fPath(NULL)
	, fFragment(NULL)
	, fDispatchFunc(NULL)
	, fPrefs(NULL)
	, fAttributes(NULL) {
	
	//每一个QTSSModule都可以看成一个fQueueElem,也就是队列元素
	fQueueElem.SetEnclosingObject(this);
	this->SetTaskName("QTSSModule");
	if ((inPath != NULL) && (inPath[0] != '\0')) {
		// Create a code fragment if this module is being loaded from disk
		fFragment = NEW OSCodeFragment(inPath);
		fPath = NEW char[::strlen(inPath) + 2];
		::strcpy(fPath, inPath);
		//这里根据模块的全路径构造OSCodeFragment
	}

	fAttributes = NEW QTSSDictionary(NULL, &fAttributesMutex);

	this->SetVal(qtssModPrefs, &fPrefs, sizeof(fPrefs));
	this->SetVal(qtssModAttributes, &fAttributes, sizeof(fAttributes));

	// If there is a name, copy it into the module object's internal buffer
	if (inName != NULL)
		this->SetValue(qtssModName, 0, inName, ::strlen(inName),
				QTSSDictionary::kDontObeyReadOnly);

	//初始化fRoleArray,初始化fModuleState
	//每一个模块应该拥有很多的moduleRole
	::memset(fRoleArray, 0, sizeof(fRoleArray));
	::memset(&fModuleState, 0, sizeof(fModuleState));
}
/**
在QTSSModule构造函数中最重要功能是根据模块全路径创建OSCodeFragment
而在OSCodeFragment的构造过程中会依据传入的路径回调dlopen函数将该模块一
动态句柄的形式打开,最后将打开后返回的句柄保存到OSCodeFragment::fFragmentP
不妨看看OSCodeFragment类的定义和实现
**/

class OSCodeFragment
{
public:
	OSCodeFragment(const char* inPath);
	~OSCodeFragment();
	Bool16  IsValid() { return (fFragmentP != NULL); }
	void*   GetSymbol(const char* inSymbolName);
	
private:
	void*   fFragmentP;
};

OSCodeFragment::OSCodeFragment(const char* inPath)
	: fFragmentP(NULL)
{
    fFragmentP = dlopen(inPath, RTLD_NOW | RTLD_GLOBAL);
}

OSCodeFragment::~OSCodeFragment()
{
    if (fFragmentP == NULL)
        return;
    dlclose(fFragmentP);
}

void* OSCodeFragment::GetSymbol(const char* inSymbolName)
{
    if (fFragmentP == NULL)
        return NULL;
    return dlsym(fFragmentP, inSymbolName);
}
/**
通过调用GetSymbol并传入模块中的函数名称就可以使用模块中定义的方法
**/

/**
8.1.2 配置QTSSModule
**/
QTSS_Error QTSSModule::SetupModule(QTSS_CallbacksPtr inCallbacks,
		QTSS_MainEntryPointPtr inEntrypoint) {
	QTSS_Error theErr = QTSS_NoErr;

	//a) Load fragment from disk if necessary
	if ((fFragment != NULL) && (inEntrypoint == NULL))
		theErr = this->LoadFromDisk(&inEntrypoint);
	if (theErr != QTSS_NoErr)
		return theErr;

	// At this point, we must have an entrypoint
	if (inEntrypoint == NULL)
		return QTSS_NotAModule;

	//b) Invoke the private initialization routine
	QTSS_PrivateArgs thePrivateArgs;
	thePrivateArgs.inServerAPIVersion = QTSS_API_VERSION;
	thePrivateArgs.inCallbacks = inCallbacks;
	thePrivateArgs.outStubLibraryVersion = 0;
	thePrivateArgs.outDispatchFunction = NULL;

	theErr = (inEntrypoint)(&thePrivateArgs);
	if (theErr != QTSS_NoErr)
		return theErr;

	//c) Set the dispatch function so we'll be able to invoke this module later on
	fDispatchFunc = thePrivateArgs.outDispatchFunction;

	return QTSS_NoErr;
}
/**
QTSSModule::SetupModule分成3步
a).对于从指定路径加载的模块由于在回调SetupModule函数的时候只传入了sCallbacks对于
	inEntrypoint默认为NULL所以在这里会使用LoadFromDisk函数为inEntrypoint赋值
	也就是得到该模块的main函数,对应的QTSSHomeDirectoryModule和QTSSRefMovieModule两个模块
	而言就是分别得到QTSSHomeDirectoryModule_Main和QTSSRefMovieModule_Main两个函数入口
b) 得到模块的函数入口后需要为main函数准备函数形参,在这里初始化QTSS_PrivateArgs结构体作为
	QTSSHomeDirectoryModule_Main和QTSSRefMovieModule_Main两个函数的参数
c) 对于每一个模块必须是QTSSModule的派生类,在QTSSModule中定义了一个成员变量
	QTSS_DispatchFuncPtr fDispatchFunc;这两将thePrivateArgs.outDispatchFunction赋值给
	fDispatchFunc
	其中LoadFromDisk函数的实现如下:
**/
QTSS_Error QTSSModule::LoadFromDisk(QTSS_MainEntryPointPtr* outEntrypoint) {
	static StrPtrLen sMainEntrypointName("_Main");

	StrPtrLen theFileName(fPath);
	StringParser thePathParser(&theFileName);
	//
	// The main entrypoint symbol name is the file name plus that _Main__ string up there.
	OSCharArrayDeleter theSymbolName(
			NEW char[theFileName.Len + sMainEntrypointName.Len + 2]);
	
	::memcpy(theSymbolName, theFileName.Ptr, theFileName.Len);
	theSymbolName[theFileName.Len] = '\0';

	::strcat(theSymbolName, sMainEntrypointName.Ptr);
	
	//此时theSymbolName的值为QTSSRefMovieModule_Main和QTSSHomeDirectoryModule_Main
	*outEntrypoint = (QTSS_MainEntryPointPtr) fFragment->GetSymbol(
			theSymbolName.GetObject());
	//经过fFragment->GetSymbol回调后在8.1.2中的fDispatchFunc值就会被赋值了
	//针对QTSSRefMovieModule_Main函数而言它的回调过程如下
	return QTSS_NoErr;
}

QTSS_Error QTSSHomeDirectoryModule_Main(void* inPrivateArgs)
{
    return _stublibrary_main(inPrivateArgs, QTSSHomeDirectoryDispatch);
}
/**
inPrivateArgs为8.1.2中初始化的thePrivateArgs参数,在回调QTSSHomeDirectoryModule_Main函数前
对于thePrivateArgs它的outDispatchFunction成员变量被初始化成NULL,但是在调用_stublibrary_main
函数后outDispatchFunction成员变量被赋值成QTSSHomeDirectoryDispatch了。_stublibrary_main
函数实现如下:
**/
//sCallbacks 在下面的分析中将无处不用,事实上它就是定义在类QTSServer当中的
//static QTSS_Callbacks sCallbacks 静态成员变量
static QTSS_CallbacksPtr    sCallbacks = NULL;

QTSS_Error _stublibrary_main(void* inPrivateArgs, QTSS_DispatchFuncPtr inDispatchFunc)
{
    QTSS_PrivateArgsPtr theArgs = (QTSS_PrivateArgsPtr)inPrivateArgs;
    // Setup
    sCallbacks = theArgs->inCallbacks;
    sErrorLogStream = theArgs->inErrorLogStream;
    // Send requested information back to the server
    theArgs->outStubLibraryVersion = QTSS_API_VERSION;
    theArgs->outDispatchFunction = inDispatchFunc;
    return QTSS_NoErr;
}
/**
8.1.3 将刚刚构造的QTSSModule添加到哪？添加到一个名叫sModuleQueue的队列
在学习之AddModule函数之前我们先来认识一下前定义在QTSS_Private.h文件当中
的如下两个结构体
**/

typedef struct
{
    UInt32                  inServerAPIVersion;
    QTSS_CallbacksPtr       inCallbacks;//模块回调函数指针结构
    QTSS_StreamRef          inErrorLogStream;
    UInt32                  outStubLibraryVersion;
    QTSS_DispatchFuncPtr    outDispatchFunction;
    
} QTSS_PrivateArgs, *QTSS_PrivateArgsPtr;

typedef struct
{
    QTSSModule* curModule;  // this structure is setup in each thread
    QTSS_Role   curRole;    // before invoking a module in a role. Sometimes
    Task*       curTask;    // this info. helps callback implementation
    Bool16      eventRequested;
    Bool16      globalLockRequested;    // request event with global lock.
    Bool16      isGlobalLocked;
    SInt64      idleTime;   // If a module has requested idle time.
    
} QTSS_ModuleState, *QTSS_ModuleStatePtr;
/**
当我们在QTSServer::AddModule中要调用CallDispatch也就是调用fDispatchFunc的时候
是需要传入两个参数的,那么需要传入的两个参数就是上面两个函数指针,至于它们有什么作用
在后面的分析中慢慢分析吧,这里我们只是对它们混个眼熟
**/
Bool16 QTSServer::AddModule(QTSSModule* inModule)
{
	Assert(inModule->IsInitialized());//如果fDispatchFunc为空则不执行下面的程序

	// Prepare to invoke the module's Register role. Setup the Register param block
	QTSS_ModuleState theModuleState;
	//初始化当前模块状态为QTSS_Register_Role
	theModuleState.curModule = inModule;
	theModuleState.curRole = QTSS_Register_Role;
	theModuleState.curTask = NULL;
	OSThread::SetMainThreadData(&theModuleState);

	// Currently we do nothing with the module name
	// 初始化该模块所拥有的角色参数
	QTSS_RoleParams theRegParams;
	theRegParams.regParams.outModuleName[0] = 0;

	// If the module returns an error from the QTSS_Register role, don't put it anywhere
	// 回调8.1.2中得到的fDispatchFunc函数指针,并将QTSS_Register_Role和theRegParams
	//做为函数参数传入针对QTSSHomeDirectoryModule和QTSSRefMovieModule两个模块
	//分别会调用QTSSHomeDirectoryDispatch函数和QTSSRefMovieModuleDispatch两个函数
	//a)使用CallDispatch对当前模块进行注册
	//8.1.4
	if (inModule->CallDispatch(QTSS_Register_Role, &theRegParams) != QTSS_NoErr)
		return false;
		
	OSThread::SetMainThreadData (NULL);
	//
	// Add this module to the module queue
	sModuleQueue.EnQueue(inModule->GetQueueElem());

	return true;
}
/**
QTSServer::AddModule函数主要做了两件事
a)使用CallDispatch对当前模块进行注册
b)将当前模块加入到sModuleQueue
**/
8.1.4 使用CallDispatch对当前模块进行注册分析--以QTSSRefMovieModule为列
// Dispatch this module's role call back.
QTSS_Error QTSSRefMovieModuleDispatch(QTSS_Role inRole, QTSS_RoleParamPtr inParams)
{
    switch (inRole)
    {
        case QTSS_Register_Role:
            return Register(&inParams->regParams);
        case QTSS_Initialize_Role:
            return Initialize(&inParams->initParams);
        case QTSS_RereadPrefs_Role:
            return RereadPrefs();
        case QTSS_RTSPFilter_Role:
            return Filter(&inParams->rtspFilterParams);
    }
    return QTSS_NoErr;
}
// Handle the QTSS_Register role call back.
QTSS_Error Register(QTSS_Register_Params* inParams)
{
   // Do role & attribute setup
    (void)QTSS_AddRole(QTSS_Initialize_Role);
    (void)QTSS_AddRole(QTSS_RereadPrefs_Role);
    (void)QTSS_AddRole(QTSS_RTSPFilter_Role);
    
    // Tell the server our name!
    static char* sModuleName = "QTSSRefMovieModule";
    ::strcpy(inParams->outModuleName, sModuleName);

    return QTSS_NoErr;
}
/**
Register函数的作用就是告诉Server该模块要注册那些角色吗?这里需要分析
QTSS_AddRole函数的作用,在分析QTSS_AddRole函数之前我们需要对下面这个结构体
有所了解,该结构体定义在QTSS_Private.h文件当中
**/
typedef QTSS_Error  (*QTSS_CallbackProcPtr)(...);
enum
{
    kAddRoleCallback                = 4,
    kLastCallback                   = 61
};
typedef struct {
    // Callback function pointer array
    QTSS_CallbackProcPtr addr [kLastCallback];
} QTSS_Callbacks, *QTSS_CallbacksPtr;
/**
还记得在8.1中我们对模块进行设置的时候调用QTSS_Error theErr = theNewModule->SetupModule(&sCallbacks);
传入了sCallbacks,其中sCallbacks就是定义在class QTSServer中的静态成员变量static QTSS_Callbacks sCallbacks;
回顾上面的分析我们在SetupModule函数当中我们是不是将sCallbacks赋值到了相应模块的QTSS_PrivateArgs结构所对应
的inCallbacks成员当中去了,由于sCallbacks是静态成员变量那么所有的模块都应该是共享sCallbacks的.恰恰QTSS_Callbacks
结构维护的是一个QTSS_CallbackProcPtr类型的addr函数指针数组,当我们调用AddModule的时候会调用CallDispatch函数
也就是调用对应模块的fDispatchFunc函数,对于每一个模块都必须实现一个xxxxDispatch函数,它就是fDispatchFunc函数的
实现,在fDispatchFunc函数回调过程中首先就是要为其准备函数参数,它需要两个参数一个是QTSS_Role 另一个是 QTSS_RoleParamPtr
默认第一次调用QTSS_Role的值为QTSS_Register_Role,在回到上面的Register函数当中,发现它回调了三个QTSS_AddRole函数
同时传递下去的参数分别为QTSS_Initialize_Role,QTSS_RereadPrefs_Role,QTSS_RTSPFilter_Role,当然这里根据不同的模块
会不尽相同
**/
QTSS_Error  QTSS_AddRole(QTSS_Role inRole)
{
	//这里的sCallbacks就是定义在类QTSServer当中的
	//static QTSS_Callbacks sCallbacks 静态成员变量
    return (sCallbacks->addr [kAddRoleCallback]) (inRole);  
}
/**
我们在这里发现QTSS_AddRole函数回调了sCallbacks所维护的addr数组对应的kAddRoleCallback索引
其实也是调用了一个函数,那么sCallbacks到底在哪里被初始化了呢?在InitModules之前早在
QTSServer::InitCallbacks()函数当中对其进行了初始化工作
**/
QTSS_ServerState StartServer(
	XMLPrefsParser* inPrefsSource, PrefsSource* inMessagesSource,
	UInt16 inPortOverride, int statsUpdateInterval, 
	QTSS_ServerState inInitialState, Bool16 inDontFork,
	UInt32 debugLevel, UInt32 debugOptions)
{
	sServer->Initialize(inPrefsSource, inMessagesSource,
			inPortOverride,createListeners);
}

Bool16 QTSServer::Initialize(XMLPrefsParser* inPrefsSource,
		PrefsSource* inMessagesSource, UInt16 inPortOverride,
		Bool16 createListeners)
{
	this->InitCallbacks();	
}
//这里我们只针对kAddRoleCallback进行分析
void QTSServer::InitCallbacks()
{
	sCallbacks.addr[kAddRoleCallback] =
			(QTSS_CallbackProcPtr) QTSSCallbacks::QTSS_AddRole;
}
//对于上面的QTSS_AddRole函数而言最终就是调用下面这个函数了
QTSS_Error  QTSSCallbacks::QTSS_AddRole(QTSS_Role inRole)
{
    QTSS_ModuleState* theState = (QTSS_ModuleState*)OSThread::GetMainThreadData();
    if (OSThread::GetCurrent() != NULL)
        theState = (QTSS_ModuleState*)OSThread::GetCurrent()->GetThreadData();
        
    // Roles can only be added before modules have had their Initialize role invoked.
	//根据上面的分析此时theState->curRole = QTSS_Register_Role
    if ((theState == NULL) ||  (theState->curRole != QTSS_Register_Role))
        return QTSS_OutOfState;
    
	//那么在这里theState->curModule又是谁？请回到QTSServer::AddModule函数中去看看
	//对于你要注册那个模块那么久对应的是那么模块
	//对于QTSSRefMovieModule而言就是对应的QTSSRefMovieModule
    return theState->curModule->AddRole(inRole);
}
/**
由于各模块都是QTSSModule的派生类所以对应的AddRole方法都是在QTSSModule中被实现
**/
QTSS_Error QTSSModule::AddRole(QTSS_Role inRole) {
	// There can only be one QTSS_RTSPRequest processing module
	if ((inRole == QTSS_RTSPRequest_Role) && (sHasRTSPRequestModule))
		return QTSS_RequestFailed;
	if ((inRole == QTSS_OpenFilePreProcess_Role) && (sHasOpenFileModule))
		return QTSS_RequestFailed;

	//通过GetPrivateRoleIndex返回QTSS_Role对应的ID
	//对应的QTSSRefMovieModule而言在其模块Register的过程中传递进去的分别是
	//QTSS_Initialize_Role,QTSS_RereadPrefs_Role,QTSS_RTSPFilter_Role
	//所以这里也将返回他们
	SInt32 arrayID = GetPrivateRoleIndex(inRole);
	if (arrayID < 0)
		return QTSS_BadArgument;

	//还记得fRoleArray数组吗?这里既然是将该数组对应的索引设置成true就行了
	fRoleArray[arrayID] = true;

	if (inRole == QTSS_RTSPRequest_Role)
		sHasRTSPRequestModule = true;
	if (inRole == QTSS_OpenFile_Role)
		sHasOpenFileModule = true;
	if (inRole == QTSS_RTSPAuthenticate_Role)
		sHasRTSPAuthenticateModule = true;
	//
	// Add this role to the array of roles attribute
	QTSS_Error theErr = this->SetValue(qtssModRoles,
			this->GetNumValues(qtssModRoles), &inRole, sizeof(inRole),
			QTSSDictionary::kDontObeyReadOnly);
	Assert(theErr == QTSS_NoErr);
	return QTSS_NoErr;
}

/**
8.2 LoadCompiledInModules 
*/
void QTSServer::LoadCompiledInModules()
{
	QTSSModule* theFileModule = new QTSSModule("QTSSFileModule");
	(void) theFileModule->SetupModule(&sCallbacks, &QTSSFileModule_Main);
	(void) AddModule(theFileModule);

	QTSSModule* theReflectorModule = new QTSSModule("QTSSReflectorModule");
	(void) theReflectorModule->SetupModule(&sCallbacks,
			&QTSSReflectorModule_Main);
	(void) AddModule(theReflectorModule);

	QTSSModule* theRelayModule = new QTSSModule("QTSSRelayModule");
	(void) theRelayModule->SetupModule(&sCallbacks, &QTSSRelayModule_Main);
	(void) AddModule(theRelayModule);

	QTSSModule* theAccessLog = new QTSSModule("QTSSAccessLogModule");
	(void) theAccessLog->SetupModule(&sCallbacks, &QTSSAccessLogModule_Main);
	(void) AddModule(theAccessLog);

	QTSSModule* theFlowControl = new QTSSModule("QTSSFlowControlModule");
	(void) theFlowControl->SetupModule(&sCallbacks,
			&QTSSFlowControlModule_Main);
	(void) AddModule(theFlowControl);

	QTSSModule* theFileSysModule = new QTSSModule("QTSSPosixFileSysModule");
	(void) theFileSysModule->SetupModule(&sCallbacks,
			&QTSSPosixFileSysModule_Main);
	(void) AddModule(theFileSysModule);

	QTSSModule* theAdminModule = new QTSSModule("QTSSAdminModule");
	(void) theAdminModule->SetupModule(&sCallbacks, &QTSSAdminModule_Main);
	(void) AddModule(theAdminModule);

	QTSSModule* theMP3StreamingModule = new QTSSModule(
			"QTSSMP3StreamingModule");
	(void) theMP3StreamingModule->SetupModule(&sCallbacks,
			&QTSSMP3StreamingModule_Main);
	(void) AddModule(theMP3StreamingModule);



	QTSSModule* theQTACCESSmodule = new QTSSModule("QTSSAccessModule");
	(void) theQTACCESSmodule->SetupModule(&sCallbacks, &QTSSAccessModule_Main);
	(void) AddModule(theQTACCESSmodule);
	

#ifdef PROXYSERVER
	QTSSModule* theProxyModule = new QTSSModule("QTSSProxyModule");
	(void)theProxyModule->SetupModule(&sCallbacks, &QTSSProxyModule_Main);
	(void)AddModule(theProxyModule);
#endif
}
/**
在经过上面的分析后LoadCompiledInModules函数的作用就一目了然了,它就是通过编译源码的方式将
来创建各个模块,同理使用SetupModule对其进行配置以及使用AddModule函数对其进行注册操作
注册成功后对应的QTSSModule::fRoleArray静态成员数组对应的标志位将会变成true.
**/

/**
8.3 什么叫QTSS_Role? 在模块加载阶段每个模块初始化后都会对Server进行注册工作
在注册的过程会调用QTSSModule::AddRole(QTSS_Role inRole)方法来告诉Server
那些Role理应被当前模块支持,先来了解一下和QTSS_Role的数据类型
**/
/********************************************************************/
// QTSS API ROLES
//
// Each role represents a unique situation in which a module may be
// invoked. Modules must specify which roles they want to be invoked for. 
// QTSS.h
enum
{
    //Global
    //reg  //All modules get this once at startup
    QTSS_Register_Role =             FOUR_CHARS_TO_INT('r', 'e', 'g', ' '), 
    //init //Gets called once, later on in the startup process
    QTSS_Initialize_Role =           FOUR_CHARS_TO_INT('i', 'n', 'i', 't'), 
    //shut //Gets called once at shutdown
    QTSS_Shutdown_Role =             FOUR_CHARS_TO_INT('s', 'h', 'u', 't'), 
    //elog //This gets called when the server wants to log an error.
    QTSS_ErrorLog_Role =             FOUR_CHARS_TO_INT('e', 'l', 'o', 'g'), 
    //pref //This gets called when the server rereads preferences.
    QTSS_RereadPrefs_Role =          FOUR_CHARS_TO_INT('p', 'r', 'e', 'f'), 
    //stat //This gets called whenever the server changes state.
    QTSS_StateChange_Role =          FOUR_CHARS_TO_INT('s', 't', 'a', 't'), 
    //timr //This gets called whenever the module's interval timer times out calls.
    QTSS_Interval_Role =             FOUR_CHARS_TO_INT('t', 'i', 'm', 'r'), 
    
    //RTSP-specific
    //filt //Filter all RTSP requests before the server parses them
    QTSS_RTSPFilter_Role =           FOUR_CHARS_TO_INT('f', 'i', 'l', 't'), 
    //rout //Route all RTSP requests to the correct root folder.
    QTSS_RTSPRoute_Role =            FOUR_CHARS_TO_INT('r', 'o', 'u', 't'), 
    //athn //Authenticate the RTSP request username.
    QTSS_RTSPAuthenticate_Role =     FOUR_CHARS_TO_INT('a', 't', 'h', 'n'), 
    //auth //Authorize RTSP requests to proceed
    QTSS_RTSPAuthorize_Role =        FOUR_CHARS_TO_INT('a', 'u', 't', 'h'), 
    //prep //Pre-process all RTSP requests before the server responds.
    QTSS_RTSPPreProcessor_Role =     FOUR_CHARS_TO_INT('p', 'r', 'e', 'p'), 
    //Modules may opt to "steal" the request and return a client response.
    //requ //Process an RTSP request & send client response
    QTSS_RTSPRequest_Role =          FOUR_CHARS_TO_INT('r', 'e', 'q', 'u'), 
    //post //Post-process all RTSP requests
    QTSS_RTSPPostProcessor_Role =    FOUR_CHARS_TO_INT('p', 'o', 's', 't'), 
    //sesc //RTSP session is going away
    QTSS_RTSPSessionClosing_Role =   FOUR_CHARS_TO_INT('s', 'e', 's', 'c'), 
    //icmd //Incoming interleaved RTP data on this RTSP connection
    QTSS_RTSPIncomingData_Role =     FOUR_CHARS_TO_INT('i', 'c', 'm', 'd'), 

    //RTP-specific
    //send //Send RTP packets to the client
    QTSS_RTPSendPackets_Role =           FOUR_CHARS_TO_INT('s', 'e', 'n', 'd'), 
    //dess //Client session is going away
    QTSS_ClientSessionClosing_Role =     FOUR_CHARS_TO_INT('d', 'e', 's', 's'), 
    
    //RTCP-specific
    //rtcp //Process all RTCP packets sent to the server
    QTSS_RTCPProcess_Role =          FOUR_CHARS_TO_INT('r', 't', 'c', 'p'), 

    //File system roles
    //oppr
    QTSS_OpenFilePreProcess_Role =  FOUR_CHARS_TO_INT('o', 'p', 'p', 'r'),  
    //opfl
    QTSS_OpenFile_Role =            FOUR_CHARS_TO_INT('o', 'p', 'f', 'l'),  
    //adfl
    QTSS_AdviseFile_Role =          FOUR_CHARS_TO_INT('a', 'd', 'f', 'l'),  
    //rdfl
    QTSS_ReadFile_Role =            FOUR_CHARS_TO_INT('r', 'd', 'f', 'l'),  
    //clfl
    QTSS_CloseFile_Role =           FOUR_CHARS_TO_INT('c', 'l', 'f', 'l'),  
    //refl
    QTSS_RequestEventFile_Role =    FOUR_CHARS_TO_INT('r', 'e', 'f', 'l'),  
    
};
typedef UInt32 QTSS_Role;
/**
在QTSS中上面的联合体来表示QTSS_Role
**/
class QTSSModule: public QTSSDictionary, public Task {
public:
	//convert QTSS.h 4 char id roles to private role index
	SInt32 GetPrivateRoleIndex(QTSS_Role apiRole);
	// These enums allow roles to be stored in a more optimized way
	// add new RoleNames to sRoleNames in QTSSModule.cpp for debugging
	enum {
		kInitializeRole = 0,
		kShutdownRole = 1,
		kRTSPFilterRole = 2,
		kRTSPRouteRole = 3,
		kRTSPAthnRole = 4,
		kRTSPAuthRole = 5,
		kRTSPPreProcessorRole = 6,
		kRTSPRequestRole = 7,
		kRTSPPostProcessorRole = 8,
		kRTSPSessionClosingRole = 9,
		kRTPSendPacketsRole = 10,
		kClientSessionClosingRole = 11,
		kRTCPProcessRole = 12,
		kErrorLogRole = 13,
		kRereadPrefsRole = 14,
		kOpenFileRole = 15,
		kOpenFilePreProcessRole = 16,
		kAdviseFileRole = 17,
		kReadFileRole = 18,
		kCloseFileRole = 19,
		kRequestEventFileRole = 20,
		kRTSPIncomingDataRole = 21,
		kStateChangeRole = 22,
		kTimedIntervalRole = 23,

		kNumRoles = 24
	};
	typedef UInt32 RoleIndex;

	// Call this to activate this module in the specified role.
	QTSS_Error AddRole(QTSS_Role inRole);

	// This returns true if this module is supposed to run in the specified role.
	Bool16 RunsInRole(RoleIndex inIndex) {
		return fRoleArray[inIndex];
	}
private:
	Bool16 fRoleArray[kNumRoles];
};
/**
在QTSSModule中用fRoleArray数组来记录当前模块支持那些Role,对于每一种Role在QTSSModule
中定义了一个enum枚举来和fRoleArray数组中的每一个索引一一对应,对应支持的Role在
fRoleArray数组中对应的索引将会标识成true.另外使用GetPrivateRoleIndex函数来将
QTSSModule类中定义的枚举和QTSS.h文件中定义的Role枚举一一进行映射,目前系统
默认一共支持24种Role
**/
/**
8.3 BuildModuleRoleArrays函数分析
在分析BuildModuleRoleArrays函数之前先看看在QTSServerInterface
类中定义的sModuleArray以及sNumModulesInRole
**/
class QTSServerInterface: public QTSSDictionary
{
protected:
	//
	// MODULE DATA
	static QTSSModule** sModuleArray[QTSSModule::kNumRoles];
	static UInt32 sNumModulesInRole[QTSSModule::kNumRoles];
	static OSQueue sModuleQueue;
};
/**
sModuleArray是一个QTSSModule*类型的二维数组,QTSSModule目前支持24种Roles
这里sModuleArray二维数组用于记录对于24种Roles类型当中每一种类型的Roles
拥有多少个QTSSModule模块,并将每一个QTSSModule指针记录在该二维数组当中,
而sNumModulesInRole数组用于记录每一种类型的Roles拥有多少数量模块的数量
**/
void QTSServer::BuildModuleRoleArrays()
{
	OSQueueIter theIter(&sModuleQueue);
	QTSSModule* theModule = NULL;

	// Make sure these variables are cleaned out in case they've already been inited.
	// 先清除sModuleArray和sNumModulesInRole数组
	DestroyModuleRoleArrays();

	// Loop through all the roles of all the modules, recording the number of
	// modules in each role, and also recording which modules are doing what.
	// 遍历sModuleQueue队列中的每一个元素,还记得sModuleQueue吗？
	// 每一个模块可看成一个OSQueueElem然后在注册模块的时候会将自身加入
	// 到sModuleQueue队列
	for (UInt32 x = 0; x < QTSSModule::kNumRoles; x++) {
	    //首先将每一种类型的Role所关联的模块数量计为0个
		sNumModulesInRole[x] = 0;
		for (theIter.Reset();
			!theIter.IsDone(); theIter.Next()) {
			theModule =
					(QTSSModule*) 
					theIter.GetCurrent()->GetEnclosingObject();
			//如果遍历出来的QTSSModule注册了x对应的Role那么将
			//sNumModulesInRole[x]+1,这里就是将计数加1,表示
			//该类型的Role所关联的模块数量加1
			if (theModule->RunsInRole(x))
				sNumModulesInRole[x] += 1;
		}
        //如果x类型的Role所关联的模块数量大于0
		if (sNumModulesInRole[x] > 0) {
			UInt32 moduleIndex = 0;
			//为sModuleArray[x]分配sNumModulesInRole[x] + 1大小的空间
			//假设这里x类型的Role关联了10个模块,那么这里就要分配11个大小
			//的QTSSModule给sModuleArray[x]
			sModuleArray[x] = new QTSSModule*[sNumModulesInRole[x] + 1];
			//再次对队列进行遍历,然后对满足条件的元素(也就是说该模块和x对应的Role有关联)
			//将其记录到sModuleArray[x][moduleIndex]当中
			//sModuleArray是一个二维数组
			for (theIter.Reset(); !theIter.IsDone();
			     theIter.Next()) {
				theModule =
						(QTSSModule*) 
						theIter.GetCurrent()->GetEnclosingObject();
				if (theModule->RunsInRole(x)) {
					sModuleArray[x][moduleIndex] = theModule;
					moduleIndex++;
				}
			}
		}
	}
}
/**
BuildModuleRoleArrays函数的工作就是将各大模块按照Role类型将各模块
记录到sModuleArray二维数组当中
**/
void QTSServer::DoInitRole()
{
	QTSS_RoleParams theInitParams;
	theInitParams.initParams.inServer = this;
	theInitParams.initParams.inPrefs = fSrvrPrefs;
	theInitParams.initParams.inMessages = fSrvrMessages;
	theInitParams.initParams.inErrorLogStream = &sErrorLogStream;

	QTSS_ModuleState theModuleState;
	theModuleState.curRole = QTSS_Initialize_Role;
	theModuleState.curTask = NULL;
	OSThread::SetMainThreadData(&theModuleState);

	//
	// Add the OPTIONS method as the one method the server handles by default (it handles
	// it internally). Modules that handle other RTSP methods will add
	QTSS_RTSPMethod theOptionsMethod = qtssOptionsMethod;
	(void) this->SetValue(qtssSvrHandledMethods, 0, &theOptionsMethod,
			sizeof(theOptionsMethod));

// For now just disable the SetParameter to be compatible with Real.  It should really be removed only for clients that have problems with their SetParameter implementations like (Real Players).
// At the moment it isn't necesary to add the option.
//   QTSS_RTSPMethod	theSetParameterMethod = qtssSetParameterMethod;
//    (void)this->SetValue(qtssSvrHandledMethods, 0, &theSetParameterMethod, sizeof(theSetParameterMethod));

	for (UInt32 x = 0;
			x
					< QTSServerInterface::GetNumModulesInRole(
							QTSSModule::kInitializeRole); x++)
	{
		QTSSModule* theModule = QTSServerInterface::GetModule(
				QTSSModule::kInitializeRole, x);
		theInitParams.initParams.inModule = theModule;
		theModuleState.curModule = theModule;
		QTSS_Error theErr = theModule->CallDispatch(QTSS_Initialize_Role,
				&theInitParams);

		if (theErr != QTSS_NoErr)
		{
			// If the module reports an error when initializing itself,
			// delete the module and pretend it was never there.
			QTSSModuleUtils::LogError(qtssWarningVerbosity, qtssMsgInitFailed,
					theErr, theModule->GetValue(qtssModName)->Ptr);

			sModuleQueue.Remove(theModule->GetQueueElem());
			delete theModule;
		}
	}
	this->SetupPublicHeader();

	OSThread::SetMainThreadData (NULL);
}

