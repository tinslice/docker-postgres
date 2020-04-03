if [ -n "$POSTGRES_RUN_SCRIPTS" ]; then
    for db_name in `echo -n $POSTGRES_RUN_SCRIPTS | jq -r 'keys'[]`;do
        for init_script in `echo -n $POSTGRES_RUN_SCRIPTS | jq -r .${db_name}[]`; do
            ORIGIN_IFS=$IFS
            IFS=':' read -r -a script_parts <<< "$init_script"
            sql_user="${script_parts[0]}"
            sql_file="${script_parts[1]}"
            
            if [ -z "$sql_file" ]; then
                sql_file="${script_parts[0]}"
                sql_user=""
            fi

            if [ ! ${sql_file: -4} == ".sql" ]; then
                sql_file="${sql_file}.sql" 
            fi
            
            echo "== running script '$db_name:$sql_file'"
            if [ -n "$sql_user" ]; then
                psql -a -U $sql_user -d $db_name -f ${PG_SQL_SCRIPTS_PATH}/${sql_file}
            else
                psql -a -d $db_name -f ${PG_SQL_SCRIPTS_PATH}/${sql_file}
            fi
            IFS=$ORIGIN_IFS
        done
    done
fi