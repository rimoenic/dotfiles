# WSL(WSLg) 固有の設定。
# home.nix から WSL_DISTRO_NAME の有無で自動 import される。
{ config, pkgs, lib, ... }:

{
  # Windows 側のフォントを WSL から共有する。
  # /etc/fonts/local.conf を手で編集していたのを Home Manager 管理に移した。
  fonts.fontconfig.configFile.wsl-windows-fonts = {
    enable = true;
    priority = 10;
    settings = {
      description = "Use fonts installed on the Windows host";
      dir = "/mnt/c/Windows/Fonts";
    };
  };

  # WSLg のコンポジタは input_method プロトコルの bind を拒否する
  # （zwp_input_method_v1: permission to bind input_method denied →
  # connection error 71 で fcitx5 が即終了）。よって Wayland 経路は使えず、
  # GTK_IM_MODULE/QT_IM_MODULE 経由の X11(xcb) 経路に固定する。
  i18n.inputMethod.fcitx5.waylandFrontend = false;

  # fcitx5-daemon は本来 graphical-session.target に紐付くが、WSLg には
  # これを activate するデスクトップセッションが無く自動起動しない。
  # default.target に載せ替える。
  systemd.user.services.fcitx5-daemon = {
    Unit = {
      # default.target に WantedBy されるので同じ target を After に
      # 置くと順序が循環しうる。graphical-session への紐付けは全て外す。
      After = lib.mkForce [ ];
      PartOf = lib.mkForce [ ];
    };
    Service = {
      # wayland: コンポジタ接続、waylandim: Wayland 入力メソッド
      # フロントエンド。後者が bind 拒否の原因なので両方無効化する。
      # 旧環境の `-d` は付けない（フォークすると systemd が
      # メインプロセスを見失い Restart と組んで再起動ループになる）。
      ExecStart = lib.mkForce (
        "${config.i18n.inputMethod.package}/bin/fcitx5 --disable=wayland,waylandim"
      );
      # X11 経路なので DISPLAY が必要。Restart は WSLg の準備待ちの保険。
      Environment = [ "DISPLAY=:0" ];
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = lib.mkForce [ "default.target" ];
  };
}
