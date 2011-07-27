#!/bin/sh

set -e

work_dir=${work_dir:?"work_dir needs to be set"}

export LANG=C
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive
export PATH=/bin:/usr/bin:/sbin:/usr/sbin

unset GEM_HOME
unset GEM_PATH
unset RUBYOPT


ipaddr="${ipaddr:-$(/sbin/ip route get 8.8.8.8 | head -1 | awk '{print $7}')}"
ipv4_gw="${ipv4_gw:-$(/sbin/ip route get 8.8.8.8 | head -1 | awk '{print $3}')}"

prefix="${prefix:-$(/sbin/ip route show | awk '$9 == ip { sub(/.*\//, "", $1); print $1; }' ip=$ipaddr)}"

dns_server=${dns_server:-${ipaddr}}
dhcp_server=${dhcp_server:-${ipaddr}}
metadata_server=${metadata_server:-${ipaddr}}
sta_server=${sta_server:-${ipaddr}}

local_store_path=${local_store_path?"local_store_path needs to be set"}
account_id=${account_id:-"a-shpoolxx"}

hypervisor=${hypervisor:?"hypervisor needs to be set"}
vmimage_s3_prefix=http://dlc.wakame.axsh.jp.s3.amazonaws.com/demo/vmimage

case ${hypervisor} in
kvm)
  vmimage_uuid=lucid0
  vmimage_dist_name=ubuntu
  vmimage_dist_ver=10.04
  vmimage_arch=i386
  vmimage_desc="${vmimage_dist_name} ${vmimage_dist_ver} ${vmimage_arch}"
  vmimage_file=${vmimage_uuid}.qcow2
  vmimage_s3=${vmimage_s3_prefix}/${vmimage_file}.gz
  ;;
lxc)
  vmimage_uuid=lucid0
  vmimage_dist_name=ubuntu
  vmimage_dist_ver=10.04
  vmimage_arch=amd64
  vmimage_desc="${vmimage_dist_name} ${vmimage_dist_ver} ${vmimage_arch}"
  vmimage_file=${vmimage_dist_name}-${vmimage_dist_ver}_without-metadata_${hypervisor}_${vmimage_arch}.raw
  vmimage_s3=${vmimage_s3_prefix}/${vmimage_file}.gz
  ;;
*)
  echo "unknown hypervisor type" >&2
  exit 1
  ;;
esac

case ${vmimage_arch} in
i386)
  images_arch=x86
  ;;
amd64)
  images_arch=x86_64
  ;;
esac


cd ${work_dir}/dcmgr/
shlog ./bin/vdc-manage host    add hva.demo1 -u   hp-demohost -f -a ${account_id} -c 100 -m 400000 -p ${hypervisor} -r $(uname -m)
echo $?
shlog ./bin/vdc-manage storage add sta.demo1 -u   sp-demostor -f -a ${account_id} -b xpool -s $((1024 * 1024)) -i ${sta_server} -n /export/home/wakame/vdc/sta/snap

# vlan
#shlog ./bin/vdc-manage vlan    add -t 1      -u vlan-demovlan    -a ${account_id}
#shlog ./bin/vdc-manage network add           -u   nw-demonet                      --ipv4_gw ${ipv4_gw} --prefix ${prefix} --domain vdc.local --dns ${dns_server} --dhcp ${dhcp_server} --metadata ${metadata_server} --metadata_port ${metadata_port} --vlan_id 1 --description demo
# non vlan
shlog ./bin/vdc-manage network add           -u   nw-demonet                      --ipv4_gw ${ipv4_gw} --prefix ${prefix} --domain vdc.local --dns ${dns_server} --dhcp ${dhcp_server} --metadata ${metadata_server} --metadata_port ${metadata_port} --description demo


shlog ./bin/vdc-manage tag map tag-shhost -o hp-demohost
shlog ./bin/vdc-manage tag map tag-shnet  -o nw-demonet
shlog ./bin/vdc-manage tag map tag-shstor -o sp-demostor

shlog ./bin/vdc-manage image add local ${local_store_path}/${vmimage_file} -a ${account_id} -u wmi-${vmimage_uuid} -r ${images_arch} -d "${vmimage_desc}" -s init
shlog ./bin/vdc-manage spec  add -u is-demospec -a ${account_id} -r $(uname -m) -p ${hypervisor} -c 1 -m 256 -w 1

shlog ./bin/vdc-manage group add -u  ng-demofgr -a ${account_id} -n default -d demo
shlog ./bin/vdc-manage group addrule ng-demofgr -r  tcp:22,22,ip4:0.0.0.0
shlog ./bin/vdc-manage group addrule ng-demofgr -r  tcp:80,80,ip4:0.0.0.0
shlog ./bin/vdc-manage group addrule ng-demofgr -r  udp:53,53,ip4:0.0.0.0
shlog ./bin/vdc-manage group addrule ng-demofgr -r icmp:-1,-1,ip4:0.0.0.0

cat <<'EOS' > /tmp/pub.pem
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDZhAOcHSe4aY8GwwLCJ4Et3qUBcyVPokFoCyCrtTZJVUU++B9554ahiVcrQCbfuDlaXV2ZCfIND+5N1UEk5umMoQG1aPBw9Nz9wspMpWiTKGOAm99yR9aZeNbUi8zAfyYnjrpuRUKCH1UPmh6EDaryFNDsxInmaZZ6701PgT++cZ3Vy/r1bmb93YvpV+hfaL/FmY3Cu8n+WJSoJQZ4eCMJ+4Pw/pkxjfuLUw3mFl40RVAlwlTuf1I4bB/m1mjlmirBEU6+CWLGYUNWDKaFBpJcGB6sXoQDS4FvlV92tUAEKIBWG5ma0EXBdJQBi1XxSCU2p7XMX8DhS7Gj/TSu7011 wakame-vdc.pem
EOS

cat <<'EOS' > /tmp/pri.pem
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA2YQDnB0nuGmPBsMCwieBLd6lAXMlT6JBaAsgq7U2SVVFPvgf
eeeGoYlXK0Am37g5Wl1dmQnyDQ/uTdVBJObpjKEBtWjwcPTc/cLKTKVokyhjgJvf
ckfWmXjW1IvMwH8mJ466bkVCgh9VD5oehA2q8hTQ7MSJ5mmWeu9NT4E/vnGd1cv6
9W5m/d2L6VfoX2i/xZmNwrvJ/liUqCUGeHgjCfuD8P6ZMY37i1MN5hZeNEVQJcJU
7n9SOGwf5tZo5ZoqwRFOvglixmFDVgymhQaSXBgerF6EA0uBb5VfdrVABCiAVhuZ
mtBFwXSUAYtV8UglNqe1zF/A4Uuxo/00ru9NdQIDAQABAoIBAC/WHakerFadOGxH
RPsIDxvUZDuOZD1ANNw53kSFBNxZ2XHAxcNcjLpH5xjG8gWvkUVzVRtMGaSPxVvu
s3X3JpPb8PFBk+dzoopYZX83vWjnsAJfxWNvsx1reuuhlzUagXyfohaQOtE9LMrS
nTVzgA3fUBdSHfXDcOm2aS08ApXSJOIxYxD/9AF6HNBsqTe+qvHiHVy570wkc2gf
K8m90NITTefIv67YzyVNubqCa2k9AiDojRKv0MeBpMqzHA3Lyw8El6Z0RTH694aV
AM1+y760DKw3SE320p9wz/onh6mei5jg4eoGDZHqGCY4rb3U9qLkMFHPmsOssWQq
/O5056ECgYEA+y0DHYCq3bcJFxhHqogVYbSnnJTJriC4XObjMK5srz1Y9GL6mfhd
3qJIbyjgRofqLEdOUXq2LR8BVcSnWxVwwzkThtYpRlbHPMv3MPr/PKgyNj3Gsvv5
0Y2EzcLiD1cm1f5Z//EWu+mOAfzW8JOLL8w+ZedsdvCUmFrZp/eClR0CgYEA3bGA
NwWOpERSylkA3cK5XGMFYwj6cE2+EMaFqzdEy4bLKhkdLMEA1NA7CbtO46e7AvCu
sthj5Qty605uGEI6+S5M/IPlX/Gh66f3qnXXNsVKXJbOcUC9lEbRwZa0V1u1Eqrx
mJ3g1as31EgmKRv4vIJ2wQTVgorBNDuUdZUzYjkCgYA3h78Nkbm05Nd8pKCLgiSA
AmmgA4EHHzLDT0RhKd7ba0u0VAGlcrSGGQi8kqPq0/egrG8TMnb+SMGJzb1WNMpG
TuMTR1u+skbAGTPgP02YgnL/bO71+SFFA+2dc/14eMMcQmxxWkK1brA3nkeCzovS
GGyfKOfg79VaTZObP+w9vQKBgQC4dpBLt/kHX75Plh0taHAZml8KF5diyJ1Ekhr4
6wT4IJF91uW6rmFFsnndUBiFPrRR7vg94eXE2HDnsBvVXY56dfcjCZBa89CaJ+ng
0Sqg7SpBvk3KWGcmMIMqBH7MTYduIATky0EgKNZMcTgnbpnaKOgtFRufAlteXdDa
wam+qQKBgHxGg9HJI3Ax8M5rgmsGReBM8e1GHojV5pmgWm0AsX04RS/7/gNkXHdv
MoU4FfcO/Tf7b+qwp40OjN0dr7xDwIWXih2LrAxGK2Lw43hlC5huYmqpEIYoiag+
PxIk/VB7tQxkp4Rtv005mWHPUYlh8x4lMqiVAhPJzEBfN9UEfkrk
-----END RSA PRIVATE KEY-----
EOS

shlog ./bin/vdc-manage keypair add -a ${account_id} -u ssh-demo -n demo --private-key=/tmp/pri.pem --public-key=/tmp/pub.pem

[ -f /tmp/pub.pem ] && rm -f /tmp/pub.pem
[ -f /tmp/pri.pem ] && rm -f /tmp/pri.pem

[ -d ${local_store_path} ] || {
  mkdir -p ${local_store_path}
}

[ -f ${local_store_path}/${vmimage_file} ] || {
  cd ${local_store_path}
  wget ${vmimage_s3}
  gunzip ${vmimage_file}.gz
}

exit 0