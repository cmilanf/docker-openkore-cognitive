#!/bin/sh

helpmsg () {
    echo "Azure Storage Queues create script for GAB 2019 demo"
    echo "(c) 2019 Carlos Milán Figueredo & Alberto Marcos González"
    echo ""
    echo "Usage: $0 [create | delete] storageAccountName storageAccountKey queueSuffix queueNumber"
    echo ""
    echo "Example: $0 create gab19openkore storagekey botijo 50"
    echo ""
}
DEFAULT_STORAGE_ACCOUNT_KEY="SET YOUR AZURE STORAGE ACCOUNT KEY HERE"

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ] || [ -z "$5" ]
then
    echo "Error: insufficient number of parameters"
    helpmsg
    exit 1
fi

case "$1" in
    create)
        for i in `seq 0 $(($5-1))`;
        do
            echo "Creating queue $4$i in storage account $2..."
            if [ "$3" = "default" ]; then
                az storage queue create --name "$4$i" --account-name "$2" --account-key "$DEFAULT_STORAGE_ACCOUNT_KEY" --auth-mode key
            else
                az storage queue create --name "$4$i" --account-name "$2" --account-key "$3" --auth-mode key
            fi
        done
        ;;
    delete)
        for i in `seq 0 $(($5-1))`;
        do
            echo "Deleting queue $4$i in storage account $2..."
            if [ "$3" = "default" ]; then
                az storage queue delete --name "$4$i" --account-name "$2" --account-key "$DEFAULT_STORAGE_ACCOUNT_KEY" --auth-mode key
            else
                az storage queue delete --name "$4$i" --account-name "$2" --account-key "$3" --auth-mode key
            fi
        done
        ;;
    *)
        helpsmg        
        ;;
esac
