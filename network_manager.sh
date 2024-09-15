#!/bin/sh

# $1 $2 -> user_account user_password

# utils

# virables
# -> return_data : return text information
# -> TRUE : true
# -> FALSE : false

# functions
# -> loop [func name] [times] [timeout]
# -> retry [func name] [times]

if [ -z $1 ] || [ -z $2 ] || [ -z $3 ]; then
    echo "please ensure 3 params are entered"
    echo "usage: ./network_manager.sh [Action]"
    echo "Action: auto-connect [user_account] [user_password]"
    echo "        network-restart"
    echo "        network-logout [timeout]"
    exit 1
fi

TRUE=1
FALSE=0
return_data=''

mainUrl="http://10.1.99.100/"
logoutUrl="http://10.1.99.100:801/eportal/portal/logout"
unbindUrl="http://10.1.99.100:801/eportal/portal/mac/unbind"
loginUrl=""

function loop() {
    # $1 -> func name
    # $2 -> times (-1 is anyway loop)
    # $3 -> delay time

    local count=0
    local delay=1
    if [ ! -z $3 ]; then
        delay=$3
    fi

    while [ $count -lt $2 ] || [ $2 -eq -1 ]; do
        $1
        count=$(expr $count + 1)
        sleep $delay
    done
}

function retry() {
    # $1 -> func name
    # $2 -> times
    # $3 -> delay time (float)

    local count=0

    # how many times to retry
    local retry_times=1
    local delay=0
    
    if [ ! -z $2 ]; then
        retry_times=$2
    fi

    if [ ! -z $3 ]; then
        delay=$3
    fi

    while [ $count -lt $retry_times ]; do
        $1
        if [ $? -eq $TRUE ]; then
            return $TRUE
        fi
        sleep $delay
        count=$(expr $count + 1)
    done

    return $FALSE
}

# End

function is_endpoint_online() {
    # $1 -> timeout
    # $2 -> test endpoint

    local timeout=1
    local test_url=''

    if [ ! -z $1 ]; then
        timeout=$1
    fi

    if [ ! -z $2 ]; then
        test_url=$2
    else
        return $FALSE
    fi
    
    online_status=$(curl -I -s $test_url -m $timeout | grep 'HTTP/1.1 200 OK' | tr -d '\r')

    if [ "${online_status}" == "HTTP/1.1 200 OK" ]; then
        return $TRUE
    else
        return $FALSE
    fi
}

function network_login() {
    # TODO
    loginUrl_return=$(curl -s $loginUrl -m 4 | grep -o '登录成功')
    if [ "$loginUrl_return" == "登录成功" ]; then
        echo 'FU'
    fi
    curl -I -s $loginUrl -m $timeout | grep 'HTTP/1.1 200 OK' | tr -d '\r'
    curl $loginUrl
}

function is_school_network_api_online() {
    # $1 -> timeout
    
    local timeout=1
    if [ ! -z $1 ]; then
        timeout=$1
    fi

    local uid=$(curl -s -m $timeout $mainUrl | grep -P -o 'uid='.*?';')
    if [ "$uid" == '' ]; then
        return $FALSE
    else
        uid=${uid//uid=\'/ }
        uid=${uid//\';/ }

        return_data=$uid
        return $TRUE
    fi
}

function school_network_get_uid() {
    
    local timeout=1
    if [ ! -z $1 ]; then
        timeout=$1
    fi

    local uid=$(curl -s -m $timeout $mainUrl | grep -P -o 'uid='.*?';')
    if [ "$uid" == '' ]; then
        return $FALSE
    else
        uid=${uid//uid=\'/ }
        uid=${uid//\';/ }

        return_data=$uid
        return $TRUE
    fi
}

function network_interface() {
    case $1 in
        $TRUE)
            ifconfig phy0-sta0 up
            ifconfig wan up
        ;;
        $FALSE)
            ifconfig phy0-sta0 down
            ifconfig wan down
        ;;
    esac
}

function school_network_logout() {
    # $1 -> timeout

    local timeout=1
    if [ ! -z $1 ]; then
        timeout=$1
    fi

    logoutUrl_return=$(curl -s $logoutUrl -m $timeout | grep -o 'Radius注销成功')
    if [ "$logoutUrl_return" != "Radius注销成功" ]; then
        return $FALSE
    fi
    
    sleep $timeout

    # TODO: unbindUrl
    unbindUrl_return=$(curl -s $unbindUrl -m $timeout | grep -o '解绑终端MAC成功')
    if [ "$unbindUrl_return" != "解绑终端MAC成功" ]; then
        return $FALSE
    fi

    return $TRUE
}



#loop loop_func -1 1

# TODO:
# + trigger: time 06:00
#   + reboot
#
# + trigger: time 06:40
#   + restart Network
#   + loop until 7:10
#       + if (is school network api appear) is $TRUE
#           + if (is uid logined) is $TRUE <and> (uid is setted uid) is $TRUE
#               + break
#           + else
#               + while
#                   + 
#
#

function network_restart() {
    network_interface $FALSE
    network_interface $TRUE
}

function is_school_network_online() {
    is_endpoint_online 2 $mainUrl
    return $?
}

function network_connect() {
    retry is_school_network_online 10 5
    case $? in
        $TRUE)
            #TODO
        ;;
        $FALSE)
            network_restart
        ;;
    esac
}

# main

function action_auto_connect() {
    network_restart
    loop network_connect -1 1
}

function set_login_url() {
    if [ ! -z $1 ] && [ ! -z $2 ]; then
        loginUrl="http://10.1.99.100:801/eportal/portal/login?user_account=$1&user_password=$2"
    else
        echo '[user_account] [user_password] is not setted'
    fi
    
}

case $3 in
    "auto-connect")
        set_login_url $2 $3
        action_auto_connect
    ;;
    "network-restart")
        network_restart
    ;;
    "network-logout")
        school_network_logout $2
    ;;
esac