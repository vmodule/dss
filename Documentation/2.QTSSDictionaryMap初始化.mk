QTSSDictionary类定义如下
class QTSSDictionary : public QTSSStream
{
public:
	//
	// CONSTRUCTOR / DESTRUCTOR
	
	QTSSDictionary(QTSSDictionaryMap* inMap, OSMutex* inMutex = NULL);
	virtual ~QTSSDictionary();
	enum{
		kServerDictIndex                = 0,
		kPrefsDictIndex                 = 1,
		kTextMessagesDictIndex          = 2,
		kServiceDictIndex               = 3,
		
		kRTPStreamDictIndex             = 4,
		kClientSessionDictIndex         = 5,
		kRTSPSessionDictIndex           = 6,
		kRTSPRequestDictIndex           = 7,
		kRTSPHeaderDictIndex            = 8,
		kFileDictIndex                  = 9,
		kModuleDictIndex                = 10,
		kModulePrefsDictIndex           = 11,
		kAttrInfoDictIndex              = 12,
		kQTSSUserProfileDictIndex       = 13,
		kQTSSConnectedUserDictIndex     = 14,
		k3GPPRequestDictIndex           = 15,
		k3GPPStreamDictIndex            = 16,
		k3GPPClientSessionDictIndex     = 17,
		k3GPPRTSPSessionDictIndex       = 18,

		kNumDictionaries                = 19,
		
		kNumDynamicDictionaryTypes      = 500,
		kIllegalDictionary              = kNumDynamicDictionaryTypes + kNumDictionaries
	};	
private:
	//
	// Repository for dictionary maps
	static QTSSDictionaryMap*       sDictionaryMaps[kNumDictionaries + kNumDynamicDictionaryTypes];
	static UInt32                   sNextDynamicMap;	
	UInt32                          fNextAvailableID;
	UInt32                          fNumValidAttrs;
	UInt32                          fAttrArraySize;
	QTSSAttrInfoDict**              fAttrArray;
	UInt32                          fFlags;	
}；

class QTSSAttrInfoDict : public QTSSDictionary
{
public:
	struct AttrInfo
	{
		// This is all the relevent information for each dictionary
		// attribute.
		char                    fAttrName[QTSS_MAX_ATTRIBUTE_NAME_SIZE + 1];//名字
		QTSS_AttrFunctionPtr    fFuncPtr;//回调函数
		QTSS_AttrDataType       fAttrDataType;//数据类型
		QTSS_AttrPermission     fAttrPermission;//权限
	};
	QTSSAttrInfoDict();
	virtual ~QTSSAttrInfoDict();
private:
	AttrInfo fAttrInfo;
	QTSS_AttributeID fID;
	static AttrInfo sAttributes[];
	friend class QTSSDictionaryMap;

};

enum{
    //QTSS_AttrInfoObject parameters
    // All of these parameters are preemptive-safe.
    qtssAttrName                    = 0,    //read //char array             //Attribute name
    qtssAttrID                      = 1,    //read //QTSS_AttributeID       //Attribute ID
    qtssAttrDataType                = 2,    //read //QTSS_AttrDataType      //Data type
    qtssAttrPermissions             = 3,    //read //QTSS_AttrPermission    //Permissions

    qtssAttrInfoNumParams           = 4
};
从QTSSDictionary类定义看出它的构造函数接收它本身的指针,并且在类中定义了sDictionaryMaps指针数组
针对每一个enum成员都有一个QTSSDictionaryMap实例与之对应,要用来干嘛?其构造函数如下：
QTSSDictionaryMap::QTSSDictionaryMap(UInt32 inNumReservedAttrs, UInt32 inFlags)
:   fNextAvailableID(inNumReservedAttrs), 
	fNumValidAttrs(inNumReservedAttrs),
	fAttrArraySize(inNumReservedAttrs), fFlags(inFlags)
{
    if (fAttrArraySize < kMinArraySize)
        fAttrArraySize = kMinArraySize;
    fAttrArray = NEW QTSSAttrInfoDict*[fAttrArraySize];
    ::memset(fAttrArray, 0, sizeof(QTSSAttrInfoDict*) * fAttrArraySize);
}
上面的构造函数会根据传入的inNumReservedAttrs分配一个QTSSAttrInfoDict指针数组,并且数组的
大小由inNumReservedAttrs传入值决定

//声明静态成员变量
QTSSDictionaryMap*      QTSSDictionaryMap::sDictionaryMaps[kNumDictionaries + kNumDynamicDictionaryTypes];
UInt32                  QTSSDictionaryMap::sNextDynamicMap = kNumDictionaries;

2.5、QTSSDictionaryMap数据结构初始化
void QTSSDictionaryMap::Initialize()
{
    //
    // Have to do this one first because this dict map is used by all the other
    // dict maps.
    sDictionaryMaps[kAttrInfoDictIndex]     = new QTSSDictionaryMap(qtssAttrInfoNumParams);//4
    // Setup the Attr Info attributes before constructing any other dictionaries
    for (UInt32 x = 0; x < qtssAttrInfoNumParams; x++)
        sDictionaryMaps[kAttrInfoDictIndex]->SetAttribute(x, QTSSAttrInfoDict::sAttributes[x].fAttrName,
                                                            QTSSAttrInfoDict::sAttributes[x].fFuncPtr,
                                                            QTSSAttrInfoDict::sAttributes[x].fAttrDataType,
                                                            QTSSAttrInfoDict::sAttributes[x].fAttrPermission);
	首先针对kAttrInfoDictIndex索引创建1个QTSSDictionaryMap实例，然后每一个QTSSDictionaryMap实例维护了一个
	fAttrArray的二级指针也就是QTSSAttrInfoDict*的数组,所以在这里,kAttrInfoDictIndex索引所对应的实例将维护
	4个QTSSAttrInfoDict*的实例,然后调用SetAttribute对每个QTSSAttrInfoDict*实例进行设置
	下面的代码和上面一样,针对每一个enum索引将维护索引对应的值个QTSSAttrInfoDict*
															
    sDictionaryMaps[kServerDictIndex]       = new QTSSDictionaryMap(qtssSvrNumParams, QTSSDictionaryMap::kCompleteFunctionsAllowed);
    sDictionaryMaps[kPrefsDictIndex]        = new QTSSDictionaryMap(qtssPrefsNumParams, QTSSDictionaryMap::kInstanceAttrsAllowed | QTSSDictionaryMap::kCompleteFunctionsAllowed);
    sDictionaryMaps[kTextMessagesDictIndex] = new QTSSDictionaryMap(qtssMsgNumParams);
    sDictionaryMaps[kServiceDictIndex]      = new QTSSDictionaryMap(0);
    sDictionaryMaps[kRTPStreamDictIndex]    = new QTSSDictionaryMap(qtssRTPStrNumParams);
	sDictionaryMaps[kClientSessionDictIndex]= new QTSSDictionaryMap(qtssCliSesNumParams, QTSSDictionaryMap::kCompleteFunctionsAllowed);
    sDictionaryMaps[kRTSPSessionDictIndex]  = new QTSSDictionaryMap(qtssRTSPSesNumParams);
    sDictionaryMaps[kRTSPRequestDictIndex]  = new QTSSDictionaryMap(qtssRTSPReqNumParams);
    sDictionaryMaps[kRTSPHeaderDictIndex]   = new QTSSDictionaryMap(qtssNumHeaders);
    sDictionaryMaps[kFileDictIndex]         = new QTSSDictionaryMap(qtssFlObjNumParams);
    sDictionaryMaps[kModuleDictIndex]       = new QTSSDictionaryMap(qtssModNumParams);
    sDictionaryMaps[kModulePrefsDictIndex]  = new QTSSDictionaryMap(0, QTSSDictionaryMap::kInstanceAttrsAllowed | QTSSDictionaryMap::kCompleteFunctionsAllowed);
    sDictionaryMaps[kQTSSUserProfileDictIndex] = new QTSSDictionaryMap(qtssUserNumParams);
    sDictionaryMaps[kQTSSConnectedUserDictIndex] = new QTSSDictionaryMap(qtssConnectionNumParams);
    sDictionaryMaps[k3GPPRequestDictIndex] = new QTSSDictionaryMap(qtss3GPPRequestNumParams);
    sDictionaryMaps[k3GPPStreamDictIndex] = new QTSSDictionaryMap(qtss3GPPStreamNumParams);
    sDictionaryMaps[k3GPPClientSessionDictIndex] = new QTSSDictionaryMap(qtss3GPPCliSesNumParams);
    sDictionaryMaps[k3GPPRTSPSessionDictIndex] = new QTSSDictionaryMap(qtss3GPPRTSPSessNumParams);
}
class QTSServerInterface : public QTSSDictionary
{
public:
	//Initialize must be called right off the bat to initialize dictionary resources
	static void     Initialize();
private:		
	static QTSServerInterface*  sServer;
	static QTSSAttrInfoDict::AttrInfo   sAttributes[];	//注意这个静态成员数组	
}
2.6、初始化QTSServerInterface成员变量以及对2.5部创建的sDictionaryMaps数组对应的
实例使用sAttributes静态成员变量进行填充
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

    //Write out a premade server header
    StringFormatter serverFormatter(sServerHeaderPtr.Ptr, kMaxServerHeaderLen);
    serverFormatter.Put(RTSPProtocol::GetHeaderString(qtssServerHeader));
    serverFormatter.Put(": ");
    serverFormatter.Put(sServerNameStr);
    serverFormatter.PutChar('/');
    serverFormatter.Put(sServerVersionStr);
    serverFormatter.PutChar(' ');

    serverFormatter.PutChar('(');
    serverFormatter.Put("Build/");
    serverFormatter.Put(sServerBuildStr);
    serverFormatter.Put("; ");
    serverFormatter.Put("Platform/");
    serverFormatter.Put(sServerPlatformStr);
    serverFormatter.PutChar(';');
 
    if (sServerCommentStr.Len > 0)
    {
        serverFormatter.PutChar(' ');
        serverFormatter.Put(sServerCommentStr);
    }
    serverFormatter.PutChar(')');


    sServerHeaderPtr.Len = serverFormatter.GetCurrentOffset();
    Assert(sServerHeaderPtr.Len < kMaxServerHeaderLen);
}