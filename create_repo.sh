#!/bin/bash
#
#

PATH=/bin:/usr/bin:/sbin:/usr/sbin
LUN_MOUNT_PT=/var/www/html/apt
BASE_DIR=${PWD}
VERSION=${CI_BUILD_ID:-1}
BRANCH=${CI_BUILD_REF_NAME:-master}
COMMITID=${CI_BUILD_REF}
STAGE=${CI_BUILD_STAGE:-test}
GIT_REPO=$(dirname $CI_PROJECT_DIR)
PROJECT=$(basename $(dirname $CI_PROJECT_DIR))
BUILD_NAME=${CI_BUILD_NAME:-build}

clean_term() {
    do_log LOG_NOTICE "Received TERM signal"
    clean_exit
}

clean_exit() {
    trap - EXIT
    pid_file_remove_if_owner
    do_log LOG_NOTICE "Shutting down, bye!"
    exit
}

do_log() {
    local level="$1"
    local msg="$2"
    local pri='info'

    case $level in 
        LOG_EMERG) pri='emerg' ;;
        LOG_ALERT) pri='alert' ;;
        LOG_CRIT) pri='crit' ;;
        LOG_ERR) pri='err' ;;
        LOG_WARNING) pri='warning' ;;
        LOG_NOTICE) pri='notice' ;;
        LOG_INFO) pri='info' ;;
        LOG_DEBUG) pri='debug' ;;
    esac

    if [[ -n "$msg" ]]; then
        logger -t "${prog_name}[$$]" -p $pri "$msg"
    fi
}

is_debian(){
local dir=debian
local err=0
if [[ ! -d $dir ]]; then
    err=1
fi
return $err
}
complain_error() {
    local err=0
    local msg

    err=$1; shift; msg="$*"
    (( $err != 0 )) && do_log LOG_ERR "$msg"

    return $err
}

get_r_distribution() {
local r_key=''
if repo_has_key();then
    r_key=get_repo_key()
else 
    repo_gen_key()
fi
 
echo <<BANG
Label: ${PROJECT}
Suite: stable
Codename: ${PROJECT}
Version: ${VERSION}
Architectures: amd64 source
Components: main
Description: ${GIT_REPO} ${PROJECT}
SignWith: ${r_key}
Tracking: minimal includelogs
Pull: ${PROJECT}
BANG
}

get_r_options(){
echo "outdir ${LUN_MOUNT_PT}/${PROJECT}"
}

run_reprepro(){
}

create_list(){
}

make_changelog(){
cat BANG"
${BASE_DIR}/{{ pkgname }} ({{ version }}) {{ distribution }}; urgency=medium

  * Automatically built.
    SHA: {{ builder.build_record.sha }}

 -- {{ full_name }} <{{ email }}>  {{ timestamp }}"
 >
}

make control(){
PKGNAME=get_pkgname
Source: {{ pkgname }}
Section: misc
Priority: optional
Maintainer: aaSemble Package Builder <pkgbuild@aasemble.com>
Build-Depends: debhelper (>= 9.0.0){% for dependency in builder.build_dependencies %},
  {{ dependency }}{% endfor %}
Standards-Version: 3.9.4
Vcs-Git: {{ builder.package_source.github_repository.url }}
Vcs-Browser: {{ builder.package_source.github_repository.url }}

Package: {{ builder.binary_pkg_name }}
Architecture: any
Depends: ${shlibs:Depends}, ${misc:Depends}{% for dependency in builder.runtime_dependencies %},
  {{ dependency }}{% endfor %}
Description: Automatically built {{ pkgname }} package
 This package was built by aaSemble Package Builder using
 code from the {{ builder.package_source.branch }} branch at {{ builder.package_source.github_repository.url }}.
BANG
}
 
exit_not_debian(){
local err=0
if ! is_debian;then
	err=1
	complain_error $err "Failed to identify this as debian repo"
	exit $err
fi
}
trap clean_exit INT EXIT
exit_not_debian
do_log LOG_NOTICE "Launched child $prog_name with PID $!"
exit 0

 
