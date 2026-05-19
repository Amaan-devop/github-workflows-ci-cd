#!/bin/bash

# Purpose can be: backup | preprod_refresh | prod_support_refresh
HOST=$1
USER=$2
DATABASE_NAME=$3
PURPOSE=$4
BACKUP_PURPOSE=$5

CURRENT_DATE_TIME=$(date +"%Y_%m_%d_%H_%M")
SQL_SCRIPT_PATH="data-refresh.sql"

environment="${PURPOSE%_refresh}"
POST_DEPLOYMENT_SCRIPT_PATH="post-deployment/${environment}.sql"

PROD_DB="${DATABASE_NAME}_prod"
NEW_DB="${DATABASE_NAME}_new"
PREPROD_DB="${DATABASE_NAME}_preprod"
PROD_SUPPORT_DB="${DATABASE_NAME}_prod_support"
UAT_DB="${DATABASE_NAME}_uat"

echo "Running with purpose: $PURPOSE"
echo "Timestamp: $CURRENT_DATE_TIME"

# Function to create new DB from prod
create_new_db_from_prod() {
    echo "Step 1: Creating new database: $NEW_DB from $PROD_DB"
    psql -h $HOST -U $USER -d postgres -c "CREATE DATABASE $NEW_DB;"
    if [ $? -ne 0 ]; then
        echo "Failed to create $NEW_DB from $PROD_DB"
        exit 1
    fi
    
    echo "Copying the database ${DATABASE_NAME}_prod into $NEW_DB"
    pg_dump -h $HOST -U $USER -Fc ${DATABASE_NAME}_prod | pg_restore -h $HOST -U $USER -d $NEW_DB
}

# Function to run SQL script
run_sql_script_on_new() {
    echo "Step 2: Running SQL script on $NEW_DB"
    psql -h $HOST -U $USER -d $NEW_DB -f "$SQL_SCRIPT_PATH"
    if [ $? -ne 0 ]; then
        echo "Failed to execute SQL script on $NEW_DB"
        exit 1
    fi
}

# Function to refresh target DB
refresh_target_db() {
    TARGET_DB=$1
    TARGET_BACKUP_DB="${TARGET_DB}_bkp_${CURRENT_DATE_TIME}"

    echo "Step 3: Terminating connections to $TARGET_DB"
    psql -h $HOST -U $USER -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$TARGET_DB' AND pid <> pg_backend_pid();"

    echo "Step 4: Renaming $TARGET_DB to $TARGET_BACKUP_DB"
    psql -h $HOST -U $USER -d postgres -c "ALTER DATABASE $TARGET_DB RENAME TO $TARGET_BACKUP_DB;"

    echo "Step 5: Renaming $NEW_DB to $TARGET_DB"
    psql -h $HOST -U $USER -d postgres -c "ALTER DATABASE $NEW_DB RENAME TO $TARGET_DB;"
}

# Function to run Post deployment script
run_post_deployment_script() {
    TARGET_DB=$1
    echo "Step 6: Running SQL script on $TARGET_DB"
    psql -h $HOST -U $USER -d $TARGET_DB -f "$POST_DEPLOYMENT_SCRIPT_PATH"
    if [ $? -ne 0 ]; then
        echo "Failed to execute SQL script on $TARGET_DB"
        exit 1
    fi
}

# Main logic
case "$PURPOSE" in
    backup|backup_and_add_purpose)
        if [[ "$PURPOSE" == "backup_and_add_purpose" ]]; then
            if [[ -z "${BACKUP_PURPOSE:-}" ]]; then
                echo "Backup Purpose is required when PURPOSE=backup_and_add_purpose" >&2
                exit 1
            fi
            BACKUP_DB="${DATABASE_NAME}_prod_bkp_${CURRENT_DATE_TIME}_${BACKUP_PURPOSE}"
        else
            BACKUP_DB="${DATABASE_NAME}_prod_bkp_${CURRENT_DATE_TIME}"
        fi

        echo "Creating backup of $PROD_DB as $BACKUP_DB"
        psql -h $HOST -U $USER -d postgres -c "CREATE DATABASE $BACKUP_DB;"
        echo "Copying the database ${DATABASE_NAME}_prod into ${BACKUP_DB}"
        pg_dump -h $HOST -U $USER -Fc ${DATABASE_NAME}_prod | pg_restore -h $HOST -U $USER -d $BACKUP_DB

        # mask data
        if [[ "$PURPOSE" == "backup_and_add_purpose" ]]; then
            echo "Running script to mask data on $BACKUP_DB"
            psql -h $HOST -U $USER -d $BACKUP_DB -f "$SQL_SCRIPT_PATH"
            if [ $? -ne 0 ]; then
                echo "Failed to execute SQL script on $NEW_DB"
                exit 1
            fi
        fi
        ;;

    prod_support_refresh)
        create_new_db_from_prod
        run_sql_script_on_new
        refresh_target_db "$PROD_SUPPORT_DB"
        run_post_deployment_script "$PROD_SUPPORT_DB"
        echo "Successfully refreshed $PROD_SUPPORT_DB"
        ;;

    *)
        echo "Invalid purpose: $PURPOSE"
        echo "Valid options: backup | backup_and_add_purpose | preprod_refresh | prod_support_refresh | uat_refresh"
        exit 1
        ;;
esac