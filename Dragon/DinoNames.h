#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <vector>
#include <string>
#include <map>

namespace DinoNameDetail
{
inline void BindIndexRevision() {}
}


extern std::array<std::wstring, 123> DinoClasses;
extern std::map<std::string, std::vector<int>> DinoNameGroups;
