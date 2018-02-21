# p, A password manager

*p* is a very simple command line password manager, based on GnuPG.
Its effective code is <200 lines of bash, making it easy to
read and maintain.

<p align="center">
<img src="https://github.com/gchers/p/blob/master/utils/demo.gif" width="500" height="380" />
</p>

Here's a quick overview of the main commands.
```
# Show help.
$ p
# Add a new password (this already copies the password to the clipboard).
# It optionally generates a password randomly.
$ p -a twitter
# Copy a password to the clipboard.
$ p twitter
# List labels and their passwords' age
$ p -l
# Modify a password.
$ p -m twitter
# Remove a password.
$ p -r twitter
```

# How it works

Every password is associated to a label, which should represent the service
the password is used on (e.g.: 'twitter', 'freenode', ...).
Each password is stored in a separate GnuPG-encrypted file under the directory `$STORE`.
The GnuPG key's _master password_ is used to decrypt password files.

When `p some_label` is called, the password corresponding to `some_label`
is copied to the clipboard.

*p* is easily scriptable. For example, a user may want to periodically
check that there are no passwords older than 3 months. This can be achieved by
using Unix cron, and performing a test on the output of:
```
$ p -l
```
which returns a list of the labels, together with their age in days.
NOTE however that this function is beta; in fact, it works by looking at
the storage files' timestamp, which can be misleading if you sync passwords
with other computers.

*p* does not guarantee that an attacker controlling your computer will not be
able to get all your passwords: a simple keylogger used while you type the
master passphrase would do the job for him. However, a keylogger would be
probably able to steal your passwords anyways while you type
them...

*p* code was designed to be as simple as possible, so to enable peer reviews,
a so that potentially anyone who understands a bit *bash* can check it does
what it says before using it.

_NOTE: I've been using *p* on my laptops for many years now, and never
encountered any (critical) problem.
However, until more people test it, I will consider this as a beta version.
Use it at your own risk._

# Installation

*p* requires: bash, standard \*nix utilities (e.g., awk), and GnuPG [1].
Also, it needs a copy-to-clipboard utility (`xclip` for Linux/BSD,
`pbcopy` for MacOS).

It was tested on recent: MacOS, OpenBSD, FreeBSD, some Linux distros.

To install, you need to first create a new GnuPG identity:
```
gpg --gen-key
```
protected by a password. This password will be asked every time you need to
read data from the storage file.
When asked for `Real name` and `Email address` you can put something like
`password-manager`.
Take note of the key id, which is some hex string (e.g.,
5CE3CEA98C3746A8CDFBD8C6E68DAE58DFA511FE).

Then:
```
$ mkdir -p ~/.local/src                   # Or where you like to leave the script.
$ cd ~/.local/src
$ git clone https://github.com/gchers/p
$ cd p
$ mkdir ~/.p                              # Where password files will be.
$ mkdir -p ~/.config/p/                   # Where to put the config file.
$ cp p.conf ~/.config/p/config
$ chmod +x p.sh
$ # As root:
# ln -s $PWD/p.sh /usr/local/bin/p        # Or anywhere on your $PATH.
```

Finally, edit `~/.config/p/config` and set `GPG_ID` to the
key id of the GnuPG identity you created.

Try it works by calling:
```
$ p
```

If the program complains you don't have a copy-to-clipboard utility, please
install one (`xclip` on Linux/BSD, `pbcopy` should already be in MacOS).

# Further configuration

*p* shouldn't need any more tweaks. You may however want
to check the following settings in `~/.config/p/config`.

## CMD\_COPY

This specifies the command used to copy to clipboard.
It should be automatically detected.
A list of such programs is in [2].

## GPG\_ID

The id of the GPG key used to encrypt/decrypt the passwords.

## STORE

The directory under which password files are stored.
It defaults to `~/.p`.

# Issues

## Using OSX, tmux and pbcopy
If you're an OSX user using tmux, you will probably not be able to use *pbcopy*,
and thus the copy-to-clipboard functionality. Well, there's a solution: [3].

# Attack scenarios

*p* cannot prevent the following kind of attacks. Both of them require
an adversary to *already have access* to the machine.

If you find a bug, please open a ticket.

## Clipboard repeated pasting

A user-level malicous program may keep pasting from the clipboard, until the
user will eventually retrieve a password, which will be leaked.

## Shoulder surfing + private key

By shoulder surfing, an attacker may only discover the password of the
GnuPG key. In order to find all the user's password, he would also need
to steal the actual private key, by getting access to the machine.


# References

[1] <https://www.gnupg.org/>

[2] <http://stackoverflow.com/a/750466/1230980>

[3] <http://superuser.com/a/413233>
