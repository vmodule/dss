/*****************************************************
2.5 首先看QTSSDictionaryMap的初始化过程
******************************************************/
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
2.5.1.QTSSDictionaryMap定义解析....
sDictionaryMaps为class QTSSDictionaryMap中的静态指针数组,定义如下
QTSSDictionaryMap* QTSSDictionaryMap::sDictionaryMaps[kNumDictionaries + kNumDynamicDictionaryTypes];
其中kNumDictionaries和kNumDynamicDictionaryTypes的值分别为19和500在class QTSSDictionaryMap中同时也定义
了一个枚举类型它的值分别是kServerDictIndex～kIllegalDictionary从上述初始化函数以及class QTSSDictionaryMap
的成员变量我们可以看出在DSS中对应的每一个kServerDictIndex～k3GPPRTSPSessionDictIndex的enum索引都将在此分配
一个QTSSDictionaryMap实例,并且class QTSSDictionaryMap也提供了GetMap(UInt32 inIndex)成员方法用于访问每一个
索引对应的QTSSDictionaryMap实例子,其中QTSSDictionaryMap定义如下:
**/
class QTSSDictionaryMap
{
public:
    static void Initialize();
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
    // Using one of the above predefined indexes, 
    //this returns the corresponding map
    static QTSSDictionaryMap*       GetMap(UInt32 inIndex)
};

/***
2.5.2.QTSSDictionaryMap构造函数分析
在QTSSDictionaryMap::Initialize()函数中要对每一个enum对应的索引都分配一个QTSSDictionaryMap实例
那么在它的构造函数中都做了一些什么?QTSSDictionaryMap构造函数如下
****/
QTSSDictionaryMap::QTSSDictionaryMap(UInt32 inNumReservedAttrs, UInt32 inFlags)
    :fNextAvailableID(inNumReservedAttrs), 
    fNumValidAttrs(inNumReservedAttrs),
    fAttrArraySize(inNumReservedAttrs),
    fFlags(inFlags)
{
    if (fAttrArraySize < kMinArraySize)//kMinArraySize = 20
        fAttrArraySize = kMinArraySize;
    //为fAttrArray分配至少20个大小QTSSAttrInfoDict对象的空间
    fAttrArray = NEW QTSSAttrInfoDict*[fAttrArraySize];
    ::memset(fAttrArray, 0, sizeof(QTSSAttrInfoDict*) * fAttrArraySize);
}
/**
QTSSDictionaryMap构造函数需要传入两个参数,一个是ReservedAttrs的数量,另一个是标志,这里暂且不知它是
什么玩意,在构造函数中会为我们new了一个QTSSAttrInfoDict*的数组,这里只是分配了这么大的内存空间,
其中数组的大小至少为20,如果大于20则它的大小依赖与传入的第一个参数也就是inNumReservedAttrs的值,
那么QTSSAttrInfoDict是什么?fAttrArray又是什么?fAttrArray是一个QTSSAttrInfoDict**的二级指针,
说白了就是QTSSAttrInfoDict*的数组,并且QTSSAttrInfoDict是QTSSDictionary的子类
**/
class QTSSDictionaryMap
{
public:
    enum
    {
        kMinArraySize = 20
    };
    UInt32                          fNextAvailableID;
    UInt32                          fNumValidAttrs;
    UInt32                          fAttrArraySize;
    QTSSAttrInfoDict**              fAttrArray;
    UInt32                          fFlags;
};
/**
结合上面的分析我们可以得出DSS中存在一个全局的QTSSDictionaryMap对象数组名字叫sDictionaryMaps
它的大小目前是19,也就是kServerDictIndex～k3GPPRTSPSessionDictIndex,并且每一个数组元素又
维护了至少20个QTSSAttrInfoDict*的指针,也就是至少20个QTSSDictionary*指针,如果说DSS服务器包含
kServerDictIndex到k3GPPRTSPSessionDictIndex个部件,那么他们每一种功能就至少包含20中属性树,并且每一种
属性树用一个QTSSDictionary对象来描述
**/
/**
2.5.3.每一种属性树究竟包含多少种属性?
回到QTSSDictionaryMap::Initialize()函数中结合QTSSDictionaryMap构造函数的传参过程
找到它传入参数的定义的地方在apistublib/QTSS.h文件当中,DSS将属性归类成如下,每一类属性
树都被定义成一个枚举类型
**/
typedef UInt32 QTSS_RTPStreamAttributes;
typedef UInt32 QTSS_RTPStream3GPPAttributes; //QTSS_3GPPStreamObject
typedef UInt32 QTSS_ClientSessionAttributes;
typedef UInt32 QTSS_ClientSession3GPPAttributes;
typedef UInt32 QTSS_RTSPSessionAttributes;
typedef UInt32 QTSS_3GPPRTSPSessionAttributes;
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
2.5.4.QTSSAttrInfoDict的配置和读取,再回到QTSSDictionaryMap::Initialize()函数在创建kAttrInfoDictIndex
对应的属性树之后,有对其属性惊喜初始化操作
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
void QTSSDictionaryMap::SetAttribute(QTSS_AttributeID inID, 
                                    const char* inAttrName,
                                    QTSS_AttrFunctionPtr inFuncPtr,
                                    QTSS_AttrDataType inDataType,
                                    QTSS_AttrPermission inPermission )
{
    UInt32 theIndex = QTSSDictionaryMap::ConvertAttrIDToArrayIndex(inID);
    UInt32 theNameLen = ::strlen(inAttrName);
    Assert(theNameLen < QTSS_MAX_ATTRIBUTE_NAME_SIZE);
    Assert(fAttrArray[theIndex] == NULL);
    //在前面只是为fAttrArray分配了至少20个大小QTSSAttrInfoDict的空间
    //并将其空间初始化成0,在这里为fAttrArray数组中的元素分配内存
    fAttrArray[theIndex] = NEW QTSSAttrInfoDict;
    
    //Copy the information into the first available element
    fAttrArray[theIndex]->fID = inID;
    //将QTSSAttrInfoDict::sAttributes数组中的信息保存到fAttrArray[theIndex]
    ::strcpy(&fAttrArray[theIndex]->fAttrInfo.fAttrName[0], inAttrName);
    fAttrArray[theIndex]->fAttrInfo.fFuncPtr = inFuncPtr;
    fAttrArray[theIndex]->fAttrInfo.fAttrDataType = inDataType; 
    fAttrArray[theIndex]->fAttrInfo.fAttrPermission = inPermission;
    //调用SetVal
    fAttrArray[theIndex]->SetVal(qtssAttrName, 
        &fAttrArray[theIndex]->fAttrInfo.fAttrName[0], theNameLen);
    fAttrArray[theIndex]->SetVal(qtssAttrID, 
        &fAttrArray[theIndex]->fID, sizeof(fAttrArray[theIndex]->fID));
    fAttrArray[theIndex]->SetVal(qtssAttrDataType, 
        &fAttrArray[theIndex]->fAttrInfo.fAttrDataType, 
        sizeof(fAttrArray[theIndex]->fAttrInfo.fAttrDataType));
    fAttrArray[theIndex]->SetVal(qtssAttrPermissions, 
    &fAttrArray[theIndex]->fAttrInfo.fAttrPermission,
        sizeof(fAttrArray[theIndex]->fAttrInfo.fAttrPermission));
}
/**
上面函数主要分成三步
a)首先为fAttrArray指针数组所对应的元素分配内存
b)使用QTSSAttrInfoDict::sAttributes静态成员数组信息初始化刚创建的
QTSSAttrInfoDict对象
c)调用SetVal将QTSSAttrInfoDict对象中的相关信息保存到QTSSDictionaryMap的
fAttributes对象.
根据以上三个步骤继续往下分析,那么QTSSDictionary::SetValue函数又做了什么?继续往下分析
在上面的分析过程中,初始化fAttrArray[theIndex]后,回调了它父类的SetVal函数,它究竟做了什么?
首先当我们new QTSSAttrInfoDict的同时,它的父类被构造,我们先分析QTSSAttrInfoDict的构造
然后再分析它父类QTSSDictionary的构造,最后我们分析QTSSDictionary::SetVal函数的实现
**/
/**
2.5.5.认识QTSSAttrInfoDict类
它定义如下:
**/
class QTSSAttrInfoDict : public QTSSDictionary
{
public:
    struct AttrInfo
    {
        // This is all the relevent information for each dictionary
        // attribute.
        char  fAttrName[QTSS_MAX_ATTRIBUTE_NAME_SIZE + 1];
        QTSS_AttrFunctionPtr    fFuncPtr;//函数指针
        QTSS_AttrDataType       fAttrDataType;//数据类型
        QTSS_AttrPermission     fAttrPermission;//操作权限
    };
    QTSSAttrInfoDict();
    virtual ~QTSSAttrInfoDict();
private:
    AttrInfo fAttrInfo;
    QTSS_AttributeID fID;
    static AttrInfo sAttributes[];
    friend class QTSSDictionaryMap;
};
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
kAttrInfoDictIndex类型的值了.另外就是AttrInfo结构提中的成员变量
*/

/*
2.5.6.认识QTSSAttrInfoDict的父类QTSSDictionary
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
    DictValueElement*   fAttributes;        
};        
/*
在创建QTSSAttrInfoDict对象的同时QTSSDictionary同时被创建,它的构造函数如下
*/
QTSSDictionary::QTSSDictionary(QTSSDictionaryMap* inMap, OSMutex* inMutex) 
:   fAttributes(NULL), fInstanceAttrs(NULL), fInstanceArraySize(0),
    fMap(inMap), fInstanceMap(NULL), fMutexP(inMutex), fMyMutex(false),
    fLocked(false)
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
个数这个值被赋值到QTSSDictionaryMap对象中的fNextAvailableID成员变量用来表示实际有效的属性个数?
结合QTSSDictionary的构造函数那么上面函数inMap->GetNumAttrs()返回的值就是kAttrInfoDictIndex类型
返回的fNextAvailableID的值所以始终为4,在QTSSDictionary对象中为我们分配了4个DictValueElement对象
并记录到QTSSDictionary类的成员变量fAttributes当中,再结合2.5.4中初始化完fAttrArray[theIndex]后
会使用QTSSDictionary::SetVal函数来初始化QTSSDictionary::fAttributes成员变量,所以fAttributes就是用来
保存这4条属性的,从上面的分析可以看出,对于每一个QTSSDictionaryMap管理的QTSSAttrInfoDict,都会对应
一个DictValueElement*指针,也就是包含4条属性值
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
2.5.7.QTSSDictionary::SetVal函数的实现
在2.5.4当中构造QTSSAttrInfoDict并初始化,过程中会同时构造它的父类QTSSDictionary,然而在
QTSSDictionary构造函数当中根据new QTSSDictionaryMap(qtssAttrInfoNumParams)传递下来的
参数会帮我们new一个fAttributes指针,它的大小就是对应每个QTSSAttrInfoDict对象包含多少条
属性,这里称为属性元素,在这列对于qtssAttrInfoNumParams类型的QTSSAttrInfoDict来说,它包含
4条属性分别是qtssAttrName,qtssAttrID,qtssAttrDataType,qtssAttrPermissions,事实上每个属性
目录都是记录4条属性
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
/*
到此QTSSDictionaryMap::Initialize()过程就算分析完了
*/
