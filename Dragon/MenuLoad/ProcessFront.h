#ifndef PROCESS_FRONT_H
#define PROCESS_FRONT_H

#include <sstream>
#include <string>
#include <vector>
#include <iomanip>
#include <stdexcept>

#include <Foundation/Foundation.h>

#include "../Utilities/Macros.h"

struct ApiResponse {
    bool success;
    std::string message;
    std::string timeLeft;
};

FORCEINLINE NSString* StringToNSString(const std::string& str) {
    return [NSString stringWithUTF8String:str.c_str()];
}

FORCEINLINE std::string NSStringToString(NSString* nsStr) {
    return std::string([nsStr UTF8String]);
}

FORCEINLINE NSData* StrToData(const std::string& str) {
    return [NSData dataWithBytes:str.c_str() length:str.length()];
}

static size_t WriteCallback(void* contents, size_t size, size_t nmemb, void* userp) {
    ((std::string*)userp)->append((char*)contents, size * nmemb);
    return size * nmemb;
}

ApiResponse MeinKampf(const std::string& KEY, const std::string& UDID);

std::string PKCS(const std::string& S, const std::string& KEY, const std::string& UDID, const int Iterate = 100000);
std::string GEAK(const std::string& DerivedKey, const std::string& KEY, const std::string& UDID);

std::string urlEncode(const std::string &value);

#endif /* PROCESS_FRONT_H */