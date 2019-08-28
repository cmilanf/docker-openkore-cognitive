#!/bin/sh
echo "******************************"
echo "* openkore Docker entrypoint *"
echo "******************************"
echo ""
DATE=$(date '+%Y-%m-%d %H:%M:%S')
echo "Initalizing Docker container..."
SLEEP=$((RANDOM % 30))
echo "Sleeping for ${SLEEP} seconds, so I let other bots take care of the database connections pool."
sleep ${SLEEP}
if [ -z "${OK_IP}" ]; then echo "Missing OK_IP environment variable. Unable to continue."; exit 1; fi
if [ -z "${OK_USERNAME}" ]; then echo "Missing OK_USERNAME environment variable. Unable to continue."; exit 1; fi
if [ -z "${OK_PWD}" ]; then echo "Missing OK_PWD environment variable. Unable to continue."; exit 1; fi
if [ -z "${OK_CHAR}" ]; then OK_CHAR=1; fi
if [ "${OK_KILLSTEAL}" == "1" ]; then 
    sed -i "1505s|return 0|return 1|" /opt/openkore/src/Misc.pm
    sed -i "1532s|return 0|return 1|" /opt/openkore/src/Misc.pm
    sed -i "1569s|return !objectIsMovingTowardsPlayer(\$monster);|return 1;|" /opt/openkore/src/Misc.pm
    sed -i "1581s|return 0|return 1|" /opt/openkore/src/Misc.pm
fi

if [ -z "${OK_USERNAMEMAXSUFFIX}" ]; then
    sed -i "s|^username$|username ${OK_USERNAME}|g" /opt/openkore/control/config.txt
else
    if [ -z "${MYSQL_HOST}" ]; then echo "Missing MYSQL_HOST environment variable. Unable to continue."; exit 1; fi
    if [ -z "${MYSQL_DB}" ]; then echo "Missing MYSQL_DB environment variable. Unable to continue."; exit 1; fi
    if [ -z "${MYSQL_USER}" ]; then echo "Missing MYSQL_USER environment variable. Unable to continue."; exit 1; fi
    if [ -z "${MYSQL_PWD}" ]; then echo "Missing MYSQL_PWD environment variable. Unable to continue."; exit 1; fi
    for i in `seq 0 $((${OK_USERNAMEMAXSUFFIX}-1))`;
    do
        USERNAME=${OK_USERNAME}${i}
        MYSQL_QUERY="SELECT \`online\` FROM custom_char_online_lock WHERE name='${USERNAME}';"
        CHAR_IS_ONLINE=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D ${MYSQL_DB} -ss -e "${MYSQL_QUERY}");
        if [ "${CHAR_IS_ONLINE}" == "0" ]; then
            MYSQL_QUERY="UPDATE custom_char_online_lock SET \`online\`=1 WHERE name='${USERNAME}'"
            mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D ${MYSQL_DB} -ss -e "${MYSQL_QUERY}"
            CLASS=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D ${MYSQL_DB} -ss -e "SELECT class FROM \`char\` WHERE name='${USERNAME}';")
            mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
            cp /opt/openkore/control/class/base.txt /opt/openkore/control/config.txt
            case ${CLASS} in
                4) # ACOLYTE
                    cat /opt/openkore/control/class/acolyte.txt >> /opt/openkore/control/config.txt
                    ;;
                8) # PRIEST
                    cat /opt/openkore/control/class/priest.txt >> /opt/openkore/control/config.txt
                    ;;
                15) # MONK
                    cat /opt/openkore/control/class/monk.txt >> /opt/openkore/control/config.txt
                    ;;
                2) # MAGE
                    cat /opt/openkore/control/class/mage.txt >> /opt/openkore/control/config.txt
                    ;;
                9) # WIZARD
                    cat /opt/openkore/control/class/wizard.txt >> /opt/openkore/control/config.txt
                    ;;
                16) # SAGE
                    cat /opt/openkore/control/class/sage.txt >> /opt/openkore/control/config.txt
                    ;;
                1) # SWORDMAN
                    cat /opt/openkore/control/class/swordman.txt >> /opt/openkore/control/config.txt
                    ;;
                7) # KNIGHT
                    cat /opt/openkore/control/class/knight.txt >> /opt/openkore/control/config.txt
                    ;;
                *)
                    echo "attackUseWeapon 1" >> /opt/openkore/control/config.txt
                    echo "attackNoGiveup 0" >> /opt/openkore/control/config.txt
                    echo "attackCanSnipe 0" >> /opt/openkore/control/config.txt
                    echo "attackCheckLOS 0" >> /opt/openkore/control/config.txt
                    ;;
            esac
            cat /opt/openkore/control/class/base-end.txt >> /opt/openkore/control/config.txt
            sed -i "s|^username$|username ${USERNAME}|g" /opt/openkore/control/config.txt
            # 1,2 -> Follow Almarc, 3,4 -> Follow Karloch, 5-10 -> Do not follow
            case $(shuf -i1-10 -n1) in
                1|2)
                    sed -i "s|^followTarget$|followTarget Almarc|g" /opt/openkore/control/config.txt
                    sed -i "s|^attackAuto 2$|attackAuto 1|g" /opt/openkore/control/config.txt
                    ;;
                3|4)
                    sed -i "s|^followTarget$|followTarget Karloch|g" /opt/openkore/control/config.txt
                    sed -i "s|^attackAuto 2$|attackAuto 1|g" /opt/openkore/control/config.txt
                    ;;
            esac
            export STORAGE_QUEUE_NAME=${USERNAME}
            echo "Bot username is ${USERNAME}. This will be also his Azure Storage Queue name."
            break
        fi
    done
fi
sed -i "s|^master$|master rAthena|g" /opt/openkore/control/config.txt
sed -i "s|^server$|server 0|g" /opt/openkore/control/config.txt
sed -i "s|^password$|password ${OK_PWD}|g" /opt/openkore/control/config.txt
sed -i "s|^char$|char ${OK_CHAR}|g" /opt/openkore/control/config.txt
sed -i "s|^autoResponse 0$|autoResponse 1|g" /opt/openkore/control/config.txt
sed -i "s|^autoResponseOnHeal 0$|autoResponseOnHeal 1|g" /opt/openkore/control/config.txt
sed -i "s|^route_randomWalk_inTown 0$|route_randomWalk_inTown 1|g" /opt/openkore/control/config.txt
sed -i "s|^partyAuto 1$|partyAuto 2|g" /opt/openkore/control/config.txt
sed -i "s|^follow 0$|follow 1|g" /opt/openkore/control/config.txt
sed -i "s|^followSitAuto 0$|followSitAuto 1|g" /opt/openkore/control/config.txt
sed -i "s|^attackAuto_inLockOnly 1$|attackAuto_inLockOnly 0|g" /opt/openkore/control/config.txt

sed -i "s|^lockMap$|lockMap gef_fild07|g" /opt/openkore/control/config.txt
sed -i "s|^lockMap_x$|lockMap_x 265|g" /opt/openkore/control/config.txt
sed -i "s|^lockMap_y$|lockMap_y 185|g" /opt/openkore/control/config.txt
sed -i "s|^lockMap_randX$|lockMap_randX 110|g" /opt/openkore/control/config.txt
sed -i "s|^lockMap_randY$|lockMap_randY 20|g" /opt/openkore/control/config.txt

sed -i "s|^ip 172.17.0.3$|ip ${OK_IP}|g" /opt/openkore/tables/servers.txt

sed -i "s|^loadPlugins_list macro,profiles,breakTime,raiseStat,raiseSkill,map,reconnect,eventMacro,item_weight_recorder,xconf$|loadPlugins_list macro,profiles,breakTime,raiseStat,raiseSkill,map,reconnect,eventMacro,item_weight_recorder,xconf,azureCognitive|g" /opt/openkore/control/sys.txt

exec "$@"
