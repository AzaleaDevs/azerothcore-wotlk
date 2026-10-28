#!/bin/sh
# Isolated database experiment, not a test of the unimplemented game service.
set -eu
name="azalea-daily-atomicity-$$"
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM
docker run -d --network none --name "$name" -e MYSQL_ALLOW_EMPTY_PASSWORD=yes mysql:8.4 >/dev/null
ready() {
  for i in $(seq 1 90); do
    docker exec "$name" mysqladmin ping --silent >/dev/null 2>&1 && return 0
    sleep 1
  done
  return 1
}
ready
sql() { docker exec -i "$name" mysql -N -uroot "$@"; }
sql -e 'CREATE DATABASE reward_test'
sql reward_test <<'SQL'
CREATE TABLE claim (character_guid INT NOT NULL, madrid_day INT NOT NULL,
  mail_id INT NOT NULL, PRIMARY KEY(character_guid, madrid_day), UNIQUE(mail_id)) ENGINE=InnoDB;
CREATE TABLE mail (id INT PRIMARY KEY, receiver INT NOT NULL, money INT NOT NULL) ENGINE=InnoDB;
START TRANSACTION;
INSERT INTO claim VALUES (1, 20000, 101);
INSERT INTO mail VALUES (101, 1, 50000);
COMMIT;
INSERT INTO mail VALUES (104, 99, 1);
SQL
# An error after writing the ledger must not leave a claim behind.
if sql reward_test <<'SQL' >/dev/null 2>&1
START TRANSACTION;
INSERT INTO claim VALUES (2, 20000, 104);
INSERT INTO mail VALUES (104, 2, 50000);
COMMIT;
SQL
then echo 'Expected duplicate failure' >&2; exit 1; fi
[ "$(sql reward_test -e 'SELECT COUNT(*) FROM claim WHERE character_guid=2')" = 0 ]
# Competing claims insert different mail ids, but only one claim may commit.
claim() {
  sql reward_test <<SQL
START TRANSACTION;
INSERT INTO claim VALUES (3, 20000, $1);
INSERT INTO mail VALUES ($1, 3, 50000);
COMMIT;
SQL
}
claim 102 >/dev/null 2>&1 & p1=$!
claim 103 >/dev/null 2>&1 & p2=$!
wait "$p1" || :
wait "$p2" || :
[ "$(sql reward_test -e 'SELECT COUNT(*) FROM claim WHERE character_guid=3')" = 1 ]
[ "$(sql reward_test -e 'SELECT COUNT(*) FROM mail WHERE receiver=3')" = 1 ]
docker restart "$name" >/dev/null
ready
[ "$(sql reward_test -e 'SELECT COUNT(*) FROM claim c JOIN mail m ON m.id=c.mail_id AND m.receiver=c.character_guid')" = 2 ]
printf '%s\n' 'Isolated SQL model: atomic rollback, concurrent duplicate, and restart checks passed.'
