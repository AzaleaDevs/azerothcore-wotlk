-- Azalea Core · daily rewards: uninstall (acore_characters). Not in pending_*, so it never runs by itself.
-- Remove lua_scripts/azalea_daily_rewards.lua from the live installation first, then run this.
DROP TABLE IF EXISTS `azalea_daily_rewards_claim`;
