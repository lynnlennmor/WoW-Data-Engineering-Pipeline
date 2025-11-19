/*
Author: Lynn
Project: WoW Data Engineering Pipeline
Goal: "Automated" process of moving data from Staging Tables to Production tables. 
	   Truncating data and replacing it with updated dataset.
*/

-- =========================================================
--	1. Truncate & Insert updated data to tables from staging
-- =========================================================

-- Stored Procedure to Update WoW data automatically.
CREATE OR ALTER PROCEDURE wow_sp_refresh_data
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		BEGIN TRANSACTION;

		PRINT 'Truncating and Refreshing data into: [session_zones] ';
		TRUNCATE TABLE session_zones;
		INSERT INTO session_zones (character_name, session_date_time, zone_name, duration_seconds)
		SELECT 
			character,
			date,
			zone,
			duration
		FROM wow_zone_durations_staging;

		PRINT 'Truncating and Refreshing data into: [session_dungeons] ';
		TRUNCATE TABLE session_dungeons;
		INSERT INTO session_dungeons (character_name,session_date_time,dungeon_name,duration_seconds)
		SELECT 
			character,
			date,
			zone,
			duration
		FROM wow_dungeon_data_staging;

		PRINT 'Truncating and Refreshing data into: [session_combat_spells] ';
		TRUNCATE TABLE session_combat_spells;
		INSERT INTO session_combat_spells (character_name,session_date_time,spell_name,spell_count)
		SELECT 
			character,
			date,
			spell,
			count
		FROM wow_combat_spells_staging;

		PRINT 'Truncating and Refreshing data into: [session_data] ';
		TRUNCATE TABLE session_data;
		INSERT INTO session_data (
			character_name,
			session_date_time,
			session_duration_seconds,
			monster_kills,
			monster_elite_kills,
			items_looted,
			levels_gained,
			quests_completed,
			gold_earned,
			gold_spent,
			shadow_bolts_casts,
			demons_summoned,
			alchemy_creations,
			herbs_gathered,
			jump_count
		)
		SELECT
			d.character,
			d.date,
			d.sessionDuration,
			d.kills,
			d.eliteKills,
			d.itemsLooted,
			d.levelsGained,
			d.questsTurnedIn,
			d.goldEarned,
			d.goldSpent,
			spells.total_shadow_bolts,
			spells.total_demons,
			d.alchemyCreations,
			d.herbGathering,
			d.jumpCount
		FROM wow_data_staging d
		LEFT JOIN (
			SELECT
				date,
				SUM(CASE WHEN spell = 'Shadow Bolt' THEN count ELSE 0 END) as total_shadow_bolts,
				SUM(CASE WHEN spell LIKE '%Summon%' THEN count ELSE 0 END) as total_demons
			FROM wow_combat_spells_staging
			GROUP BY date
		) as spells
			ON d.date = spells.date
		ORDER BY date;

		COMMIT TRANSACTION;

		PRINT 'Test Complete';

		-- Log sucess
		INSERT INTO wow_refresh_log (procedure_name, status, message)
		VALUES ('wow_refresh_data', 'Sucess', 'wow_data refreshed sucessfully :)');
	END TRY

	BEGIN CATCH
		PRINT 'An error has occured...';
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION;

		-- Log failures
		INSERT INTO wow_refresh_log (procedure_name, status, message)
		VALUES (
			'wow_refresh_data',
			'Error',
			CONCAT('Error: ', ERROR_MESSAGE())
		);

		THROW;
	END CATCH;
END

EXEC wow_sp_refresh_data;