// 
// Maintained by Project Contributors 2024 (c)
//

#ifndef DEEP_COPY_HPP
#define DEEP_COPY_HPP

#include <type_traits>
#include <cstdint>
#include <functional>
#include <memory>

template <typename T>
struct FieldSpec {
    using SourceFieldType = T;
    std::uintptr_t sourceOffset;

    struct DestMappingBase {
        virtual void apply(const SourceFieldType& source, void* dest) const = 0;
        virtual ~DestMappingBase() = default;
    };

    template <typename DestFieldType>
    struct DestMapping : DestMappingBase {
        std::uintptr_t destOffset;
        std::function<DestFieldType(const SourceFieldType&)> converter;

        DestMapping(std::uintptr_t dOff, std::function<DestFieldType(const SourceFieldType&)> conv)
            : destOffset(dOff), converter(conv) {}

        void apply(const SourceFieldType& source, void* dest) const override {
            DestFieldType* destField = reinterpret_cast<DestFieldType*>(
                reinterpret_cast<std::uint8_t*>(dest) + destOffset);
            *destField = converter(source);
        }
    };

    std::vector<std::unique_ptr<DestMappingBase>> destMappings;

    FieldSpec(std::uintptr_t sOff) : sourceOffset(sOff) {}

    template <typename DestFieldType>
    void addDestination(std::uintptr_t dOff, std::function<DestFieldType(const SourceFieldType&)> conv) {
        destMappings.emplace_back(std::make_unique<DestMapping<DestFieldType>>(dOff, conv));
    }

    template <typename DestFieldType>
    void addDestination(std::uintptr_t dOff) {
        destMappings.emplace_back(std::make_unique<DestMapping<DestFieldType>>(
            dOff, [](const SourceFieldType& value) -> DestFieldType { return static_cast<DestFieldType>(value); }
        ));
    }
};

template <typename SourceType, typename DestType, typename... Fields>
void DeepCopyStruct(const SourceType& source, DestType& destination, const Fields&... fields) {
    auto copyField = [&](const auto& fieldSpec) {
        using SourceFieldType = typename std::remove_reference_t<decltype(fieldSpec)>::SourceFieldType;

        const SourceFieldType* sourceField = reinterpret_cast<const SourceFieldType*>(
            reinterpret_cast<const std::uint8_t*>(&source) + fieldSpec.sourceOffset);

        for (const auto& destMapping : fieldSpec.destMappings) {
            destMapping->apply(*sourceField, &destination);
        }
    };
    (copyField(fields), ...);
}

template <typename SourceContainer, typename DestContainer, typename... Fields>
void DeepCopyArray(const SourceContainer& sourceArray, DestContainer& destArray, const Fields&... fields) {
    destArray.clear();
    for (const auto& source : sourceArray) {
        typename DestContainer::value_type dest;
        DeepCopyStruct(source, dest, fields...);
        destArray.emplace_back(std::move(dest));
    }
}

#endif // DEEP_COPY_HPP
