#! /usr/bin/env bash
if [ $# -ne 1 ] 
then
    echo "Chyba: Argument musi byt jeden"
    exit
else
    if ! [ -f "$1" ] 
    then
        echo "Chyba: Argument musi byt textovy soubor"
        exit
    fi
fi    

file="$1"

while IFS= read -r line; do
    echo "a line: $line"
done < "$file"