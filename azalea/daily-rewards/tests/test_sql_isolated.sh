#!/bin/sh
set -eu
repo=$(git rev-parse --show-toplevel)
name="azalea-daily-sql-test-$$"
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM
docker run -d --network none --name "$name" -e MYSQL_ALLOW_EMPTY_PASSWORD=yes mysql:8.4 >/dev/null
ready=0
for i in $(seq 1 60); do
  if docker exec "$name" mysqladmin ping --silent >/dev/null 2>&1; then ready=1; break; fi
  sleep 1
done
[ "$ready" = 1 ] || { echo 'MySQL startup timed out'; exit 1; }
docker exec "$name" mysql -uroot -e 'CREATE DATABASE reward_test'
docker exec -i "$name" mysql -uroot reward_test < "$repo/data/sql/updates/pending_db_characters/rev_1793200933290635449.sql"
docker exec -i "$name" mysql -uroot reward_test < "$repo/data/sql/updates/pending_db_characters/rev_1793200933290635449.sql"
docker exec "$name" mysql -uroot reward_test -e "INSERT INTO azalea_daily_reward_claim (character_guid,madrid_day,reward_day,reward_money_copper,claimed_at_utc) VALUES (1,20000,1,50000,1700000000),(2,20000,1,50000,1700000000),(1,20001,2,100000,1700086400)"
if docker exec "$name" mysql -uroot reward_test -e "INSERT INTO azalea_daily_reward_claim (character_guid,madrid_day,reward_day,claimed_at_utc) VALUES (1,20000,1,1700000000)" >/dev/null 2>&1; then
  echo 'Duplicate claim was incorrectly accepted'; exit 1
fi
printf '%s\n' 'SQL migration: repeatable; different characters and days accepted; same-character same-day duplicate rejected.'
