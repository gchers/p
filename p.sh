#!/usr/bin/env bash
# p, a password manager
#
# Giovanni Cherubin <g.chers :at: gmail.com>

configfile=~/.config/p/config

## Utils
# Encrypt text $2 using identity $1. Output file is $3.
function p_encrypt()
{
    echo -n "$2" | $GPG -er $1 --yes --output $3
}

# Decrypt file $1.
function p_decrypt()
{
    $GPG -d "$1"
}

# Prompt message.
function msg()
{
    echo "[*] $1"
}

# Prompt error message and exit with status 1.
function error()
{
    (>&2 echo "[!] $1")
    exit 1
}

# Returns the days since file $1 was last modified
function file_age()
{
    [ -z "$1" ] && error "input error to file_age()"
    # Last edit date
    m_date=$(stat -f "%m" -t "+%s" "$1")
    [[ $? != 0 ]] && error "file $1 not found"
    # Compute days
    let days=($(date "+%s")-$m_date)/86400
    echo $days
}

# Generate a new password of 32 characters
function gen_password()
{
    n=32
    # Generate a password of $n characters.
    passw=$(head /dev/random | LC_CTYPE=C tr -dc A-Za-z0-9 | cut -c -$n)
    echo -n $passw
}

# Prompts $1 and waits for y|Y (proceed) or any
# other key (abort)
function proceed_abort() {
    echo -n "$1 [y/n] "
    read ans
    case "$ans" in
        y|Y)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
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


## Functions
function show_help()
{
    echo "usage: $0 <option> [option's argument]

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

# Checks if password with label $1 exists
function label_exists()
{
    valid_label $1 || error "invalid label"

    if [[ -f "$STORE/$1" ]]
    then
        return 0
    else
        return 1
    fi
}

# Copy password with label starting with $1 to the clipboard
function get_pw()
{
    valid_label $1 || error "invalid label"
    # Determine first matching label
    labels=$(find "$STORE/$1"* -type f -maxdepth 1 2> /dev/null | head -n1)
    [[ -z $labels ]] && error "password with label $1 not found"
    label="$(basename $labels)"
    #[[ -z $label ]] && error "password with label $1 not found"
    # Decrypt
    encfile="$STORE/$label"
    passw="$(p_decrypt $encfile)"
    [[ $? != 0 ]] && error 'decryption failed'
    # Copy to clipboard
    echo -n $passw | $CMD_COPY
    days=$(file_age $encfile)
    msg "the password for \"$label\" was created $days days ago"
    msg "password copied to clipboard"
}

# Create/edit password with label $1
function edit_pw()
{
    # Read/generate new password
    echo -n "password (empty to generate one): "
    read passw
    [ -z "$passw" ] && passw=$(gen_password)
    [ -z "$passw" ] && error "failed to generate a password"
    # Store password
    outfile="$STORE/$1"
    p_encrypt "$GPG_ID" "$passw" "$outfile"
    [[ $? != 0 ]] && error "encryption failed"
    msg "password added"
    echo -n "$passw" | $CMD_COPY
    msg "password copied to clipboard"
}

# Remove password with label $1
function rm_pw()
{
    label_exists $1 || error "label $1 not found"
    proceed_abort "do you want to remove label $OPTARG?" || error "aborted"
    rm "$STORE/$1"
    msg "password removed"
}

# Print labels (optionally matching "$1")
function print_labels()
{
    echo -e "label\tage"
    echo "--------------"
    for fname in "$STORE/$1"*
    do
        label=$(basename $fname)
        days=$(file_age $fname)
        echo -e "$label\t$days"
    done
}

function init() {
    # Make $STORE dir if it doesn't exist
    [ -d $STORE ] || mkdir -p $STORE
    [[ $? != 0 ]] && error "failed to create directory $STORE"
    # If CMD_COPY is unset, try to figure out which command we should
    # use for pasting to clipboard.
    if [ -z "$CMD_COPY" ]
    then
        if xclip -version > /dev/null 2>&1
        then
            COPY_CMD="xclip -i -selection clipboard"
        elif pbcopy -help > /dev/null 2>&1
        then
            COPY_CMD="pbcopy"
        else
            error "I couldn't find neither xclip (Linux&*BSD) nor pbcopy (OS X). Set CMD_COPY in the configuration file."
        fi
    fi
}

## Main
source $configfile
init

while getopts "a:m:r:hl" opt
do
    case "$opt" in
    a)
        label_exists $OPTARG && error "label exists"
        edit_pw $OPTARG
        exit 0
        ;;
    m)
        label_exists $OPTARG || error "label not found"
        edit_pw $OPTARG
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
