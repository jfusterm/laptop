#!/bin/bash

set -euo pipefail

OS=$(uname)
TMP=$(mktemp -d)
REPO_DIR=$(pwd)

# Colors
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NO_COLOR='\033[0m'

# Default versions
GO_VERSION=${GO_VERSION:-1.13.1}
BAT_VERSION=${BAT_VERSION:-0.12.1}
HUB_VERSION=${HUB_VERSION:-2.12.8}
TERRAFORM_VERSION=${TERRAFORM_VERSION:-0.12.10}
PACKER_VERSION=${PACKER_VERSION:-1.4.4}
VAGRANT_VERSION=${VAGRANT_VERSION:-2.2.5}
VAULT_VERSION=${KIND_VERSION:-1.2.3}
HELM_VERSION=${HELM_VERSION:-2.14.1}
EKSCTL_VERSION=${KIND_VERSION:-0.6.0}
KIND_VERSION=${KIND_VERSION:-0.5.1}


usage() {
	cat <<-EOF
	Usage: $0 options

	OPTIONS:
    -a      Bootstrap everything!
    -c      Configure Visual Studio Code
    -d      Configure the dotfiles
    -s      Configure the shell

	EOF
}

setup_shell() {
  # set zsh as default
  echo -e "\n${CYAN}Switching shell to ${GREEN}zsh${NO_COLOR}"
  sudo chsh -s $(which zsh) $(whoami)

  # oh-my-zsh
  echo -e "\n${CYAN}Installing ${GREEN}oh-my-zsh${NO_COLOR}"
  curl -Lo ${TMP}/install.sh https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh
  bash ${TMP}/install.sh --unattended
  mkdir -p ${ZSH_CUSTOM:=~/.oh-my-zsh}/completions
  chmod -R 755 ${ZSH_CUSTOM:=~/.oh-my-zsh}/completions

  # zsh-completions
  echo -e "\n${CYAN}Installing ${GREEN}zsh-completions${NO_COLOR}"
  git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:=~/.oh-my-zsh/custom}/plugins/zsh-completions

  # zsh-autosuggestions
  echo -e "\n${CYAN}Installing ${GREEN}zsh-autosuggestions${NO_COLOR}"
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

  # zsh-syntax-highlighting
  echo -e "\n${CYAN}Installing ${GREEN}zsh-syntax-highlighting${NO_COLOR}"
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

  # powerlevel10k
  echo -e "\n${CYAN}Installing ${GREEN}powerlevel10k${NO_COLOR}"
  # git clone https://github.com/bhilburn/powerlevel9k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel9k
  git clone https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k

  # kubectx | kubens completions
  echo -e "\n${CYAN}Installing ${GREEN}kubectx | kubens${NO_COLOR} ${CYAN}completions${NO_COLOR}"
  curl -Lo ${ZSH_CUSTOM:=~/.oh-my-zsh}/completions/_kubens.zsh https://raw.githubusercontent.com/ahmetb/kubectx/master/completion/kubens.zsh
  curl -Lo ${ZSH_CUSTOM:=~/.oh-my-zsh}/completions/_kubectx.zsh https://raw.githubusercontent.com/ahmetb/kubectx/master/completion/kubectx.zsh
}

setup_dotfiles() {
  echo -e "\n${CYAN}Setting ${GREEN}dotfiles ${CYAN}( zshrc | vimrc | gitconfig | p10k.zsh )${NO_COLOR}"
  mv ~/.zshrc ~/.zshrc.orig
  ln -f -s ${REPO_DIR}/dotfiles/zshrc ~/.zshrc
  ln -f -s ${REPO_DIR}/dotfiles/vimrc ~/.vimrc
  ln -f -s ${REPO_DIR}/dotfiles/gitconfig ~/.gitconfig
  ln -f -s ${REPO_DIR}/p10k/p10k.zsh ~/.p10k.zsh
}

setup_vscode() {
  echo -e "\n${CYAN}Setting ${GREEN}Visual Studio Code configuration${NO_COLOR}"
  if [ ${OS} == "Darwin" ]; then
    mkdir -p ~/Library/Application\ Support/Code/User
    ln -s ${REPO_DIR}/vscode/settings.json ~/Library/Application\ Support/Code/User/settings.json
  elif [ ${OS} == "Linux" ]; then
    mkdir -p ~/.config/Code/User
    ln -s ${REPO_DIR}/vscode/settings.json ~/.config/Code/User/settings.json
  fi

  # Install vscode extensions
  echo -e "\n${CYAN}Installing ${GREEN}Visual Studio Code extensions${NO_COLOR}"
  for EXTENSION in $(cat vscode/extensions.txt | xargs); do
    code --install-extension $EXTENSION
  done
}

bootstrap_ubuntu() {
  echo -e "\n${GREEN}Bootstrapping Ubuntu${NO_COLOR}"
  sudo apt update
  echo -e "\n${CYAN}Upgrading system${NO_COLOR}"
  sudo apt -y upgrade
  echo -e "\n${CYAN}Installing basic tools${NO_COLOR}"
  sudo apt install -y apt-transport-https \
                      zsh \
                      git \
                      tmux \
                      jq \
                      curl \
                      vim \
                      gnome-tweaks \
                      htop \
                      python3 \
                      python3-pip \
                      tree \
                      xz-utils \
                      gnupg \
                      nmap \
                      build-essential \
                      file \
                      unzip \
                      bzip2 \
                      zip \
                      fzf \
                      netcat \
                      zsync \
                      ecryptfs-utils \
                      ca-certificates \
                      software-properties-common \
                      nautilus-dropbox \
                      virtualbox

  # brave
  echo -e "\n${CYAN}Installing ${GREEN}Brave${NO_COLOR}"
  curl -s https://brave-browser-apt-release.s3.brave.com/brave-core.asc | sudo apt-key --keyring /etc/apt/trusted.gpg.d/brave-browser-release.gpg add -
  echo "deb [arch=amd64] https://brave-browser-apt-release.s3.brave.com/ trusty main" | sudo tee /etc/apt/sources.list.d/brave-browser-release-trusty.list
  sudo apt update
  sudo apt install -y brave-browser

  # docker
  echo -e "\n${CYAN}Installing ${GREEN}Docker${NO_COLOR}"
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu disco stable" | sudo tee /etc/apt/sources.list.d/docker.list
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io
  sudo usermod -aG docker $(whoami)

  # snap
  echo -e "\n${CYAN}Installing basic apps with ${GREEN}Snap${NO_COLOR}"
  sudo snap install code --classic
  sudo snap install spotify
  sudo snap install slack --classic
  sudo snap install kubectl --classic

  # pip
  echo -e "\n${CYAN}Installing ${GREEN}Python${NO_COLOR} ${CYAN}packages${NO_COLOR}"
  sudo pip3 install --user -r pip/requirements.txt

  # go
  echo -e "\n${CYAN}Installing ${GREEN}Go${NO_COLOR}"
  curl -Lo ${TMP}/go.tar.gz https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz
  sudo tar -C /usr/local -xzf ${TMP}/go.tar.gz
  export PATH=$PATH:/usr/local/go/bin

  # bat
  echo -e "\n${CYAN}Installing ${GREEN}bat${NO_COLOR}"
  curl -Lo ${TMP}/bat.deb https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/bat_${BAT_VERSION}_amd64.deb
  sudo dpkg -i ${TMP}/bat.deb

  # hub
  echo -e "\n${CYAN}Installing ${GREEN}hub${NO_COLOR}"
  curl -Lo ${TMP}/hub.tgz https://github.com/github/hub/releases/download/v${HUB_VERSION}/hub-linux-amd64-${HUB_VERSION}.tgz
  tar xvzf ${TMP}/hub.tgz -C ${TMP}
  sudo ${TMP}/hub-linux-amd64-${HUB_VERSION}/install

  # kubectx | kubens
  echo -e "\n${CYAN}Installing ${GREEN}kubectx | kubens${NO_COLOR}"
  sudo curl -Lo /usr/local/bin/kubectx https://raw.githubusercontent.com/ahmetb/kubectx/master/kubectx
  sudo curl -Lo /usr/local/bin/kubens https://raw.githubusercontent.com/ahmetb/kubectx/master/kubens
  sudo chmod +x /usr/local/bin/kube*

  # eksctl
  echo -e "\n${CYAN}Installing ${GREEN}eksctl${NO_COLOR}"
  curl -Lo ${TMP}/eksctl.tar.gz https://github.com/weaveworks/eksctl/releases/download/${EKSCTL_VERSION}/eksctl_$(uname -s)_amd64.tar.gz
  sudo tar xvzf ${TMP}/eksctl.tar.gz -C /usr/local/bin/

  # kind
  echo -e "\n${CYAN}Installing ${GREEN}kind${NO_COLOR}"
  mkdir ${TMP}/go
  GOPATH=${TMP}/go GO111MODULE="on" go get sigs.k8s.io/kind@v${KIND_VERSION}
  sudo mv ${TMP}/go/bin/kind /usr/local/bin

  # vagrant
  echo -e "\n${CYAN}Installing ${GREEN}vagrant${NO_COLOR}"
  curl -Lo ${TMP}/vagrant.zip https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}_linux_amd64.zip
  sudo unzip -o ${TMP}/vagrant.zip -d /usr/local/bin

  # terraform
  echo -e "\n${CYAN}Installing ${GREEN}terraform${NO_COLOR}"
  curl -Lo ${TMP}/terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
  sudo unzip -o ${TMP}/terraform.zip -d /usr/local/bin

  # packer
  echo -e "\n${CYAN}Installing ${GREEN}packer${NO_COLOR}"
  curl -Lo ${TMP}/packer.zip https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip
  sudo unzip -o ${TMP}/packer.zip -d /usr/local/bin

  # vault
  echo -e "\n${CYAN}Installing ${GREEN}vault${NO_COLOR}"
  curl -Lo ${TMP}/vault.zip https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
  sudo unzip -o ${TMP}/vault.zip -d /usr/local/bin

  # helm
  echo -e "\n${CYAN}Installing ${GREEN}helm${NO_COLOR}"
  curl -Lo ${TMP}/helm.tar.gz https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz
  sudo tar xvzf ${TMP}/helm.tar.gz -C /usr/local/bin --strip-components=1 linux-amd64/helm

  # nerd-fonts
  echo -e "\n${CYAN}Installing ${GREEN}nerd-fonts${NO_COLOR}"
  git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git ${TMP}/nerd-fonts
  bash ${TMP}/nerd-fonts/install.sh Hack
  fc-cache -fv

  setup_shell
  setup_dotfiles
  setup_vscode

  # Restore Gnome configuration (dconf dump / > gnome/settings.dconf)
  echo -e "\n${CYAN}Restoring Gnome settings${NO_COLOR}"
  dconf load / < gnome/settings.dconf

  # Cleaning
  echo -e "\n${CYAN}Cleaning...${NO_COLOR}"
  sudo rm -fr ${TMP}
  sudo apt -y autoremove
  sudo apt clean
}

bootstrap_macos() {
  echo -e "\n${CYAN}Installing ${GREEN}homebrew${NO_COLOR}"
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

  # Install tools
  echo -e "\n${CYAN}Installing ${GREEN}tools${NO_COLOR}"
  brew tap Homebrew/bundle
  brew bundle --file=brew/brewfile

  if ! grep -i $(which zsh) /etc/shells; then
    sudo sh -c "echo $(which zsh) >> /etc/shells"
  fi

  setup_shell
  setup_dotfiles
  setup_vscode
}

bootstrap() {
  if [ ${OS} == "Darwin" ]; then
    bootstrap_macos
  elif [ ${OS} == "Linux" ]; then
    bootstrap_ubuntu
  fi

  echo -e "\n${GREEN}Bootstrap finished!${NO_COLOR}"
}

main() {
  if [ $# == "0" ]; then
    usage
    exit 0
  fi

  while getopts "acds" OPTION; do
    case $OPTION in
      a)
        bootstrap
        exit 0
        ;;
      c)
        setup_vscode
        exit 0
        ;;
      d)
        setup_dotfiles
        exit 0
        ;;
      s)
        setup_shell
        exit 0
        ;;
      *)
        usage
        exit 0
        ;;
    esac
  done
}

main "$@"
