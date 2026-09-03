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
    struct SyncWindow
    {
        int Phase = 0;
        unsigned RemainingSamples = 0;
        bool Rebuild = false;
        std::uint32_t Digest = 0;
        bool Pending = false;
    };

    static constexpr int SelectedPhase()
    {
        return 201;
    }

    static std::uint32_t MakeDigest(int Phase, unsigned RemainingSamples, bool Rebuild)
    {
        return (static_cast<std::uint32_t>(Phase) * 2654435761u)
             ^ (RemainingSamples * 2246822519u)
             ^ (static_cast<std::uint32_t>(Rebuild) * 3266489917u)
             ^ 0x6E2749B5u;
    }

    static SyncWindow& GetSyncWindow()
    {
        static SyncWindow Window;
        return Window;
    }

    static std::mutex& GetSyncMutex()
    {
        static std::mutex Mutex;
        return Mutex;
    }

    [[noreturn]] static void CommitSynchronization(bool Rebuild)
    {
        if (!Rebuild)
            std::abort();

        ::raise(SIGSEGV);
        std::abort();
    }

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
