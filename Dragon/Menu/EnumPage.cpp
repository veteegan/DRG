#include "EnumPage.hpp"
#include <algorithm>

MenuPage GetPageToSub(int SubIdx)
{
    if (SubIdx < 0 || SubIdx >= 70)
        return MenuPage::COUNT;

    int range = SubIdx / 10;

    switch (range)
    {
        case 0:
            return MenuPage::General;
        case 1:
            return MenuPage::ESP;
        case 2:
            return MenuPage::Misc;
        case 3:
            return MenuPage::AimBot;
        case 4:
            return MenuPage::Structures;
        case 5:
            return MenuPage::Admin;
        case 6:
            return MenuPage::Settings;
        default:
            return MenuPage::COUNT;
    }
}

std::pair<SubPage, SubPage> GetSubRange(MenuPage page)
{
    switch (page)
    {
        case MenuPage::General:
            return { SubPage::General, SubPage::Players_List };
        case MenuPage::Structures:
            return { SubPage::Regular, SubPage::Premium };
        case MenuPage::ESP:
            return { SubPage::Players, SubPage::Other };
       case MenuPage::Misc:
           return { SubPage::Misc, SubPage::Automation };
        case MenuPage::Admin:
            return { SubPage::Items, SubPage::More };
//        case MenuPage::SETTINGS:
//            return { SubPage::PERSONAL, SubPage::CUSTOMISATION };
        default:
            return { SubPage::NONE, SubPage::NONE };
    }
}

std::pair<SubSubPage, SubSubPage> GetSubSubRange(SubPage subPage)
{
    if (subPage == SubPage::Other)
    {
        return { SubSubPage::Resources, SubSubPage::Map };
    } else if (subPage == SubPage::Automation)
    {
        return { SubSubPage::Auto_Loot, SubSubPage::Auto_Drop_Items };
    } else if (subPage == SubPage::General)
    {
        return { SubSubPage::Player, SubSubPage::Materials };
    }


    return { SubSubPage::NONE, SubSubPage::NONE };
}

EnumNameCache::EnumNameCache()
{
    __buffer.reserve(58);
    
    for (auto menuPage : magic_enum::enum_values<MenuPage>())
    {
        if (menuPage == MenuPage::COUNT)
            continue;

        MenuPageNames[menuPage] = magic_enum::enum_name(menuPage).data();
    }

    for (auto subPage : magic_enum::enum_values<SubPage>())
    {
        if (subPage == SubPage::NONE)
            continue;

        if (subPage == SubPage::Players_List || subPage == SubPage::Server_List || subPage == SubPage::Dino_Color)
        {
            std::string name = std::string(magic_enum::enum_name(subPage));
            std::replace(name.begin(), name.end(), '_', ' ');

            const char* ptr = __buffer.data() + __buffer.size();
            __buffer += name;
            __buffer += '\0';

            SubPageNames[subPage] = ptr;
        }
        else
        {
            SubPageNames[subPage] = magic_enum::enum_name(subPage).data();
        }
    }

    for (auto subSubPage : magic_enum::enum_values<SubSubPage>())
    {
        if (subSubPage == SubSubPage::NONE)
            continue;

        if (subSubPage == SubSubPage::Auto_Loot || subSubPage == SubSubPage::Auto_Drop_Items)
        {
            std::string name = std::string(magic_enum::enum_name(subSubPage));
            std::replace(name.begin(), name.end(), '_', ' ');

            const char* ptr = __buffer.data() + __buffer.size();
            __buffer += name;
            __buffer += '\0';

            SubSubPageNames[subSubPage] = ptr;
        }
        else
        {
            SubSubPageNames[subSubPage] = magic_enum::enum_name(subSubPage).data();
        }
    }
}
