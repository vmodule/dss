

/**
��socket thread����֮ǰ,��Ҫ�ȳ�ʼ��ģ��,
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
��StartServer�����лص�QTSServer::InitModules�����ز���ʼ��ģ��
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
8.1 LoadModules��ָ��·������ģ��,Ĭ��ָ��·��������streamingserver.xml�ļ����ж�������:
<PREF NAME="module_folder">/usr/local/sbin/StreamingServerModules</PREF>
Ĭ�ϱ�������ڰ�װ�ļ������ǿ��Կ���StreamingServerModulesĿ¼,��Ŀ¼��Ĭ���������������ļ�
�ֱ�ΪQTSSHomeDirectoryModule��QTSSRefMovieModule����ģ��,����������LoadModules����
**/
void QTSServer::LoadModules(QTSServerPrefs* inPrefs)
{
	// Fetch the name of the module directory and open it.
	// ������Ǹ���/usr/local/sbin/StreamingServerModules������
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
LoadModules�������Ǹ���ָ����StreamingServerModules·��,������Ϊ/usr/local/sbin/StreamingServerModules
ȥѭ����ȡ��Ŀ¼,Ȼ����ݸ�Ŀ¼�µ�Դ�ļ������ִ����ص�CreateModule������ģ��,Ĭ������¸�Ŀ¼����
QTSSHomeDirectoryModule��QTSSRefMovieModule����ģ��,�ٷ���CreateModule������ʵ��
**/
void QTSServer::CreateModule(char* inModuleFolderPath, char* inModuleName)
{
	//
	// Construct a full path to this module
	//����ȫ·����:/usr/local/sbin/StreamingServerModules/QTSSRefMovieModule
	UInt32 totPathLen = ::strlen(inModuleFolderPath) + ::strlen(inModuleName);
	OSCharArrayDeleter theModPath(NEW char[totPathLen + 4]);
	
	::strcpy(theModPath.GetObject(), inModuleFolderPath);
	::strcat(theModPath.GetObject(), kPathDelimiterString);
	::strcat(theModPath.GetObject(), inModuleName);

	//
	// Construct a QTSSModule object, and attempt to initialize the module
	// 8.1.1 ����ģ��·����Ϣ����QTSSModuleʵ��
	QTSSModule* theNewModule = NEW 
						QTSSModule(inModuleName, theModPath.GetObject());
	
	// 8.1.2 ����QTSSModule
	QTSS_Error theErr = theNewModule->SetupModule(&sCallbacks);

	if (theErr != QTSS_NoErr)
	{
		QTSSModuleUtils::LogError(qtssWarningVerbosity, qtssMsgBadModule,
				theErr, inModuleName);
		delete theNewModule;
	}
	// 8.1.3 ���ոչ����QTSSModule��ӵ��ģ�
	// If the module was successfully initialized, add it to our module queue
	else if (!this->AddModule(theNewModule))
	{
		QTSSModuleUtils::LogError(qtssWarningVerbosity, qtssMsgRegFailed,
				theErr, inModuleName);
		delete theNewModule;
	}
}
/**
QTSServer::CreateModule�ֳ�3����ɶ�ģ��ļ��غͳ�ʼ������
8.1.1)����ģ��·����Ϣ����QTSSModuleʵ��
8.1.2)����QTSSModule
8.1.3)����ʼ���õ�QTSSModule��ӵ��ģ�
**/

/*
8.1.1 ����ģ��·����Ϣ����QTSSModuleʵ��	
*/
QTSSModule::QTSSModule(char* inName, char* inPath) 
	: QTSSDictionary(QTSSDictionaryMap::GetMap(QTSSDictionaryMap::kModuleDictIndex))
	, fQueueElem(NULL)
	, fPath(NULL)
	, fFragment(NULL)
	, fDispatchFunc(NULL)
	, fPrefs(NULL)
	, fAttributes(NULL) {
	
	//ÿһ��QTSSModule�����Կ���һ��fQueueElem,Ҳ���Ƕ���Ԫ��
	fQueueElem.SetEnclosingObject(this);
	this->SetTaskName("QTSSModule");
	if ((inPath != NULL) && (inPath[0] != '\0')) {
		// Create a code fragment if this module is being loaded from disk
		fFragment = NEW OSCodeFragment(inPath);
		fPath = NEW char[::strlen(inPath) + 2];
		::strcpy(fPath, inPath);
		//�������ģ���ȫ·������OSCodeFragment
	}

	fAttributes = NEW QTSSDictionary(NULL, &fAttributesMutex);

	this->SetVal(qtssModPrefs, &fPrefs, sizeof(fPrefs));
	this->SetVal(qtssModAttributes, &fAttributes, sizeof(fAttributes));

	// If there is a name, copy it into the module object's internal buffer
	if (inName != NULL)
		this->SetValue(qtssModName, 0, inName, ::strlen(inName),
				QTSSDictionary::kDontObeyReadOnly);

	//��ʼ��fRoleArray,��ʼ��fModuleState
	//ÿһ��ģ��Ӧ��ӵ�кܶ��moduleRole
	::memset(fRoleArray, 0, sizeof(fRoleArray));
	::memset(&fModuleState, 0, sizeof(fModuleState));
}
/**
��QTSSModule���캯��������Ҫ�����Ǹ���ģ��ȫ·������OSCodeFragment
����OSCodeFragment�Ĺ�������л����ݴ����·���ص�dlopen��������ģ��һ
��̬�������ʽ��,��󽫴򿪺󷵻صľ�����浽OSCodeFragment::fFragmentP
��������OSCodeFragment��Ķ����ʵ��
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
ͨ������GetSymbol������ģ���еĺ������ƾͿ���ʹ��ģ���ж���ķ���
**/

/**
8.1.2 ����QTSSModule
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
QTSSModule::SetupModule�ֳ�3��
a).���ڴ�ָ��·�����ص�ģ�������ڻص�SetupModule������ʱ��ֻ������sCallbacks����
	inEntrypointĬ��ΪNULL�����������ʹ��LoadFromDisk����ΪinEntrypoint��ֵ
	Ҳ���ǵõ���ģ���main����,��Ӧ��QTSSHomeDirectoryModule��QTSSRefMovieModule����ģ��
	���Ծ��Ƿֱ�õ�QTSSHomeDirectoryModule_Main��QTSSRefMovieModule_Main�����������
b) �õ�ģ��ĺ�����ں���ҪΪmain����׼�������β�,�������ʼ��QTSS_PrivateArgs�ṹ����Ϊ
	QTSSHomeDirectoryModule_Main��QTSSRefMovieModule_Main���������Ĳ���
c) ����ÿһ��ģ�������QTSSModule��������,��QTSSModule�ж�����һ����Ա����
	QTSS_DispatchFuncPtr fDispatchFunc;������thePrivateArgs.outDispatchFunction��ֵ��
	fDispatchFunc
	����LoadFromDisk������ʵ������:
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
	
	//��ʱtheSymbolName��ֵΪQTSSRefMovieModule_Main��QTSSHomeDirectoryModule_Main
	*outEntrypoint = (QTSS_MainEntryPointPtr) fFragment->GetSymbol(
			theSymbolName.GetObject());
	//����fFragment->GetSymbol�ص�����8.1.2�е�fDispatchFuncֵ�ͻᱻ��ֵ��
	//���QTSSRefMovieModule_Main�����������Ļص���������
	return QTSS_NoErr;
}

QTSS_Error QTSSHomeDirectoryModule_Main(void* inPrivateArgs)
{
    return _stublibrary_main(inPrivateArgs, QTSSHomeDirectoryDispatch);
}
/**
inPrivateArgsΪ8.1.2�г�ʼ����thePrivateArgs����,�ڻص�QTSSHomeDirectoryModule_Main����ǰ
����thePrivateArgs����outDispatchFunction��Ա��������ʼ����NULL,�����ڵ���_stublibrary_main
������outDispatchFunction��Ա��������ֵ��QTSSHomeDirectoryDispatch�ˡ�_stublibrary_main
����ʵ������:
**/
//sCallbacks ������ķ����н��޴�����,��ʵ�������Ƕ�������QTSServer���е�
//static QTSS_Callbacks sCallbacks ��̬��Ա����
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
8.1.3 ���ոչ����QTSSModule��ӵ��ģ���ӵ�һ������sModuleQueue�Ķ���
��ѧϰ֮AddModule����֮ǰ����������ʶһ��ǰ������QTSS_Private.h�ļ�����
�����������ṹ��
**/

typedef struct
{
    UInt32                  inServerAPIVersion;
    QTSS_CallbacksPtr       inCallbacks;//ģ��ص�����ָ��ṹ
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
��������QTSServer::AddModule��Ҫ����CallDispatchҲ���ǵ���fDispatchFunc��ʱ��
����Ҫ��������������,��ô��Ҫ�����������������������������ָ��,����������ʲô����
�ں���ķ���������������,��������ֻ�Ƕ����ǻ������
**/
Bool16 QTSServer::AddModule(QTSSModule* inModule)
{
	Assert(inModule->IsInitialized());//���fDispatchFuncΪ����ִ������ĳ���

	// Prepare to invoke the module's Register role. Setup the Register param block
	QTSS_ModuleState theModuleState;
	//��ʼ����ǰģ��״̬ΪQTSS_Register_Role
	theModuleState.curModule = inModule;
	theModuleState.curRole = QTSS_Register_Role;
	theModuleState.curTask = NULL;
	OSThread::SetMainThreadData(&theModuleState);

	// Currently we do nothing with the module name
	// ��ʼ����ģ����ӵ�еĽ�ɫ����
	QTSS_RoleParams theRegParams;
	theRegParams.regParams.outModuleName[0] = 0;

	// If the module returns an error from the QTSS_Register role, don't put it anywhere
	// �ص�8.1.2�еõ���fDispatchFunc����ָ��,����QTSS_Register_Role��theRegParams
	//��Ϊ���������������QTSSHomeDirectoryModule��QTSSRefMovieModule����ģ��
	//�ֱ�����QTSSHomeDirectoryDispatch������QTSSRefMovieModuleDispatch��������
	//a)ʹ��CallDispatch�Ե�ǰģ�����ע��
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
QTSServer::AddModule������Ҫ����������
a)ʹ��CallDispatch�Ե�ǰģ�����ע��
b)����ǰģ����뵽sModuleQueue
**/
8.1.4 ʹ��CallDispatch�Ե�ǰģ�����ע�����--��QTSSRefMovieModuleΪ��
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
Register���������þ��Ǹ���Server��ģ��Ҫע����Щ��ɫ��?������Ҫ����
QTSS_AddRole����������,�ڷ���QTSS_AddRole����֮ǰ������Ҫ����������ṹ��
�����˽�,�ýṹ�嶨����QTSS_Private.h�ļ�����
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
���ǵ���8.1�����Ƕ�ģ��������õ�ʱ�����QTSS_Error theErr = theNewModule->SetupModule(&sCallbacks);
������sCallbacks,����sCallbacks���Ƕ�����class QTSServer�еľ�̬��Ա����static QTSS_Callbacks sCallbacks;
�ع�����ķ���������SetupModule�������������ǲ��ǽ�sCallbacks��ֵ������Ӧģ���QTSS_PrivateArgs�ṹ����Ӧ
��inCallbacks��Ա����ȥ��,����sCallbacks�Ǿ�̬��Ա������ô���е�ģ�鶼Ӧ���ǹ���sCallbacks��.ǡǡQTSS_Callbacks
�ṹά������һ��QTSS_CallbackProcPtr���͵�addr����ָ������,�����ǵ���AddModule��ʱ������CallDispatch����
Ҳ���ǵ��ö�Ӧģ���fDispatchFunc����,����ÿһ��ģ�鶼����ʵ��һ��xxxxDispatch����,������fDispatchFunc������
ʵ��,��fDispatchFunc�����ص����������Ⱦ���ҪΪ��׼����������,����Ҫ��������һ����QTSS_Role ��һ���� QTSS_RoleParamPtr
Ĭ�ϵ�һ�ε���QTSS_Role��ֵΪQTSS_Register_Role,�ڻص������Register��������,�������ص�������QTSS_AddRole����
ͬʱ������ȥ�Ĳ����ֱ�ΪQTSS_Initialize_Role,QTSS_RereadPrefs_Role,QTSS_RTSPFilter_Role,��Ȼ������ݲ�ͬ��ģ��
�᲻����ͬ
**/
QTSS_Error  QTSS_AddRole(QTSS_Role inRole)
{
	//�����sCallbacks���Ƕ�������QTSServer���е�
	//static QTSS_Callbacks sCallbacks ��̬��Ա����
    return (sCallbacks->addr [kAddRoleCallback]) (inRole);  
}
/**
���������﷢��QTSS_AddRole�����ص���sCallbacks��ά����addr�����Ӧ��kAddRoleCallback����
��ʵҲ�ǵ�����һ������,��ôsCallbacks���������ﱻ��ʼ������?��InitModules֮ǰ����
QTSServer::InitCallbacks()�������ж�������˳�ʼ������
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
//��������ֻ���kAddRoleCallback���з���
void QTSServer::InitCallbacks()
{
	sCallbacks.addr[kAddRoleCallback] =
			(QTSS_CallbackProcPtr) QTSSCallbacks::QTSS_AddRole;
}
//���������QTSS_AddRole�����������վ��ǵ����������������
QTSS_Error  QTSSCallbacks::QTSS_AddRole(QTSS_Role inRole)
{
    QTSS_ModuleState* theState = (QTSS_ModuleState*)OSThread::GetMainThreadData();
    if (OSThread::GetCurrent() != NULL)
        theState = (QTSS_ModuleState*)OSThread::GetCurrent()->GetThreadData();
        
    // Roles can only be added before modules have had their Initialize role invoked.
	//��������ķ�����ʱtheState->curRole = QTSS_Register_Role
    if ((theState == NULL) ||  (theState->curRole != QTSS_Register_Role))
        return QTSS_OutOfState;
    
	//��ô������theState->curModule����˭����ص�QTSServer::AddModule������ȥ����
	//������Ҫע���Ǹ�ģ����ô�ö�Ӧ������ôģ��
	//����QTSSRefMovieModule���Ծ��Ƕ�Ӧ��QTSSRefMovieModule
    return theState->curModule->AddRole(inRole);
}
/**
���ڸ�ģ�鶼��QTSSModule�����������Զ�Ӧ��AddRole����������QTSSModule�б�ʵ��
**/
QTSS_Error QTSSModule::AddRole(QTSS_Role inRole) {
	// There can only be one QTSS_RTSPRequest processing module
	if ((inRole == QTSS_RTSPRequest_Role) && (sHasRTSPRequestModule))
		return QTSS_RequestFailed;
	if ((inRole == QTSS_OpenFilePreProcess_Role) && (sHasOpenFileModule))
		return QTSS_RequestFailed;

	//ͨ��GetPrivateRoleIndex����QTSS_Role��Ӧ��ID
	//��Ӧ��QTSSRefMovieModule��������ģ��Register�Ĺ����д��ݽ�ȥ�ķֱ���
	//QTSS_Initialize_Role,QTSS_RereadPrefs_Role,QTSS_RTSPFilter_Role
	//��������Ҳ����������
	SInt32 arrayID = GetPrivateRoleIndex(inRole);
	if (arrayID < 0)
		return QTSS_BadArgument;

	//���ǵ�fRoleArray������?�����Ȼ�ǽ��������Ӧ���������ó�true������
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
�ھ�������ķ�����LoadCompiledInModules���������þ�һĿ��Ȼ��,������ͨ������Դ��ķ�ʽ��
����������ģ��,ͬ��ʹ��SetupModule������������Լ�ʹ��AddModule�����������ע�����
ע��ɹ����Ӧ��QTSSModule::fRoleArray��̬��Ա�����Ӧ�ı�־λ������true.
**/

/**
8.3 ʲô��QTSS_Role? ��ģ����ؽ׶�ÿ��ģ���ʼ���󶼻��Server����ע�Ṥ��
��ע��Ĺ��̻����QTSSModule::AddRole(QTSS_Role inRole)����������Server
��ЩRole��Ӧ����ǰģ��֧��,�����˽�һ�º�QTSS_Role����������
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
��QTSS�����������������ʾQTSS_Role
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
��QTSSModule����fRoleArray��������¼��ǰģ��֧����ЩRole,����ÿһ��Role��QTSSModule
�ж�����һ��enumö������fRoleArray�����е�ÿһ������һһ��Ӧ,��Ӧ֧�ֵ�Role��
fRoleArray�����ж�Ӧ�����������ʶ��true.����ʹ��GetPrivateRoleIndex��������
QTSSModule���ж����ö�ٺ�QTSS.h�ļ��ж����Roleö��һһ����ӳ��,Ŀǰϵͳ
Ĭ��һ��֧��24��Role
**/
/**
8.3 BuildModuleRoleArrays��������
�ڷ���BuildModuleRoleArrays����֮ǰ�ȿ�����QTSServerInterface
���ж����sModuleArray�Լ�sNumModulesInRole
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
sModuleArray��һ��QTSSModule*���͵Ķ�ά����,QTSSModuleĿǰ֧��24��Roles
����sModuleArray��ά�������ڼ�¼����24��Roles���͵���ÿһ�����͵�Roles
ӵ�ж��ٸ�QTSSModuleģ��,����ÿһ��QTSSModuleָ���¼�ڸö�ά���鵱��,
��sNumModulesInRole�������ڼ�¼ÿһ�����͵�Rolesӵ�ж�������ģ�������
**/
void QTSServer::BuildModuleRoleArrays()
{
	OSQueueIter theIter(&sModuleQueue);
	QTSSModule* theModule = NULL;

	// Make sure these variables are cleaned out in case they've already been inited.
	// �����sModuleArray��sNumModulesInRole����
	DestroyModuleRoleArrays();

	// Loop through all the roles of all the modules, recording the number of
	// modules in each role, and also recording which modules are doing what.
	// ����sModuleQueue�����е�ÿһ��Ԫ��,���ǵ�sModuleQueue��
	// ÿһ��ģ��ɿ���һ��OSQueueElemȻ����ע��ģ���ʱ��Ὣ�������
	// ��sModuleQueue����
	for (UInt32 x = 0; x < QTSSModule::kNumRoles; x++) {
	    //���Ƚ�ÿһ�����͵�Role��������ģ��������Ϊ0��
		sNumModulesInRole[x] = 0;
		for (theIter.Reset();
			!theIter.IsDone(); theIter.Next()) {
			theModule =
					(QTSSModule*) 
					theIter.GetCurrent()->GetEnclosingObject();
			//�������������QTSSModuleע����x��Ӧ��Role��ô��
			//sNumModulesInRole[x]+1,������ǽ�������1,��ʾ
			//�����͵�Role��������ģ��������1
			if (theModule->RunsInRole(x))
				sNumModulesInRole[x] += 1;
		}
        //���x���͵�Role��������ģ����������0
		if (sNumModulesInRole[x] > 0) {
			UInt32 moduleIndex = 0;
			//ΪsModuleArray[x]����sNumModulesInRole[x] + 1��С�Ŀռ�
			//��������x���͵�Role������10��ģ��,��ô�����Ҫ����11����С
			//��QTSSModule��sModuleArray[x]
			sModuleArray[x] = new QTSSModule*[sNumModulesInRole[x] + 1];
			//�ٴζԶ��н��б���,Ȼ�������������Ԫ��(Ҳ����˵��ģ���x��Ӧ��Role�й���)
			//�����¼��sModuleArray[x][moduleIndex]����
			//sModuleArray��һ����ά����
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
BuildModuleRoleArrays�����Ĺ������ǽ�����ģ�鰴��Role���ͽ���ģ��
��¼��sModuleArray��ά���鵱��
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

