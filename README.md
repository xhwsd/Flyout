# Flyout

Flyout is a World of Warcraft Vanilla (1.12) addon that mimicks the flyout feature implemented in later expansions. Using a macro you can create a flyout action button that groups together various spells.

## How to

1. Open your macros and create a new macro
2. In the macro body, start by typing `/flyout` and then the names of the spells separated by a semicolon

   - To use a specific rank, you can write `Frostbolt(Rank 1)` (omitting the rank will use the highest available)
   - **Do not insert a semicolon after the last spell name**

   ![Macro body example](screenshots/macro.png)

3. Drag the newly created macro to one of your action bars and you're good to go

   ![Flyout](screenshots/bar.png)

## Compatibility

The addon relies on functions provided by the default action bar and action button logic implemented by Blizzard. Some addons override these functions or use their own and therefore may not work together with this addon.

Compatible addons:

- ElvUI
- pfUI
- Bartender2
- Bongos
- Roid-Macros
- CleverMacro
- MacroExtender
