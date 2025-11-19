/*
Author: Lynn
Project: WoW Data Engineering Pipeline
Goal: Queries to transform & clean data for analytics

Query 1: Session data 
- Including: kills, elitekills, levelsGained, questsTurnedIn, goldEarned, goldSpent,itemsLooted,
- alchemyCreations, herbGathering, JumpCount, demonsSummoned

Query 2: Combat Spells
- Including: Shadow Bolts, Demons Summoned (total and split by demon)

Query 3: Zone visits & duration (total)

Query 4: Dungeons played (total count)

Query 5: Total data
- Including: Total monsters killed, Total Jumps, total elite monsters,
- total quests, total shadow bolts, demons, herbs, alchemy creations
- total dungeons, total looted items
*/

-- =================
--	1. Session data
-- =================
SELECT
	character_name,
	ROW_NUMBER() OVER(ORDER BY session_date_time) AS adventure_day,
	session_date_time,
	session_duration_seconds,
	CONCAT(
        FLOOR(session_duration_seconds / 3600), 'h ',
        FLOOR((session_duration_seconds % 3600) / 60), 'm') AS session_duration_text,
	monster_kills,
	monster_elite_kills,
	items_looted,
	levels_gained,
	quests_completed,
	CASE 
		WHEN session_date_time > '2025-11-05' THEN gold_earned ELSE 0
	END as total_gold_earned, -- I messed up with the in game tracking
	CASE 
		WHEN session_date_time > '2025-11-05' THEN gold_spent ELSE 0
	END as total_gold_spent, -- I messed up with the in game tracking
	shadow_bolts_casts,
	demons_summoned,
	alchemy_creations,
	ISNULL(
	CASE
		WHEN sd.herbs_gathered IS NULL THEN pss.count ELSE sd.herbs_gathered
	END,0) as herb_gathered, -- I changed the tracking output in the Addon, so have to use this bandaid
	ISNULL(jump_count,0) as jump_count
FROM session_data sd
LEFT JOIN wow_profession_spells_staging pss
	ON pss.date = sd.session_date_time
WHERE character_name = 'Dagwood'
	AND session_duration_seconds > 480;-- Any session under 8 minutes are not included

-- ==================
--	2. Combat Spells
-- ==================
SELECT
	spell_name,
	SUM(spell_count) as total_spell_count
FROM session_combat_spells
WHERE character_name = 'Dagwood'
GROUP BY spell_name
ORDER BY spell_name;

-- ===================================
--	3. Zone visits & duration (total)
-- ===================================
SELECT
	zone_name,
	SUM(duration_seconds) as zone_duration_seconds,
    CONCAT(
        FLOOR(SUM(duration_seconds) / 3600), 'h ',
        FLOOR((SUM(duration_seconds) % 3600) / 60), 'm') AS zone_duration_text
FROM (
	SELECT
		*
	FROM session_zones sz
	WHERE sz.duration_seconds > 180 -- Any duration less then 3 min is most likely a flyover
		AND sz.zone_name NOT IN (SELECT dungeon_name FROM session_dungeons) -- Excluding dungeons from zones
		AND character_name = 'Dagwood'
) as cleaned_zones
GROUP BY zone_name
ORDER BY zone_duration_seconds DESC;

-- 4. Dungeons played
SELECT
	dungeon_name,
	SUM(duration_seconds) as dungeon_duration_seconds,
    CONCAT(
        FLOOR(SUM(duration_seconds) / 3600), 'h ',
        FLOOR((SUM(duration_seconds) % 3600) / 60), 'm') AS dungeon_duration_text
FROM session_dungeons
WHERE character_name = 'Dagwood'
GROUP BY dungeon_name
ORDER BY dungeon_duration_seconds DESC;


-- ===============
--	5. Total data
-- ===============
SELECT
	character_name,
	SUM(levels_gained) + 1 as character_level, -- +1 is ot include level 1
	AVG(session_duration_seconds) as avg_session_duration_seconds,
	CONCAT(
        FLOOR(AVG(session_duration_seconds) / 3600), 'h ',
        FLOOR((AVG(session_duration_seconds) % 3600) / 60), 'm') AS avg_session_duration_text,
	MAX(session_duration_seconds) as longest_session_seconds,
	CONCAT(
        FLOOR(MAX(session_duration_seconds) / 3600), 'h ',
        FLOOR((MAX(session_duration_seconds) % 3600) / 60), 'm') AS longest_session_text,
	SUM(monster_kills) as total_monster_kills,
	SUM(monster_elite_kills) as totala_monster_elite_kills,
	SUM(items_looted) as total_items_looted,
	SUM(quests_completed) as total_quests_completed,
	SUM(
		CASE WHEN session_date_time > '2025-11-05' THEN gold_earned ELSE 0
		END) as total_gold_earned, -- I messed up with the in game tracking
	SUM(
		CASE WHEN session_date_time > '2025-11-05' THEN gold_spent ELSE 0
		END) as total_gold_spent, -- I messed up with the in game tracking
	SUM(shadow_bolts_casts) as total_shadow_bolts_casts,
	SUM(demons_summoned) as total_demons_summoned,
	sum(alchemy_creations) as total_alchemy_creations,
	SUM(
		CASE
			WHEN sd.herbs_gathered IS NULL THEN pss.count ELSE sd.herbs_gathered
		END) as total_herb_gathered,
	SUM(ISNULL(jump_count,0)) as total_jump_count
FROM session_data sd
LEFT JOIN wow_profession_spells_staging pss
	ON pss.date = sd.session_date_time
WHERE character_name = 'Dagwood'
	AND session_duration_seconds > 480 -- Any session under 8 minutes are not included
GROUP BY character_name;