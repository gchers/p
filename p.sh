#!/bin/bash
# p, a password manager
#
# Giovanni Cherubin <g.chers :at: gmail.com>

configfile=./p.cfg

## Utils
# Encrypt file $2 using identity $1. Output file is $3.
function p_encrypt()
{
    gpg -e -r $1 --yes --output $3 $2
}

# Decrypt file $1.
function p_decrypt()
{
    gpg -d $1
}

# Prompt message.
function msg()
{
    echo "[*] $1"
}

# Prompt error message and exit with status 1.
function error()
{
    echo "[!] $1"
    exit 1
}

# Return elapsed days from $1 (date in format %s) to today.
function elapsed_days()
{
    let days=($(date "+%s")-$1)/86400
    echo $days
}

# Generates a new password.
function gen_password()
{
    passw=$(head -c64 /dev/random | md5)
    echo -n $passw
}

## Functions
function show_help()
{
    echo "usage: $0 [option [argument]]/[argument]

    \`p' is an \"as simple as I could\" command line password manager.
    Passwords are stored in a GPG encrypted file, store.gpg,
    together with a label for each of them, and their creation date.
    Once passwords are added, a password with label \"x\" can be
    obtained by typing:
        \$ p x
    which copies the password to the clipboard to prevent shoulder-surfing.
        
    OPTIONS:
       -h   Show this message
       -a   Add a new password [with label \$argument]
       -m   Modify the password of an existent label
       -r   Remove the password of an existent label
       -l   Print label and elapsed days after creation for all passwords
       -g   Get a password with label \$argument. This can be also achieved by
            simply running \"$0 argument\", where argument is the label."
}

function get_pw()
{
    # Decrypt $STORE_ENC and get the first row with matching label
    array=($(p_decrypt $STORE_ENC | grep -i $1 | head -n1; \
            exit ${PIPESTATUS[0]}))
    # Exit on decryption fail or if label not found
    [[ $? != 0 ]] && error 'decryption failed'
    passw=${array[1]}
    date=${array[2]}
    [[ $passw ]] || error "label \"$1\" not found"
    # Copy to clipboard
    echo -n $passw | $CMD_COPY
    msg "this password was created $(elapsed_days $date) days ago"
    msg "password copied to clipboard"
}

function add_pw()
{
    # Read label (if needed) and read/generate new password
    label=$1
    if [ -z $label ]
    then
        echo -n "label: "
        read label
    fi
    echo -n "password (empty to generate one): "
    read passw
    [[ $passw ]] || passw=$(gen_password); echo -n $passw | $CMD_COPY && \
        msg "password copied to clipboard"
    # If $STORE_ENC exists decrypt it, else create it
    if [ -f $STORE_ENC ]
    then
        p_decrypt $STORE_ENC > $STORE_PLAIN
        # Exit on decryption fail
        [[ $? != 0 ]] && rm -f $STORE_PLAIN && error "decryption failed"
    else
        touch $STORE_PLAIN
    fi
    # Store in format: label | password | date
    echo "$label $passw $(date '+%s')" >> $STORE_PLAIN
    p_encrypt $GPG_ID $STORE_PLAIN $STORE_ENC
    # Exit on encryption fail
    [[ $? != 0 ]] && rm -f $STORE_PLAIN && error "encryption failed"
    rm $STORE_PLAIN
    msg "password added"
}

function mod_pw()
{
    p_decrypt $STORE_ENC | grep -v $1 > $STORE_PLAIN
    status=(${PIPESTATUS[@]})
    # Exit on decryption fail or if label not found
    [[ ${status[0]} != 0 ]] && rm -f $STORE_PLAIN && \
        error "decryption failed"
    echo -n "new password (empty to generate one): "
    read passw
    [[ $passw ]] || passw=$(gen_password); echo -n $passw | $CMD_COPY && \
        msg "password copied to clipboard"
    # Store in format: label | password | date
    echo "$1 $passw $(date '+%s')" >> $STORE_PLAIN
    p_encrypt $GPG_ID $STORE_PLAIN $STORE_ENC
    # Exit on encryption fail
    [[ $? != 0 ]] && rm -f $STORE_PLAIN && error "encryption failed"
    rm $STORE_PLAIN
}

function rm_pw()
{
    # Decrypt and remove entry with label $1
    p_decrypt $STORE_ENC | grep -v $1 > $STORE_PLAIN
    # Exit on decryption fail
    [[ ${PIPESTATUS[0]} != 0 ]] && rm -f $STORE_PLAIN && \
        error "decryption failed"
    p_encrypt $GPG_ID $STORE_PLAIN $STORE_ENC
    # Exit on encryption fail
    [[ $? != 0 ]] && rm -f $STORE_PLAIN && error "encryption failed"
    rm $STORE_PLAIN
    msg "password removed"
}

function print_labels()
{
    p_decrypt $STORE_ENC > $STORE_PLAIN
    # Exit on decryption fail
    [[ $? != 0 ]] && rm -f $STORE_PLAIN && error "decryption failed"
    # Print in the form: label | age, where age is calculated for every
    # entry of 3rd column with elapsed_days()
    echo -e "label\tage"
    echo "--------------"
    cat $STORE_PLAIN | \
    while read l
    do
        IFS=" " read -a array <<< "$l"
        echo -e "${array[0]}\t$(elapsed_days ${array[2]})"
    done
    rm -f $STORE_PLAIN
}

## Main
source $configfile

while getopts "a:m:r:hl" opt
do
    case "$opt" in
    a)
        add_pw $OPTARG
        exit 0
        ;;
    m)
        mod_pw $OPTARG
        exit 0
        ;;
    r)
        rm_pw $OPTARG
        exit 0
        ;;
    g)
        get_pw $OPTARG
        exit 0
        ;;
    l)
        print_labels
        exit 0
        ;;
    h)
        show_help
        exit 0
        ;;
    *)
        exit 1
        ;;
    esac
done

# If no option arguments
[[ $1 ]] && get_pw $1 || show_help
exit 0
