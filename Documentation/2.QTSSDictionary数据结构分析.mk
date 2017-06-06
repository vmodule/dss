/**
2.1 认识QTS中的数据类型和各数据类型所具有的属性
在QTSS.h文件中定义了QTServer中所支持的数据类型以及属性
**/
typedef void*                   QTSS_Object;
typedef QTSS_Object             QTSS_RTPStreamObject;
typedef QTSS_Object             QTSS_RTSPSessionObject;
typedef QTSS_Object             QTSS_RTSPRequestObject;
typedef QTSS_Object             QTSS_RTSPHeaderObject;
typedef QTSS_Object             QTSS_ClientSessionObject;
typedef QTSS_Object             QTSS_ServerObject;
typedef QTSS_Object             QTSS_PrefsObject;
typedef QTSS_Object             QTSS_TextMessagesObject;
typedef QTSS_Object             QTSS_FileObject;
typedef QTSS_Object             QTSS_ModuleObject;
typedef QTSS_Object             QTSS_ModulePrefsObject;
typedef QTSS_Object             QTSS_AttrInfoObject;
typedef QTSS_Object             QTSS_UserProfileObject;
typedef QTSS_Object             QTSS_ConnectedUserObject;

typedef QTSS_Object             QTSS_3GPPStreamObject;
typedef QTSS_Object             QTSS_3GPPClientSessionObject;
typedef QTSS_Object             QTSS_3GPPRTSPSessionObject;
typedef QTSS_Object             QTSS_3GPPRequestObject;
/**
在QTServer中所有的各大数据类型用QTSS_Object来描述,而QTSS_Object其实就是一个
void*,同时针对每一个数据类型都定义了对应的属性,它们的定义如下:
**/
typedef UInt32 QTSS_AttrPermission;//

typedef UInt32 QTSS_AttrRights; // see QTSS_UserProfileObject

typedef UInt32 QTSS_RTPStreamAttributes;

typedef UInt32 QTSS_RTPStream3GPPAttributes;

typedef UInt32 QTSS_ClientSessionAttributes;

typedef UInt32 QTSS_ClientSession3GPPAttributes;

typedef UInt32 QTSS_RTSPSessionAttributes;

typedef UInt32 QTSS_3GPPRTSPSessionAttributes;//QTSS_3GPPRTSPSessionObject

typedef UInt32 QTSS_RTSPRequestAttributes;

typedef UInt32 QTSS_RTSPRequest3GPPAttributes;

typedef UInt32 QTSS_ServerAttributes;

typedef UInt32 QTSS_PrefsAttributes;

typedef UInt32 QTSS_TextMessagesAttributes;

typedef UInt32 QTSS_FileObjectAttributes;

typedef UInt32 QTSS_ModuleObjectAttributes;

typedef UInt32 QTSS_AttrInfoObjectAttributes;

typedef UInt32 QTSS_UserProfileObjectAttributes;

typedef UInt32 QTSS_ConnectedUserObjectAttributes;
/**
从上述定义可以看出当前,QTSServer中默认支持18种数据类型,同时支持18种一一对应的属性
并且针对每一种数据类型的属性都拥有不同数量的属性记录数量定义在相应的枚举中,
以QTSS_3GPPStreamObject这种数据类型为例它对应的属性定义为QTSS_RTPStream3GPPAttributes,
其枚举定义
**/
enum 
{
    //All text names are identical to the enumerated type names
    qtss3GPPStreamEnabled               = 0,
    qtss3GPPStreamRateAdaptBufferBytes  = 1,
    qtss3GPPStreamRateAdaptTimeMilli    = 2,
    qtss3GPPStreamNumParams             = 3
};
typedef UInt32 QTSS_RTPStream3GPPAttributes; //QTSS_3GPPStreamObject
/**
对于QTSS_RTPStream3GPPAttributes属性定义了3条记录分别为qtss3GPPStreamEnabled,
qtss3GPPStreamRateAdaptBufferBytes,qtss3GPPStreamRateAdaptTimeMilli,而对于
属性中的每一条记录都用一个QTSSAttrInfoDict类来描述,称作为每条记录所包含的信息,它的定义
如下:
**/
class QTSSAttrInfoDict: public QTSSDictionary
{
public:
	struct AttrInfo
	{
		// This is all the relevent information for each dictionary
		// attribute.
		char fAttrName[QTSS_MAX_ATTRIBUTE_NAME_SIZE + 1];
		QTSS_AttrFunctionPtr fFuncPtr;
		QTSS_AttrDataType fAttrDataType;
		QTSS_AttrPermission fAttrPermission;
	};
	QTSSAttrInfoDict();
	virtual ~QTSSAttrInfoDict();
private:
	AttrInfo fAttrInfo;
	QTSS_AttributeID fID;

	static AttrInfo sAttributes[];

	friend class QTSSDictionaryMap;
};
/**
QTSSAttrInfoDict的定义告诉我们,所有用QTSSAttrInfoDict描述的记录都包含了一个AttrInfo结构体
该结构体里面记录了四条属性参数分别为,记录名字,记录函数指针,记录数据类型,记录权限,所以对应的
每一类属性对应的每一条记录都应该包含(名字,函数指针,数据类型,权限),同时QTSSAttrInfoDict又是
QTSSDictionary的子类,所以也可以将每一类属性对应的每一条记录看成一个QTSSDictionary,同时每一种
数据类型也是直接或者派生对应着一个QTSSDictionary类,除此之外其他数据类型对应的实类如下:
**/
//kRTPStreamDictIndex, QTSS_RTPStreamObject
class RTPStream : public QTSSDictionary, public UDPDemuxerTask
{
public:
    static void Initialize();
};

//kRTSPSessionDictIndex,QTSS_RTSPSessionObject
class RTSPSessionInterface : public QTSSDictionary, public Task
{
public:
    //Initialize must be called right off the bat to initialize dictionary resources
    static void     Initialize();
};   

//kRTSPRequestDictIndex,QTSS_RTSPRequestObject
class RTSPRequestInterface : public QTSSDictionary
{
public:
    static void         Initialize();
protected:
    //kRTSPHeaderDictIndex,QTSS_RTSPHeaderObject    
    QTSSDictionary      fHeaderDictionary;
}; 

//kClientSessionDictIndex,QTSS_ClientSessionObject
class RTPSessionInterface : public QTSSDictionary, public Task
{
public:
    // Initializes dictionary resources
    static void Initialize();
};

//kServerDictIndex,QTSS_ServerObject
//kQTSSConnectedUserDictIndex,QTSS_ConnectedUserObject
class QTSServerInterface: public QTSSDictionary
{
public:
	//Initialize must be called right off the bat
	// to initialize dictionary resources
	static void Initialize();
};

//kPrefsDictIndex,QTSS_PrefsObject
//kModulePrefsDictIndex,QTSS_ModulePrefsObject
class QTSSPrefs : public QTSSDictionary
{
};

class QTSServerPrefs : public QTSSPrefs
{
public:
    static void Initialize();
};

//kTextMessagesDictIndex,QTSS_TextMessagesObject
class QTSSMessages : public QTSSDictionary
{
public:
    static void Initialize();
};

//kFileDictIndex,QTSS_FileObject
class QTSSFile : public QTSSDictionary
{
public:
    static void Initialize();
};

//kModuleDictIndex,QTSS_ModuleObject
class QTSSModule: public QTSSDictionary, public Task {
public:
	static void Initialize();
};

//kQTSSUserProfileDictIndex,QTSS_UserProfileObject
class QTSSUserProfile : public QTSSDictionary
{
public:
    static void         Initialize();
};

//k3GPPRequestDictIndex,QTSS_3GPPRequestObject
class RTSPRequest3GPP : public QTSSDictionary
{
public:
    //Initialize
    static void         Initialize();
};

//k3GPPStreamDictIndex,QTSS_3GPPStreamObject
class RTPStream3GPP : public QTSSDictionary
{
public:
    // Initializes dictionary resources
    static void Initialize();
};

//k3GPPClientSessionDictIndex,QTSS_3GPPClientSessionObject
class RTPSession3GPP : public QTSSDictionary
{
public:
    static void         Initialize();
};

//k3GPPRTSPSessionDictIndex,QTSS_3GPPRTSPSessionObject
class RTSPSession3GPP : public QTSSDictionary
{
public:
    //Initialize
    //Call initialize before instantiating this class: see QTSServer.cpp.
    static void         Initialize();
};
/**
由上面的分析我们可以得出,在QTSS中每一种QTSS_Object数据类型对应有一种属性类对应是
QTSSDictionary的子类或者是QTSSDictionary的派生类,然后每一种属性都有若干条记录
每一条记录也是一个QTSSDictionary子类(QTSSAttrInfoDict),那么这些属性都用什么统一
来管理呢?QTSSDictionaryMap来了
**/
/*****************************************************
2.2 认识QTSSDictionaryMap,定义在QTSSDictionary.h中
******************************************************/
class QTSSDictionaryMap
{
public:
	//
	// This must be called before using any QTSSDictionary or QTSSDictionaryMap functionality
	static void Initialize();
	// Stores all meta-information for attributes
    // This enum allows all QTSSDictionaryMaps to be stored in an array 
    enum
    {
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
	//
	// CONSTRUCTOR / DESTRUCTOR

	QTSSDictionaryMap(UInt32 inNumReservedAttrs, UInt32 inFlags = kNoFlags);
	~QTSSDictionaryMap()
	{
		for (UInt32 i = 0; i < fAttrArraySize; i++)
			delete fAttrArray[i];
		delete[] fAttrArray;
	}
	
	// MODIFIERS

	// Sets this attribute ID to have this information

	void SetAttribute(QTSS_AttributeID inID, const char* inAttrName,
			QTSS_AttrFunctionPtr inFuncPtr, QTSS_AttrDataType inDataType,
			QTSS_AttrPermission inPermission);	
	
	// This function converts a QTSS_ObjectType to an index
	static UInt32 GetMapIndex(QTSS_ObjectType inType);

	// Using one of the above predefined indexes, this returns the corresponding map
	static QTSSDictionaryMap* GetMap(UInt32 inIndex)
	{
		Assert(inIndex < kNumDynamicDictionaryTypes + kNumDictionaries);
		return sDictionaryMaps[inIndex];
	}

	static QTSS_ObjectType CreateNewMap();
private:
	//
	// Repository for dictionary maps
	static QTSSDictionaryMap* sDictionaryMaps[kNumDictionaries
			+ kNumDynamicDictionaryTypes];
	static UInt32 sNextDynamicMap;
	enum
	{
		kMinArraySize = 20
	};
	UInt32 fNextAvailableID;//认清它,对应的是上面分析的每个属性类别中真正对应的多少条记录的索引号
	UInt32 fNumValidAttrs;
	UInt32 fAttrArraySize;
	QTSSAttrInfoDict** fAttrArray;
	UInt32 fFlags;
	friend class QTSSDictionary;
};
/**
对于每一个属性类都会创建一个QTSSDictionaryMap实例,然后存储到sDictionaryMaps数组当中
通过GetMapIndex传递对应属性类的索引来获取当前属性类的实例QTSSDictionaryMap对应的索引,
使用GetMap传递索引号来获得当前的QTSSDictionaryMap实例而在上面说过,对应每一类属性类,
有多条记录,每一条记录都用一个QTSSAttrInfoDict*指针来描述,这里所有的QTSSAttrInfoDict*指针
都存储在fAttrArray二维指针当中.对于QTSSDictionaryMap中定义的枚举类型,代表每一种属性类型
所对应的QTSSDictionaryMap实例在sDictionaryMaps二维指针中的索引
**/
/**
2.3 QTSSDictionaryMap::Initialize静态初始化
**/
void QTSSDictionaryMap::Initialize()
{
    //
    // Have to do this one first because this dict map is used by all the other
    // dict maps.
    sDictionaryMaps[kAttrInfoDictIndex]     = new QTSSDictionaryMap(qtssAttrInfoNumParams);
    // Setup the Attr Info attributes before constructing any other dictionaries
    for (UInt32 x = 0; x < qtssAttrInfoNumParams; x++)
        sDictionaryMaps[kAttrInfoDictIndex]->SetAttribute(x,
        QTSSAttrInfoDict::sAttributes[x].fAttrName,
        QTSSAttrInfoDict::sAttributes[x].fFuncPtr,
        QTSSAttrInfoDict::sAttributes[x].fAttrDataType,
        QTSSAttrInfoDict::sAttributes[x].fAttrPermission);
    sDictionaryMaps[kServerDictIndex]       = new QTSSDictionaryMap(qtssSvrNumParams, 
                                               QTSSDictionaryMap::kCompleteFunctionsAllowed);
    sDictionaryMaps[kPrefsDictIndex]        = new QTSSDictionaryMap(qtssPrefsNumParams, 
                                                QTSSDictionaryMap::kInstanceAttrsAllowed | 
                                                QTSSDictionaryMap::kCompleteFunctionsAllowed);
    sDictionaryMaps[kTextMessagesDictIndex] = new QTSSDictionaryMap(qtssMsgNumParams);
    sDictionaryMaps[kServiceDictIndex]      = new QTSSDictionaryMap(0);
    sDictionaryMaps[kRTPStreamDictIndex]    = new QTSSDictionaryMap(qtssRTPStrNumParams);
	sDictionaryMaps[kClientSessionDictIndex]= new QTSSDictionaryMap(qtssCliSesNumParams, 
	                                            QTSSDictionaryMap::kCompleteFunctionsAllowed);
    sDictionaryMaps[kRTSPSessionDictIndex]  = new QTSSDictionaryMap(qtssRTSPSesNumParams);
    sDictionaryMaps[kRTSPRequestDictIndex]  = new QTSSDictionaryMap(qtssRTSPReqNumParams);
    sDictionaryMaps[kRTSPHeaderDictIndex]   = new QTSSDictionaryMap(qtssNumHeaders);
    sDictionaryMaps[kFileDictIndex]         = new QTSSDictionaryMap(qtssFlObjNumParams);
    sDictionaryMaps[kModuleDictIndex]       = new QTSSDictionaryMap(qtssModNumParams);
    sDictionaryMaps[kModulePrefsDictIndex]  = new QTSSDictionaryMap(0, 
                                                QTSSDictionaryMap::kInstanceAttrsAllowed | 
                                                QTSSDictionaryMap::kCompleteFunctionsAllowed);
    sDictionaryMaps[kQTSSUserProfileDictIndex] = new QTSSDictionaryMap(qtssUserNumParams);
    sDictionaryMaps[kQTSSConnectedUserDictIndex] = new QTSSDictionaryMap(qtssConnectionNumParams);
    sDictionaryMaps[k3GPPRequestDictIndex] = new QTSSDictionaryMap(qtss3GPPRequestNumParams);
    sDictionaryMaps[k3GPPStreamDictIndex] = new QTSSDictionaryMap(qtss3GPPStreamNumParams);
    sDictionaryMaps[k3GPPClientSessionDictIndex] = new QTSSDictionaryMap(qtss3GPPCliSesNumParams);
    sDictionaryMaps[k3GPPRTSPSessionDictIndex] = new QTSSDictionaryMap(qtss3GPPRTSPSessNumParams);
}
/**
初始化过程主要就是为每种属性类型new一个QTSSDictionaryMap实例,然后按照索引存储到sDictionaryMaps
二维指针当中,再就是回调QTSSDictionaryMap::SetAttribute设置相关的静态属性.在分析如何配置静态属性
之前我们先来分析一些QTSSDictionaryMap的构造函数
**/
/***
2.4.QTSSDictionaryMap构造函数分析
****/
QTSSDictionaryMap::QTSSDictionaryMap(UInt32 inNumReservedAttrs, UInt32 inFlags)
	: fNextAvailableID(inNumReservedAttrs)
	, fNumValidAttrs(inNumReservedAttrs)
	, fAttrArraySize(inNumReservedAttrs)
	, fFlags(inFlags)
{
    if (fAttrArraySize < kMinArraySize)
        fAttrArraySize = kMinArraySize;
    fAttrArray = NEW QTSSAttrInfoDict*[fAttrArraySize];
    ::memset(fAttrArray, 0, sizeof(QTSSAttrInfoDict*) * fAttrArraySize);
}
/**
QTSSDictionaryMap的构造函数在QTSSDictionaryMap::Initialize()静态初始化过程中被调用,为每一个属性类型
分配一个QTSSDictionaryMap实例然后存储到sDictionaryMaps静态数组中,而在QTSSDictionaryMap的构造函数中
传入两个参数,一个是inNumReservedAttrs代表该属性类别包含多少条属性或者说包含多少条记录,在构造函数
里面为我们分配了一个fAttrArraySize大小的QTSSAttrInfoDict数组(fAttrArray),并对其进行初始化,这里告诉我们
对于每个属性类对应的记录(属性)都将记录到fAttrArray数组当中,并且每一个属性类都将对应一个fAttrArray数组
**/
/**
2.5. How to config 
QTSSAttrInfoDict的配置和读取,再回到QTSSDictionaryMap::Initialize()函数在创建
kAttrInfoDictIndex->QTSS_AttrInfoObject数据类型对应得属性类型后,需要对其中的属性或记录
进行静态设置
**/
void QTSSDictionaryMap::Initialize()
{
    sDictionaryMaps[kAttrInfoDictIndex] = new QTSSDictionaryMap(qtssAttrInfoNumParams);
    // Setup the Attr Info attributes before constructing any other dictionaries
    // 这里是使用QTSSAttrInfoDict::sAttributes数组来初始化上面创建的fAttrArray数组
    for (UInt32 x = 0; x < qtssAttrInfoNumParams; x++)
        sDictionaryMaps[kAttrInfoDictIndex]->SetAttribute(x,
        QTSSAttrInfoDict::sAttributes[x].fAttrName,
        QTSSAttrInfoDict::sAttributes[x].fFuncPtr,
        QTSSAttrInfoDict::sAttributes[x].fAttrDataType,
        QTSSAttrInfoDict::sAttributes[x].fAttrPermission);
	//qtssAttrInfoNumParams对应QTSS_AttrInfoObjectAttributes这个属性包含多少条记录(属性)
	//通过QTSSDictionaryMap::SetAttribute来配置属性
}
/**
qtssAttrInfoNumParams为4,所以在构造QTSSDictionaryMap的同时会为我们分配20个QTSSAttrInfoDict
对象,但是这里只初始化了4个,所以剩下的16个应该是用于后用吧?设置属性使用SetAttribute函数
它的实现如下:
@inID:index of attribute 0~20...
@inAttrName:attr of Name...
@inFuncPtr: attr of callback
@inDataType: attr of data type int bool or ?
@inPermission: attr of operation of permission write or read or ?
**/
void QTSSDictionaryMap::SetAttribute(
	QTSS_AttributeID inID, 
	const char* inAttrName,
	QTSS_AttrFunctionPtr inFuncPtr,
	QTSS_AttrDataType inDataType,
	QTSS_AttrPermission inPermission)
{
	//theIndex 每条属性在当前属性类目中的ID索引,应该对应的fNextAvailableID
    UInt32 theIndex = QTSSDictionaryMap::ConvertAttrIDToArrayIndex(inID);
    UInt32 theNameLen = ::strlen(inAttrName);
    //在前面只是为fAttrArray分配了至少20个大小QTSSAttrInfoDict的空间
    //并将其空间初始化成0,在这里对于每一条属性都应当创建一个QTSSAttrInfoDict实例
    fAttrArray[theIndex] = NEW QTSSAttrInfoDict;
    
    //Copy the information into the first available element
    fAttrArray[theIndex]->fID = inID;
    //将QTSSAttrInfoDict::sAttributes数组中的信息保存到fAttrArray[theIndex]
    ::strcpy(&fAttrArray[theIndex]->fAttrInfo.fAttrName[0], inAttrName);
    fAttrArray[theIndex]->fAttrInfo.fFuncPtr = inFuncPtr;
    fAttrArray[theIndex]->fAttrInfo.fAttrDataType = inDataType; 
    fAttrArray[theIndex]->fAttrInfo.fAttrPermission = inPermission;
	
    //对应每一条属性回调QTSSAttrInfoDict->SetVal函数
	//配置属性名字
    fAttrArray[theIndex]->SetVal(qtssAttrName, 
        &fAttrArray[theIndex]->fAttrInfo.fAttrName[0], theNameLen);
	//配置属性id 也就是记录fNextAvailableID
    fAttrArray[theIndex]->SetVal(qtssAttrID, 
        &fAttrArray[theIndex]->fID, sizeof(fAttrArray[theIndex]->fID));
	//记录该条记录的数据类型	
    fAttrArray[theIndex]->SetVal(qtssAttrDataType, 
        &fAttrArray[theIndex]->fAttrInfo.fAttrDataType, 
        sizeof(fAttrArray[theIndex]->fAttrInfo.fAttrDataType));
	//记录操作权限
    fAttrArray[theIndex]->SetVal(qtssAttrPermissions, 
    &fAttrArray[theIndex]->fAttrInfo.fAttrPermission,
        sizeof(fAttrArray[theIndex]->fAttrInfo.fAttrPermission));
}
/**
上面函数主要分成三步
a)首先为fAttrArray指针数组所对应的元素分配内存
b)使用QTSSAttrInfoDict::sAttributes静态成员数组信息初始化刚创建的QTSSAttrInfoDict对象
c)调用SetVal将QTSSAttrInfoDict对象中的相关信息保存到QTSSDictionary的fAttributes对象.
根据以上三个步骤继续往下分析,那么QTSSDictionary::SetValue函数又做了什么?继续往下分析
在上面的分析过程中,初始化fAttrArray[theIndex]后,回调了它父类的SetVal函数,它究竟做了什么?
首先当我们new QTSSAttrInfoDict的同时,它的父类被构造,我们先分析QTSSAttrInfoDict的构造
然后再分析它父类QTSSDictionary的构造,最后我们分析QTSSDictionary::SetVal函数的实现
**/
/**
2.6.QTSSAttrInfoDict类的构造过程
它定义如下:
**/
QTSSAttrInfoDict::QTSSAttrInfoDict()
    : QTSSDictionary(QTSSDictionaryMap::GetMap(QTSSDictionaryMap::kAttrInfoDictIndex)), 
    fID(qtssIllegalAttrID)
{
    //注意这里传参数QTSSDictionary(QTSSDictionaryMap::
    //GetMap(QTSSDictionaryMap::kAttrInfoDictIndex))
    //也就是说对于父类QTSSDictionary而言不管是那个部件kAttrInfoDictIndex~
    //k3GPPRTSPSessionDictIndex都是将QTSSDictionaryMap::kAttrInfoDictIndex
    //作为参数传递进去
}
/*从QTSSAttrInfoDict的构造函数可以看出所有的功能在创建QTSSDictionaryMap的时候都被初始化成
kAttrInfoDictIndex类型的值了.另外就是AttrInfo结构体中的成员变量,这也说明了
对于每个属性类中对应的记录(属性)对应的QTSSDictionaryMap都记录在kAttrInfoDictIndex
当中
*/

/*
2.7.认识QTSSAttrInfoDict的父类QTSSDictionary
*/
class QTSSDictionary : public QTSSStream
{
public:
    QTSSDictionary(QTSSDictionaryMap* inMap, OSMutex* inMutex = NULL);
    virtual ~QTSSDictionary();
private:    
    struct DictValueElement
    {
        // This stores all necessary information for each attribute value.
        
        DictValueElement() :fAllocatedLen(0), fNumAttributes(0),
                            fAllocatedInternally(false), fIsDynamicDictionary(false) {}                         
        // Does not delete! You Must call DeleteAttributeData for that
        ~DictValueElement() {}
        StrPtrLen   fAttributeData; // The data
        UInt32      fAllocatedLen;  // How much space do we have allocated?
        UInt32      fNumAttributes; // If this is an iterated attribute, how many?
        Bool16      fAllocatedInternally; //Should we delete this memory?
        Bool16      fIsDynamicDictionary; //is this a dictionary object?
    };
	DictValueElement* fAttributes;//每条记录应当对应一个DictValueElement结构体
	DictValueElement* fInstanceAttrs;
	UInt32 fInstanceArraySize;
	QTSSDictionaryMap* fMap;
	QTSSDictionaryMap* fInstanceMap;
	OSMutex* fMutexP;
};     

/*
在创建QTSSAttrInfoDict对象的同时QTSSDictionary同时被创建,它的构造函数如下
*/
QTSSDictionary::QTSSDictionary(QTSSDictionaryMap* inMap, OSMutex* inMutex) 
	: fAttributes(NULL)
	, fInstanceAttrs(NULL)
	, fInstanceArraySize(0)
	, fMap(inMap)
	, fInstanceMap(NULL)
	, fMutexP(inMutex)
	, fMyMutex(false)
	, fLocked(false)
{
    if (fMap != NULL)
        fAttributes = NEW DictValueElement[inMap->GetNumAttrs()];
	if (fMutexP == NULL)
	{
		fMyMutex = true;
		fMutexP = NEW OSMutex();
	}
}
/*
在QTSSDictionaryMap::Initialize()函数当中new QTSSDictionaryMap对象的时候会传递实际使用的属性树
个数这个值被赋值到QTSSDictionaryMap对象中的fNextAvailableID成员变量用来表示实际有效的属性条数?
结合QTSSDictionary的构造函数那么上面函数inMap->GetNumAttrs()返回的值就是kAttrInfoDictIndex类型
返回的fNextAvailableID的值所以始终为4,在QTSSDictionary对象中为我们分配了4个DictValueElement对象
并记录到QTSSDictionary类的成员变量fAttributes当中,再结合2.5中初始化完fAttrArray[theIndex]后
会使用QTSSDictionary::SetVal函数来初始化QTSSDictionary::fAttributes成员变量,所以fAttributes就是用来
保存这4条属性的,从上面的分析可以看出,对于每一个QTSSDictionaryMap管理的QTSSAttrInfoDict,都会对应
一个DictValueElement*指针,也就是包含4条属性值,这里的意思就是对于每个类别的属性类目,都有若干条属性记录
而每条属性记录都应该用一个DictValueElement*指针来维护,保存在当前QTSSDictionary的fAttributes当中
name,id,datatype,qtssAttrPermissions.所以在这里,对于属性中的每条记录而言,每条记录都应当包含4个
DictValueElement结构体也就是DictValueElement*指针,如果将DictValueElement*指针看成一个数组
那么它从0到3数组编号分别保存的就是当前记录对应的名字,当前记录在该记录类目中的索引,当前记录的数据类型,
当前记录的操作权限
*/
QTSSDictionary::~QTSSDictionary()
{
    if (fMap != NULL)
        this->DeleteAttributeData(fAttributes, fMap->GetNumAttrs(), fMap);
    if (fAttributes != NULL)
        delete [] fAttributes;
    this->DeleteAttributeData(fInstanceAttrs, fInstanceArraySize, fInstanceMap);
    delete [] fInstanceAttrs;
    delete fInstanceMap;
	if (fMyMutex)
		delete fMutexP;
}

/**
2.8.QTSSDictionary::SetVal函数的实现
**/
void QTSSDictionary::SetVal(QTSS_AttributeID inAttrID,
                            void* inValueBuffer,
                            UInt32 inBufferLen) { 
    Assert(inAttrID >= 0);
    Assert(fMap);
    Assert((UInt32)inAttrID < fMap->GetNumAttrs());
    fAttributes[inAttrID].fAttributeData.Ptr = (char*)inValueBuffer;
    fAttributes[inAttrID].fAttributeData.Len = inBufferLen;
    fAttributes[inAttrID].fAllocatedLen = inBufferLen;
    // This function assumes there is only one value and that it isn't allocated internally
    fAttributes[inAttrID].fNumAttributes = 1;
}



 
      
