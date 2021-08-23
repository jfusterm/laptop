#!/bin/bash

set -euo pipefail

OS=$(uname)
TMP=$(mktemp -d --suffix=_bootstrap_laptop 2> /dev/null || mktemp -d -t _bootstrap_laptop)
REPO_DIR=$(pwd)

# Colors
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NO_COLOR='\033[0m'

# Default versions
GO_VERSION=${GO_VERSION:-1.17}
BAT_VERSION=${BAT_VERSION:-0.18.3}
HUB_VERSION=${HUB_VERSION:-2.14.2}
TERRAFORM_VERSION=${TERRAFORM_VERSION:-1.0.5}
PACKER_VERSION=${PACKER_VERSION:-1.7.4}
VAGRANT_VERSION=${VAGRANT_VERSION:-2.2.18}
VAULT_VERSION=${VAULT_VERSION:-1.8.1}
HELM_VERSION=${HELM_VERSION:-3.6.3}
EKSCTL_VERSION=${EKSCTL_VERSION:-0.62.0}
AWS_IAM_AUTH_VERSION=${AWS_IAM_AUTH_VERSION:-0.5.3}
K3D_VERSION=${K3D_VERSION:-4.4.7}
K9S_VERSION=${K9S_VERSION:-0.24.15}
SKAFFOLD_VERSION=${SKAFFOLD_VERSION:-1.30.0}

trap clean_tmp EXIT

usage() {
	cat <<-EOF
	Usage: $0 options

	OPTIONS:
    -a      Bootstrap everything!
    -c      Configure Visual Studio Code
    -d      Configure the dotfiles
    -s      Configure the shell
    -u      Update system, tools and repositories

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
  echo -e "\n${CYAN}Setting ${GREEN}dotfiles ${CYAN}( zshrc | vimrc | gitconfig | p10k.zsh | kitty )${NO_COLOR}"
  mv ~/.zshrc ~/.zshrc.orig
  ln -f -s ${REPO_DIR}/dotfiles/zshrc ~/.zshrc
  ln -f -s ${REPO_DIR}/dotfiles/vimrc ~/.vimrc
  ln -f -s ${REPO_DIR}/dotfiles/gitconfig ~/.gitconfig
  ln -f -s ${REPO_DIR}/p10k/p10k.zsh ~/.p10k.zsh
  ln -f -s ${REPO_DIR}/dotfiles/kitty.conf ~/.config/kitty/kitty.conf
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

setup_tools() {
  # go
  echo -e "\n${CYAN}Installing ${GREEN}Go${NO_COLOR}"
  curl -Lo ${TMP}/go.tar.gz https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz
  sudo tar -C /usr/local -xzf ${TMP}/go.tar.gz
  export PATH=$PATH:/usr/local/go/bin

  # bat
  echo -e "\n${CYAN}Installing ${GREEN}bat${NO_COLOR}"
  curl -Lo ${TMP}/bat.tar.gz https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/bat-v${BAT_VERSION}-x86_64-unknown-linux-gnu.tar.gz
  sudo tar xvzf ${TMP}/bat.tar.gz -C /usr/local/bin --strip-components=1 bat-v${BAT_VERSION}-x86_64-unknown-linux-gnu/bat

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

  # aws-iam-authenticator
  echo -e "\n${CYAN}Installing ${GREEN}aws-iam-authenticator${NO_COLOR}"
  sudo curl -Lo ${TMP}/aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v${AWS_IAM_AUTH_VERSION}/aws-iam-authenticator_${AWS_IAM_AUTH_VERSION}_linux_amd64
  sudo chmod +x ${TMP}/aws-iam-authenticator
  sudo mv ${TMP}/aws-iam-authenticator /usr/local/bin

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

  # k9s
  echo -e "\n${CYAN}Installing ${GREEN}k9s${NO_COLOR}"
  curl -Lo ${TMP}/k9s.tar.gz https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_x86_64.tar.gz
  sudo tar xvzf ${TMP}/k9s.tar.gz -C /usr/local/bin k9s

  # k3d
  echo -e "\n${CYAN}Installing ${GREEN}k3d${NO_COLOR}"
  curl -Lo k3d https://github.com/rancher/k3d/releases/download/v${K3D_VERSION}/k3d-linux-amd64
  sudo chmod +x k3d
  sudo mv k3d /usr/local/bin

  # skaffold
  echo -e "\n${CYAN}Installing ${GREEN}skaffold${NO_COLOR}"
  curl -Lo skaffold https://github.com/GoogleContainerTools/skaffold/releases/download/v${SKAFFOLD_VERSION}/skaffold-linux-amd64
  sudo chmod +x skaffold
  sudo mv skaffold /usr/local/bin
}

setup_fonts() {
  # nerd-fonts
  echo -e "\n${CYAN}Installing ${GREEN}nerd-fonts${NO_COLOR}"
  git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git ${TMP}/nerd-fonts
  bash ${TMP}/nerd-fonts/install.sh Hack
  fc-cache -fv
}

setup_pip() {
  # pip
  echo -e "\n${CYAN}Installing ${GREEN}Python${NO_COLOR} ${CYAN}packages${NO_COLOR}"
  pip3 install --user -r pip/requirements.txt
}

bootstrap_fedora() {
  echo -e "\n${GREEN}Bootstrapping Fedora${NO_COLOR}"
  echo -e "\n${CYAN}Upgrading system${NO_COLOR}"
  sudo dnf clean all
  sudo dnf upgrade --refresh -y
  echo -e "\n${CYAN}Installing basic tools${NO_COLOR}"
  sudo dnf install -y zsh \
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
                      xz \
                      gnupg \
                      nmap \
                      @development-tools \
                      file \
                      unzip \
                      bzip2 \
                      zip \
                      fzf \
                      nmap-ncat \
                      ecryptfs-utils \
                      ca-certificates \
                      util-linux-user \
                      dnf-plugins-core \
                      gnome-shell-extension-appindicator \
                      gnome-shell-extension-dash-to-dock \
                      gnome-extensions-app \
                      dnf-plugin-system-upgrade \
                      grubby \
                      wireguard-tools \
                      podman \
                      buildah \
                      kitty

  echo -e "\n${CYAN}Removing virtualization packages${NO_COLOR}"
  sudo dnf remove -y @virtualization

  # brave
  echo -e "\n${CYAN}Installing ${GREEN}Brave${NO_COLOR}"
  sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/x86_64/
  sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
  sudo dnf install brave-browser -y

  # docker
  echo -e "\n${CYAN}Installing ${GREEN}docker${NO_COLOR}"
  sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
  sudo dnf install docker-ce docker-ce-cli containerd.io -y
  sudo usermod -aG docker ${USER}

  # kubectl
  echo -e "\n${CYAN}Installing ${GREEN}kubectl${NO_COLOR}"
  sudo sh -c 'echo -e "[kubernetes]\nname=Kubernetes\nbaseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg" > /etc/yum.repos.d/kubernetes.repo'
  sudo dnf install kubectl -y

  # code
  echo -e "\n${CYAN}Installing ${GREEN}Visual Studio Code${NO_COLOR}"
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
  sudo dnf check-update
  sudo dnf install code -y

  # flathub
  echo -e "\n${CYAN}Setting ${GREEN}Flathub${NO_COLOR}"
  sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

  # spotify
  echo -e "\n${CYAN}Installing ${GREEN}Spotify${NO_COLOR}"
  sudo flatpak install flathub com.spotify.Client -y

  # postman
  echo -e "\n${CYAN}Installing ${GREEN}Postman${NO_COLOR}"
  sudo flatpak install flathub com.getpostman.Postman -y

  # slack
  echo -e "\n${CYAN}Installing ${GREEN}Slack${NO_COLOR}"
  curl -Lo ${TMP}/slack.rpm https://downloads.slack-edge.com/releases/linux/4.19.2/prod/x64/slack-4.19.2-0.1.fc21.x86_64.rpm
  sudo dnf install ${TMP}/slack.rpm -y

  # dropbox
  echo -e "\n${CYAN}Installing ${GREEN}Dropbox${NO_COLOR}"
  curl -Lo ${TMP}/dropbox.rpm https://www.dropbox.com/download?dl=packages/fedora/nautilus-dropbox-2020.03.04-1.fedora.x86_64.rpm
  sudo dnf install ${TMP}/dropbox.rpm -y

  # setup
  setup_tools
  setup_fonts
  setup_shell
  setup_dotfiles
  setup_vscode
  setup_pip

  # Restore Gnome configuration (dconf dump / > gnome/settings.dconf)
  echo -e "\n${CYAN}Restoring Gnome settings${NO_COLOR}"
  dconf load / < gnome/settings_fedora.dconf

  # clean
  sudo dnf autoremove -y
  sudo dnf clean all
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
                      gnome-shell-extension-dashtodock \
                      gnome-extensions-app \
                      virtualbox \
                      kitty

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

  # setup
  setup_tools
  setup_fonts
  setup_shell
  setup_dotfiles
  setup_vscode
  setup_pip

  # Restore Gnome configuration (dconf dump / > gnome/settings.dconf)
  echo -e "\n${CYAN}Restoring Gnome settings${NO_COLOR}"
  dconf load / < gnome/settings_ubuntu.dconf

  # clean
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
  setup_pip
}

update() {
  if [ -d /usr/local/go ]; then
    echo -e "\n${CYAN}Removing ${GREEN}/usr/local/go/${NO_COLOR}"
    sudo rm -r /usr/local/go/
  fi

  echo -e "\n${CYAN}Updating ${GREEN}system${NO_COLOR}, ${GREEN}tools${NO_COLOR} and ${GREEN}repositories${NO_COLOR}"
  if [ ${OS} == "Darwin" ]; then
    if which brew > /dev/null 2>&1; then
      echo -e "\n${CYAN}Upgrading ${GREEN}brew${NO_COLOR}"
      brew upgrade
    fi
  elif [ ${OS} == "Linux" ]; then
    if cat /etc/os-release | grep "Ubuntu" > /dev/null; then
      echo -e "\n${CYAN}Upgrading ${GREEN}system${NO_COLOR}"
      sudo apt update
      sudo apt upgrade -y
      echo -e "\n${CYAN}Upgrading ${GREEN}snap${NO_COLOR} ${CYAN}packages${NO_COLOR}"
      sudo snap refresh -y
      setup_tools
    elif cat /etc/os-release | grep "Fedora" > /dev/null; then
      echo -e "\n${CYAN}Updating ${GREEN}system${NO_COLOR}"
      sudo dnf upgrade --refresh -y
      echo -e "\n${CYAN}Updating ${GREEN}flatpack${NO_COLOR} ${CYAN}packages${NO_COLOR}"
      sudo flatpak update -y
      setup_tools
    fi
  fi

  if [ -d ${ZSH_CUSTOM:=~/.oh-my-zsh} ];then
    echo -e "\n${CYAN}Updating ${GREEN}oh-my-zsh${NO_COLOR}"
    cd ${ZSH_CUSTOM:=~/.oh-my-zsh}
    git pull
  fi

  if [ -d ${ZSH_CUSTOM:=~/.oh-my-zsh/custom}/plugins/zsh-completions ];then
    echo -e "\n${CYAN}Updating ${GREEN}zsh-completions${NO_COLOR}"
    cd ${ZSH_CUSTOM:=~/.oh-my-zsh/custom}/plugins/zsh-completions
    git pull
  fi

  if [ -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions ];then
    echo -e "\n${CYAN}Updating ${GREEN}zsh-autosuggestions${NO_COLOR}"
    cd ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    git pull
  fi

  if [ -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting ];then
    echo -e "\n${CYAN}Updating ${GREEN}zsh-syntax-highlighting${NO_COLOR}"
    cd ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    git pull
  fi

  if [ -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k ];then
    echo -e "\n${CYAN}Updating ${GREEN}powerlevel10k${NO_COLOR}"
    cd ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
    git pull
  fi
}

clean_tmp() {
  echo -e "\n${CYAN}Cleaning...${NO_COLOR}"
  sudo rm -fr ${TMP}
}

bootstrap() {
  if [ ${OS} == "Darwin" ]; then
    bootstrap_macos
  elif [ ${OS} == "Linux" ]; then
    if cat /etc/os-release | grep "Ubuntu" > /dev/null; then
      bootstrap_ubuntu
    elif cat /etc/os-release | grep "Fedora" > /dev/null; then
      bootstrap_fedora
    fi
  fi

  echo -e "\n${GREEN}Bootstrap finished!${NO_COLOR}"
}

main() {
  if [ $# == "0" ]; then
    usage
    exit 0
  fi

  while getopts "acdsu" OPTION; do
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
      u)
        update
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
