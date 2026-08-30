#ifndef B1C08363_9F9C_4507_810A_A0C76A633FC0
#define B1C08363_9F9C_4507_810A_A0C76A633FC0

#include "../MenuLoad/Includes.h"
#include <set>
#include <vector>
#include <string>

class LogManager 
{
private:
    std::set<std::string> LogSet;    
    std::vector<std::string> LogList; 

public:

    void Add(const std::string& Log)
    {
        if (LogSet.insert(Log).second) 
        {
            LogList.push_back(Log); 
        }
    }

    void Print()
    {
        for (const auto& Log : LogList)
        {
            ImGui::Text("%s", Log.c_str());
        }
    }

    void Clear()
    {
        LogSet.clear();
        LogList.clear();
    }
};

inline LogManager logManager;

#endif /* B1C08363_9F9C_4507_810A_A0C76A633FC0 */
