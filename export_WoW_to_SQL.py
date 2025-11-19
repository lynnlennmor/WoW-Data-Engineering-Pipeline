import re
import json
import pandas as pd
from sqlalchemy import create_engine #SQL database interaction
import urllib # Used for engine connection (simplifying connection string)
import pyodbc #For conneection to SQL Server

#Connect to SQL Server
params = urllib.parse.quote_plus(
            "DRIVER={ODBC Driver 17 for SQL Server};"
            "SERVER=<.\\SERVERNAME>;"
            "DATABASE=<DATABSENAME>;"
            "Trusted_Connection=yes"
        )
engine = create_engine(f"mssql+pyodbc:///?odbc_connect={params}")

# === 1. Read your SavedVariables file ===
lua_path = r"<PATHSTRING>.lua"
with open(lua_path, "r", encoding="utf-8") as f:
    lua_data = f.read()

# === 2 Extract only the inner table list (everything between the first and last { }) ===
start = lua_data.find("{")
end = lua_data.rfind("}") + 1
lua_table = lua_data[start:end]

# === 3 Convert Lua syntax to JSON-friendly ===
json_like = lua_table
json_like = re.sub(r"\[\"(.*?)\"\]\s*=", r'"\1":', json_like)
json_like = re.sub(r"(\w+)\s*=", r'"\1":', json_like)
json_like = json_like.replace("nil", "null")
json_like = json_like.replace("true", "true").replace("false", "false")
json_like = re.sub(r",(\s*[}\]])", r"\1", json_like)

# Wrap the outer table in [] to represent a list
# (The file looks like {{...}, {...}} so we turn that into [{"...": ...}, {...}] )
json_like = re.sub(r"^{\s*{", "[{", json_like)
json_like = re.sub(r"}\s*}$", "}]", json_like)

# === 4 Try parsing JSON ===
try:
    sessions = json.loads(json_like)
except json.JSONDecodeError as e:
    print("JSON parse failed:", e)
    print("\n Here's what it tried to parse:\n", json_like[:100])
    exit()

# === 5 Flatten nested data ===
flat_data = []
for session in sessions:
    flat = {
        "character": session.get("character"),
        "date": session.get("date"),
        "kills": session.get("kills"),
        "eliteKills":session.get("eliteKills"),
        "startLevel":session.get("startLevel"),
        "levelsGained": session.get("levelsGained"),
        "questsTurnedIn": session.get("questsTurnedIn"),
        "goldEarned": session.get("goldEarned"),
        "goldSpent": session.get("goldSpent"),
        "sessionDuration": session.get("sessionDuration"),
        "itemsLooted": session.get("itemsLooted"),
        "alchemyCreations":session.get("alchemyCreations"),
        "herbGathering":session.get("herbGathering"),
        "jumpCount": session.get("jumpCount"),
        "zoneDurations": json.dumps(session.get("zoneDurations", {}))[1:-1],
        "spellCombatCount": json.dumps(session.get("spellCombatCount", {}))[1:-1],
        "spellProfessionCount": json.dumps(session.get("spellProfessionCount", {}))[1:-1]
    }
    flat_data.append(flat)

# === 6 Clean Data & Export to Excel & SQL===
df = pd.DataFrame(flat_data)
# Creates normalized for ZoneDurations
zone_duration_data = []
for idx, row in df.iterrows():
    zones = [z.strip() for z in row['zoneDurations'].split(",")]
    for zone in zones:
        #print(zone)
        if ":" in zone:
            name, duration = zone.split(":",1)
            name = name.strip().strip('"')
            zone_duration_data.append({
                "character":row["character"],
                "date":row["date"],
                "zone":name,
                "duration":int(duration.strip())
            })
# Append to DataFrame            
df_zone_duration = pd.DataFrame(zone_duration_data)

# Dungeon counter
dungeon_list = ["Ragefire Chasm", "Wailing Caverns", "The Deadmines", "Shadowfang Keep", "The Stockade", "Blackfathom Deeps", "Gnomeregan", "Razorfen Kraul", "Scarlet Monastery", "Graveyard", "Library", "Armory", "Cathedral", "Razorfen Downs", "Uldaman", "Zul'Farrak", "Maraudon", "Wicked Grotto", "Foulspore Cavern", "Earth Song Falls", "The Temple of Atal'Hakkar", "Blackrock Depths", "Blackrock Spire", "Scholomance", "Stratholme", "Dire Maul"]
dungeon_data = []
for index, row in df_zone_duration.iterrows():
    zone_name = row["zone"]
    duration = row["duration"]
    if zone_name in dungeon_list:
        dungeon_data.append({
            "character":row["character"],
            "date":row["date"],
            "zone":zone_name,
            "duration":int(duration)
        })
# Append to DataFrame        
df_dungeons = pd.DataFrame(dungeon_data)

# Creates normalized table for CombatSpells & ProfessionSpells
combat_spells = []
profession_spells = []
for idx, row in df.iterrows():
    spells  = [s.strip() for s in row['spellCombatCount'].split(",")]
    pspells  = [s.strip() for s in row['spellProfessionCount'].split(",")]
    for spell in spells:
        #print(spell)
        if ":" in spell:
            name, count = spell.split(":",1)
            name = name.strip().strip('"')
            combat_spells.append({
                "character":row["character"],
                "date":row["date"],
                "spell":name,
                "count":int(count.strip())
            })
    for spell in pspells:
        #print(spell)
        if ":" in spell:
            name, count = spell.split(":",1)
            name = name.strip().strip('"')
            profession_spells.append({
                "character":row["character"],
                "date":row["date"],
                "spell":name,
                "count":int(count.strip())
            })

# Append to DataFrame
df_combat_spell = pd.DataFrame(combat_spells)
df_profession_spell = pd.DataFrame(profession_spells)

# Append to SQL Database 
df.to_sql('wow_data_staging', engine, if_exists='replace', chunksize=5000, index=False)
df_zone_duration.to_sql('wow_zone_durations_staging', engine, if_exists='replace', chunksize=5000, index=False)
df_combat_spell.to_sql('wow_combat_spells_staging', engine, if_exists='replace', chunksize=5000, index=False)
df_profession_spell.to_sql('wow_profession_spells_staging', engine, if_exists='replace', chunksize=5000, index=False)
df_dungeons.to_sql('wow_dungeon_data_staging', engine, if_exists='replace', chunksize=5000, index=False)

print(f"✅ Export to SQL complete!")

# Append to Excel Sheet (backup)
output = "SimpleLoginTracker_Sessions_2.0.xlsx"
with pd.ExcelWriter(output) as writer:
    df.to_excel(writer, sheet_name="Sessions", index=False)
    df_zone_duration.to_excel(writer, sheet_name="ZoneDurations", index=False)
    df_dungeons.to_excel(writer, sheet_name="Dungeons", index=False)
    df_combat_spell.to_excel(writer, sheet_name="CombatSpells", index=False)
    df_profession_spell.to_excel(writer, sheet_name="professionSpells", index=False)
#df.to_excel(output, index=False)
print(f"✅ Export complete! Saved as {output}")