#import "CryptoModule.h"

#import <CommonCrypto/CommonCryptor.h>
#import <Security/Security.h>

@implementation CryptoModule

RCT_EXPORT_MODULE();

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

- (NSData *)decodeBase64:(NSString *)value {
  if (value.length == 0) return [NSData data];
  return [[NSData alloc] initWithBase64EncodedString:value options:NSDataBase64DecodingIgnoreUnknownCharacters] ?: [NSData data];
}

- (NSString *)encodeBase64:(NSData *)data {
  return [data base64EncodedStringWithOptions:0] ?: @"";
}

- (NSData *)normalizedIV:(NSData *)ivData {
  NSMutableData *result = [NSMutableData dataWithLength:kCCBlockSizeAES128];
  NSUInteger copyLength = MIN(ivData.length, kCCBlockSizeAES128);
  if (copyLength > 0) {
    [result replaceBytesInRange:NSMakeRange(0, copyLength) withBytes:[ivData bytes]];
  }
  return result;
}

- (NSString *)aesEncryptInternal:(NSString *)text key:(NSString *)key iv:(NSString *)iv mode:(NSString *)mode {
  NSData *rawData = [self decodeBase64:text];
  NSData *rawKey = [self decodeBase64:key];
  NSData *rawIv = [self decodeBase64:iv];
  if (rawKey.length == 0) return @"";

  CCOptions options = kCCOptionPKCS7Padding;
  const void *ivBytes = nil;
  if ([mode isEqualToString:@"AES/CBC/PKCS7Padding"]) {
    NSData *ivToUse = [self normalizedIV:rawIv];
    ivBytes = [ivToUse bytes];
  } else {
    options |= kCCOptionECBMode;
  }

  size_t outputLength = rawData.length + kCCBlockSizeAES128;
  void *output = calloc(1, outputLength);
  size_t moved = 0;
  CCCryptorStatus status = CCCrypt(kCCEncrypt,
                                   kCCAlgorithmAES,
                                   options,
                                   [rawKey bytes],
                                   rawKey.length,
                                   ivBytes,
                                   [rawData bytes],
                                   rawData.length,
                                   output,
                                   outputLength,
                                   &moved);
  if (status != kCCSuccess) {
    free(output);
    return @"";
  }
  NSData *encrypted = [NSData dataWithBytesNoCopy:output length:moved freeWhenDone:YES];
  return [self encodeBase64:encrypted];
}

- (NSString *)aesDecryptInternal:(NSString *)text key:(NSString *)key iv:(NSString *)iv mode:(NSString *)mode {
  NSData *rawData = [self decodeBase64:text];
  NSData *rawKey = [self decodeBase64:key];
  NSData *rawIv = [self decodeBase64:iv];
  if (rawKey.length == 0) return @"";

  CCOptions options = kCCOptionPKCS7Padding;
  const void *ivBytes = nil;
  if ([mode isEqualToString:@"AES/CBC/PKCS7Padding"]) {
    NSData *ivToUse = [self normalizedIV:rawIv];
    ivBytes = [ivToUse bytes];
  } else {
    options |= kCCOptionECBMode;
  }

  size_t outputLength = rawData.length + kCCBlockSizeAES128;
  void *output = calloc(1, outputLength);
  size_t moved = 0;
  CCCryptorStatus status = CCCrypt(kCCDecrypt,
                                   kCCAlgorithmAES,
                                   options,
                                   [rawKey bytes],
                                   rawKey.length,
                                   ivBytes,
                                   [rawData bytes],
                                   rawData.length,
                                   output,
                                   outputLength,
                                   &moved);
  if (status != kCCSuccess) {
    free(output);
    return @"";
  }
  NSData *decrypted = [NSData dataWithBytesNoCopy:output length:moved freeWhenDone:YES];
  return [[NSString alloc] initWithData:decrypted encoding:NSUTF8StringEncoding] ?: @"";
}

- (SecKeyRef)publicKeyFromBase64:(NSString *)publicKey {
  NSData *keyData = [self decodeBase64:publicKey];
  if (keyData.length == 0) return nil;
  NSDictionary *attrs = @{
    (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
    (__bridge id)kSecAttrKeyClass: (__bridge id)kSecAttrKeyClassPublic,
    (__bridge id)kSecAttrKeySizeInBits: @(keyData.length * 8),
  };
  return SecKeyCreateWithData((__bridge CFDataRef)keyData, (__bridge CFDictionaryRef)attrs, nil);
}

- (SecKeyRef)privateKeyFromBase64:(NSString *)privateKey {
  NSData *keyData = [self decodeBase64:privateKey];
  if (keyData.length == 0) return nil;
  NSDictionary *attrs = @{
    (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
    (__bridge id)kSecAttrKeyClass: (__bridge id)kSecAttrKeyClassPrivate,
    (__bridge id)kSecAttrKeySizeInBits: @(keyData.length * 8),
  };
  return SecKeyCreateWithData((__bridge CFDataRef)keyData, (__bridge CFDictionaryRef)attrs, nil);
}

- (NSString *)rsaEncryptInternal:(NSString *)text key:(NSString *)key padding:(NSString *)padding {
  SecKeyRef keyRef = [self publicKeyFromBase64:key];
  if (keyRef == nil) return @"";
  NSData *plainData = [self decodeBase64:text];
  SecKeyAlgorithm algorithm = [padding isEqualToString:@"RSA/ECB/OAEPWithSHA1AndMGF1Padding"]
    ? kSecKeyAlgorithmRSAEncryptionOAEPSHA1
    : kSecKeyAlgorithmRSAEncryptionRaw;
  if (!SecKeyIsAlgorithmSupported(keyRef, kSecKeyOperationTypeEncrypt, algorithm)) {
    CFRelease(keyRef);
    return @"";
  }
  CFErrorRef error = nil;
  CFDataRef encryptedData = SecKeyCreateEncryptedData(keyRef, algorithm, (__bridge CFDataRef)plainData, &error);
  CFRelease(keyRef);
  if (encryptedData == nil) {
    if (error != nil) CFRelease(error);
    return @"";
  }
  NSData *result = CFBridgingRelease(encryptedData);
  if (error != nil) CFRelease(error);
  return [self encodeBase64:result];
}

- (NSString *)rsaDecryptInternal:(NSString *)text key:(NSString *)key padding:(NSString *)padding {
  SecKeyRef keyRef = [self privateKeyFromBase64:key];
  if (keyRef == nil) return @"";
  NSData *cipherData = [self decodeBase64:text];
  SecKeyAlgorithm algorithm = [padding isEqualToString:@"RSA/ECB/OAEPWithSHA1AndMGF1Padding"]
    ? kSecKeyAlgorithmRSAEncryptionOAEPSHA1
    : kSecKeyAlgorithmRSAEncryptionRaw;
  if (!SecKeyIsAlgorithmSupported(keyRef, kSecKeyOperationTypeDecrypt, algorithm)) {
    CFRelease(keyRef);
    return @"";
  }
  CFErrorRef error = nil;
  CFDataRef plainData = SecKeyCreateDecryptedData(keyRef, algorithm, (__bridge CFDataRef)cipherData, &error);
  CFRelease(keyRef);
  if (plainData == nil) {
    if (error != nil) CFRelease(error);
    return @"";
  }
  NSData *result = CFBridgingRelease(plainData);
  if (error != nil) CFRelease(error);
  return [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding] ?: @"";
}

RCT_REMAP_METHOD(rsaEncrypt,
                 rsaEncrypt:(NSString *)text
                 key:(NSString *)key
                 padding:(NSString *)padding
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {
  (void)reject;
  resolve([self rsaEncryptInternal:text key:key padding:padding]);
}

RCT_REMAP_METHOD(rsaDecrypt,
                 rsaDecrypt:(NSString *)text
                 key:(NSString *)key
                 padding:(NSString *)padding
                 resolver2:(RCTPromiseResolveBlock)resolve
                 rejecter2:(RCTPromiseRejectBlock)reject) {
  (void)reject;
  resolve([self rsaDecryptInternal:text key:key padding:padding]);
}

RCT_REMAP_METHOD(aesEncrypt,
                 aesEncrypt:(NSString *)text
                 key:(NSString *)key
                 iv:(NSString *)iv
                 mode:(NSString *)mode
                 resolver3:(RCTPromiseResolveBlock)resolve
                 rejecter3:(RCTPromiseRejectBlock)reject) {
  (void)reject;
  resolve([self aesEncryptInternal:text key:key iv:iv mode:mode]);
}

RCT_REMAP_METHOD(aesDecrypt,
                 aesDecrypt:(NSString *)text
                 key:(NSString *)key
                 iv:(NSString *)iv
                 mode:(NSString *)mode
                 resolver4:(RCTPromiseResolveBlock)resolve
                 rejecter4:(RCTPromiseRejectBlock)reject) {
  (void)reject;
  resolve([self aesDecryptInternal:text key:key iv:iv mode:mode]);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(rsaEncryptSync:(NSString *)text key:(NSString *)key padding:(NSString *)padding) {
  return [self rsaEncryptInternal:text key:key padding:padding];
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(rsaDecryptSync:(NSString *)text key:(NSString *)key padding:(NSString *)padding) {
  return [self rsaDecryptInternal:text key:key padding:padding];
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(aesEncryptSync:(NSString *)text key:(NSString *)key iv:(NSString *)iv mode:(NSString *)mode) {
  return [self aesEncryptInternal:text key:key iv:iv mode:mode];
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(aesDecryptSync:(NSString *)text key:(NSString *)key iv:(NSString *)iv mode:(NSString *)mode) {
  return [self aesDecryptInternal:text key:key iv:iv mode:mode];
}

RCT_EXPORT_METHOD(generateRsaKey:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  NSDictionary *attributes = @{
    (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
    (__bridge id)kSecAttrKeySizeInBits: @2048,
  };
  CFErrorRef error = nil;
  SecKeyRef privateKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attributes, &error);
  if (privateKey == nil) {
    NSString *message = error != nil ? ((__bridge NSError *)error).localizedDescription : @"generate key failed";
    if (error != nil) CFRelease(error);
    reject(@"-1", message, nil);
    return;
  }
  SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
  NSData *publicData = CFBridgingRelease(SecKeyCopyExternalRepresentation(publicKey, nil));
  NSData *privateData = CFBridgingRelease(SecKeyCopyExternalRepresentation(privateKey, nil));
  if (publicKey != nil) CFRelease(publicKey);
  if (privateKey != nil) CFRelease(privateKey);
  resolve(@{
    @"publicKey": [self encodeBase64:publicData ?: [NSData data]],
    @"privateKey": [self encodeBase64:privateData ?: [NSData data]],
  });
}

@end
