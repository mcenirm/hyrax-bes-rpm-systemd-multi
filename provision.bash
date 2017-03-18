#!/bin/bash

set -e
set -u

. /vagrant/settings.conf

missing=()
for rpm in "${HYRAX_RPMS[@]}" ; do
  rpmfile=${HYRAX_RELEASES_DIR}/${HYRAX_RPMS_PREFIX}/${rpm}
  name=$( rpm -q --queryformat='%{name}' -p "$rpmfile" )
  if ! rpm --quiet -q "$name" ; then
    missing+=( "$rpmfile" )
  fi
done
if [ ${#missing[*]} -gt 0 ] ; then
  yum -y localinstall "${missing[@]}"
fi

war_file=/vagrant/opendap.war
if [ ! -f "$war_file" ] ; then
  tar xf "$HYRAX_RELEASES_DIR/$HYRAX_WEBAPP_PREFIX/$HYRAX_WEBAPP_DIST" -C /vagrant
  mv -v "/vagrant/$HYRAX_WEBAPP_NAME/opendap.war" "$war_file"
fi

rpm --quiet -q epel-release || yum -y install epel-release

needs=(
    rsync
    strace
    lsof
    java-1.8.0-openjdk-devel
    tomcat
    xmlstarlet
)
missing=()
for name in "${needs[@]}" ; do
  if ! rpm --quiet -q "$name" ; then
    missing+=( "$name" )
  fi
done
if [ ${#missing[*]} -gt 0 ] ; then
  yum -y install "${missing[@]}"
fi

install -v -o root -g root -m 0644 -p -T /vagrant/bes@.service /etc/systemd/system/bes@.service
systemctl daemon-reload
systemctl stop tomcat.service

olfs_urls=()
env_bes_port=10022
for env_name in "${BES_ENV_NAMES[@]}" ; do
  systemctl stop "bes@${env_name}"

  let ++env_bes_port

  env_data=/data-${env_name}
  mkdir -p -v -- "$env_data"
  echo == "$env_name" > "$env_data/marker-$env_name".txt

  for bes_dir in /etc/bes /var/{cache,log}/bes ; do
    env_dir=${bes_dir/\/bes/\/bes-${env_name}}
    mkdir -p -v -- "$env_dir"
    chown --reference="$bes_dir" -c "$env_dir"
    chmod --reference="$bes_dir" -c "$env_dir"
    # TODO SELinux context
  done
  rsync -a --delete /etc/bes/modules/ /etc/bes-"$env_name"/modules/

  env_settings=(
      "BES.LogName=/var/log/bes-${env_name}/bes.log"
      "BES.UncompressCache.dir=/var/cache/bes-${env_name}"
      "BES.Catalog.catalog.RootDirectory=${env_data}"
      "BES.ServerPort=${env_bes_port}"
      "BES.ServerIP=127.0.0.1"
  )
  sed_cmd=( sed )
  for env_setting in "${env_settings[@]}" ; do
    key=${env_setting%%=*}
    key_re=${key//./\\.}
    value=${env_setting#*=}
    sed_cmd+=(
      -e
      's=^#* *\('"$key_re"'\) *\=.*$=\1\='"$value"'='
    )
  done
  "${sed_cmd[@]}" < /etc/bes/bes.conf > /etc/bes-${env_name}/bes.conf

  systemctl start "bes@${env_name}"

  env_webapp_dir=/var/lib/tomcat/webapps/opendap-${env_name}
  rm -rf -- "$env_webapp_dir"
  sudo -u tomcat mkdir -v -p -- "$env_webapp_dir"
  ( cd "$env_webapp_dir" && sudo -u tomcat jar xf "$war_file" )
  xmlstarlet ed \
      --inplace \
      -u 'OLFSConfig/BESManager/BES/port' -v "$env_bes_port" \
      "$env_webapp_dir"/WEB-INF/conf/olfs.xml
  olfs_urls+=( "http://localhost:8080/opendap-${env_name}/" )
done

systemctl start tomcat.service
sleep 3
sudo ss -tnlp | sed -e 's/ \(Address\)/-\1/g' | column -t | sort -k 4

printf '==  %s  ==\n' "${olfs_urls[@]}" | column -t
