# bash functions for test script
#

function abort() {
  echo $* >&2
  exit 1
}

# Run multiple sequence of comand lines
#run 'ls /'
#run 'echo && echo && ls /'
#
#run <<_END
#ls / && echo 1
#ls / || echo 2
#ls / && echo 3
#_END
function run {
  local ret=0
  if [[ -t 0 ]]; then
    eval "$*"
    ret=$?
  else
    read -u 0 -d '' i
    eval "$i"
    ret="$?"
  fi

  return $ret
}

# retry 3 /bin/ls
# echo "ls / " | retry 3
function retry {
  local retry_max="$1"
  shift

  local count="$retry_max"
  local lastret=0
  while [[ $count -gt 0 ]]; do
    run "$*"
    lastret="$?"
    [[ $lastret -eq 0 ]] && break
    count=$(($count - 1))
    echo "retry hold [$(($retry_max - $count))/${retry_max}]...."
    /bin/sleep 1
  done

  [[ ( $count -eq 0 ) && ( $lastret -ne 0 ) ]] && {
    echo "Retry failed [$retry_max]: ${*}" >&2
    return 1
  }
  return 0
}

NL=`echo -ne '\015'`

function screen_it {
  local title=$1
  local cmd=$2

  # read cmd lines from stdin
  [[ -z "$cmd"  ]] && {
    cmd="$cmd `read`"
  }
  retry 3 screen -L -r vdc -x -X screen -t $title
  screen -L -r vdc -x -p $title -X stuff "${cmd}$NL"
}

function setup_base {
  [ -d $tmp_path ] || mkdir $tmp_path

  run_builder "00_install-pkg.sh"
  (
      work_dir=$prefix_path
      run_builder "99_setup-developer.sh"
  )
}

function cleanup {
  which screen >/dev/null && {
    screen -ls vdc | egrep -q vdc && {
      screen -S vdc -X quit
    }
  } || :

  ps -ef | egrep 'bin/[d]nsmasq' -q && {
    killall dnsmasq
  }

  ps -ef | egrep '[t]gtd' -q && {
    initctl stop tgt
  }

  case ${hypervisor} in
  kvm)
    ps -ef | egrep 'bin/[k]vm' -q && {
      killall kvm
    }
   ;;
  lxc)
    for container_name in $(lxc-ls); do
      echo ... ${container_name}
      lxc-destroy -n ${container_name} || lxc-kill -n ${container_name}
    done
    unset container_name

    mount | egrep ${vmdir_path} | awk '{print $3}' | while read line ;do
      echo ... ${line}
      umount ${line}
    done
    unset line
   ;;
  esac

  for component in collector nsa hva sta; do
    pid=$(ps awwx | egrep "[b]in/${component}" | awk '{print $1}')
    [ -z "${pid}" ] || kill -9 ${pid}
  done

  for port in ${ports}; do
    pid=$(ps awwx | egrep "[r]ackup -p ${port}" | awk '{print $1}')
    [ -z "${pid}" ] || kill -9 ${pid}
  done

  # netfilter
  which ebtables >/dev/null && ebtables --init-table || :
  for table in nat filter; do
    for xcmd in F Z X; do
      which iptables >/dev/null && iptables -t ${table} -${xcmd} || :
    done
  done

  [ -d ${prefix_path}/frontend/dcmgr_gui/log/ ] && {
    [ -f ${prefix_path}/frontend/dcmgr_gui/log/proxy_access.log ] || : && \
      echo ": > ${prefix_path}/frontend/dcmgr_gui/log/proxy_access.log" | /bin/sh
  } || :
  
  for i in ${tmp_path}/screenlog.* ${tmp_path}/*.log; do rm -f ${i}; done

  [ -d ${tmp_path}/xpool/${account_id} ] && {
    for i in ${tmp_path}/xpool/${account_id}/*; do rm -f ${i}; done
  }
}

# kick the builder script. 
#
# use following form to set configurable variables for xxx.sh:
# ( val1=1; run_builder "xxx.sh"; )
function run_builder {
  local builder_script=$1

  i="$DISTRIB_ID/$DISTRIB_RELEASE/$builder_script" 
  [ -f "$builder_path/$i" ] || abort "ERROR: Unknown builder script: $builder_script"
  # run script in subshell to inherit variables.
  (
    [[ -f $(dirname $builder_path/$i)/common.sh ]] && {
      . $(dirname $builder_path/$i)/common.sh
    }
    . $builder_path/$i
  ) || abort "Failed to run $builder_script"
  return 0
}

function shlog {
  echo $* "(cwd: `pwd`)"
  eval $*
}

# for without_screen
pids=
trap 'kill -9 ${pids};' 2

function run2bg() {
  #eval "$* &"
  shlog "$* &"

  pid=$!
  echo "[pid:${pid}]# '$*'"
  pids="${pids} ${pid}"
}
