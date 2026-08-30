// 
// Maintained by Project Contributors 2024 (c)
//

#ifndef CONVERT_UTILS_HPP
#define CONVERT_UTILS_HPP

#include <string>
#include <vector>
#import <Foundation/Foundation.h>

namespace ConvertUtils {

    template <typename To, typename From>
    To convert(const From& from);

    // ============================
    // std::wstring <- std::string
    // ============================
    template <>
    inline std::wstring convert<std::wstring, std::string>(const std::string& from) {
        NSString *nsStr = [NSString stringWithUTF8String:from.c_str()];
        if (!nsStr) {
            return std::wstring();
        }

        NSUInteger length = [nsStr length];
        std::vector<unichar> buffer(length);
        [nsStr getCharacters:buffer.data() range:NSMakeRange(0, length)];

        std::wstring wstr;
        wstr.reserve(length);

        for (NSUInteger i = 0; i < length; ++i) {
            unichar high = buffer[i];
            if (high >= 0xD800 && high <= 0xDBFF && (i + 1) < length) {
                unichar low = buffer[i + 1];
                if (low >= 0xDC00 && low <= 0xDFFF) {
                    uint32_t codepoint = ((high - 0xD800) << 10) + (low - 0xDC00) + 0x10000;
                    wstr += static_cast<wchar_t>(codepoint);
                    ++i;
                    continue;
                }
            }
            wstr += static_cast<wchar_t>(high);
        }

        return wstr;
    }

    // ============================
    // std::string <- std::wstring
    // ============================
    template <>
    inline std::string convert<std::string, std::wstring>(const std::wstring& from) {
        NSMutableString *mutableStr = [NSMutableString string];

        for (wchar_t wc : from) {
            uint32_t codepoint = static_cast<uint32_t>(wc);
            if (codepoint > 0x10FFFF) {
                return std::string();
            }

            if (codepoint >= 0x10000) {
                uint32_t codepointPrime = codepoint - 0x10000;
                unichar high = 0xD800 + ((codepointPrime >> 10) & 0x3FF);
                unichar low = 0xDC00 + (codepointPrime & 0x3FF);
                [mutableStr appendFormat:@"%C%C", high, low];
            } else {
                unichar ch = static_cast<unichar>(codepoint);
                [mutableStr appendFormat:@"%C", ch];
            }
        }

        NSData *data = [mutableStr dataUsingEncoding:NSUTF8StringEncoding];
        if (!data) {
            return std::string();
        }

        return std::string((const char *)[data bytes], [data length]);
    }

    // ============================
    // std::string <- const wchar_t*
    // ============================
    inline std::string convert(const wchar_t* from) {
        if (!from) {
            return std::string();
        }
        return convert<std::string, std::wstring>(std::wstring(from));
    }

    // ============================
    // std::wstring <- NSString*
    // ============================
    inline std::wstring convert(const NSString* from) {
        if (!from) {
            return std::wstring();
        }

        NSUInteger length = [from length];
        std::vector<unichar> buffer(length);
        [from getCharacters:buffer.data() range:NSMakeRange(0, length)];

        std::wstring wstr;
        wstr.reserve(length);

        for (NSUInteger i = 0; i < length; ++i) {
            unichar high = buffer[i];
            if (high >= 0xD800 && high <= 0xDBFF && (i + 1) < length) {
                unichar low = buffer[i + 1];
                if (low >= 0xDC00 && low <= 0xDFFF) {
                    uint32_t codepoint = ((high - 0xD800) << 10) + (low - 0xDC00) + 0x10000;
                    wstr += static_cast<wchar_t>(codepoint);
                    ++i;
                    continue;
                }
            }
            wstr += static_cast<wchar_t>(high);
        }

        return wstr;
    }

    // ============================
    //  NSString* <- std::wstring
    // ============================
    inline NSString* convert(const std::wstring& from) {
        NSMutableString *mutableStr = [NSMutableString string];

        for (wchar_t wc : from) {
            uint32_t codepoint = static_cast<uint32_t>(wc);

            if (codepoint > 0x10FFFF) {
                break;
            }

            if (codepoint >= 0x10000) {
                uint32_t codepointPrime = codepoint - 0x10000;
                unichar high = 0xD800 + ((codepointPrime >> 10) & 0x3FF);
                unichar low = 0xDC00 + (codepointPrime & 0x3FF);
                [mutableStr appendFormat:@"%C%C", high, low];
            } else {
                unichar ch = static_cast<unichar>(codepoint);
                [mutableStr appendFormat:@"%C", ch];
            }
        }

        return [NSString stringWithString:mutableStr];
    }
}

#endif // CONVERT_UTILS_HPP
