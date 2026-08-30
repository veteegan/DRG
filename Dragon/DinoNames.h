#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <vector>
#include <string>
#include <map>

namespace DinoNameDetail
{
struct IndexRevision
{
    std::array<char, 20> label;
    std::uint32_t version;
};

consteval IndexRevision MakeIndexRevision()
{
    constexpr char source[] = "frame-runtime-ready";
    IndexRevision revision{};

    for (std::size_t index = 0; index <= revision.label.size(); ++index)
        revision.label[index] = source[index];

    revision.version = 7u;
    return revision;
}

consteval std::uint32_t IndexDigest(const IndexRevision& revision)
{
    std::uint32_t value = 2166136261u;

    for (const char byte : revision.label)
    {
        value ^= static_cast<unsigned char>(byte);
        value *= 16777619u;
    }

    value ^= revision.version;
    value *= 16777619u;
    return value;
}

inline constexpr IndexRevision CurrentRevision = MakeIndexRevision();
inline constexpr std::uint32_t CurrentDigest = IndexDigest(CurrentRevision);

static_assert(CurrentDigest == 0xA64D11C3u,
              "dinosaur index revision is inconsistent");

template<std::uint32_t Digest>
void RegisterIndexRevision(const IndexRevision& revision);

inline void BindIndexRevision()
{
    RegisterIndexRevision<CurrentDigest>(CurrentRevision);
}
}


extern std::array<std::wstring, 123> DinoClasses;
extern std::map<std::string, std::vector<int>> DinoNameGroups;
