#include "iOSAlerts.h"
#include "ConvertUtils.hpp"

void iOS::ShowAlert(NSString* Title, 
               NSString* Message, 
               NSString* CancelTitle, 
               NSString* ConfirmTitle, 
               std::function<void()> ConfirmHandler)
{
    // Create the alert controller
    UIAlertController* alertController = [UIAlertController alertControllerWithTitle:Title
                                                                              message:Message 
                                                                       preferredStyle:UIAlertControllerStyleAlert];
    
    // Add the "Cancel" action button
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:CancelTitle 
                                                          style:UIAlertActionStyleCancel 
                                                        handler:nil];
    [alertController addAction:cancelAction];

    // Optionally add a "Confirm" action button if specified
    if (ConfirmTitle != nullptr && ConfirmHandler != nullptr)
    {
        UIAlertAction* confirmAction = [UIAlertAction actionWithTitle:ConfirmTitle 
                                                               style:UIAlertActionStyleDefault 
                                                             handler:^(UIAlertAction * action)
        {
            ConfirmHandler();
        }];
        [alertController addAction:confirmAction];
    }

    // Show the alert on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow* keyWindow = UIApplication.sharedApplication.windows.firstObject;
        if (keyWindow) {
            UIViewController* rootViewController = keyWindow.rootViewController;
            if (rootViewController) {
                [rootViewController presentViewController:alertController animated:YES completion:nil];
            }
        }
    });
}

void iOS::ShowTextInputAlert(NSString* Title, NSString* Message, std::string& outString, std::function<void(bool)> CompletionHandler)
{
    UIAlertController* alertController = [UIAlertController alertControllerWithTitle:Title message:Message preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addTextFieldWithConfigurationHandler:nil];
    
    UIAlertAction* okAction = [UIAlertAction actionWithTitle:@"Enter" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
        UITextField* textField = alertController.textFields.firstObject;
        outString = std::string([textField.text UTF8String]);
        CompletionHandler(true);  // Notify success
    }];
    
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction* action) {
        CompletionHandler(false);  // Notify that the input was canceled
    }];
    
    [alertController addAction:okAction];
    [alertController addAction:cancelAction];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow* keyWindow = UIApplication.sharedApplication.windows.firstObject;
        if (keyWindow) {
            UIViewController* rootViewController = keyWindow.rootViewController;
            if (rootViewController) {
                [rootViewController presentViewController:alertController animated:YES completion:nil];
            }
        }
    });
}

void iOS::ShowTextInputAlert(NSString* Title, NSString* Message, std::wstring& outString, std::function<void(bool)> CompletionHandler)
{
    UIAlertController* alertController = [UIAlertController alertControllerWithTitle:Title message:Message preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addTextFieldWithConfigurationHandler:nil];
    
    UIAlertAction* okAction = [UIAlertAction actionWithTitle:@"Enter" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
        UITextField* textField = alertController.textFields.firstObject;
        outString = ConvertUtils::convert(textField.text);
        CompletionHandler(true);  // Notify success
    }];
    
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction* action) {
        CompletionHandler(false);  // Notify that the input was canceled
    }];
    
    [alertController addAction:okAction];
    [alertController addAction:cancelAction];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow* keyWindow = UIApplication.sharedApplication.windows.firstObject;
        if (keyWindow) {
            UIViewController* rootViewController = keyWindow.rootViewController;
            if (rootViewController) {
                [rootViewController presentViewController:alertController animated:YES completion:nil];
            }
        }
    });
}


void iOS::ShowSelectionAlert(NSString* Title, 
                        NSString* Message, 
                        const std::vector<std::string>& Options, 
                        std::function<void(int)> SelectionHandler,
                        NSString* CancelTitle)
{
    // Create the alert controller
    UIAlertController* alertController = [UIAlertController alertControllerWithTitle:Title
                                                                              message:Message
                                                                       preferredStyle:UIAlertControllerStyleActionSheet];

    // Add each option as a separate action
    for (size_t i = 0; i < Options.size(); ++i)
    {
        NSString* optionTitle = [NSString stringWithUTF8String:Options[i].c_str()];
        UIAlertAction* optionAction = [UIAlertAction actionWithTitle:optionTitle
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction* action) 
        {
            SelectionHandler(static_cast<int>(i)); // Call the handler with the selected index
        }];
        [alertController addAction:optionAction];
    }

    // Add the "Cancel" action button
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:CancelTitle 
                                                          style:UIAlertActionStyleCancel 
                                                        handler:nil];
    [alertController addAction:cancelAction];

    // Present the alert on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow* keyWindow = UIApplication.sharedApplication.windows.firstObject;
        if (keyWindow) {
            UIViewController* rootViewController = keyWindow.rootViewController;
            if (rootViewController) {
                [rootViewController presentViewController:alertController animated:YES completion:nil];
            }
        }
    });
}
