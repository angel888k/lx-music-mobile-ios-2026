#import "UserApiModule.h"

#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <React/RCTBridgeModule.h>
#import <Security/Security.h>

static NSString * const kUserApiEventName = @"api-action";

@interface UserApiModule() <RCTBridgeModule>

@property (nonatomic, strong) JSContext *context;
@property (nonatomic, strong) dispatch_queue_t jsQueue;
@property (nonatomic, copy) NSString *scriptKey;
@property (nonatomic, strong) NSDictionary *loadScriptInfo;
@property (nonatomic, assign) BOOL hasListeners;
@property (nonatomic, assign) BOOL didInit;
@property (nonatomic, assign) NSUInteger runtimeToken;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *pendingEvents;

@end

@implementation UserApiModule

RCT_EXPORT_MODULE();

+ (BOOL)requiresMainQueueSetup {
  return YES;
}

- (instancetype)init {
  self = [super init];
  if (self != nil) {
    _jsQueue = dispatch_queue_create("cn.toside.music.mobile.userApi", DISPATCH_QUEUE_SERIAL);
    _runtimeToken = 0;
    _pendingEvents = [NSMutableArray array];
  }
  return self;
}

- (NSArray<NSString *> *)supportedEvents {
  return @[kUserApiEventName];
}

- (void)startObserving {
  self.hasListeners = YES;
  if (self.pendingEvents.count > 0) {
    NSArray<NSDictionary *> *events = [self.pendingEvents copy];
    [self.pendingEvents removeAllObjects];
    for (NSDictionary *event in events) {
      [self sendEventWithName:kUserApiEventName body:event];
    }
  }
}

- (void)stopObserving {
  self.hasListeners = NO;
}

- (void)sendApiEvent:(NSDictionary *)payload {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (!self.hasListeners) {
      [self.pendingEvents addObject:payload];
      return;
    }
    [self sendEventWithName:kUserApiEventName body:payload];
  });
}

- (void)sendLogEventWithType:(NSString *)type log:(NSString *)log {
  if (log == nil) log = @"";
  [self sendApiEvent:@{
    @"action": @"log",
    @"type": type ?: @"log",
    @"log": log,
  }];
}

- (void)sendInitFailed:(NSString *)message {
  NSString *errorMessage = message.length ? message : @"Create JavaScript Env Failed";
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@{
    @"info": [NSNull null],
    @"status": @NO,
    @"errorMessage": errorMessage,
  } options:0 error:nil];
  NSString *data = jsonData != nil ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"{\"info\":null,\"status\":false}";
  [self sendApiEvent:@{
    @"action": @"init",
    @"errorMessage": errorMessage,
    @"data": data,
  }];
  [self sendLogEventWithType:@"error" log:errorMessage];
}

- (NSString *)preloadScript {
  NSString *path = [[NSBundle mainBundle] pathForResource:@"user-api-preload" ofType:@"js"];
  if (path == nil) return nil;
  return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
}

- (NSString *)truncateLog:(NSString *)message {
  if (message.length <= 1024) return message;
  return [[message substringToIndex:1024] stringByAppendingString:@"..."];
}

- (NSData *)decodeBase64:(NSString *)value {
  if (value.length == 0) return [NSData data];
  return [[NSData alloc] initWithBase64EncodedString:value options:NSDataBase64DecodingIgnoreUnknownCharacters] ?: [NSData data];
}

- (NSString *)encodeBase64:(NSData *)data {
  return [data base64EncodedStringWithOptions:0] ?: @"";
}

- (NSString *)jsonArrayStringFromData:(NSData *)data {
  const unsigned char *bytes = (const unsigned char *)[data bytes];
  NSMutableArray<NSNumber *> *result = [NSMutableArray arrayWithCapacity:data.length];
  for (NSUInteger idx = 0; idx < data.length; idx++) {
    int8_t value = (int8_t)bytes[idx];
    [result addObject:@(value)];
  }
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
  return jsonData != nil ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"[]";
}

- (NSString *)md5FromEncodedString:(NSString *)value {
  NSString *decoded = value.stringByRemovingPercentEncoding ?: value;
  const char *cStr = decoded.UTF8String;
  unsigned char digest[CC_MD5_DIGEST_LENGTH];
  CC_MD5(cStr, (CC_LONG)strlen(cStr), digest);
  NSMutableString *result = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
  for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
    [result appendFormat:@"%02x", digest[i]];
  }
  return result;
}

- (NSData *)normalizedIV:(NSData *)ivData {
  NSMutableData *result = [NSMutableData dataWithLength:kCCBlockSizeAES128];
  NSUInteger copyLength = MIN(ivData.length, kCCBlockSizeAES128);
  if (copyLength > 0) {
    [result replaceBytesInRange:NSMakeRange(0, copyLength) withBytes:[ivData bytes]];
  }
  return result;
}

- (NSString *)aesEncryptData:(NSString *)data key:(NSString *)key iv:(NSString *)iv mode:(NSString *)mode {
  NSData *rawData = [self decodeBase64:data];
  NSData *rawKey = [self decodeBase64:key];
  NSData *rawIv = [self decodeBase64:iv];
  if (rawKey.length == 0) return @"";

  CCOptions options = kCCOptionPKCS7Padding;
  NSData *ivToUse = nil;
  if ([mode isEqualToString:@"AES/CBC/PKCS7Padding"]) {
    ivToUse = [self normalizedIV:rawIv];
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
                                   [ivToUse bytes],
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

- (NSString *)rsaEncryptData:(NSString *)data publicKey:(NSString *)publicKey padding:(NSString *)padding {
  SecKeyRef keyRef = [self publicKeyFromBase64:publicKey];
  if (keyRef == nil) return @"";

  NSData *plainData = [self decodeBase64:data];
  SecKeyAlgorithm algorithm = [padding isEqualToString:@"RSA/ECB/OAEPWithSHA1AndMGF1Padding"]
    ? kSecKeyAlgorithmRSAEncryptionOAEPSHA1
    : kSecKeyAlgorithmRSAEncryptionRaw;

  if (!SecKeyIsAlgorithmSupported(keyRef, kSecKeyOperationTypeEncrypt, algorithm)) {
    CFRelease(keyRef);
    return @"";
  }

  CFErrorRef error = nil;
  CFDataRef encryptedData = SecKeyCreateEncryptedData(keyRef,
                                                      algorithm,
                                                      (__bridge CFDataRef)plainData,
                                                      &error);
  CFRelease(keyRef);
  if (encryptedData == nil) {
    if (error != nil) CFRelease(error);
    return @"";
  }

  NSData *bridged = CFBridgingRelease(encryptedData);
  if (error != nil) CFRelease(error);
  return [self encodeBase64:bridged];
}

- (void)installConsole {
  __weak UserApiModule *weakSelf = self;
  self.context[@"__native_console_log"] = ^(JSValue *value) {
    [weakSelf sendLogEventWithType:@"log" log:[value toString] ?: @""];
  };
  self.context[@"__native_console_info"] = ^(JSValue *value) {
    [weakSelf sendLogEventWithType:@"info" log:[value toString] ?: @""];
  };
  self.context[@"__native_console_warn"] = ^(JSValue *value) {
    [weakSelf sendLogEventWithType:@"warn" log:[value toString] ?: @""];
  };
  self.context[@"__native_console_error"] = ^(JSValue *value) {
    [weakSelf sendLogEventWithType:@"error" log:[value toString] ?: @""];
  };
  [self.context evaluateScript:@"var console = { log: function(v){ __native_console_log(String(v)); }, info: function(v){ __native_console_info(String(v)); }, warn: function(v){ __native_console_warn(String(v)); }, error: function(v){ __native_console_error(String(v)); } };"];
}

- (void)emitActionFromScript:(NSString *)action data:(NSString *)data {
  if (action.length == 0) return;
  NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithObject:action forKey:@"action"];
  if (data != nil) payload[@"data"] = data;
  [self sendApiEvent:payload];
}

- (void)setupNativeFunctionsWithInfo:(NSDictionary *)info runtimeToken:(NSUInteger)token {
  __weak UserApiModule *weakSelf = self;
  self.context[@"__lx_native_call__"] = ^(NSString *key, NSString *action, NSString *data) {
    if (weakSelf == nil) return;
    if (![weakSelf.scriptKey isEqualToString:key]) return;
    if ([action isEqualToString:@"init"]) {
      weakSelf.didInit = YES;
    }
    [weakSelf emitActionFromScript:action data:data];
  };
  self.context[@"__lx_native_call__utils_str2b64"] = ^NSString *(NSString *input) {
    NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
    return [weakSelf encodeBase64:data];
  };
  self.context[@"__lx_native_call__utils_b642buf"] = ^NSString *(NSString *input) {
    return [weakSelf jsonArrayStringFromData:[weakSelf decodeBase64:input]];
  };
  self.context[@"__lx_native_call__utils_str2md5"] = ^NSString *(NSString *input) {
    return [weakSelf md5FromEncodedString:input ?: @""];
  };
  self.context[@"__lx_native_call__utils_aes_encrypt"] = ^NSString *(NSString *data, NSString *key, NSString *iv, NSString *mode) {
    return [weakSelf aesEncryptData:data ?: @"" key:key ?: @"" iv:iv ?: @"" mode:mode ?: @""];
  };
  self.context[@"__lx_native_call__utils_rsa_encrypt"] = ^NSString *(NSString *data, NSString *publicKey, NSString *padding) {
    return [weakSelf rsaEncryptData:data ?: @"" publicKey:publicKey ?: @"" padding:padding ?: @""];
  };
  self.context[@"__lx_native_call__set_timeout"] = ^(NSNumber *timerId, NSNumber *timeout) {
    if (weakSelf == nil) return;
    double delay = timeout != nil ? MAX(timeout.doubleValue, 0) / 1000.0 : 0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), weakSelf.jsQueue, ^{
      if (weakSelf == nil) return;
      if (weakSelf.context == nil) return;
      if (weakSelf.runtimeToken != token) return;
      [weakSelf callJSAction:@"__set_timeout__" data:timerId ?: @0];
    });
  };
}

- (void)callJSAction:(NSString *)action data:(id)data {
  if (self.context == nil || action.length == 0) return;
  JSValue *handler = self.context[@"__lx_native__"];
  if (handler == nil || handler.isUndefined) return;
  NSMutableArray *args = [NSMutableArray arrayWithObjects:self.scriptKey ?: @"", action, nil];
  if (data != nil) [args addObject:data];
  [handler callWithArguments:args];
}

- (void)loadScriptOnQueue:(NSDictionary *)info {
  self.runtimeToken += 1;
  NSUInteger token = self.runtimeToken;
  self.didInit = NO;
  self.context = [[JSContext alloc] init];

  __weak UserApiModule *weakSelf = self;
  self.context.exceptionHandler = ^(JSContext *context, JSValue *exception) {
    if (weakSelf == nil) return;
    context.exception = nil;
    NSString *message = [weakSelf truncateLog:[exception toString] ?: @"Unknown JavaScript error"];
    [weakSelf sendLogEventWithType:@"error" log:[NSString stringWithFormat:@"Call script error: %@", message]];
    if (!weakSelf.didInit) {
      weakSelf.didInit = YES;
      [weakSelf sendInitFailed:message];
    }
  };

  self.scriptKey = NSUUID.UUID.UUIDString;
  [self installConsole];
  [self setupNativeFunctionsWithInfo:info runtimeToken:token];

  NSString *preload = [self preloadScript];
  if (preload.length == 0) {
    [self sendInitFailed:@"Missing user-api-preload.js"];
    self.context = nil;
    return;
  }

  [self.context evaluateScript:preload];
  if (self.context.exception != nil) {
    self.context = nil;
    return;
  }

  JSValue *setup = self.context[@"lx_setup"];
  if (setup == nil || setup.isUndefined) {
    [self sendInitFailed:@"lx_setup is not available"];
    self.context = nil;
    return;
  }

  NSString *script = info[@"script"] ?: @"";
  [setup callWithArguments:@[
    self.scriptKey ?: @"",
    info[@"id"] ?: @"",
    info[@"name"] ?: @"Unknown",
    info[@"description"] ?: @"",
    info[@"version"] ?: @"",
    info[@"author"] ?: @"",
    info[@"homepage"] ?: @"",
    script,
  ]];
  if (self.context.exception != nil) {
    self.context = nil;
    return;
  }

  [self.context evaluateScript:script];
  if (self.context.exception != nil) {
    [self callJSAction:@"__run_error__" data:nil];
    self.context = nil;
  }
}

- (void)destroyInternal {
  self.runtimeToken += 1;
  self.didInit = NO;
  self.scriptKey = nil;
  self.context = nil;
  [self.pendingEvents removeAllObjects];
}

RCT_EXPORT_METHOD(loadScript:(NSDictionary *)data) {
  self.loadScriptInfo = data;
  dispatch_async(self.jsQueue, ^{
    [self destroyInternal];
    [self loadScriptOnQueue:data ?: @{}];
  });
}

RCT_EXPORT_METHOD(sendAction:(NSString *)action data:(NSString *)data) {
  dispatch_async(self.jsQueue, ^{
    [self callJSAction:action data:data];
  });
}

RCT_EXPORT_METHOD(destroy) {
  dispatch_async(self.jsQueue, ^{
    [self destroyInternal];
  });
}

@end
