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
}
