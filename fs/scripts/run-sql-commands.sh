if [ -n "$POSTGRES_RUN_SQL" ]; then
  ORIGIN_IFS=$IFS
  IFS=$'\n'
  for db_name in `echo -n $POSTGRES_RUN_SQL | jq -r 'keys'[]`;do
    for sql_cmd in `echo -n $POSTGRES_RUN_SQL | jq -r .${db_name}[]`; do
        echo "== running sql: ${db_name}:${sql_cmd}"
        if [ "$db_name" = '_' ]; then
          psql --command "${sql_cmd};"
        else
          psql -d $db_name --command "${sql_cmd};"
        fi
    done
  done
  IFS=$ORIGIN_IFS
fi