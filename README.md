**Flyout** is a World of Warcraft Vanilla (1.12) addon that mimics the flyout feature implemented in later expansions.

### How to

1. Open your macros and create a new macro
2. In the macro body, start by typing `/flyout` and then the names of spells/macros separated by a semicolon
   - To use a specific rank of a spell, use `Frostbolt(Rank 1)`. To use the highest rank available, use `Frostbolt`
   - To keep the flyout open until you move the mouse off it, use the 'sticky' macro condition (`/flyout [sticky] Disenchant; Enchanting`)
   - To set the icon of the flyout macro to the icon of the default action (the first spell or macro), use the 'icon' macro condition (`/flyout [icon] Disenchant; Enchanting`)

   ![Macro body example](screenshots/macro.png)


3. Drag the newly created macro to one of your action bars and you're good to go

   ![Flyout](screenshots/bar.png)

Using the flyout (clicking on the flyout macro on the action bar or pressing the keybind) will cast the spell or execute the macro that is first in the list. Right-clicking any action in the flyout will set that action as the default action.

You can type `/flyout` in the in-game chat to view a list of available customization options.

### Compatibility

Compatible addons:

- ElvUI
- pfUI
- Bartender2
- Bongos
- Roid-Macros
- CleverMacro
- MacroExtender
