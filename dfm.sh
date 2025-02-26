#!/usr/bin/env bash

#
# DotFiles Manager - DFM
# v1.0.0
#
# You can override env vars prefixed with 'DFM_'.
# Only 'yq' extra-tool is mandadory to parse yaml configuration file (see https://github.com/mikefarah/yq).
#

set -o pipefail
set -o nounset

# Default env vars values
DFM_DEBUG=${DFM_DEBUG:=0}
[[ ${DFM_DEBUG} -eq 1 ]] && set -o xtrace
DFM_CONFIG_FILE_PATH=${DFM_CONFIG_FILE_PATH:-"~/dfm_config.yml"}
DFM_FORCE=${DFM_FORCE:=0}
DFM_SEMAPHORE=${DFM_SEMAPHORE:-"/tmp/dfm.log"}
DFM_TEMPDIR=${DFM_TEMPDIR:-$(mktemp -d /tmp/dfm.XXXXXXXXX)}
DFM_VERBOSE=${DFM_VERBOSE:=0}

# allow using DFM_SEMAPHORE in yaml conf file to add logs
export DFM_SEMAPHORE

trap _dfm_clean INT TERM EXIT

function _dfm_clean() {
  rm -rf ${DFM_TEMPDIR}
}

function _dfm_echoVerbose() {
  if [[ ${DFM_VERBOSE} -eq 1 ]]; then
    echo -e "$(tput bold)Verbose:$(tput sgr0) ${@}"
  fi
}

function _dfm_echoBold() {
  echo -e "$(tput bold)${@}$(tput sgr0)"
}

function _dfm_echoYellowBold() {
  echo -e "$(tput bold)$(tput setaf 3)${@}$(tput sgr0)"
}

function _dfm_echoSuccess() {
  echo -e "$(tput bold)$(tput setaf 2)Success:$(tput sgr0) $(tput setaf 2)${@}$(tput sgr0)"
}

function _dfm_echoError () {
  echo -e "$(tput bold)$(tput setaf 1)Error:$(tput sgr0) $(tput setaf 1)${@}$(tput sgr0)"
}

function _dfm_checkTools() {
  if ! command -v yq &>/dev/null; then
    _dfm_echoError "The 'yq' tool is required but is not installed. Please go to https://github.com/mikefarah/yq and install it."
    exit 1
  fi
}

function _dfm_checkSemaphore() {
  if [[ ${DFM_FORCE} -eq 1 ]]; then
    _dfm_echoVerbose "Force execution, remove semaphore file '${DFM_SEMAPHORE}'."
    rm -f ${DFM_SEMAPHORE}
  elif [[ -f ${DFM_SEMAPHORE} ]]; then
    _dfm_echoVerbose "Semaphore file '${DFM_SEMAPHORE}' exists, no need to continue."
    _dfm_echoVerbose "To force execution, call with 'DFM_FORCE=1'."
  fi
}

function _dfm_createSemaphore() {
  echo "DFM - Last execution at $(date)" >> ${DFM_SEMAPHORE}
  echo
  _dfm_echoVerbose "Semaphore file '${DFM_SEMAPHORE}' created."
  _dfm_echoVerbose "To force execution, call with 'DFM_FORCE=1'."
}

function _dfm_check() {
  # mandatory env var
  if [[ -z ${DFM_CONFIG_FILE_PATH} ]]; then
    _dfm_echoError "The env var 'DFM_CONFIG_FILE_PATH' is required but not defined! Please read the documentation."
    exit 1
  fi

  # check config file
  if [[ ! -f ${DFM_CONFIG_FILE_PATH} ]]; then
    _dfm_echoError "The file '${DFM_CONFIG_FILE_PATH}' doesn't exist! Please read the documentation."
    exit 1
  fi

  # check config file parsing
  if ! yq ${DFM_CONFIG_FILE_PATH} &>/dev/null; then
    _dfm_echoError "The config file '${DFM_CONFIG_FILE_PATH}' isn't parsable:"
    yq ${DFM_CONFIG_FILE_PATH}
    exit 2
  fi
}

function _dfm_main() {
  local _nb_dotfiles=$(yq '.dotfiles | length' ${DFM_CONFIG_FILE_PATH})
  local _i=0
  while [[ ${_i} -lt ${_nb_dotfiles} ]]; do
    local _name=$(yq ".dotfiles[${_i}].name" ${DFM_CONFIG_FILE_PATH})
    local _conf_target=$(yq ".dotfiles[${_i}].conf_target | envsubst" ${DFM_CONFIG_FILE_PATH})
    local _conf_symlink=$(yq ".dotfiles[${_i}].conf_symlink | envsubst" ${DFM_CONFIG_FILE_PATH})
    local _binary=$(yq ".dotfiles[${_i}].binary" ${DFM_CONFIG_FILE_PATH})

    _dfm_echoYellowBold "\nManaging '${_name}'..."

    # check activation
    _dfm_echoVerbose "Configuration symlink: ${_conf_symlink}"
    if [[ $(yq ".dotfiles[${_i}].enabled" ${DFM_CONFIG_FILE_PATH}) == "false" ]]; then
      rm -f ${_conf_symlink}
      _dfm_echoBold "Not managing '${_name}': this dotfile is disabled. The symlink is removed if existed."
      ((_i++))
      continue
    fi

    # check binary
    if ! command -v ${_binary} &>/dev/null; then
      _dfm_echoBold "Not managing '${_name}': binary ${_binary} doesn't exist."
      ((_i++))
      continue
    fi

    # create configuration symlink
    _dfm_echoVerbose "Configuration target: ${_conf_target}"
    if [[ ! -f ${_conf_target} ]]; then
      _dfm_echoBold "The configuration target file '${_conf_target}' doens't exist."
    else
      if [[ ! -L ${_conf_symlink} ||  ! -e ${_conf_symlink} ]]; then
        mkdir -p $(dirname ${_conf_symlink})
        ln -sf ${_conf_target} ${_conf_symlink}
      fi
      ls -lh ${_conf_symlink}
    fi

    # export env vars if needed
    if [[ $(yq ".dotfiles[${_i}].export_vars | length" ${DFM_CONFIG_FILE_PATH}) -gt 0 ]]; then
      local _nb_elts=$(yq ".dotfiles[${_i}].export_vars | length" ${DFM_CONFIG_FILE_PATH})
      local _e=0
      while [[ ${_e} -lt ${_nb_elts} ]]; do
        local _var_name=$(yq ".dotfiles[${_i}].export_vars[${_e}].name" ${DFM_CONFIG_FILE_PATH})
        local _var_value=$(yq ".dotfiles[${_i}].export_vars[${_e}].value" ${DFM_CONFIG_FILE_PATH})
        export ${_var_name}="${_var_value}"
        _dfm_echoVerbose "Exporting '${_var_name}=${_var_value}'"
        ((_e++))
      done
    fi

    # execute init command if needed
    if [[ $(yq ".dotfiles[${_i}].init_command | length" ${DFM_CONFIG_FILE_PATH}) -gt 0 ]]; then
      local _init_command=$(yq ".dotfiles[${_i}].init_command | envsubst" ${DFM_CONFIG_FILE_PATH})
      _dfm_echoVerbose "init_command: ${_init_command}"
      local _dotconf_tempfile="${DFM_TEMPDIR}/${_binary}"
      _dfm_echoVerbose "_dotconf_tempfile: ${_dotconf_tempfile}"
      echo "${_init_command}" > ${_dotconf_tempfile}
      _dfm_echoVerbose "execute this command:\n\t$(cat ${_dotconf_tempfile})"
      eval "$(cat ${_dotconf_tempfile})" &>/dev/null
    fi

    _dfm_echoSuccess "Managing '${_name}' is done."
    ((_i++))
  done
}

###### main #####

_dfm_checkTools
_dfm_checkSemaphore
if [[ ! -f ${DFM_SEMAPHORE} ]]; then
  _dfm_check
  _dfm_main
  _dfm_createSemaphore
fi
