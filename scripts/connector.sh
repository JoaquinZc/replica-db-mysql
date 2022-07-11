echo "Esperando..."
# Esperar 1 minuto para que se haya encendido todo y hacer la configuración.
sleep 60
echo "-----------------"
mysql --host mysqlslave -uroot -p$MYSQL_SLAVE_PASSWORD -AN -e 'STOP SLAVE;';
mysql --host mysqlmaster -uroot -p$MYSQL_MASTER_PASSWORD -AN -e 'RESET SLAVE ALL;';
sleep 2
echo "* Creando el usuario"
echo "* Ubicando master al esclavo"
MYSQL_USERS=$(eval "mysql --host mysqlmaster -uroot -p$MYSQL_MASTER_PASSWORD -e 'SELECT User FROM mysql.user \G' | grep User | sed -n -e 's/^.*: //p'")
if grep -q $MYSQL_REPLICATION_USER <<< "$MYSQL_USERS"; then
    echo "El usuario ya está creado."
else
    mysql --host mysqlmaster -uroot -p$MYSQL_MASTER_PASSWORD -AN -e "CREATE USER '$MYSQL_REPLICATION_USER'@'%' IDENTIFIED WITH mysql_native_password BY '$MYSQL_REPLICATION_PASSWORD';"
    mysql --host mysqlmaster -uroot -p$MYSQL_MASTER_PASSWORD -AN -e "GRANT REPLICATION SLAVE ON *.* TO '$MYSQL_REPLICATION_USER'@'%' IDENTIFIED BY '$MYSQL_REPLICATION_PASSWORD';"
    mysql --host mysqlmaster -uroot -p$MYSQL_MASTER_PASSWORD -AN -e "GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_REPLICATION_USER'@'%' WITH GRANT OPTION;"
    mysql --host mysqlmaster -uroot -p$MYSQL_MASTER_PASSWORD -AN -e 'flush privileges;'
fi

sleep 2
echo "Asignando al esclavo el master."

MASTER_POSITION=$(eval "mysql --host mysqlmaster -uroot -p$MYSQL_MASTER_PASSWORD -e 'show master status \G' | grep Position | sed -n -e 's/^.*: //p'")
MASTER_FILE=$(eval "mysql --host mysqlmaster -uroot -p$MYSQL_MASTER_PASSWORD -e 'show master status \G'     | grep File     | sed -n -e 's/^.*: //p'")
mysql --host mysqlslave -uroot -p$MYSQL_SLAVE_PASSWORD -AN -e "CHANGE REPLICATION SOURCE TO SOURCE_HOST='mysqlmaster', SOURCE_PORT=3306, SOURCE_USER='$MYSQL_REPLICATION_USER', SOURCE_PASSWORD='$MYSQL_REPLICATION_PASSWORD', SOURCE_SSL=1, master_log_file='$MASTER_FILE', master_log_pos=$MASTER_POSITION;"

echo "Iniciando esclavo...";
sleep 2
mysql --host mysqlslave -uroot -p$MYSQL_SLAVE_PASSWORD -AN -e "START SLAVE;"
echo "Esclavo iniciado."

mysql --host mysqlmaster -uroot -p$MYSQL_MASTER_PASSWORD -AN -e 'set GLOBAL max_connections=2000';
mysql --host mysqlslave -uroot -p$MYSQL_SLAVE_PASSWORD -AN -e 'set GLOBAL max_connections=2000';


