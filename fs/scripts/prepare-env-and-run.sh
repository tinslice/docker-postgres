#!/usr/bin/env bash

export PG_SCRIPTS_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=/usr/lib/postgresql/${PG_VERSION}/bin:$PATH

PG_CONFIG="/etc/postgresql/${PG_VERSION}/main/postgresql.conf"
PG_DATA_PATH="/var/lib/postgresql/data"
PG_SQL_SCRIPTS_PATH="/etc/postgresql/scripts"

rm -rf $PG_DATA_PATH/container_ready
rm -rf $PG_DATA_PATH/postmaster.pid


if [ -n "$PG_PORT" ]; then
    echo "== set postgresql port to '$PG_PORT'"
    sed -i "s/^port\\ =.*/port\\ =\\ $PG_PORT/g" $PG_CONFIG
fi

echo "== set default postgresql configuration"
# echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/${PG_VERSION}/main/pg_hba.conf 
sed -i "s|^local\\ *all\\ *all.*|local\\ all\\ all\\ trust|g" /etc/postgresql/${PG_VERSION}/main/pg_hba.conf
sed -i "s|^[#]*listen_addresses\\ =.*|listen_addresses\\ =\\ '*'|g" $PG_CONFIG
sed -i "s|^[#]*data_directory\\ =.*|data_directory\\ =\\ '${PG_DATA_PATH}'|g" $PG_CONFIG

PG_SHARED_LIBS='pg_stat_statements,pg_repack'
sed -i "s|^[#]*shared_preload_libraries\\ =.*|shared_preload_libraries\\ =\\ '${PG_SHARED_LIBS}'|g" $PG_CONFIG

export PG_FIRST_START=0

if [ ! "`ls -A ${PG_DATA_PATH}`" ]; then
    echo "== initialise postgres"
    initdb -D $PG_DATA_PATH
    export PG_FIRST_START=1
fi

echo "== starting postgresql server"
/usr/lib/postgresql/${PG_VERSION}/bin/postgres -D /var/lib/postgresql/${PG_VERSION}/main -c config_file=${PG_CONFIG} &

while ! pg_isready  > /dev/null 2> /dev/null; do
    echo ">> waiting for postgresql server to start"
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
echo "== container ready"
while true; do sleep 10;done