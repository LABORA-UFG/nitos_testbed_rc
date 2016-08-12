#!/bin/bash

# Startup wrapper for the nitos_testbed_rc
# detects system-wide RVM installations & Ruby from distro packages

# system-wide RVM must be installed using
# '\curl -L https://get.rvm.io | sudo bash -s stable'

die() { echo "ERROR: $@" 1>&2 ; exit 1; }

RUBY_VER="2.3.1p112"
RUBY_BIN_SUFFIX=""

if [ `id -u` != "0" ]; then
  die "This script is intended to be run as 'root'"
fi

if [ -e /etc/profile.d/rvm.sh ]; then
    # use RVM if installed
    echo "System-wide RVM installation detected"
    source /etc/profile.d/rvm.sh
    if [[ $? != 0 ]] ; then
        die "Failed to initialize RVM environment"
    fi
    # rvm use $RUBY_VER@omf > /dev/null
    # if [[ $? != 0 ]] ; then
    #     die "$RUBY_VER with gemset 'omf' is not installed in your RVM"
    # fi
    ruby -v | grep 2.3.1  > /dev/null
    if [[ $? != 0 ]] ; then
        die "Could not run Ruby 2.3.1"
    fi
    gem list | grep nitos_testbed_rc  > /dev/null
    if [[ $? != 0 ]] ; then
        die "The nitos_testbed_rc gem is not installed in the 'omf' gemset"
    fi
else
    # check for distro ruby when no RVM was found
    echo "No system-wide RVM installation detected"
    ruby -v | grep 2.3.1  > /dev/null
    if [[ $? != 0 ]] ; then
        ruby2.3.1 -v | grep 2.3.1  > /dev/null
        if [[ $? != 0 ]] ; then
            die "Could not run system Ruby 2.3.1. No useable Ruby installation found."
        fi
        RUBY_BIN_SUFFIX="2.3.1"
    fi
    echo "Ruby 2.3.1 found"
    gem$RUBY_BIN_SUFFIX list | grep nitos_testbed_rc  > /dev/null
    if [[ $? != 0 ]] ; then
        die "The nitos_testbed_rc gem is not installed"
    fi
fi

EXEC=""

case "$1" in

1)  echo "Starting user_proxy"
    EXEC=`which user_proxy`
    if [[ $? != 0 ]] ; then
        die "could not find user_proxy executable"
    fi
    ;;
2)  echo "Starting frisbee_proxy"
    EXEC=`which frisbee_proxy`
    if [[ $? != 0 ]] ; then
        die "could not find frisbee_proxy executable"
    fi
    ;;
3)  echo "Starting cm_proxy"
    EXEC=`which cm_proxy`
    if [[ $? != 0 ]] ; then
        die "could not find cm_proxy executable"
    fi
    ;;
*) echo "Starting run_proxies"
    EXEC=`which run_proxies`
    if [[ $? != 0 ]] ; then
        die "could not find run_proxies executable"
    fi
    ;;
esac

echo "Running $EXEC"
exec /usr/bin/env ruby$RUBY_BIN_SUFFIX $EXEC