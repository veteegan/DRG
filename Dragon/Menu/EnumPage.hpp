#ifndef ENUM_PAGE_H
#define ENUM_PAGE_H

// #include <string>

#include <map>
#include <unordered_map>

#include "../Utilities/magic_enum/magic_enum.hpp"

enum class MenuPage : int
{
    General = 0,
    ESP,
    Misc,
    AimBot,
    Structures,
    Admin,
    Settings,
    COUNT
};

enum class SubPage : int
{
    NONE = -1,
    // General 0-9
    General = 0,
    Server_List,
    Players_List,
    // ,
    
    // ESP 10-19
    Players = 10,
    Dinosaurs,
    Structures,
    Other,
    
    // Misc 20-29
    Misc = 20,
    Weapon,
    Personal,
    Automation,

    // AimBot 30-39
    // = 30,
    // ,
    
    // Structures 40-49
    Regular = 40,
    Metal,
    Tek,
    Premium,
    Turrets,
    
    // Admin 50-59
    Items = 50,
    Dino,
    Dino_Color,
    Commands,
    More//,
    
    // Settings 60-69
    // = 50,
    // ,
    //
};

enum class SubSubPage : int
{
    NONE = -1,
    // ESP-Others 0-9
    Resources = 0,
    Crosshair,
    Map,
    
    // Misc-Automation 10-19
    Auto_Loot = 10,
    Auto_Drop_Items,
    
    // General-General 20-29
    Player = 20,
    World,
    Color,
    Materials
    // ,
    //
    // ...
};

struct MenuState
{
    MenuPage mainPage;
    std::map<MenuPage, SubPage> subPages;
    std::map<SubPage, SubSubPage> subSubPages;

    MenuState()
        : mainPage(MenuPage::General)
    {
        subPages = {
            { MenuPage::General, SubPage::General },
            { MenuPage::Misc, SubPage::Misc },
            { MenuPage::Structures, SubPage::Regular },
            { MenuPage::ESP,  SubPage::Players },
            { MenuPage::Admin,  SubPage::Items }
//            { MenuPage::, SubPage:: }
        };

        subSubPages = {
            { SubPage::Other, SubSubPage::Resources },
            { SubPage::Automation, SubSubPage::Auto_Loot },
            { SubPage::General, SubSubPage::Player }
            // { SubPage::, SubSubPage:: }
        };
    }
} inline menuState;

MenuPage GetPageToSub(int SubIdx);

std::pair<SubPage, SubPage> GetSubRange(MenuPage page);

std::pair<SubSubPage, SubSubPage> GetSubSubRange(SubPage subPage);

class EnumNameCache
{
public:
    static EnumNameCache& GetInstance()
    {
        static EnumNameCache instance;
        return instance;
    }

    EnumNameCache(const EnumNameCache&) = delete;
    EnumNameCache& operator=(const EnumNameCache&) = delete;

    const std::unordered_map<MenuPage, const char*>& GetMenuPageNames() const { return MenuPageNames; }
    const std::unordered_map<SubPage, const char*>& GetSubPageNames() const { return SubPageNames; }
    const std::unordered_map<SubSubPage, const char*>& GetSubSubPageNames() const { return SubSubPageNames; }

private:
    EnumNameCache();

    ~EnumNameCache()
    {
        MenuPageNames.clear();
        SubPageNames.clear();
        SubSubPageNames.clear();
    }

    std::string __buffer;
    std::unordered_map<MenuPage, const char*> MenuPageNames;
    std::unordered_map<SubPage, const char*> SubPageNames;
    std::unordered_map<SubSubPage, const char*> SubSubPageNames;
};

#endif // ENUM_PAGE_H
