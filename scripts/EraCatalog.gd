extends RefCounted
class_name EraCatalog

# The table controls names, rewards, opponents, weapons and menu presentation.
# Add a new dictionary to append an era without changing gameplay code.
const ERAS: Array[Dictionary] = [
    {
        "id": "stone", "name": "Stone Age", "weapon": "Flint Spears",
        "mini": "Dire Wolf", "boss": "Tribal War Chief", "pet": "Chibi Wolf",
        "button": "res://assets/ui/play_stone.svg", "accent": "#c5a479",
        "opponent": "Wild Hunters", "reward": "Hunter's Bow"
    },
    {
        "id": "bronze", "name": "Bronze Age", "weapon": "Hunter's Bow",
        "mini": "Cave Lion", "boss": "Bronze Warlord", "pet": "Chibi Lion",
        "button": "res://assets/ui/play_bronze.svg", "accent": "#d89a5c",
        "opponent": "Bronze Raiders", "reward": "Iron Javelins"
    },
    {
        "id": "iron", "name": "Iron Age", "weapon": "Iron Javelins",
        "mini": "Armored Boar", "boss": "Iron Legion Captain", "pet": "Chibi Boar",
        "button": "res://assets/ui/play_iron.svg", "accent": "#b8c3cf",
        "opponent": "Legion Scouts", "reward": "Crossbow"
    },
    {
        "id": "medieval", "name": "Medieval Era", "weapon": "Crossbow",
        "mini": "Dire Bear", "boss": "Siege Knight", "pet": "Chibi Bear",
        "button": "res://assets/ui/play_medieval.svg", "accent": "#d9c28c",
        "opponent": "Castle Guards", "reward": "Musket"
    },
    {
        "id": "industrial", "name": "Industrial Era", "weapon": "Musket",
        "mini": "Steam Hound", "boss": "Iron Baron", "pet": "Clockwork Pup",
        "button": "res://assets/ui/play_industrial.svg", "accent": "#d2a263",
        "opponent": "Factory Troopers", "reward": "Assault Rifle"
    },
    {
        "id": "modern", "name": "Modern Era", "weapon": "Assault Rifle",
        "mini": "War Drone", "boss": "Field Commander", "pet": "Scout Drone",
        "button": "res://assets/ui/play_modern.svg", "accent": "#8dbc93",
        "opponent": "Combat Units", "reward": "Plasma Launcher"
    },
    {
        "id": "future", "name": "Future Era", "weapon": "Plasma Launcher",
        "mini": "Mech Hound", "boss": "Titan Overlord", "pet": "Mini Mech",
        "button": "res://assets/ui/play_future.svg", "accent": "#74d5ff",
        "opponent": "Sentinels", "reward": "Mastery Emblem"
    }
]

static func get_era(index: int) -> Dictionary:
    return ERAS[clampi(index, 0, ERAS.size() - 1)]

static func era_count() -> int:
    return ERAS.size()
