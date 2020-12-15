#!/usr/bin/env bash
set -e

_log() {
  echo "`date +"%Y-%m-%d %T %Z"`   ${1}"
}

export PG_SCRIPTS_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=/usr/lib/postgresql/${PG_VERSION}/bin:$PATH

PG_CONFIG="/etc/postgresql/${PG_VERSION}/main/postgresql.conf"
PG_DATA_PATH="/var/lib/postgresql/data"
if [ -n "$PGDATA" ]; then
  PG_DATA_PATH="$PGDATA"
fi

PG_SQL_SCRIPTS_PATH="/etc/postgresql/scripts"

rm -rf $PG_DATA_PATH/container_ready
rm -rf $PG_DATA_PATH/postmaster.pid

if [ -n "$PG_PORT" ]; then
  _log "== set postgresql port to '$PG_PORT'"
  sed -i "s/^port\\ =.*/port\\ =\\ $PG_PORT/g" $PG_CONFIG
fi

_log "== set default postgresql configuration"
# echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/${PG_VERSION}/main/pg_hba.conf
sed -i "s|^local\\ *all\\ *all.*|local\\ all\\ all\\ trust|g" /etc/postgresql/${PG_VERSION}/main/pg_hba.conf
sed -i "s|^[#]*listen_addresses\\ =.*|listen_addresses\\ =\\ '*'|g" $PG_CONFIG
sed -i "s|^[#]*data_directory\\ =.*|data_directory\\ =\\ '${PG_DATA_PATH}'|g" $PG_CONFIG

sed -i "s|^[#]*log_min_duration_statement\\ =.*|log_min_duration_statement\\ =\\ 500|g" $PG_CONFIG
sed -i "s|^[#]*log_checkpoints\\ =.*|log_checkpoints\\ =\\ on|g" $PG_CONFIG
sed -i "s|^[#]*log_connections\\ =.*|log_connections\\ =\\ on|g" $PG_CONFIG
sed -i "s|^[#]*log_disconnections\\ =.*|log_disconnections\\ =\\ on|g" $PG_CONFIG
sed -i "s|^[#]*log_duration\\ =.*|log_duration\\ =\\ off|g" $PG_CONFIG
sed -i "s|^[#]*log_lock_waits\\ =.*|log_lock_waits\\ =\\ on|g" $PG_CONFIG
sed -i "s|^[#]*log_statement\\ =.*|log_statement\\ =\\ none|g" $PG_CONFIG

PG_SHARED_LIBS='pg_stat_statements,pg_repack'
sed -i "s|^[#]*shared_preload_libraries\\ =.*|shared_preload_libraries\\ =\\ '${PG_SHARED_LIBS}'|g" $PG_CONFIG

export PG_FIRST_START=0

if [ -z "$POSTGRES_ENCODING" ]; then
  export POSTGRES_ENCODING="UTF8"
fi

if [ ! "`ls -A ${PG_DATA_PATH}`" ]; then
  _log "== initialise postgres"
  initdb -E $POSTGRES_ENCODING -D $PG_DATA_PATH
  export PG_FIRST_START=1
fi

_log "== starting postgresql server"
/usr/lib/postgresql/${PG_VERSION}/bin/postgres -D /var/lib/postgresql/${PG_VERSION}/main -c config_file=${PG_CONFIG} &

while ! pg_isready  > /dev/null 2> /dev/null; do
  _log ">> waiting for postgresql server to start"
  sleep 1
done

if [ $PG_FIRST_START -eq 1 ]; then
  mkdir -p $PG_SQL_SCRIPTS_PATH
fi

. ${PG_SCRIPTS_PATH}/configure-db.sh

# run sql files defined in the RUN_SCRIPTS env variable
. ${PG_SCRIPTS_PATH}/run-sql-scripts.sh

# run sql commands defined in the RUN_SQL env variable
. ${PG_SCRIPTS_PATH}/run-sql-commands.sh

touch $PG_DATA_PATH/container_ready
_log "== container ready"

while true; do sleep 10;done