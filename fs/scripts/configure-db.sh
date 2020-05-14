_jq_object() {
  echo -n ${1} | base64 --decode | jq -r "${2} | select (.!=null)"
}

_pg_role_update() {
  local role=${1}
  local privileges=${2}
  local roles="${3}"

  if [ -z "$roles" ]; then
    roles=''
  fi

  if [ -n "$role" ]; then
    if ! psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='${role}'" | grep -q 1; then
      echo "== creating role '$role'"
      psql --command "CREATE ROLE $role $privileges;"
    else
      echo "== updating priviledges for role '$role'"
      psql --command "ALTER ROLE $role WITH $privileges;"
    fi

    local roles_array=`echo -n $roles | jq -r .[]`
    local granted_role=''
    for granted_role in $roles_array; do
      psql --command "GRANT $granted_role TO $role"
    done
  fi
}

_pg_database_init() {
  local db_name=${1}
  local init_script=''

  echo "== run init scripts for '$db_name'"
  for init_script in `echo -n $POSTGRES_DB | jq -r .${db_name}.init[]?`; do
    local ORIGIN_IFS=$IFS
    IFS=':' read -r -a script_parts <<< "$init_script"
    local sql_user="${script_parts[0]}"
    local sql_file="${script_parts[1]}"
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
}

# change database owner
_pg_database_owner() {
  local db_name=${1}
  local db_db_role=${2}
  local db_schemas=${3}

  echo "== changing owner for database '$db_name' to '$db_role'"
  psql -d $db_name -c "ALTER DATABASE $db_name OWNER TO $db_role;"
  psql -d $db_name -c "GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_role;"
  
  # psql --command "GRANT ALL ON ALL TABLES IN SCHEMA public TO $db_role;"

  local db_schema='';
  for db_schema in $db_schemas; do
    psql -d $db_name -c "ALTER SCHEMA $db_schema OWNER TO $db_role;"
    _pg_database_schema_permissions "$db_name" "$db_role" "ALL" "$db_schema"

    local db_table=''
    for db_table in `psql -d $db_name -qAt -c "SELECT tablename FROM pg_tables WHERE schemaname = '$db_schema';"` ; do  
      psql -d $db_name -c "ALTER TABLE \"$db_table\" OWNER TO $db_role;"
    done

    local db_sequence=''
    for db_sequence in `psql -d $db_name -qAt -c "SELECT sequence_name FROM information_schema.sequences where sequence_schema = '$db_schema';"` ; do  
      psql -d $db_name -c "alter sequence \"$db_sequence\" owner to $db_role;" 
    done

    local db_view=''
    for db_view in `psql -d $db_name -qAt -c "SELECT table_name FROM information_schema.views where table_schema = '$db_schema';"` ; do  
      psql -d $db_name -c "alter view \"$db_view\" owner to $db_role;" 
    done
  done
}

# change permissions on database objects
_pg_database_schema_permissions() {
  local db_name=${1}
  local db_db_role=${2}
  local db_privileges=${3}
  local db_schemas=${4}
  local db_object_type=${5}
  local db_object_name=${6}

  # grant privileges on database
  if [ -z "$db_schemas" ]; then
    local db_privilege=''
    for db_privilege in ${db_privileges//,/ }; do
      if [ $db_privilege == 'ALL' ] || [ $db_privilege == 'CREATE' ] || \
        [ $db_privilege == 'TEMPORARY' ] || [ $db_privilege == 'TEMP' ]; then
        psql -c "GRANT $db_privilege ON DATABASE $db_name TO $db_role;"
      fi
    done
  fi

  # grant privileges on database schemas
  local db_schema=''
  for db_schema in $db_schemas; do
    if [ "$db_privileges" ==  'ALL' ] && [ -z "$db_object_type"] ; then
      psql -d $db_name -c "GRANT ALL ON SCHEMA $db_schema TO $db_role;"
    else
      psql -d $db_name -c "GRANT USAGE ON SCHEMA $db_schema TO $db_role;"
    fi

    if [ -z "$db_object_type" ]; then
      local db_object_privilege=''
      for db_object_privilege in ${db_privileges//,/ }; do
        if [ $db_object_privilege == 'ALL' ] || \
          [ $db_object_privilege == 'SELECT' ] || [ $db_object_privilege == 'INSERT' ] || \
          [ $db_object_privilege == 'UPDATE' ] || [ $db_object_privilege == 'DELETE' ]; then
          psql -d $db_name -c "GRANT $db_object_privilege ON ALL TABLES IN SCHEMA $db_schema TO $db_role;"
          psql -d $db_name -c "ALTER DEFAULT PRIVILEGES IN SCHEMA $db_schema GRANT $db_object_privilege ON TABLES TO $db_role;"
        fi
        
        if [ $db_object_privilege == 'ALL' ] || [ $db_object_privilege == 'USAGE' ] || \
          [ $db_object_privilege == 'SELECT' ] || [ $db_object_privilege == 'UPDATE' ]; then
          psql -d $db_name -c "GRANT $db_object_privilege ON ALL SEQUENCES IN SCHEMA $db_schema TO $db_role;"
          psql -d $db_name -c "ALTER DEFAULT PRIVILEGES IN SCHEMA $db_schema GRANT $db_object_privilege ON SEQUENCES TO $db_role;"
        fi

        if [ $db_object_privilege == 'ALL' ] || [ $db_object_privilege == 'EXECUTE' ]; then
          psql -d $db_name -c "GRANT $db_object_privilege ON ALL FUNCTIONS IN SCHEMA $db_schema TO $db_role;"
          psql -d $db_name -c "ALTER DEFAULT PRIVILEGES IN SCHEMA $db_schema GRANT $db_object_privilege ON FUNCTIONS TO $db_role;"
        fi
      done
    else
      if [ "$db_object_name" == '*' ]; then
        psql -d $db_name -c "GRANT $db_privileges ON ALL $db_object_type IN SCHEMA $db_schema TO $db_role;"
        psql -d $db_name -c "ALTER DEFAULT PRIVILEGES IN SCHEMA $db_schema GRANT $db_privileges ON $db_object_type TO $db_role;"
      else
        psql -d $db_name -c "GRANT $db_privileges ON ${db_object_type%?} $db_object_name IN SCHEMA $db_schema TO $db_role;"
      fi
    fi
  done
}

# update database permissions for role
_pg_database_role_permissions() {
  local db_name=${1}
  
  echo "== updating user access for database '$db_name'"
  if ! psql -lqtA | grep -q "^$db_name|"; then
    echo "== WARNING: database '$db_name' does not exist"
    return 0;
  fi
  
  local db_roles=`echo -n $POSTGRES_DB | jq -r .${db_name}.roles[]?.name`
  
  local db_schemas=`psql -d $db_name -qtA -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name <> 'information_schema' AND schema_name NOT LIKE 'pg_%'"`
  local db_role=''
  for db_role in $db_roles; do
    if ! psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='${db_role}'" | grep -q 1; then
      continue
    fi   

    local db_role_config=`echo -n $POSTGRES_DB | jq -r ".${db_name}.roles[] | select(.name == \"${db_role}\")"`

    # check if owner 
    if echo $db_role_config | jq -r .owner | grep -q 'true'; then
      _pg_database_owner "$db_name" "$db_role" "$db_schemas"
      continue
    fi

    # update access based on role privileges
    local db_privileges=`echo $db_role_config | jq -r '.privileges | select (.!=null)'`
    if [ -n "$db_privileges" ]; then
      _pg_database_schema_permissions "$db_name" "$db_role" "$db_privileges"
      _pg_database_schema_permissions "$db_name" "$db_role" "$db_privileges" "$db_schemas"
    fi

    # update access based on schema config
    local db_role_schemas=`echo -n $db_role_config | jq -r .schemas[]?.name`
    local db_role_schema=''
    for db_role_schema in $db_role_schemas; do
      local db_role_schema_config=`echo -n $db_role_config | jq -r ".schemas[] | select(.name == \"${db_role_schema}\")"`
      # update access based on schema privileges
      db_privileges=`echo $db_role_schema_config | jq -r '.privileges | select (.!=null)'`
      if [ -n "$db_privileges" ]; then
        _pg_database_schema_permissions "$db_name" "$db_role" "$db_privileges" "$db_role_schema"
      fi

      # update access based on object type privileges
      local db_object_type=''
      local db_object_name=''
      for db_object_type in tables sequences functions; do
        db_object_name=`echo $db_role_schema_config | jq -r .$db_object_type[]?.name`
        db_privileges=`echo $db_role_schema_config | jq -r .$db_object_type[]?.privileges`
        if [ -z "$db_object_name" ]; then
          db_object_name="*"
        fi
        if [ -n "$db_privileges" ];then
          _pg_database_schema_permissions "$db_name" "$db_role" "$db_privileges" "$db_role_schema" "$db_object_type" "$db_object_name"
        fi
      done
    done
  done
}

echo "== set postgres user password =="
if [ -z "$POSTGRES_PASSWORD" ]; then 
    export POSTGRES_PASSWORD="postgres"
fi

psql --command "ALTER USER postgres WITH PASSWORD '$POSTGRES_PASSWORD';"

echo "== create roles =="
if [ -n "$POSTGRES_ROLES" ]; then
  for db_role in `echo -n $POSTGRES_ROLES | jq -r '.[] | @base64'`; do
    db_role_name=`_jq_object "$db_role" '.name'`
    db_role_privileges=`_jq_object "$db_role" '.privileges'`
    if [ -z "$db_role_privileges" ]; then
      db_role_privileges='';
    fi

    db_role_roles=`_jq_object "$db_role" '.roles'`
    _pg_role_update "$db_role_name" "$db_role_privileges" "$db_role_roles"
  done
fi

echo "== create users =="
if [ -n "$POSTGRES_USERS" ]; then
  for db_role in `echo -n $POSTGRES_USERS | jq -r '.[] | @base64'`; do
    db_role_name=`_jq_object "$db_role" '.name'`
    db_role_password=`_jq_object "$db_role" '.password'`
    if [ -z "$db_role_password" ]; then
      db_role_password='changeit';
    fi

    db_role_privileges=`_jq_object "$db_role" '.privileges'`
    granted_privileges=''
    if [ -n "$db_role_privileges" ]; then
      privileges_array=`echo -n $db_role_privileges | jq -r .[]`
      granted_privilege=''
      for granted_privilege in $privileges_array; do
        granted_privileges="$granted_privileges $granted_privilege"
      done
    fi

    db_role_roles=`_jq_object "$db_role" '.roles'`
    _pg_role_update "$db_role_name" "inherit login password '$db_role_password' $granted_privileges" "$db_role_roles"
  done
fi

echo "== create databases && update database permissions =="
if [ -n "$POSTGRES_DB" ]; then
  for db_name in `echo -n $POSTGRES_DB | jq -r 'keys'[]`;do
    
    # create database if not exist
    if ! psql -lqtA | grep -q "^$db_name|"; then
      echo "== creating database '$db_name'"
      psql --command "create database $db_name;"
      psql -d $db_name --command "REVOKE ALL ON SCHEMA public FROM public"

      _pg_database_init $db_name
    fi

    # update database permissions
    _pg_database_role_permissions $db_name
  done
fi
