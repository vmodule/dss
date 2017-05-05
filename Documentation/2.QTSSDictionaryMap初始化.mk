QTSSDictionary�ඨ������
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
}��

class QTSSAttrInfoDict : public QTSSDictionary
{
public:
	struct AttrInfo
	{
		// This is all the relevent information for each dictionary
		// attribute.
		char                    fAttrName[QTSS_MAX_ATTRIBUTE_NAME_SIZE + 1];//����
		QTSS_AttrFunctionPtr    fFuncPtr;//�ص�����
		QTSS_AttrDataType       fAttrDataType;//��������
		QTSS_AttrPermission     fAttrPermission;//Ȩ��
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
��QTSSDictionary�ඨ�忴�����Ĺ��캯�������������ָ��,���������ж�����sDictionaryMapsָ������
���ÿһ��enum��Ա����һ��QTSSDictionaryMapʵ����֮��Ӧ,Ҫ��������?�乹�캯�����£�
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
����Ĺ��캯������ݴ����inNumReservedAttrs����һ��QTSSAttrInfoDictָ������,���������
��С��inNumReservedAttrs����ֵ����

//������̬��Ա����
QTSSDictionaryMap*      QTSSDictionaryMap::sDictionaryMaps[kNumDictionaries + kNumDynamicDictionaryTypes];
UInt32                  QTSSDictionaryMap::sNextDynamicMap = kNumDictionaries;

2.5��QTSSDictionaryMap���ݽṹ��ʼ��
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
	�������kAttrInfoDictIndex��������1��QTSSDictionaryMapʵ����Ȼ��ÿһ��QTSSDictionaryMapʵ��ά����һ��
	fAttrArray�Ķ���ָ��Ҳ����QTSSAttrInfoDict*������,����������,kAttrInfoDictIndex��������Ӧ��ʵ����ά��
	4��QTSSAttrInfoDict*��ʵ��,Ȼ�����SetAttribute��ÿ��QTSSAttrInfoDict*ʵ����������
	����Ĵ��������һ��,���ÿһ��enum������ά��������Ӧ��ֵ��QTSSAttrInfoDict*
															
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
	static QTSSAttrInfoDict::AttrInfo   sAttributes[];	//ע�������̬��Ա����	
}
2.6����ʼ��QTSServerInterface��Ա�����Լ���2.5��������sDictionaryMaps�����Ӧ��
ʵ��ʹ��sAttributes��̬��Ա�����������
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