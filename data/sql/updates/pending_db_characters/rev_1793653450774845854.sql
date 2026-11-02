-- Azalea Core · daily rewards: one row per character and Madrid calendar day (feature/daily-rewards)
CREATE TABLE IF NOT EXISTS `azalea_daily_rewards_claim` (
    `character_guid` INT UNSIGNED NOT NULL COMMENT 'characters.guid',
    `madrid_day` INT NOT NULL COMMENT 'Days since 1970-01-01, Europe/Madrid calendar',
    `streak_day` INT UNSIGNED NOT NULL COMMENT '1-13 gold, 14+ Frozen Orb',
    `reward_gold` INT UNSIGNED NOT NULL DEFAULT 0,
    `reward_item` INT UNSIGNED NOT NULL DEFAULT 0,
    `claimed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`character_guid`, `madrid_day`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Azalea Core daily rewards claims';
