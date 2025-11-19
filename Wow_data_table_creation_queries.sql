/*
Author: Lynn
Project: WoW Data Engineering Pipeline
Goal: Simple table creation
*/

CREATE TABLE session_data (
	character_name VARCHAR(255),
	session_date_time DATETIME,
	session_duration_seconds BIGINT,
	monster_kills INT,
	monster_elite_kills INT,
	items_looted INT,
	levels_gained INT,
	quests_completed INT,
	gold_earned FLOAT,
	gold_spent FLOAT,
	shadow_bolts_casts INT,
	demons_summoned INT,
	alchemy_creations INT,
	herbs_gathered INT,
	jump_count BIGINT
);

CREATE TABLE session_combat_spells (
	character_name VARCHAR(255),
	session_date_time DATETIME,
	spell_name VARCHAR(255),
	spell_count INT
);

CREATE TABLE session_dungeons (
	character_name VARCHAR(255),
	session_date_time DATETIME,
	dungeon_name VARCHAR(255),
	duration_seconds BIGINT
);

CREATE TABLE session_zones (
	character_name VARCHAR(255),
	session_date_time DATETIME,
	zone_name VARCHAR(255),
	duration_seconds BIGINT
);