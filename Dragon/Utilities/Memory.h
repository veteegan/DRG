#pragma once

#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach/mach.h>
#include <mach/mach_init.h>
#include <mach/vm_map.h>
#include <type_traits>
#include <utility>
#include "Macros.h"
#include "Core.h"
#include "StringUtils.h"

class IMemoryUtils
{
public:

    static const IMemoryUtils* Get()
    {
        static IMemoryUtils StaticInstance;
        return &StaticInstance;
    }

public:
    template<typename Type>
    inline Type Read(vm_address_t Address) const
    {
        Type OutData;
        VMRead_Internal(Address, reinterpret_cast<vm_address_t>(&OutData), sizeof(Type));
        return OutData;
    }

    template<typename Type>
    inline void Write(vm_address_t Address, Type Data) const
    {
        VMWrite_Internal(Address, reinterpret_cast<vm_address_t>(&Data), sizeof(Type));
    }

    inline bool IsBadReadPtr(const void* Ptr) const
    {
        uint8_t Data = 0;
        size_t Size = 0;

        kern_return_t KR = vm_read_overwrite(mach_task_self_, (vm_address_t)Ptr, 1, (vm_address_t)&Data, &Size);
        return (KR == KERN_INVALID_ADDRESS ||
                KR == KERN_MEMORY_FAILURE  ||
                KR == KERN_MEMORY_ERROR    ||
                KR == KERN_PROTECTION_FAILURE);
    };

    inline bool IsBadReadPtr(const vm_address_t Ptr) const
    {
        return IsBadReadPtr(reinterpret_cast<const void*>(Ptr));
    }

    void VirtualProtect(vm_address_t Address, vm_address_t Size, vm_prot_t NewProtection) const
    {
        vm_protect(mach_task_self_, Address, Size, NO, NewProtection);
    }

    void GetSegmentInfo(const mach_header_64* Header, const char* SegName, uint64* Start, uint64* End) const
    {
        const uint8_t* p = (const uint8_t*)Header + sizeof(mach_header_64);
        for (uint32_t i = 0; i < Header->ncmds; i++)
        {
            const struct load_command* lc = (const struct load_command*)p;
            if (lc->cmd == LC_SEGMENT_64)
            {
                const struct segment_command_64* s = (const struct segment_command_64*)p;
                if (TStringUtils<char>::Strcmp(s->segname, SegName) == 0)
                {
                    uintptr_t Base = (uintptr_t)Header + s->vmaddr;
                    *Start = Base;
                    *End   = Base + s->vmsize;
                    return;
                }
            }
            p += lc->cmdsize;
        }
        *Start = *End = 0;
    }


public:

    struct DyldInfo
    {
        const mach_header_64 *Header;
        intptr VMAddrSlide;
        uint32 Index;
        const char* Path;

        DyldInfo() : Path(nullptr), Header(nullptr), VMAddrSlide(NULL), Index(-1) {}
        DyldInfo(const char* _Name) : Header(nullptr), VMAddrSlide(NULL), Index(-1)
        {
            for (uint32 Index = 0; Index < _dyld_image_count(); ++Index)
            {
                const char* ImageName = _dyld_get_image_name(Index);
                if (TStringUtils<char>::Strstr(ImageName, _Name))
                {
                    this->Index = Index;
                    this->Header = (const mach_header_64*)_dyld_get_image_header(Index);
                    this->VMAddrSlide = _dyld_get_image_vmaddr_slide(Index);
                    this->Path = ImageName;

                    break;
                }
            }
        }

        void *GetAddress(uint64 Offset) const
        {
            return reinterpret_cast<void*>(GetBaseAddress() + Offset);
        }

        uint64 GetOffset(void *Address) const
        {
            return reinterpret_cast<uint64>(Address) - GetBaseAddress();
        }

        intptr GetBaseAddress() const
        {
            return VMAddrSlide;
        }
    };

    static DyldInfo GetDyldInfo(const char* Name)
    {
        return DyldInfo(Name);
    }

private:

    bool VMRead_Internal(vm_address_t Address, vm_address_t Buffer, unsigned int Length) const
    {
        vm_size_t Size = 0;
        kern_return_t ErrorCode = vm_read_overwrite(mach_task_self_, Address, Length, Buffer, &Size);
        return ErrorCode == KERN_SUCCESS && Size == Length;
    }

    bool VMWrite_Internal(vm_address_t Address, vm_address_t Buffer, unsigned int Length) const
    {
        kern_return_t ErrorCode = vm_write(mach_task_self_, Address, Buffer, Length);
        return ErrorCode == KERN_SUCCESS;
    }
};

