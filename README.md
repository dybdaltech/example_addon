# StatPeek

A small World of Warcraft addon for **Wrath of the Lich King 3.3.5** (interface `30300`). It adds a minimap button that opens a window showing your character's name, level, race, class, guild and stats.

No external libraries are required.

## Features

- Draggable minimap button. Its position around the minimap is saved between sessions.
- Movable stats window that closes with Escape and refreshes every half second while open.
- Character name in class color, with level, race, class and guild.
- Stats grouped into sections:

| Section    | Stats |
|------------|-------|
| Attributes | Strength, Agility, Stamina, Intellect, Spirit, max health, max mana/power |
| Spell      | Spell power, bonus healing, spell crit, spell hit, spell haste, spell penetration, MP5 (normal and while casting) |
| Melee      | Attack power, crit, hit, haste, attack speed, expertise, armor penetration |
| Ranged     | Ranged attack power, crit, hit, haste |
| Defense    | Armor, defense, dodge, parry, block, resilience |

## Installation

1. Download `StatPeek.zip` from the [latest release](../../releases/latest).
2. Extract it into `World of Warcraft/Interface/AddOns/`.
3. Check that you have `Interface/AddOns/StatPeek/StatPeek.toc`.
4. Restart the game, or reload the UI with `/reload`.

## Usage

Click the book icon on the minimap to open or close the window. Drag the icon to move it around the minimap edge.

| Command              | Effect |
|----------------------|--------|
| `/statpeek`          | Open or close the stats window |
| `/statpeek minimap`  | Hide or show the minimap button |
| `/statpeek reset`    | Reset the button and window positions |

## Notes

- Hit and haste values are based on combat rating, shown as `percent (rating)`. The 3.3.5 client has no API for total haste, so temporary effects like Bloodlust or Heroism are not included in the haste values.
- Spell power and spell crit show the lowest value across the magic schools, the same way the default character sheet does.

## Contributing

Commits follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `chore:` and so on).
