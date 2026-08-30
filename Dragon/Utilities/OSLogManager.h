#pragma once

// requires C++23 standard

#include <string>
#include <format>
#include <print>

#include <os/log.h>

class OSLogManager
{
public:
    OSLogManager() = delete;
    OSLogManager(const char* Subsystem, const char* Category)
    {
        Handle = os_log_create(Subsystem, Category);
    }
    
public:
    
    template<typename ...Args>
    void Log(std::format_string<Args...> Fmt, Args&&... args)
    {
        std::string LogMessage = std::format(Fmt, std::forward<Args>(args)...);

        os_log(Handle, "%{public}s", LogMessage.data());
    }
    
private:
    os_log_t Handle;
};
