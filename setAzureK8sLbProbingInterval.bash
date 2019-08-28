#!/bin/bash
# Azure Load Balancing probing was flooding the rAthena logs with connection
# attempts. This small script increases the probing interval to 60 secs.
# It uses Azure CLI.
# $1 is the AKS generated resource group
# $2 is the load balancer resource name

PROBES=$(az network lb probe list --lb-name $2 -g $1 -o tsv --query '[].id')
while read -r line; do
	az network lb probe update --ids $line --interval 60
done <<< "$PROBES"
 
