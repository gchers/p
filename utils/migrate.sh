#!/usr/bin/env bash
# Migrates passwords stored in the original format (store.gpg)
# into the new format (passwords are stored in separate
# files into ~/.p/.
# NOTE: Please, check the options carefully, and keep
# a backup of store.gpg before proceeding.

OLDSTORE=~/.p/store.gpg
NEWSTORE=~/.p/
GPG=/usr/local/bin/gpg2
GPG_ID=0x5D8A8D1B1B4948A9

# Encrypt text $2 using identity $1. Output file is $3.
function encrypt()
{
    echo -n "$2" | $GPG -er $1 --yes --output $3
}

# Decrypt file $1.
function decrypt()
{
    $GPG -d $1
}

# Checks if $1 is a valid label (alphanumeric)
function valid_label()
{
    if ! [[ $1 =~ [^a-zA-Z0-9]+ ]]
    then
        return 0
    else
        return 1
    fi
}

# Reads a new label
function read_new_label()
{
    echo "label should be alphanumeric"
    echo -n "new label: "
    read label
    valid_label $label || error "invalid label"
    echo -n $label
}

# Prompt error message $1 and exit with status 1.
function error()
{
    (>&2 echo "[!] $1")
    exit 1
}

mkdir $NEWSTORE || error "$NEWSTORE already exists"

decrypt $OLDSTORE | while read line
do
    array=($line)
    label=${array[0]}
    passw=${array[1]}
    date=${array[2]}
    echo "processing label $label"

    # Check that the label is valid
    valid_label "$label" || label=$(read_new_label)
    
    # Store password
    outfile="$NEWSTORE/$label"
    if [[ -f $outfile ]]
    then
        error "duplicate label $label"
    fi

    encrypt $GPG_ID $passw $outfile
    # Set correct timestamp
    date=$(date -r $date "+%Y-%m-%dT%H:%M:%S")
    touch -d $date $outfile
done

echo "check that everything works, and then remove (but keep a backup of) store.gpg"
