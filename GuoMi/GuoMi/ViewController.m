//
//  ViewController.m
//  GuoMi
//
//  Created by XUZY on 2022/2/15.
//

#import "ViewController.h"
#import "GMObjC.h"

#define GMMainBundle(name) [[NSBundle bundleForClass:[self class]] pathForResource:name ofType:nil]

@interface ViewController ()

@property (nonatomic, copy) NSString *gPwd;    // 测试用密码
@property (nonatomic, copy) NSString *gPubkey; // 测试用公钥
@property (nonatomic, copy) NSString *gPrikey; // 测试用私钥
@property (nonatomic, strong) UITextView *gTextView;

@end

@implementation ViewController

///MARK: - Life

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    NSLog(@"GMObjC 版本：%d", GMOBJC_VERSION_NUMBER);
    NSLog(@"GMObjC 版本：%s", GMOBJC_VERSION_TEXT);
    // 初始化测试用密码、公钥，私钥
    self.gPwd = @"123456";
    self.gPubkey = @"0408E3FFF9505BCFAF9307E665E9229F4E1B3936437A870407EA3D97886BAFBC9"
                    "C624537215DE9507BC0E2DD276CF74695C99DF42424F28E9004CDE4678F63D698";
    self.gPrikey = @"90F3A42B9FE24AB196305FD92EC82E647616C3A3694441FB3422E7838E24DEAE";
    
    [self createUI];     // UI
    
    [self testSm2EnDe];  // sm2 加解密及 ASN1 编码解码
    [self testSm2Sign];  // sm2 签名验签及 Der 编码解码
    [self testSm3];      // sm3 摘要计算文本或文件
    [self testSm4];      // sm4 加密文本或文件
    [self testECDH];     // ECDH 密钥协商
    [self readPemDerFiles];     // 测试读取PEM/DER文件
    [self saveToPemDerFiles];   // 测试保存SM2公私钥为PEM/DER文件格式
    [self createKeyPairFiles];  // 测试创建PEM/DER格式SM2密钥对
    
    [self liveTestSm2EnDe];
    [self liveTestSm4];
}

///MARK: - UI
- (void)createUI {
    self.gTextView = [[UITextView alloc]initWithFrame:CGRectZero];
    self.gTextView.scrollEnabled = YES;
    self.gTextView.editable = NO;
    self.gTextView.font = [UIFont systemFontOfSize:14];
    self.gTextView.text = @"国密 Demo 实例";
    [self.view addSubview:self.gTextView];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    CGFloat statusBarH = 20;
    if (@available(iOS 11.0, *)) {
        statusBarH = [UIApplication sharedApplication].delegate.window.safeAreaInsets.top;
    } else {
        statusBarH = [UIApplication sharedApplication].statusBarFrame.size.height;
    }
    CGSize size = self.view.bounds.size;
    CGFloat margin = size.width > size.height ? 34 : 0;
    CGRect rect = CGRectMake(margin, statusBarH, size.width-margin*2, size.height-statusBarH);
    self.gTextView.frame = rect;
}

- (void)testSm2EnDe{
    // 生成一对新的公私钥
    NSArray *keyPair = [GMSm2Utils createKeyPair];
    NSString *pubKey = keyPair[0]; // 测试用 04 开头公钥，Hex 编码格式
    NSString *priKey = keyPair[1]; // 测试用私钥，Hex 编码格式
    
    NSString *plaintext = self.gPwd; // 明文原文 123456;
    NSString *plainHex = [GMUtils stringToHex:plaintext]; // 明文 123456 的 Hex 编码格式 313233343536
    NSData *plainData = [self.gPwd dataUsingEncoding:NSUTF8StringEncoding]; // 明文 123456 的 NSData 格式
    
    // sm2 加密，依次是普通明文，Hex 格式明文，NSData 格式明文
    NSString *enResult1 = [GMSm2Utils encryptText:plaintext publicKey:pubKey]; // 加密普通字符串
    NSString *enResult2 = [GMSm2Utils encryptHex:plainHex publicKey:pubKey]; // 加密 Hex 编码格式字符串
    NSData *enResult3 = [GMSm2Utils encryptData:plainData publicKey:pubKey]; // 加密 NSData 类型数据

    // sm2 解密
    NSString *deResult1 = [GMSm2Utils decryptToText:enResult1 privateKey:priKey]; // 解密为普通字符串明文
    NSString *deResult2 = [GMSm2Utils decryptToHex:enResult2 privateKey:priKey]; // 解密为 Hex 格式明文
    NSData *deResult3 = [GMSm2Utils decryptToData:enResult3 privateKey:priKey]; // 解密为 NSData 格式明文
    
    // 判断 sm2 加解密结果
    if ([deResult1 isEqualToString:plaintext] || [deResult2 isEqualToString:plainHex] || [deResult3 isEqualToData:plainData]) {
        NSLog(@"sm2 加密解密成功");
    }else{
        NSLog(@"sm2 加密解密失败");
    }
    
    // ASN1 解码
    NSString *c1c3c2Result1 = [GMSm2Utils asn1DecodeToC1C3C2:enResult1]; // 解码为 c1c3c2字符串
    NSArray<NSString *> *c1c3c2Result2 = [GMSm2Utils asn1DecodeToC1C3C2Array:enResult2]; // 解码为 @[c1,c3,c2]
    NSData *c1c3c2Result3 = [GMSm2Utils asn1DecodeToC1C3C2Data:enResult3]; // 解码为 c1c3c2拼接的Data
    
    // 将解码后的密文顺序更改
    NSString *convertToC1C2C3 = [GMSm2Utils convertC1C3C2ToC1C2C3:c1c3c2Result1 hasPrefix:NO];
    NSString *convertToC1C3C2 = [GMSm2Utils convertC1C2C3ToC1C3C2:convertToC1C2C3 hasPrefix:NO];
    if ([convertToC1C3C2 isEqualToString:c1c3c2Result1]) {
        NSLog(@"C1C3C2 顺序更改成功");
    }else{
        NSLog(@"C1C3C2 顺序更改失败");
    }
    
    // ASN1 编码
    NSString *asn1Result1 = [GMSm2Utils asn1EncodeWithC1C3C2:c1c3c2Result1];
    NSString *asn1Result2 = [GMSm2Utils asn1EncodeWithC1C3C2Array:c1c3c2Result2];
    NSData *asn1Result3 = [GMSm2Utils asn1EncodeWithC1C3C2Data:c1c3c2Result3];
    
    // 判断 ASN1 解码编码结果，应相等
    if ([asn1Result1 isEqualToString:enResult1] || [asn1Result2 isEqualToString:enResult2] || [asn1Result3 isEqualToData:enResult3]) {
        NSLog(@"ASN1 解码编码成功");
    }else{
        NSLog(@"ASN1 解码编码失败");
    }
    
    NSMutableString *mStr = [NSMutableString stringWithString:self.gTextView.text];
    [mStr appendString:@"\n-------SM2加解密及编码-------"];
    [mStr appendFormat:@"\n生成SM2公钥：\n%@", pubKey];
    [mStr appendFormat:@"\n生成SM2私钥：\n%@", priKey];
    [mStr appendFormat:@"\nSM2加密密文：\n%@", enResult1];
    [mStr appendFormat:@"\nASN1 解码SM2密文：\n%@", c1c3c2Result1];
    [mStr appendFormat:@"\nC1C3C2 顺序SM2密文转为 C1C2C3 顺序：\n%@", convertToC1C2C3];
    [mStr appendFormat:@"\nASN1编码SM2密文：\n%@", asn1Result1];
    [mStr appendFormat:@"\nSM2解密结果：\n%@", deResult1];
    self.gTextView.text = mStr;
}

///MARK: - SM2 签名验签

- (void)testSm2Sign{
    // 生成一对新的公私钥
    NSArray *keyPair = [GMSm2Utils createKeyPair];
    NSString *pubKey = keyPair[0]; // 测试用 04 开头公钥，Hex 编码格式
    NSString *priKey = keyPair[1]; // 测试用私钥，Hex 编码格式
    
    NSString *plaintext = self.gPwd; // 明文原文 123456;
    NSString *plainHex = [GMUtils stringToHex:plaintext]; // 明文 123456 的 Hex 编码格式 313233343536
    NSData *plainData = [self.gPwd dataUsingEncoding:NSUTF8StringEncoding]; // 明文 123456 的 NSData 格式
    
    // userID 传入 nil 或空时默认 1234567812345678；不为空时，签名和验签需要相同 ID
    NSString *userID = @"lifei_zdjl@126.com"; // 普通字符串的 userID
    NSString *userHex = [GMUtils stringToHex:userID]; // Hex 格式的 userID
    NSData *userData = [userID dataUsingEncoding:NSUTF8StringEncoding]; // NSData 格式的 userID
    
    // 签名结果是 RS 拼接的 128 字节 Hex 格式字符串，前 64 字节是 R，后 64 字节是 S
    NSString *signStr1 = [GMSm2Utils signText:plaintext privateKey:priKey userID:userID];
    NSString *signStr2 = [GMSm2Utils signHex:plainHex privateKey:priKey userHex:userHex];
    NSString *signStr3 = [GMSm2Utils signData:plainData priKey:priKey userData:userData];
    
    // 验证签名
    BOOL isOK1 = [GMSm2Utils verifyText:plaintext signRS:signStr1 publicKey:pubKey userID:userID];
    BOOL isOK2 = [GMSm2Utils verifyHex:plainHex signRS:signStr2 publicKey:pubKey userHex:userHex];
    BOOL isOK3 = [GMSm2Utils verifyData:plainData signRS:signStr3 pubKey:pubKey userData:userData];
    
    if (isOK1 && isOK2 && isOK3) {
        NSLog(@"SM2 签名验签成功");
    }else{
        NSLog(@"SM2 签名验签失败");
    }
    
    // 编码为 Der 格式
    NSString *derSign1 = [GMSm2Utils derEncode:signStr1];
    NSString *derSign2 = [GMSm2Utils derEncode:signStr2];
    NSString *derSign3 = [GMSm2Utils derEncode:signStr3];
    // 解码为 RS 字符串格式，RS 拼接的 128 字节 Hex 格式字符串，前 64 字节是 R，后 64 字节是 S
    NSString *rs1 = [GMSm2Utils derDecode:derSign1];
    NSString *rs2 = [GMSm2Utils derDecode:derSign2];
    NSString *rs3 = [GMSm2Utils derDecode:derSign3];
    
    // Der 解码编码后与原文相同
    if ([rs1 isEqualToString:signStr1] && [rs2 isEqualToString:signStr2] && [rs3 isEqualToString:signStr3]) {
        NSLog(@"SM2 Der 编码解码成功");
    }else{
        NSLog(@"SM2 Der 编码解码失败");
    }
    
    NSMutableString *mStr = [NSMutableString stringWithString:self.gTextView.text];
    [mStr appendString:@"\n-------SM2签名验签-------"];
    [mStr appendFormat:@"\nSM2签名：\n%@", signStr1];
    NSString *isSuccess = isOK1 ? @"签名验签成功":@"签名验签失败";
    [mStr appendFormat:@"\n验签结果：\n%@", isSuccess];
    [mStr appendFormat:@"\nDer编码SM2签名：\n%@", derSign1];
    [mStr appendFormat:@"\nDer解码SM2签名：\n%@", rs1];
    self.gTextView.text = mStr;
}

///MARK: - SM3 摘要计算

- (void)testSm3{
    // sm3 字符串摘要
    NSString *sm3DigPwd = [GMSm3Utils hashWithString:self.gPwd];
    // sm4TestFile.txt 文件的摘要
    NSString *txtPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"sm4TestFile.txt" ofType:nil];
    NSData *fileData = [NSData dataWithContentsOfFile:txtPath];
    NSString *sm3DigFile = [GMSm3Utils hashWithData:fileData];
    
    NSMutableString *mStr = [NSMutableString stringWithString:self.gTextView.text];
    [mStr appendString:@"\n-------SM3摘要-------"];
    [mStr appendFormat:@"\n字符串 123456 SM3摘要：\n%@", sm3DigPwd];
    [mStr appendFormat:@"\n文件 sm4TestFile.txt SM3摘要：\n%@", sm3DigFile];
    // HMAC 计算
    NSString *randomKey = @"qwertyuiop1234567890"; // 服务端传过来的 key
    [mStr appendFormat:@"\n HMAC 计算摘要使用的 key：\n%@", randomKey];
    NSString *hmacSM3 = [GMSm3Utils hmacWithSm3:randomKey plaintext:self.gPwd];
    [mStr appendFormat:@"\n字符串 123456 使用 SM3 计算 HMAC 摘要：\n%@", hmacSM3];
    NSString *hmacMD5 = [GMSm3Utils hmac:GMHashType_MD5 key:randomKey plaintext:self.gPwd];
    [mStr appendFormat:@"\n字符串 123456 使用 MD5 计算 HMAC 摘要：\n%@", hmacMD5];
    NSString *hmacSHA1 = [GMSm3Utils hmac:GMHashType_SHA1 key:randomKey plaintext:self.gPwd];
    [mStr appendFormat:@"\n字符串 123456 使用 SHA1 计算 HMAC 摘要：\n%@", hmacSHA1];
    NSString *hmacSHA224 = [GMSm3Utils hmac:GMHashType_SHA224 key:randomKey plaintext:self.gPwd];
    [mStr appendFormat:@"\n字符串 123456 使用 SHA224 计算 HMAC 摘要：\n%@", hmacSHA224];
    NSString *hmacSHA256 = [GMSm3Utils hmac:GMHashType_SHA256 key:randomKey plaintext:self.gPwd];
    [mStr appendFormat:@"\n字符串 123456 使用 SHA256 计算 HMAC 摘要：\n%@", hmacSHA256];
    NSString *hmacSHA384 = [GMSm3Utils hmac:GMHashType_SHA384 key:randomKey plaintext:self.gPwd];
    [mStr appendFormat:@"\n字符串 123456 使用 SHA384 计算 HMAC 摘要：\n%@", hmacSHA384];
    NSString *hmacSHA512 = [GMSm3Utils hmac:GMHashType_SHA512 key:randomKey plaintext:self.gPwd];
    [mStr appendFormat:@"\n字符串 123456 使用 SHA512 计算 HMAC 摘要：\n%@", hmacSHA512];
    
    self.gTextView.text = mStr;
}

///MARK: - SM4 加解密

- (void)testSm4{
    NSString *sm4Key = [GMSm4Utils createSm4Key]; //  生成 32 字节 Hex 编码格式字符串密钥
    // ECB 加解密模式
    NSString *sm4EcbCipertext = [GMSm4Utils ecbEncryptText:self.gPwd key:sm4Key isNeedHexKey:YES];
    NSString *sm4EcbPlaintext = [GMSm4Utils ecbDecryptText:sm4EcbCipertext key:sm4Key isNeedHexKey:YES];
    
    NSMutableString *mStr = [NSMutableString stringWithString:self.gTextView.text];
    [mStr appendString:@"\n-------SM4加解密-------"];
    [mStr appendFormat:@"\nSM4密钥：\n%@", sm4Key];
    [mStr appendFormat:@"\nECB 模式加密密文：\n%@", sm4EcbCipertext];
    [mStr appendFormat:@"\nECB模式解密结果：\n%@", sm4EcbPlaintext];
    
    // CBC 加解密模式
    NSString *ivec = [GMSm4Utils createSm4Key]; // 生成 32 字节初始化向量
    NSString *sm4CbcCipertext = [GMSm4Utils cbcEncryptText:self.gPwd key:sm4Key isNeedHexKey:YES IV:ivec];
    NSString *sm4CbcPlaintext = [GMSm4Utils cbcDecryptText:sm4CbcCipertext key:sm4Key isNeedHexKey:YES IV:ivec];
    
    [mStr appendFormat:@"\nCBC模式需要的16字节向量：\n%@", ivec];
    [mStr appendFormat:@"\nCBC模式加密密文：\n%@", sm4CbcCipertext];
    [mStr appendFormat:@"\nCBC模式解密结果：\n%@", sm4CbcPlaintext];
    self.gTextView.text = mStr;
    
    // 加解密文件，任意文件可读取为 NSData 格式
    NSString *txtPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"sm4TestFile.txt" ofType:nil];
    NSData *fileData = [NSData dataWithContentsOfFile:txtPath];
    // 读取的文本文件
    NSString *orginStr = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
    NSLog(@"文本文件原文：\n%@", orginStr);
    
    // ECB 模式加解密
    NSData *ecbCipherData = [GMSm4Utils ecbEncryptData:fileData key:sm4Key isNeedHexKey:YES];
    NSData *ecbDecryptData = [GMSm4Utils ecbDecryptData:ecbCipherData key:sm4Key isNeedHexKey:YES];
    // CBC 模式加解密
    NSData *cbcCipherData = [GMSm4Utils cbcEncryptData:fileData key:sm4Key isNeedHexKey:YES IV:ivec];
    NSData *cbcDecryptData = [GMSm4Utils cbcDecryptData:cbcCipherData key:sm4Key isNeedHexKey:YES IV:ivec];
    // 加解密后台文本不变
    NSString *sm4EcbFileStr = [[NSString alloc] initWithData:ecbDecryptData encoding:NSUTF8StringEncoding];
    NSString *sm4CbcFileStr = [[NSString alloc] initWithData:cbcDecryptData encoding:NSUTF8StringEncoding];
    NSLog(@"SM4 ECB 模式加解密后文本：\n%@", sm4EcbFileStr);
    NSLog(@"SM4 CBC 模式加解密后文本：\n%@", sm4CbcFileStr);
}

///MARK: - ECDH 密钥协商

- (void)testECDH {
    // 客户端client生成一对公私钥
    NSArray *clientKey = [GMSm2Utils createKeyPair];
    NSString *cPubKey = clientKey[0];
    NSString *cPriKey = clientKey[1];
    
    // 服务端server生成一对公私钥
    NSArray *serverKey = [GMSm2Utils createKeyPair];
    NSString *sPubKey = serverKey[0];
    NSString *sPriKey = serverKey[1];
    
    // 客户端client从服务端server获取公钥sPubKey，client协商出32字节对称密钥clientECDH，转Hex后为64字节
    NSString *clientECDH = [GMSm2Utils computeECDH:sPubKey privateKey:cPriKey];
    // 客户端client将公钥cPubKey发送给服务端server，server协商出32字节对称密钥serverECDH，转Hex后为64字节
    NSString *serverECDH = [GMSm2Utils computeECDH:cPubKey privateKey:sPriKey];
    
    // 在全部明文传输的情况下，client与server协商出相等的对称密钥，clientECDH==serverECDH 成立
    if ([clientECDH isEqualToString:serverECDH]) {
        NSLog(@"ECDH 密钥协商成功，协商出的对称密钥为：\n%@", clientECDH);
    }else{
        NSLog(@"ECDH 密钥协商失败");
    }
}

///MARK: - PEM/DER文件
- (void)readPemDerFiles {
    NSMutableString *mStr = [NSMutableString stringWithString:self.gTextView.text];
    [mStr appendString:@"\n-------PEM/DER密钥读取-------"];
    // PEM/DER文件路径
    NSString *publicPemPath = GMMainBundle(@"sm2pub-1.pem");
    NSString *publicDerPath = GMMainBundle(@"sm2pub-1.der");
    NSString *privatePemPath = GMMainBundle(@"sm2pri-1.pem");
    NSString *privateDerPath = GMMainBundle(@"sm2pri-1.der");
    NSString *private8PemPath = GMMainBundle(@"sm2pri8-1.pem");
    // 从PEM/DER文件中读取公私钥
    NSString *publicFromPem = [GMSm2Bio readPublicKeyFromPemFile:publicPemPath];
    NSString *publicFromDer = [GMSm2Bio readPublicKeyFromDerFile:publicDerPath];
    NSString *privateFromPem = [GMSm2Bio readPrivateKeyFromPemFile:privatePemPath];
    NSString *privateFromDer = [GMSm2Bio readPrivateKeyFromDerFile:privateDerPath];
    NSString *private8FromPem = [GMSm2Bio readPrivateKeyFromPemFile:private8PemPath];
    // 同一密钥不同格式，读取结果相同
    BOOL samePublic = [publicFromPem isEqualToString:publicFromDer];
    BOOL samePrivate1 = [privateFromPem isEqualToString:privateFromDer];
    BOOL samePrivate2 = [private8FromPem isEqualToString:privateFromDer];
    if (samePublic && samePrivate1 && samePrivate2) {
        [mStr appendFormat:@"\nSuccess：不同格式密钥文件读取结果一致"];
    }else{
        [mStr appendFormat:@"\nError: 不同格式密钥文件读取结果不一致"];
    }
    [mStr appendFormat:@"\nPEM格式公钥：\n%@", publicFromPem];
    [mStr appendFormat:@"\nDER格式公钥：\n%@", publicFromDer];
    [mStr appendFormat:@"\nPEM格式私钥：\n%@", privateFromPem];
    [mStr appendFormat:@"\nDER格式私钥：\n%@", privateFromDer];
    [mStr appendFormat:@"\nPKCS8-PEM格式私钥：\n%@", private8FromPem];
    self.gTextView.text = mStr.copy;
}

- (void)saveToPemDerFiles {
    NSMutableString *mStr = [NSMutableString stringWithString:self.gTextView.text];
    [mStr appendString:@"\n-------密钥保存为PEM/DER格式文件-------"];
    
    NSArray *keyPair = [GMSm2Utils createKeyPair];
    NSString *pubKey = keyPair[0]; // 测试用 04 开头公钥，Hex 编码格式
    NSString *priKey = keyPair[1]; // 测试用私钥，Hex 编码格式
    // 保存公私钥的文件路径
    NSString *tmpDir = NSTemporaryDirectory();
    NSString *publicPemPath = [tmpDir stringByAppendingPathComponent:@"t-public.pem"];
    NSString *publicDerPath = [tmpDir stringByAppendingPathComponent:@"t-public.der"];
    NSString *privatePemPath = [tmpDir stringByAppendingPathComponent:@"t-private.pem"];
    NSString *privateDerPath = [tmpDir stringByAppendingPathComponent:@"t-private.der"];
    // 将公私钥写入PEM/DER文件
    BOOL success1 = [GMSm2Bio savePublicKeyToPemFile:pubKey filePath:publicPemPath];
    BOOL success2 = [GMSm2Bio savePublicKeyToDerFile:pubKey filePath:publicDerPath];
    BOOL success3 = [GMSm2Bio savePrivateKeyToPemFile:priKey filePath:privatePemPath];
    BOOL success4 = [GMSm2Bio savePrivateKeyToDerFile:priKey filePath:privateDerPath];
    // 保存成功返回YES，失败NO
    if (success1 && success2 && success3 && success4) {
        NSLog(@"密钥保存为PEM/DER格式文件成功!");
    }
    // 测试：读取保存的PEM/DER密钥，和传入的公私钥一致
    NSString *publicFromPem = [GMSm2Bio readPublicKeyFromPemFile:publicPemPath];
    NSString *publicFromDer = [GMSm2Bio readPublicKeyFromDerFile:publicDerPath];
    NSString *privateFromPem = [GMSm2Bio readPrivateKeyFromPemFile:privatePemPath];
    NSString *privateFromDer = [GMSm2Bio readPrivateKeyFromDerFile:privateDerPath];
    
    BOOL samePublic1 = [publicFromPem isEqualToString:pubKey];
    BOOL samePublic2 = [publicFromDer isEqualToString:pubKey];
    BOOL samePrivate1 = [privateFromPem isEqualToString:priKey];
    BOOL samePrivate2 = [privateFromDer isEqualToString:priKey];
    if (samePublic1 && samePublic2 && samePrivate1 && samePrivate2) {
        [mStr appendFormat:@"\nSuccess：密钥保存为PEM/DER格式文件，读取与原密钥一致"];
    }else{
        [mStr appendFormat:@"\nError：密钥保存为PEM/DER格式文件，读取与原密钥不一致"];
    }
    
    [mStr appendFormat:@"\n生成的公钥：\n%@", pubKey];
    [mStr appendFormat:@"\n保存后读取的公钥：\n%@", publicFromPem];
    [mStr appendFormat:@"\n生成的私钥：\n%@", priKey];
    [mStr appendFormat:@"\n保存后读取的私钥：\n%@", privateFromPem];
    self.gTextView.text = mStr.copy;
}

- (void)createKeyPairFiles {
    NSMutableString *mStr = [NSMutableString stringWithString:self.gTextView.text];
    [mStr appendString:@"\n-------创建PEM/DER格式密钥对文件-------"];
    
    NSArray<NSString *> *pemKeyArray = [GMSm2Bio createPemKeyPairFiles];
    NSArray<NSString *> *derKeyArray = [GMSm2Bio createDerKeyPairFiles];
    NSString *publicFromPem = [GMSm2Bio readPublicKeyFromPemFile:pemKeyArray[0]];
    NSString *privateFromPem = [GMSm2Bio readPrivateKeyFromPemFile:pemKeyArray[1]];
    NSString *publicFromDer = [GMSm2Bio readPublicKeyFromDerFile:derKeyArray[0]];
    NSString *privateFromDer = [GMSm2Bio readPrivateKeyFromDerFile:derKeyArray[1]];
    
    [mStr appendFormat:@"\n生成的PEM公钥：\n%@", publicFromPem];
    [mStr appendFormat:@"\n生成的PEM私钥：\n%@", privateFromPem];
    [mStr appendFormat:@"\n生成的DER公钥：\n%@", publicFromDer];
    [mStr appendFormat:@"\n生成的DER私钥：\n%@", privateFromDer];
    self.gTextView.text = mStr.copy;
}

#pragma mark - 直播项目加解密
///MARK: - SM2 加解密

// sm2 加解密及 ASN1 编码解码

- (void)liveTestSm2EnDe {
    NSString *plaintext = @"1cli2xl22pfsvwg6"; //加密串
    NSString *pubKey = @"0479ae6a40602008ae07301d289703384b3fdbbea3515f1f8d607442ff387d79013065069c9ee7276babe95503c25a053a2c9a9ce65e35379b01293c9f1f1f90c2"; //公钥
    NSString *priKey = @"d011fbe35f1cf1de2eefb42174c502fed24f8749962cb88c8e143c3f657659db";//私钥
    
    NSString *enText = [GMSm2Utils encryptText:plaintext publicKey:pubKey]; // 使用SM2加密字符串
    NSString *asn1DecodeText = [GMSm2Utils asn1DecodeToC1C3C2:enText]; //C1C3C2解码字符串
    asn1DecodeText = [NSString stringWithFormat:@"04%@", asn1DecodeText];
    NSLog(@"加密后：%@", asn1DecodeText);

    NSString *asnPreText = [asn1DecodeText substringFromIndex:2];
    NSString *asnResult = [GMSm2Utils asn1EncodeWithC1C3C2:asnPreText]; // C1C3C2编码字符串
    NSString *deResult = [GMSm2Utils decryptToText:asnResult privateKey:priKey]; // 使用SM2解密字符串
    NSLog(@"解密后：%@", deResult);
}

- (void)liveTestSm4 {
//    sm4 加密字符串为hello,world!
//    加密key为1234567890123456
//    加密结果为768f15c2179a4178c12502e853d76df3
    NSString *plaintext = @"hello,world!"; //加密串
    NSString *sm4Key = @"1234567890123456";
    // ECB 加解密模式
    NSString *sm4EcbCipertext = [GMSm4Utils ecbEncryptText:plaintext key:sm4Key isNeedHexKey:NO];
    NSLog(@"加密 --- %@", sm4EcbCipertext);
    NSString *sm4EcbPlaintext = [GMSm4Utils ecbDecryptText:sm4EcbCipertext key:sm4Key isNeedHexKey:NO];
    NSLog(@"解密 --- %@", sm4EcbPlaintext);
}

@end

