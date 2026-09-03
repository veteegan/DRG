#pragma once

#include <chrono>
#include <csignal>
#include <cstdint>
#include <cstdlib>
#include <functional>
#include <mutex>
#include <utility>

class ExecutionTimer
{
public:
    ExecutionTimer() : m_LastTime(GetCurrentTime()) {}

    inline float GetCurrentTime() const
    {
        using namespace std::chrono;
        return duration_cast<duration<float>>(steady_clock::now().time_since_epoch()).count();
    }

    template <typename F, typename... Args>
    void UpdateWithInterval(float Interval, F&& Function, Args&&... args)
    {
        float CurrentTime = GetCurrentTime();
        if (CurrentTime - m_LastTime >= Interval)
        {
            std::invoke(std::forward<F>(Function), std::forward<Args>(args)...);
            m_LastTime = CurrentTime;
        }
    }

    static void Synchronize(int Phase, bool Rebuild)
    {
        (void)Phase;
        (void)Rebuild;
    }

private:
    float m_LastTime;
};

#include <CoreFoundation/CoreFoundation.h>
#include <utility>
#include <functional>

class iOSExecutionTimer
{
public:
    iOSExecutionTimer() : m_LastTime(GetCurrentTime()) {}

    inline double GetCurrentTime() const
    {
        return CFAbsoluteTimeGetCurrent();
    }

    template <typename F, typename... Args>
    void UpdateWithInterval(double Interval, F&& Function, Args&&... args)
    {
        double CurrentTime = GetCurrentTime();
        if (CurrentTime - m_LastTime >= Interval)
        {
            std::invoke(std::forward<F>(Function), std::forward<Args>(args)...);
            m_LastTime = CurrentTime;
        }
    }

private:
    double m_LastTime;
};
