# DotFiles Manager - DFM

`dfm` allows to manage your tools dotfiles.

## Features

- all settings are in a declarative yaml file
- setting symlinks targeting your tools dotfiles
- exporting environment variables for tools that can be managed with
- executing commands (like script that adds tool autocompletion)

## Usage

To use `dfm`, create your yaml configuration file and execute `dfm.sh` script.
To create your `dfm` config, you can get the sample `dfm_config.sample.yml` that contains some examples, rename it and change it.
As `dfm` is only executed once per session, you can add it in you `.bashrc`-like file. If you add a new tool in `dfm` configuration, you simply call it with `DFM_FORCE=1` to update your dotfiles.

Simple call examples:
```console
./dfm.sh
DFM_FORCE=1 ./dfm.sh
```

You can override `dfm` default environment variables values to setup `dfm`:
- `DFM_DEBUG`: to activate tracing
- `DFM_CONFIG_FILE_PATH`: to setup `dfm` config file path
- `DFM_FORCE`: by defaut, `dfm` is executed once per session, you can force execution with it
- `DFM_SEMAPHORE`: file path used to know if `dfm` has already been executed
- `DFM_TEMPDIR`: temporary directory used during `dfm` execution
- `DFM_VERBOSE`: to display verbose messages during `dfm` execution

More call examples:
```console
DFM_VERBOSE=1 ./dfm.sh
DFM_CONFIG_FILE_PATH=<path_to>/dfm_config.yml ./dfm.sh
DFM_FORCE=1 DFM_CONFIG_FILE_PATH=<path_to>/dfm_config.yml ./dfm.sh
DFM_FORCE=1 DFM_VERBOSE=1 DFM_CONFIG_FILE_PATH=<path_to>/dfm_config.yml ./dfm.sh
```

## Motivation

Some friends are using [`stow`](https://www.gnu.org/software/stow/manual/stow.html) but you can't manage tool's env vars or autocompletion, so I didn't choose this tool.
I manage all dotfiles by adding this kind of code in my `.bashrc`:
```console
# atuin
if command -v atuin &>/dev/null; then
  export ATUIN_NOBIND="true"
  if [[ -f ${MY_DOTCONF_PATH}/atuin.toml ]]; then
    if [[ ! -L ${HOME}/.config/atuin/config.toml || ! -e ${HOME}/.config/atuin/config.toml ]]; then
      mkdir -p ${HOME}/.config/atuin
      ln -sf ${MY_DOTCONF_PATH}/atuin.toml ${HOME}/.config/atuin/config.toml
    fi
  fi
  eval "$(atuin init bash)"
fi

# awscli
if command -v aws &>/dev/null; then
  if [[ -f ${MY_DOTCONF_PATH}/aws ]]; then
    if [[ ! -L ${HOME}/.aws/config || ! -e ${HOME}/.aws/config ]]; then
      mkdir -p ${HOME}/.aws
      ln -sf ${MY_DOTCONF_PATH}/aws ${HOME}/.aws/config
    fi
  fi
fi

# kubectl
if command -v kubectl &>/dev/null; then
  source <(kubectl completion bash)
fi

# vi
if [[ -f ${MY_DOTCONF_PATH}/.vimrc ]]; then
  if [[ ! -L ${HOME}/.vimrc || ! -e ${HOME}/.vimrc ]]; then
    ln -sf ${MY_DOTCONF_PATH}/.vimrc ${HOME}/.vimrc
  fi
fi
```

So to avoid to near always write same code for each tools to manage dotfile, to generate autocompletion and to export some env vars, I created `dfm` to do all this stuff based on a config file.
