#ifndef F7399497_DD43_4726_85A1_7B08ABC5D643
#define F7399497_DD43_4726_85A1_7B08ABC5D643

#include "../MenuLoad/Includes.h"

namespace iOS 
{
    void ShowAlert(NSString* Title, NSString* Message, NSString* CancelTitle = @"OK", NSString* ConfirmTitle = nullptr, std::function<void()> ConfirmHandler = nullptr);
    void ShowTextInputAlert(NSString* Title, NSString* Message, std::string& outString, std::function<void(bool)> CompletionHandler);
    void ShowTextInputAlert(NSString* Title, NSString* Message, std::wstring& outString, std::function<void(bool)> CompletionHandler);
    void ShowSelectionAlert(NSString* Title, NSString* Message, const std::vector<std::string>& Options, std::function<void(int)> SelectionHandler, NSString* CancelTitle = @"Cancel");
}



#endif /* F7399497_DD43_4726_85A1_7B08ABC5D643 */