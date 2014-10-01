#!/bin/bash

sudo echo "Installing login-cidadao..."

OK="[$(tput setaf 2)$(tput bold) OK $(tput sgr0)$(tput sgr0)]"
FAIL="[$(tput setaf 1)$(tput bold)FAIL$(tput sgr0)$(tput sgr0)]"
WARN="[$(tput setaf 3)$(tput bold)WARN$(tput sgr0)$(tput sgr0)]"
YELLOW_WARNING="$(tput setaf 3)$(tput bold)WARNING$(tput sgr0)$(tput sgr0)"
PARAMETERS_FILE="app/config/parameters.yml"

function die {
  echo -e $1
  exit 1
}

###############################
# Setting up Permissions
###############################
echo -ne "Setting up Permissions...\\t\\t"
rm -rf app/cache/*
rm -rf app/logs/*

HTTPDUSER=`ps aux | grep -E '[a]pache|[h]ttpd|[_]www|[w]ww-data|[n]ginx' | grep -v root | head -1 | cut -d\  -f1`
if hash setfacl 2>/dev/null; then
  sudo setfacl -R -m u:"$HTTPDUSER":rwX -m u:`whoami`:rwX app/cache app/logs web/uploads
  sudo setfacl -dR -m u:"$HTTPDUSER":rwX -m u:`whoami`:rwX app/cache app/logs web/uploads
else
  sudo chmod +a "$HTTPDUSER allow delete,write,append,file_inherit,directory_inherit" app/cache app/logs web/uploads
  sudo chmod +a "`whoami` allow delete,write,append,file_inherit,directory_inherit" app/cache app/logs web/uploads
  if [ "$?" -ne 0 ]; then
    echo $FAIL
    die "\\nThere was a problem setting the directories permissions.\\nFor more info check: http://symfony.com/doc/current/book/installation.html"
  fi
fi
echo $OK

###############################
# Symfony Check
###############################
SF_CHECK="php app/check.php 2>&1"
function sf_env_check {
  PHP_INFO=$($SF_CHECK)
  if [[ $PHP_INFO == *ERROR* ]]
  then
    SF_OK=0
  fi
}

echo -ne "Checking Symfony2 requirements...\\t"
SF_OK=1
sf_env_check
if [ "$SF_OK" -ne 1 ]; then
  echo $FAIL
  die "Your environment didn't pass the test. Check the problems found by running:\\n$ $SF_CHECK"
else
  echo $OK
fi

###############################
# Composer Check
###############################
if hash composer 2>/dev/null; then
  COMPOSER=composer
else
  echo -e "Composer not found... Installing it as composer.phar"
  php -r "readfile('https://getcomposer.org/installer');" | php
  COMPOSER=composer.phar
fi

###############################
# composer install
###############################
echo -ne "Checking parameters.yml...\\t\\t"
if [ ! -f $PARAMETERS_FILE ]; then
  echo $WARN
  echo "$YELLOW_WARNING: parameters.yml initialized with default values!"
  echo " This is likely to be a major problem when installing the database!"
  echo -e " This is likely to be a major problem running the application!\\n"
else
  echo $OK
fi
echo -ne "Installing dependencies...\\t\\t"
COMPOSER_RESULT=`$COMPOSER install -n 2>&1`
if [ "$?" -ne 0 ]; then
  echo $FAIL
  die "\\nThere was a problem running composer install procedure. Here is the output returned:\\n$COMPOSER_RESULT"
else
  echo $OK
fi

###############################
# Database Setup
###############################
echo -ne "Installing the database...\\t\\t"
# Let's check if the schema is ok first...
php app/console doctrine:schema:validate -q

if [ "$?" -ne 0 ]; then
  # Ok... We'll have to do something...
  php app/console doctrine:database:create -q
  SCHEMA_CREATE=$(php app/console doctrine:schema:create 2>&1)

  if [ "$?" -ne 0 ]; then
    echo $FAIL
    die "\\nThere was a problem installing the database. Here is the error returned:\\n\\n$SCHEMA_CREATE"
  fi
fi
echo $OK

echo -e "\\nInstall is done."