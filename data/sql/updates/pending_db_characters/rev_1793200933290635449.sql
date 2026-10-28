-- Daily reward claims, one entry per character and Madrid calendar day.
-- A claim must be inserted in the same transaction as its reward delivery.
CREATE TABLE IF NOT EXISTS `azalea_daily_reward_claim` (
  `character_guid` INT UNSIGNED NOT NULL,
  `madrid_day` INT NOT NULL,
  `reward_day` TINYINT UNSIGNED NOT NULL,
  `reward_money_copper` INT UNSIGNED NOT NULL DEFAULT 0,
  `reward_item_id` INT UNSIGNED NOT NULL DEFAULT 0,
  `reward_item_count` INT UNSIGNED NOT NULL DEFAULT 0,
  `claimed_at_utc` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`character_guid`, `madrid_day`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
