# native Linux（実機・デスクトップ環境あり）固有の設定。
# home.nix から WSL_DISTRO_NAME が無い場合に自動 import される。
{ config, pkgs, lib, ... }:

{
  # 実機の Wayland コンポジタ（GNOME/KDE/Sway 等）は input_method /
  # text-input プロトコルを提供するので Wayland フロントエンドを使う。
  # X11 セッションで運用する場合は false にすると
  # GTK_IM_MODULE/QT_IM_MODULE が設定される。
  i18n.inputMethod.fcitx5.waylandFrontend = true;

  # Electron アプリを Wayland ネイティブで動かす。
  # nixpkgs のラッパーは NIXOS_OZONE_WL と WAYLAND_DISPLAY が揃った
  # ときだけ --ozone-platform=wayland --enable-wayland-ime を付ける
  # （obsidian の package.nix 参照）。
  # waylandFrontend = true では GTK_IM_MODULE/QT_IM_MODULE が設定されず、
  # XWayland に落ちた Electron は IME に繋がる経路を失うため必須。
  # WAYLAND_DISPLAY が無い X11 セッションでは展開されず無害。
  home.sessionVariables.NIXOS_OZONE_WL = "1";

  # fcitx5-daemon は i18n.inputMethod が生成する定義のまま
  # graphical-session.target に任せる（WSL のような上書きは不要）。
  # 日本語フォントは実機側で用意する必要がある。noto-fonts だけでは
  # CJK 字形が入らないため CJK パッケージを明示する。
  home.packages = with pkgs; [
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
  ];

  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Noto Sans CJK JP" ];
    serif = [ "Noto Serif CJK JP" ];
    monospace = [ "Noto Sans Mono CJK JP" ];
  };
}
