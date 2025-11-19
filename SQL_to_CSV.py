### Author: Lynn
### Project: WoW Data Engineering Pipeline
### Goal: Script to read SQL queries and export data to CSV.

from sqlalchemy import create_engine
import pandas as pd
from datetime import datetime
import urllib # Used for engine connection (simplifying connection string)
import pyodbc #For conneection to SQL Server

#Connect to SQL Server
#Removed server & database name in this file for show
params = urllib.parse.quote_plus(
            "DRIVER={ODBC Driver 17 for SQL Server};"
            "SERVER=<.\\SERVERNAME>;"
            "DATABASE=<DATABASE>;"
            "Trusted_Connection=yes"
        )
engine = create_engine(f"mssql+pyodbc:///?odbc_connect={params}")

# Running SQL Query (running a stored procedure)
# I created Stored Procedures to make the coding easier in the python file, alternatively I could have added the whole queries in there.

# Run query & save to DataFrame
df_session_data = pd.read_sql_query("EXEC wow_sp_fetch_session_data", engine)
df_combat_spells_data = pd.read_sql_query("EXEC wow_sp_fetch_combat_spells_data", engine)
df_zones_data = pd.read_sql_query("EXEC wow_sp_fetch_zone_data", engine)
df_dungeon_data = pd.read_sql_query("EXEC wow_sp_fetch_dungeon_data", engine)
df_total_data= pd.read_sql_query("EXEC wow_sp_fetch_total_data", engine)

# Export to CSV
csv_path_1 = r"<FOLDERNAME>\wow_session_data.csv"
csv_path_2 = r"<FOLDERNAME>\wow_combat_spells_data.csv"
csv_path_3 = r"<FOLDERNAME>\wow_zones_data.csv"
csv_path_4 = r"<FOLDERNAME>\wow_dungeon_data.csv"
csv_path_5 = r"<FOLDERNAME>\wow_total_data.csv"

df_session_data.to_csv(csv_path_1, index = False)
df_combat_spells_data.to_csv(csv_path_2, index = False)
df_zones_data.to_csv(csv_path_3, index = False)
df_dungeon_data.to_csv(csv_path_4, index = False)
df_total_data.to_csv(csv_path_5, index = False)

print(f"{datetime.now()}: Exported {len(df_session_data)} rows to {csv_path_1}")
print(f"{datetime.now()}: Exported {len(df_combat_spells_data)} rows to {csv_path_2}")
print(f"{datetime.now()}: Exported {len(df_zones_data)} rows to {csv_path_3}")
print(f"{datetime.now()}: Exported {len(df_dungeon_data)} rows to {csv_path_4}")
print(f"{datetime.now()}: Exported {len(df_total_data)} rows to {csv_path_5}")
