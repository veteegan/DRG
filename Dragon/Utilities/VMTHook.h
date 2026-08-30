//
//  VMTHook.h
//  Sishen
//
//  Created by Project Contributors on 18.07.25.
//

#include "Memory.h"


template<typename FuncType>
class VMTHookManager
{
private:
    FuncType* OriginalFunction;
    FuncType* NewFunction;

    int32 FunctionIndex;
public:
    VMTHookManager(FuncType* NewFunc, int32 Index) : NewFunction(NewFunc), FunctionIndex(Index) {}
    VMTHookManager(FuncType* NewFunc) : NewFunction(NewFunc) {}
    

    void Swap(void* Class)
    {
        if (!Class || !NewFunction)
            return;

        void** VTable = *reinterpret_cast<void***>(Class);
        if (!VTable || VTable[FunctionIndex] == NewFunction)
            return;

        OriginalFunction = (FuncType*)VTable[FunctionIndex];

        IMemoryUtils::Get()->VirtualProtect((uint64)VTable, FunctionIndex * sizeof(void*), VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
        VTable[FunctionIndex] = (void*)NewFunction;
        IMemoryUtils::Get()->VirtualProtect((uint64)VTable, FunctionIndex * sizeof(void*), VM_PROT_READ);
    }

    void SwapInstanceless(void* AddressInVTable)
    {
        if (NewFunction == *(FuncType**)AddressInVTable)
            return;

        OriginalFunction = *(FuncType**)AddressInVTable;
        IMemoryUtils::Get()->VirtualProtect((uint64)AddressInVTable, sizeof(void*), VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
        *(void**)AddressInVTable = (void*)NewFunction;
        IMemoryUtils::Get()->VirtualProtect((uint64)AddressInVTable, sizeof(void*), VM_PROT_READ);
    }

    void ResetInstanceless(void* AddressInVTable)
    {
        if (!OriginalFunction)
            return;

        if (NewFunction != *(FuncType**)AddressInVTable)
            return;

        IMemoryUtils::Get()->VirtualProtect((uint64)AddressInVTable, sizeof(void*), VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
        *(void**)AddressInVTable = (void*)OriginalFunction;
        IMemoryUtils::Get()->VirtualProtect((uint64)AddressInVTable, sizeof(void*), VM_PROT_READ);
    }

    void Reset(void* Class)
    {
        if (!Class || !OriginalFunction)
            return;

        void** VTable = *reinterpret_cast<void***>(Class);
        if (!VTable || VTable[FunctionIndex] != NewFunction)
            return;

        IMemoryUtils::Get()->VirtualProtect((uint64)VTable, sizeof(void*), VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
        VTable[FunctionIndex] = (void*)OriginalFunction;
        IMemoryUtils::Get()->VirtualProtect((uint64)VTable, sizeof(void*), VM_PROT_READ | VM_PROT_EXECUTE);
    }

    template<typename... Args>
    auto InvokeOriginal(Args&&... args) const -> decltype(auto)
    {
        return (*OriginalFunction)(std::forward<Args>(args)...);
    }
};
