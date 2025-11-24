{ config, pkgs, ... }:

{
  # ユーザー情報（環境変数から動的に取得）
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";

  # Home Managerのバージョン（変更しないでください）
  home.stateVersion = "24.11";

  # Home Manager自身を有効化
  programs.home-manager.enable = true;

  # パッケージ管理
  programs.git.enable = true;
  programs.neovim.enable = true;
  programs.tmux.enable = true;

  # 開発ツール
  programs.fzf.enable = true;
  programs.direnv.enable = true;

  # ghqはHome Managerのprogramsにないので、packagesで管理
  home.packages = with pkgs; [
    ghq
  ];

  # Zsh設定は既存の.zshrcを使用するため、Home Managerでは管理しない
  # 将来的にHome Managerに移行する場合は、上記のコメントを解除して設定を追加
}
