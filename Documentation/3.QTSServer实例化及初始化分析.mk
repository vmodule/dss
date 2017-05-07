/**
分析完DSS QTSDictionary数据结构后,对DSS的数据存储有了一个初步的了解
接下来分析在StartServer函数中对QTSServer的实例化以及初始化过程
**/
QTSS_ServerState StartServer(
	XMLPrefsParser* inPrefsSource, PrefsSource* inMessagesSource,
	UInt16 inPortOverride, int statsUpdateInterval, 
	QTSS_ServerState inInitialState, Bool16 inDontFork,
	UInt32 debugLevel, UInt32 debugOptions) {
    QTSServerInterface::Initialize();
    sServer = NEW QTSServer();
    sServer->SetDebugLevel(debugLevel);
    sServer->SetDebugOptions(debugOptions);
    sServer->Initialize(inPrefsSource, inMessagesSource, 
        inPortOverride,createListeners);

}
/*QTSServer是QTSServerInterface的子类,同时QTSServerInterface又是QTSSDictionary的子类
在StartServer函数中首先对QTSServerInterface进行初始化然后再创建QTSServer实例
先看QTSServerInterface的定义再看它的Initialize函数
*/
class QTSServerInterface : public QTSSDictionary
{
public:
    //Initialize must be called right off the bat to initialize dictionary resources
    static void Initialize();
    QTSServerInterface();
    virtual ~QTSServerInterface() {}
private:    
    static QTSServerInterface*  sServer;
    static QTSSAttrInfoDict::AttrInfo   sAttributes[]; 
    static QTSSAttrInfoDict::AttrInfo   sConnectedUserAttributes[];       
};     
/*
3.1.QTSServerInterface Initialize分析
*/
void QTSServerInterface::Initialize()
{
    for (UInt32 x = 0; x < qtssSvrNumParams; x++)
        QTSSDictionaryMap::GetMap(QTSSDictionaryMap::kServerDictIndex)->
            SetAttribute(x, sAttributes[x].fAttrName, sAttributes[x].fFuncPtr,
                sAttributes[x].fAttrDataType, sAttributes[x].fAttrPermission);

    for (UInt32 y = 0; y < qtssConnectionNumParams; y++)
        QTSSDictionaryMap::GetMap(QTSSDictionaryMap::kQTSSConnectedUserDictIndex)->
            SetAttribute(y, sConnectedUserAttributes[y].fAttrName, sConnectedUserAttributes[y].fFuncPtr,
                sConnectedUserAttributes[y].fAttrDataType, sConnectedUserAttributes[y].fAttrPermission);
}
/**
该函数主要做了两件事,首先就是使用SetAttribute对kServerDictIndex部件对应的QTSSDictionaryMap
所对应的每一个QTSSAttrInfoDict使用SetAttribute进行相应的初始化配置,其次是对kQTSSConnectedUserDictIndex
部件对应的QTSSDictionaryMap所对应的每一个QTSSAttrInfoDict使用SetAttribute进行相应的配置,
SetAttribute函数在上一篇文中已经做出分析,这里也发现了对于每一个QTSSDictionaryMap都将定义一个相应的静态的
QTSSAttrInfoDict::AttrInfo数组对其对应的属性树对应的数据结构进行相应的初始化工作,比如说在这里QTSSAttrInfoDict::AttrInfo
对应kServerDictIndex,而sConnectedUserAttributes对应的是kQTSSConnectedUserDictIndex
**/
/*
3.2.QTSServer构造过程
QTSServerInterface::Initialize()函数成功后会构造QTSServer
*/
class QTSServer : public QTSServerInterface
{
public:
    QTSServer() {}
    virtual ~QTSServer();
    Bool16 Initialize(
        XMLPrefsParser* inPrefsSource,
        PrefsSource* inMessagesSource,
        UInt16 inPortOverride, Bool16 createListeners);
    
};
/*
QTSServer的构造函数十分简单,但因为它是QTSServerInterface的子类所以QTSServerInterface
也将被构造,而在3.1中只是对它的静态成员属性进行了初始化配置,QTSServerInterface的构造函数
如下:
*/
QTSServerInterface::QTSServerInterface()
 :  QTSSDictionary(QTSSDictionaryMap::GetMap(QTSSDictionaryMap::kServerDictIndex),
     &fMutex),
{
    for (UInt32 y = 0; y < QTSSModule::kNumRoles; y++)
    {
        sModuleArray[y] = NULL;
        sNumModulesInRole[y] = 0;
    }

    this->SetVal(qtssSvrState,              &fServerState,              sizeof(fServerState));
    this->SetVal(qtssServerAPIVersion,      &sServerAPIVersion,         sizeof(sServerAPIVersion));
    this->SetVal(qtssSvrDefaultIPAddr,      &fDefaultIPAddr,            sizeof(fDefaultIPAddr));
    this->SetVal(qtssSvrServerName,         sServerNameStr.Ptr,         sServerNameStr.Len);
    this->SetVal(qtssSvrServerVersion,      sServerVersionStr.Ptr,      sServerVersionStr.Len);
    this->SetVal(qtssSvrServerBuildDate,    sServerBuildDateStr.Ptr,    sServerBuildDateStr.Len);
    this->SetVal(qtssSvrRTSPServerHeader,   sServerHeaderPtr.Ptr,       sServerHeaderPtr.Len);
    this->SetVal(qtssRTSPCurrentSessionCount, &fNumRTSPSessions,        sizeof(fNumRTSPSessions));
    this->SetVal(qtssRTSPHTTPCurrentSessionCount, &fNumRTSPHTTPSessions,sizeof(fNumRTSPHTTPSessions));
    this->SetVal(qtssRTPSvrCurConn,         &fNumRTPSessions,           sizeof(fNumRTPSessions));
    this->SetVal(qtssRTPSvrTotalConn,       &fTotalRTPSessions,         sizeof(fTotalRTPSessions));
    this->SetVal(qtssRTPSvrCurBandwidth,    &fCurrentRTPBandwidthInBits,sizeof(fCurrentRTPBandwidthInBits));
    this->SetVal(qtssRTPSvrTotalBytes,      &fTotalRTPBytes,            sizeof(fTotalRTPBytes));
    this->SetVal(qtssRTPSvrAvgBandwidth,    &fAvgRTPBandwidthInBits,    sizeof(fAvgRTPBandwidthInBits));
    this->SetVal(qtssRTPSvrCurPackets,      &fRTPPacketsPerSecond,      sizeof(fRTPPacketsPerSecond));
    this->SetVal(qtssRTPSvrTotalPackets,    &fTotalRTPPackets,          sizeof(fTotalRTPPackets));
    this->SetVal(qtssSvrStartupTime,        &fStartupTime_UnixMilli,    sizeof(fStartupTime_UnixMilli));
    this->SetVal(qtssSvrGMTOffsetInHrs,     &fGMTOffset,                sizeof(fGMTOffset));
    this->SetVal(qtssSvrCPULoadPercent,     &fCPUPercent,               sizeof(fCPUPercent));
    this->SetVal(qtssMP3SvrCurConn,         &fNumMP3Sessions,           sizeof(fNumMP3Sessions));
    this->SetVal(qtssMP3SvrTotalConn,       &fTotalMP3Sessions,         sizeof(fTotalMP3Sessions));
    this->SetVal(qtssMP3SvrCurBandwidth,    &fCurrentMP3BandwidthInBits,sizeof(fCurrentMP3BandwidthInBits));
    this->SetVal(qtssMP3SvrTotalBytes,      &fTotalMP3Bytes,            sizeof(fTotalMP3Bytes));
    this->SetVal(qtssMP3SvrAvgBandwidth,    &fAvgMP3BandwidthInBits,    sizeof(fAvgMP3BandwidthInBits));

    this->SetVal(qtssSvrServerBuild,        sServerBuildStr.Ptr,    sServerBuildStr.Len);
    this->SetVal(qtssSvrRTSPServerComment,  sServerCommentStr.Ptr,  sServerCommentStr.Len);
    this->SetVal(qtssSvrServerPlatform,     sServerPlatformStr.Ptr, sServerPlatformStr.Len);

    this->SetVal(qtssSvrNumThinned,         &fNumThinned,               sizeof(fNumThinned));
    this->SetVal(qtssSvrNumThreads,         &fNumThreads,               sizeof(fNumThreads));
    
    sServer = this;
}
/**
对于QTSSDictionaryMap[kServerDictIndex]所管理的QTSSAttrInfoDict一共包含43颗目录树,每一科
QTSSAttrInfoDict管理一个DictValueElement*，而对于DictValueElement*又维护着4个字段,每一个
字段用一个DictValueElement对象来维护在构造函数中使用父类的SetVal函数对每一个DictValueElement对象
做初始化工作,QTSServerInterface构造完成后调用QTSServer::Initialize函数对其他QTSSDictionaryMap[index]
做相应的初始化
**/
/**
3.3.QTSServer::Initialize函数分析
**/
Bool16 QTSServer::Initialize(XMLPrefsParser* inPrefsSource, 
    PrefsSource* inMessagesSource, 
    UInt16 inPortOverride, Bool16 createListeners)
{
    static const UInt32 kRTPSessionMapSize = 577;
    fServerState = qtssFatalErrorState;
    sPrefsSource = inPrefsSource;
    sMessagesSource = inMessagesSource;
    this->InitCallbacks();

    // DICTIONARY INITIALIZATION
    QTSSModule::Initialize();
    QTSServerPrefs::Initialize();
    QTSSMessages::Initialize();
    RTSPRequestInterface::Initialize();
    RTSPSessionInterface::Initialize();
    RTPSessionInterface::Initialize();
    RTPStream::Initialize();
    RTSPSession::Initialize();
    QTSSFile::Initialize();
    QTSSUserProfile::Initialize();
    
    RTSPRequest3GPP::Initialize();
    RTPStream3GPP::Initialize();
    RTPSession3GPP::Initialize();
    RTSPSession3GPP::Initialize();   
    //以上是18中模块的初始化对应的是定义在QTSSDictionaryMap类中定义的enum索引
 
    fSrvrPrefs = new QTSServerPrefs(inPrefsSource, false); // First time, don't write changes to the prefs file
    fSrvrMessages = new QTSSMessages(inMessagesSource);
    QTSSModuleUtils::Initialize(fSrvrMessages, this, QTSServerInterface::GetErrorLogStream());
    //
    // SETUP ASSERT BEHAVIOR
    //
    // Depending on the server preference, we will either break when we hit an
    // assert, or log the assert to the error log
    if (!fSrvrPrefs->ShouldServerBreakOnAssert())
        SetAssertLogger(this->GetErrorLogStream());// the error log stream is our assert logger
    //
    // CREATE GLOBAL OBJECTS
    fSocketPool = new RTPSocketPool();
    fRTPMap = new OSRefTable(kRTPSessionMapSize);
    //
    // Load ERROR LOG module only. This is good in case there is a startup error.
    QTSSModule* theLoggingModule = new QTSSModule("QTSSErrorLogModule");
    (void)theLoggingModule->SetupModule(&sCallbacks, &QTSSErrorLogModule_Main);
    (void)AddModule(theLoggingModule);
    this->BuildModuleRoleArrays();
    //
    // DEFAULT IP ADDRESS & DNS NAME
    // 获取IP地址和DNS名字同时写入到dirtionary
    if (!this->SetDefaultIPAddr())
        return false;

    //
    // STARTUP TIME - record it
    fStartupTime_UnixMilli = OS::Milliseconds();
    fGMTOffset = OS::GetGMTOffset();
    //
    // BEGIN LISTENING
    if (createListeners)
    {
        if ( !this->CreateListeners(false, fSrvrPrefs, inPortOverride) )
            QTSSModuleUtils::LogError(qtssWarningVerbosity, qtssMsgSomePortsFailed, 0);
    }
    if ( fNumListeners == 0 )
    {   if (createListeners)
            QTSSModuleUtils::LogError(qtssWarningVerbosity, qtssMsgNoPortsSucceeded, 0);
        return false;
    }

    fServerState = qtssStartingUpState;
    return true;
}
/**
a)使用InitCallbacks函数对QTSServer的static QTSS_Callbacks sCallbacks成员变量进行初始化
    将QTSSCallbacks类中定义的静态成员函数指向sCallbacks一共有61个函数
b).对其他18个QTSSDictionaryMap[index]进行初始化，另一个模块就是QTSServer模块,它们的初始化内容都是一样的
使用每个功能模块中定义的静态static QTSSAttrInfoDict::AttrInfo sAttributes[]属性对其所拥有的
属性目录对应的属性值进行相应的赋值操作
c).构造fSrvrPrefs,fSrvrMessages,fSocketPool,fRTPMap成员,都对应什么功能目前还未知
d).将服务器状态赋值成qtssStartingUpState
**/

/**
3.3.QTSServerPrefs构造过程分析
    它的定义如下:
*/
class QTSServerPrefs : public QTSSPrefs
{
public:
    static void Initialize();

    QTSServerPrefs(XMLPrefsParser* inPrefsSource, Bool16 inWriteMissingPrefs);
    virtual ~QTSServerPrefs() {}
};
QTSServerPrefs::QTSServerPrefs(XMLPrefsParser* inPrefsSource,
 Bool16 inWriteMissingPrefs)	
{
    SetupAttributes();//不分析
    //这里主要看RereadServerPreferences的实现
    //从函数名字是读取server的Preferences
    RereadServerPreferences(inWriteMissingPrefs);
}

void QTSServerPrefs::RereadServerPreferences(Bool16 inWriteMissingPrefs)
{
    OSMutexLocker locker(&fPrefsMutex);
    QTSSDictionaryMap* theMap = QTSSDictionaryMap::GetMap(QTSSDictionaryMap::kPrefsDictIndex);
    for (UInt32 x = 0; x < theMap->GetNumAttrs(); x++) {
        // Look for a pref in the file that matches each pref in the dictionary
        char* thePrefTypeStr = NULL;
        char* thePrefName = NULL;
        //读取/etc/streamingserver.xml
        ContainerRef server = fPrefsSource->GetRefForServer();
        ContainerRef pref = fPrefsSource->GetPrefRefByName(server, theMap->GetAttrName(x) );
        char* thePrefValue = NULL;
        /*
        从/etc/streamingserver.xml的<SERVER>自读解析<PREF>字段然后将中的值解析出来
        比如说如下,事实上kPrefsDictIndex对应的目录树中定义的属性和streamingserver.xml文件中SERVER字段
        对应
        <PREF NAME="default_authorization_realm" >Streaming Server</PREF>
		<PREF NAME="do_report_http_connection_ip_address" TYPE="Bool16" >disabled</PREF>
		<PREF NAME="tcp_seconds_to_buffer" TYPE="Float32" >.5</PREF>
		<PREF NAME="max_tcp_buffer_size" TYPE="UInt32" >200000</PREF>
		<PREF NAME="min_tcp_buffer_size" TYPE="UInt32" >8192</PREF>        
        */
        //3.3.1 从streamingserver.xml文件中加载SERVER->PREF字段
        if (pref != NULL)
            thePrefValue = fPrefsSource->GetPrefValueByRef(pref, 
				0, &thePrefName,(char**)&thePrefTypeStr);
            
        //3.3.2 对streamingserver.xml文件中SERVER->PREF字段没有定义到的key-value字段
        if ((thePrefValue == NULL) && (x < qtssPrefsNumParams)) {// Only generate errors for server prefs
        
            //如果streamingserver.xml文件没有配置kPrefsDictIndex所对应的值则使用sPrefInfo静态成员中的值
            //对sAttributes进行填充
            this->SetPrefValue(x, 0, sPrefInfo[x].fDefaultValue, sAttributes[x].fAttrDataType);
            if (sPrefInfo[x].fAdditionalDefVals != NULL) {
                //
                // Add additional default values if they exist
                for (UInt32 y = 0; sPrefInfo[x].fAdditionalDefVals[y] != NULL; y++)
                    this->SetPrefValue(x, y+1, sPrefInfo[x].fAdditionalDefVals[y], sAttributes[x].fAttrDataType);
            }
            
            if (inWriteMissingPrefs) {
                //是否对streamingserver.xml文件中没有的属性根据系统默认值然后再写入到xml文件
                //系统默认初次加载不写入
                // Add this value into the file, cuz we need it.
                pref = fPrefsSource->AddPref(server, sAttributes[x].fAttrName, 
                    QTSSDataConverter::TypeToTypeString(sAttributes[x].fAttrDataType));
                fPrefsSource->AddPrefValue(pref, sPrefInfo[x].fDefaultValue);
                
                if (sPrefInfo[x].fAdditionalDefVals != NULL)
                {
                    for (UInt32 a = 0; sPrefInfo[x].fAdditionalDefVals[a] != NULL; a++)
                        fPrefsSource->AddPrefValue(pref, sPrefInfo[x].fAdditionalDefVals[a]);
                }
            }
            continue;
        }             
        UInt32 theNumValues = 0;
        if ((x < qtssPrefsNumParams) && (!sPrefInfo[x].fAllowMultipleValues))
            theNumValues = 1;
        //3.3.3将从streamingserver.xml中获取到的值更新到kPrefsDictIndex对应的QTSSDictionaryMap
        //所对应的DictValueElement   
        this->SetPrefValuesFromFileWithRef(pref, x, theNumValues);
    }
    
    //
    // Do any special pref post-processing
    this->UpdateAuthScheme();
    this->UpdatePrintfOptions();
    QTSSModuleUtils::SetEnableRTSPErrorMsg(fEnableRTSPErrMsg);
    
    QTSSRollingLog::SetCloseOnWrite(fCloseLogsOnWrite);
    //
    // In case we made any changes, write out the prefs file
    (void)fPrefsSource->WritePrefsFile();
}

/**3.3.2 对streamingserver.xml文件中SERVER->PREF字段没有定义到的key-value字段进行处理
对于streamingserver.xml文件中刚编译出来的东西有些属性在xml文件中是没有定义的比如说
RTSP_server_info这条属性,在运行该程序前streamingserver.xml文件中是没有的针对这条属性
参数如下:
@inAttrID = 65
@inAttrIndex = 0 
@inPrefValue = true
@inPrefType = qtssAttrDataTypeBool16
@inValueSize = 0  
**/
void QTSSPrefs::SetPrefValue(
    QTSS_AttributeID inAttrID, 
    UInt32 inAttrIndex,char* inPrefValue, 
    QTSS_AttrDataType inPrefType, UInt32 inValueSize){
    
    static const UInt32 kMaxPrefValueSize = 1024;
    char convertedPrefValue[kMaxPrefValueSize];
    ::memset(convertedPrefValue, 0, kMaxPrefValueSize);
    Assert(inValueSize < kMaxPrefValueSize);
    
    UInt32 convertedBufSize = kMaxPrefValueSize;
    QTSS_Error theErr = QTSSDataConverter::StringToValue
        (inPrefValue, inPrefType, convertedPrefValue, &convertedBufSize);
    Assert(theErr == QTSS_NoErr);
    
    if (inValueSize == 0)
        inValueSize = convertedBufSize;
        
    this->SetValue(inAttrID, inAttrIndex, convertedPrefValue, inValueSize, 
            QTSSDictionary::kDontObeyReadOnly | 
            QTSSDictionary::kDontCallCompletionRoutine);                         

}
/**
@inAttrID = 65
@inAttrIndex = 0 
@inBuffer = true
@inLen = sizeof(Bool16)
@inFlags = kDontObeyReadOnly|kDontCallCompletionRoutine  
**/
QTSS_Error QTSSDictionary::SetValue(QTSS_AttributeID inAttrID, UInt32 inIndex,
                                        const void* inBuffer,  UInt32 inLen,
                                        UInt32 inFlags)
{
    // Check first to see if this is a static attribute or an instance attribute
    QTSSDictionaryMap* theMap = fMap;
    DictValueElement* theAttrs = fAttributes;
    if (QTSSDictionaryMap::IsInstanceAttrID(inAttrID))
    {
        theMap = fInstanceMap;
        theAttrs = fInstanceAttrs;
    }
    
    if (theMap == NULL)
        return QTSS_AttrDoesntExist;
    
    SInt32 theMapIndex = theMap->ConvertAttrIDToArrayIndex(inAttrID);
    
    // If there is a mutex, make this action atomic.
    OSMutexLocker locker(fMutexP);
    
    //从fAttributes取出index=65的DictValueElement对象
    UInt32 numValues = theAttrs[theMapIndex].fNumAttributes;

    QTSS_AttrDataType dataType = theMap->GetAttrType(theMapIndex);
    UInt32 attrLen = inLen;
    //
    // Can't put empty space into the array of values
    if (inIndex > numValues)
        return QTSS_BadIndex;
        
    // Copy the new data to the right place in our data buffer
    void *attributeBufferPtr;
    if ((dataType != qtssAttrDataTypeCharArray) || ((numValues < 2) && (inIndex == 0)))
    {
        //非字符串的值无需重新分配内存
        attributeBufferPtr = theAttrs[theMapIndex].fAttributeData.Ptr + (inLen * inIndex);
        theAttrs[theMapIndex].fAttributeData.Len = inLen;
    }    
    //把值拷贝到attributeBufferPtr也就是拷贝到
    //theAttrs[theMapIndex].fAttributeData.Ptr + (inLen * inIndex)
    ::memcpy(attributeBufferPtr, inBuffer, inLen);
    // Set the number of attributes to be proper
    if (inIndex >= theAttrs[theMapIndex].fNumAttributes)
    {
        //
        // We should never have to increment num attributes by more than 1
        Assert(theAttrs[theMapIndex].fNumAttributes == inIndex);
        theAttrs[theMapIndex].fNumAttributes++;
    }
    //
    // Call the completion routine
    if (((fMap == NULL) || fMap->CompleteFunctionsAllowed()) && !(inFlags & kDontCallCompletionRoutine))
        this->SetValueComplete(theMapIndex, theMap, inIndex, attributeBufferPtr, inLen);
    
    return QTSS_NoErr;
}
/**
3.3.3将从streamingserver.xml中解析出来的值更新到DictValueElement
@pref:streamingserver.xml解析器
@inAttrID:对应各属性目录ID
@inNumValues:1 只支持单值,0 支持多只如rtsp_port
**/
void QTSSPrefs::SetPrefValuesFromFileWithRef(ContainerRef pref, 
    QTSS_AttributeID inAttrID, UInt32 inNumValues)
{
    //
    // We have an attribute ID for this pref, it is in the map and everything.
    // Now, let's add all the values that are in the pref file.
    if (pref == 0)
        return;
    
    UInt32 numPrefValues = inNumValues;
    //从xml文件中解析有多少个值,如player_requires_rtp_header_info 有两个
    if (inNumValues == 0) 
        numPrefValues = fPrefsSource->GetNumPrefValues(pref);
        
    char* thePrefName = NULL;
    char* thePrefValue = NULL;
    char* thePrefTypeStr = NULL;
    QTSS_AttrDataType thePrefType = qtssAttrDataTypeUnknown;
    
    // find the type.  If this is a QTSSObject, then we need to call a different routine
    thePrefValue = fPrefsSource->GetPrefValueByRef(pref, 0, &thePrefName, &thePrefTypeStr);
    thePrefType = QTSSDataConverter::TypeStringToType(thePrefTypeStr);
    if (thePrefType == qtssAttrDataTypeQTSS_Object)
    {
        SetObjectValuesFromFile(pref, inAttrID, numPrefValues, thePrefName);
        return;
    }
    UInt32 maxPrefValueSize = 0;
    QTSS_Error theErr = QTSS_NoErr;
    //
    // We have to loop through all the values associated with this pref twice:
    // first, to figure out the length (in bytes) of the longest value, secondly
    // to actually copy these values into the dictionary.
    for (UInt32 y = 0; y < numPrefValues; y++)
    {
        UInt32 tempMaxPrefValueSize = 0;
        thePrefValue = fPrefsSource->GetPrefValueByRef(pref, y, &thePrefName, &thePrefTypeStr);
        //
        theErr = QTSSDataConverter::StringToValue( thePrefValue, thePrefType,
                                                    NULL, &tempMaxPrefValueSize );
        Assert(theErr == QTSS_NotEnoughSpace);
        
        if (tempMaxPrefValueSize > maxPrefValueSize)
            maxPrefValueSize = tempMaxPrefValueSize;
    }
    
    for (UInt32 z = 0; z < numPrefValues; z++)
    {
        thePrefValue = fPrefsSource->GetPrefValueByRef( pref, z, &thePrefName, &thePrefTypeStr);
        this->SetPrefValue(inAttrID, z, thePrefValue, thePrefType, maxPrefValueSize);
    }
    //
    // Make sure the dictionary knows exactly how many values are associated with
    // this pref
    this->SetNumValues(inAttrID, numPrefValues);
}
/**
这一个步骤其实就是从/etc/streamingserver.xml的<SERVER>字段解析<PREF>字段然后将中的值解析出来
将解析出来的值写入到kPrefsDictIndex对应的QTSSDictionaryMap数组中创建的QTSSDictionary所保存的
属性集合当中,如果xml文件中没有定义则使用QTSSDictionary<这里对应的QTSServerPrefs>定义的静态默认值,
最后如果需要更新xml文件的话会将值重新会写到xml文件当中去
**/
/**
3.4.SetDefaultIPAddr函数分析
**/
Bool16 QTSServer::SetDefaultIPAddr()
{
    //check to make sure there is an available ip interface
    if (SocketUtils::GetNumIPAddrs() == 0)
    {   
        //这一步骤已经在2.StartServer函数分析_01中分析过
        //默认情况下我们的系统会支持两个IP地址,一个为192.168.xx.xx;另一个为
        //127.0.0.1,如果这一步出错的话直接返回,说明没有网卡
        QTSSModuleUtils::LogError(qtssFatalVerbosity, qtssMsgNotConfiguredForIP, 0);
        return false;
    }

    //find out what our default IP addr is & dns name
    UInt32 theNumAddrs = 0;
    UInt32* theIPAddrs = this->GetRTSPIPAddrs(fSrvrPrefs, &theNumAddrs);
    if (theNumAddrs == 1)
        fDefaultIPAddr = SocketUtils::GetIPAddr(0);
    else
        fDefaultIPAddr = theIPAddrs[0];
    delete [] theIPAddrs;
        
    for (UInt32 ipAddrIter = 0; ipAddrIter < SocketUtils::GetNumIPAddrs(); ipAddrIter++)
    {
        if (SocketUtils::GetIPAddr(ipAddrIter) == fDefaultIPAddr)
        {
            this->SetVal(qtssSvrDefaultDNSName, SocketUtils::GetDNSNameStr(ipAddrIter));
            Assert(this->GetValue(qtssSvrDefaultDNSName)->Ptr != NULL);
            this->SetVal(qtssSvrDefaultIPAddrStr, SocketUtils::GetIPAddrStr(ipAddrIter));
            Assert(this->GetValue(qtssSvrDefaultDNSName)->Ptr != NULL);
            break;
        }
    }
    if (this->GetValue(qtssSvrDefaultDNSName)->Ptr == NULL)
    {
        //If we've gotten here, what has probably happened is the IP address (explicitly
        //entered as a preference) doesn't exist
        QTSSModuleUtils::LogError(qtssFatalVerbosity, qtssMsgDefaultRTSPAddrUnavail, 0);
        return false;   
    }
    return true;
}
/**
该函数首先回调SocketUtils::GetNumIPAddrs()获取系统支持的有效ip地址个数,如果没有,直接返回
如果有则使用GetRTSPIPAddrs(fSrvrPrefs, &theNumAddrs)从streamingserver.xml文件解析
bind_ip_addr属性,bind_ip_addr默认值为0,意思是A value of 0 means all IP addresses currently
如果theNumAddrs=1则使用SocketUtils::GetIPAddr(0);否则使用theIPAddrs[0]由xml决定
成功获取ip信息后需要将IP地址信息和DNS信息写入到DictValueElement
**/

/**
3.4.CreateListeners分析
@startListeningNow = false
@inPrefs
@inPortOverride 如果用户由传递参数则使用用户提供的端口
**/
Bool16 QTSServer::CreateListeners(Bool16 startListeningNow, 
	QTSServerPrefs* inPrefs, UInt16 inPortOverride) {
    struct PortTracking
    {
        PortTracking() : fPort(0), fIPAddr(0), fNeedsCreating(true) {}
        
        UInt16 fPort;
        UInt32 fIPAddr;
        Bool16 fNeedsCreating;
    };
    
    PortTracking* thePortTrackers = NULL;   
    UInt32 theTotalPortTrackers = 0;
    
    // Get the IP addresses from the pref
    UInt32 theNumAddrs = 0;
    UInt32* theIPAddrs = this->GetRTSPIPAddrs(inPrefs, &theNumAddrs);   
    UInt32 index = 0;
    
    if (inPortOverride != 0) {//如果用户在执行main函数指定了端口号
        theTotalPortTrackers = theNumAddrs; // one port tracking struct for each IP addr
        thePortTrackers = NEW PortTracking[theTotalPortTrackers];
        for (index = 0; index < theNumAddrs; index++) {//默认情况下为1
            thePortTrackers[index].fPort = inPortOverride;
            thePortTrackers[index].fIPAddr = theIPAddrs[index];
        }
    } else {//如果使用streamingserver.xml文件中定义的rtsp_port属性
        UInt32 theNumPorts = 0;
        //rtsp_port默认为4个,theNumAddrs默认为1
        UInt16* thePorts = GetRTSPPorts(inPrefs, &theNumPorts);
        theTotalPortTrackers = theNumAddrs * theNumPorts;
        thePortTrackers = NEW PortTracking[theTotalPortTrackers];
        //默认创建4个PortTracking
        UInt32 currentIndex  = 0;
        for (index = 0; index < theNumAddrs; index++) {
            for (UInt32 portIndex = 0; 
                portIndex < theNumPorts; portIndex++) {
                currentIndex = (theNumPorts * index) + portIndex;
                thePortTrackers[currentIndex].fPort = thePorts[portIndex];
                thePortTrackers[currentIndex].fIPAddr = theIPAddrs[index];
            }//假设theNumAddrs = 1,theNumPorts = 4
        }
        delete [] thePorts;
    }
    delete [] theIPAddrs;
    //
    // Now figure out which of these ports we are *already* listening on.
    // If we already are listening on that port, just move the pointer to the
    // listener over to the new array
    TCPListenerSocket** newListenerArray = 
        NEW TCPListenerSocket*[theTotalPortTrackers];
    UInt32 curPortIndex = 0;
    for (UInt32 count = 0; count < theTotalPortTrackers; count++) {
        for (UInt32 count2 = 0; count2 < fNumListeners; count2++) {
            //刚进来fNumListeners等于0直接退出了
            if ((fListeners[count2]->GetLocalPort() == 
                thePortTrackers[count].fPort) &&
                (fListeners[count2]->GetLocalAddr() == 
                thePortTrackers[count].fIPAddr)) {
                thePortTrackers[count].fNeedsCreating = false;
                newListenerArray[curPortIndex++] = fListeners[count2];
                Assert(curPortIndex <= theTotalPortTrackers);
                break;
            }
        }
    }
    // Create any new listeners we need
    // 在这里创建RTSPListenerSocket
    for (UInt32 count3 = 0; count3 < theTotalPortTrackers; count3++) {
        if (thePortTrackers[count3].fNeedsCreating) {
            //默认情况第一次调用会走这里构造RTSPListenerSocket
            newListenerArray[curPortIndex] = NEW RTSPListenerSocket();
            //构造完成调用RTSPListenerSocket::Initialize对其进行相应的初始化工作
            QTSS_Error err = 
                newListenerArray[curPortIndex]->Initialize(thePortTrackers[count3].fIPAddr,
                    thePortTrackers[count3].fPort);
            char thePortStr[20];
            qtss_sprintf(thePortStr, "%hu", thePortTrackers[count3].fPort);
            // 出错处理函数
            // If there was an error creating this listener, destroy it and log an error
            if ((startListeningNow) && (err != QTSS_NoErr))
                delete newListenerArray[curPortIndex];
            
            if (err == EADDRINUSE)
                QTSSModuleUtils::LogError(qtssWarningVerbosity, qtssListenPortInUse, 0, thePortStr);
            else if (err == EACCES)
                QTSSModuleUtils::LogError(qtssWarningVerbosity, qtssListenPortAccessDenied, 0, thePortStr);
            else if (err != QTSS_NoErr)
                QTSSModuleUtils::LogError(qtssWarningVerbosity, qtssListenPortError, 0, thePortStr);
            else {
                //
                // This listener was successfully created.
                //调用RTSPListenerSocket::RequestEvent
                if (startListeningNow)
                    newListenerArray[curPortIndex]->RequestEvent(EV_RE);
                curPortIndex++;
            }
        }
    }
    
    // 第一次来这里fNumListeners = 0
    // Kill any listeners that we no longer need
    for (UInt32 count4 = 0; count4 < fNumListeners; count4++)
    {
        Bool16 deleteThisOne = true;
        
        for (UInt32 count5 = 0; count5 < curPortIndex; count5++)
        {
            if (newListenerArray[count5] == fListeners[count4])
                deleteThisOne = false;
        }
        
        if (deleteThisOne)
            fListeners[count4]->Signal(Task::kKillEvent);
    }
    
    // 将上面创建好的
    // Finally, make our server attributes and fListener privy to the new...
    fListeners = newListenerArray;//上面分配的TCPListenerSocket**二级指针
    fNumListeners = curPortIndex;//有多少个有效端口号就有几个
    UInt32 portIndex = 0;
    for (UInt32 count6 = 0; count6 < fNumListeners; count6++) {
        //如果监听的网卡ip地址不等于127.0.0.1,则将相关的信息写入
        //到属性树
        if  (fListeners[count6]->GetLocalAddr() != INADDR_LOOPBACK) {
            UInt16 thePort = fListeners[count6]->GetLocalPort();
            (void)this->SetValue(qtssSvrRTSPPorts, portIndex, 
                &thePort, sizeof(thePort), QTSSDictionary::kDontObeyReadOnly);
            portIndex++;
        }
    }
    this->SetNumValues(qtssSvrRTSPPorts, portIndex);

    delete [] thePortTrackers;
    return (fNumListeners > 0);
}
/**
以上函数核心部分就是针对不同的端口号创建RTSPListenerSocket实例
a).RTSPListenerSocket的创建
b).RTSPListenerSocket::Initialize初始化
c).RTSPListenerSocket::RequestEvent事件请求
d).另外标注的哪两个for循环不知道在何时会被调用
**/

