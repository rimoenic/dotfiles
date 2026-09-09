{ config, pkgs, lib, ... }:


{
  # ユーザー情報（環境変数から動的に取得）
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";

  # Home Managerのバージョン（変更しないでください）
  home.stateVersion = "24.11";

  # Home Manager自身を有効化
  programs.home-manager.enable = true;

  # home.packages のフォントは fontconfig を有効にしないと
  # アプリ側から参照されない（WSLg 上の GUI アプリや fcitx5 が対象）。
  fonts.fontconfig = {
    enable = true;

    # Windows 側のフォントを WSL から共有する。
    # /etc/fonts/local.conf を手で編集していたのを Home Manager 管理に移した。
    # 存在しない dir は fontconfig が黙って無視するので、
    # /mnt/c が無い環境でも条件分岐は不要。
    configFile.wsl-windows-fonts = {
      enable = true;
      priority = 10;
      settings = {
        description = "Use fonts installed on the Windows host";
        dir = "/mnt/c/Windows/Fonts";
      };
    };
  };

  # 日本語入力（WSLg 上の Obsidian 等の GUI アプリ向け）。
  # fcitx5-mozc を home.packages に置くだけでは、IM モジュールの環境変数も
  # fcitx5 デーモンも設定されず変換が始まらないので i18n.inputMethod を使う。
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = [ pkgs.fcitx5-mozc ];

      # WSLg は Wayland なので Wayland フロントエンドを有効にする。
      # obsidian ラッパーが --wayland-text-input-version=3 を付けるため、
      # fcitx5 側が text-input プロトコルを話せないと繋がらない。
      # このモジュールは waylandFrontend = true のとき GTK_IM_MODULE を外す
      # 代わりに gtk*.extraConfig で gtk-im-module を設定するので、
      # XWayland の GTK アプリも従来通り動く。
      waylandFrontend = true;

      settings.inputMethod = {
        GroupOrder."0" = "Default";
        "Groups/0" = {
          Name = "Default";
          "Default Layout" = "us";
          DefaultIM = "mozc";
        };
        # 直接入力を先頭に置き、Ctrl+Space で mozc に切り替える。
        "Groups/0/Items/0".Name = "keyboard-us";
        "Groups/0/Items/1".Name = "mozc";
      };
    };
  };

  # nixpkgs の obsidian ラッパーは NIXOS_OZONE_WL と WAYLAND_DISPLAY の
  # 両方が立っているときだけ --enable-wayland-ime を付ける。
  # これが無いと Electron が fcitx5 と繋がらず日本語が入力できない。
  home.sessionVariables.NIXOS_OZONE_WL = "1";

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "obsidian"
    ];

  # Git 設定は git/*.gitconfig（素のINI）に置き、include で読み込む。
  # Windows 側の ~/.gitconfig からも同じファイルを include しており、
  # 共通部分を一箇所に保つため Nix では settings を持たせない。
  programs.git = {
    enable = true;

    includes = let
      dotfiles = "${config.home.homeDirectory}/.dotfiles/git";
    in [
      { path = "${dotfiles}/common.gitconfig"; }
      { path = "${dotfiles}/wsl.gitconfig"; }
      # ユーザ情報。未作成でも Git は存在しない include を黙って無視する。
      { path = "${dotfiles}/local.gitconfig"; }
    ];
  };

  programs.neovim = {
    enable = true;
    withRuby = true;      # 26.05より前の挙動を維持（最新はfalse）
    withPython3 = true;   # 26.05より前の挙動を維持（最新はfalse）

    extraConfig = ''
set ignorecase
set smartcase
set wrapscan
set incsearch
set inccommand=split

set expandtab
set softtabstop=0
set tabstop=4

set smarttab
set shiftwidth=4
set shiftround

" set statusline=%F%m%r%h%w%=\ [FORMAT=%{&ff}]\ [TYPE=%Y]\ [ASCII=\%03.3b]\
" [HEX=\%02.2B]\ [POS=%04l,%04v][%p%%]\ [LEN=%L]
" " ファイル名表示
" set statusline=%F
" " 変更チェック表示
" set statusline+=%m
" " 読み込み専用かどうか表示
" set statusline+=%r
" " ヘルプページなら[HELP]と表示
" set statusline+=%h
" " プレビューウインドウなら[Prevew]と表示
" set statusline+=%w
" " これ以降は右寄せ表示
" set statusline+=%=
" " file encoding
" set statusline+=[FORMAT=%{&ff}]
" set statusline+=[ENC=%{&fileencoding}]
" " 現在行数/全行数
" set statusline+=[LOW=%l/%L]
"
"
" "
" ステータスラインを常に表示(0:表示しない、1:2つ以上ウィンドウがある時だけ表示)
" set laststatus=2
"
"
    '';
  };

  programs.tmux = {
    enable = true;
    shell = "${pkgs.zsh}/bin/zsh";
    prefix = "C-t"; # rebindingしてくれるから手動でunbindなどする必要無し
    keyMode = "vi";
    baseIndex = 1; # pane-base-indexも設定してくれる
    escapeTime = 1;
    terminal = "screen-256color";

    extraConfig = ''
      set-environment -g CHERE_INVOKING 1

      # 設定リロード
      bind-key C-r source-file ~/.config/tmux/tmux.conf \; display-message "Reloaded."

      # 同期ペイン
      bind m setw synchronize-panes on \; display-message "Sync-Pane On."
      bind M setw synchronize-panes off \; display-message "Sync-Pane Off."

      # カレントディレクトリ引継ぎ用
      bind c new-window -c "#{pane_current_path}"

      # WSL clipboard対応
      if-shell 'test -n ''${WSLENV}' '\
        bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "cat | powershell.exe -Command clip.exe"; \
        bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "cat | powershell.exe -Command clip.exe"; \
      '

      # ペイン分割（カレントディレクトリ引継ぎ）
      bind | split-window -hc "#{pane_current_path}"
      bind - split-window -vc "#{pane_current_path}"

      # ペイン移動
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R
      bind -r C-p select-window -t :-
      bind -r C-n select-window -t :+

      # ペインボーダーの色
      set -g pane-border-style fg=green,bg=black
      set -g pane-active-border-style fg=black,bg=yellow

      # コマンドラインの色
      set -g message-style fg=white,bg=black,bright

      # ステータスバー
      set -g status-interval 10
      set -g status-style bg=colour238,fg=colour255
      setw -g window-status-style bg=default,fg=colour87,none
      setw -g window-status-current-style bg=white,fg=colour21
      set -g status-left-length 40
      set -g status-left "#[fg=green]Session: #S #[fg=yellow]#I #[fg=cyan]#P"
      set -g status-right "#[fg=cyan][%Y-%m-%d(%a) %H:%M]"
      set -g status-justify centre
      setw -g monitor-activity on
      set -g visual-activity on
      set -g status-position top

      # ペイン区切り線の修正
      # https://github.com/tmux/tmux/wiki/FAQ#why-are-tmux-pane-separators-dashed-rather-than-continuous-lines
      set -as terminal-overrides ",*:U8=0"
    '';
  };

  # cliツール
  programs.bat.enable = true;   # alter. cat
  programs.delta.enable = true; # git の pager（git/common.gitconfig で core.pager に指定）
  programs.eza.enable = true;   # alter. ls
  programs.fd.enable = true;    # alter. find
  programs.jq.enable = true;    # JSON処理
  #programs.pazi.enable = true;
  #programs.pet.enable = true;  # command snippet

  # 開発ツール
  programs.fzf.enable = true;
  programs.direnv.enable = true;
  programs.uv.enable = true;

  # その他
  programs.awscli.enable = true;
  #programs.obsidian.enable = true;


  # ghq/zshはHome Managerのprogramsにないので、packagesで管理
  home.packages = with pkgs; [
    ghq
    zsh
    aws-sam-cli
    tenv              # terraform version manager
    ruby              # roadworker gem のため
    dig               # DNS lookup (bind9-dnsutils相当)
    fq                # バイナリフォーマット解析
    nkf               # 文字コード変換
    pwgen             # パスワード生成
    whois
    zip
    unzip
    noto-fonts-cjk-sans   # 日本語フォント
    noto-fonts-cjk-serif  # 日本語フォント
    nerd-fonts.caskaydia-cove
    obsidian          # ノートアプリ（WSLg必要）
    apacheHttpd       # htpasswd等のユーティリティ
    jsonnet
    shellcheck
    shfmt
    go                # golang
    gcc               # for Golang
    tree
    subversion
    qrencode
    jc                # JSON化CLIツール
    rclone
    graphviz
  ];

  # Zsh設定は既存の.zshrcを使用するため、Home Managerでは管理しない
  # 将来的にHome Managerに移行する場合は、上記のコメントを解除して設定を追加
}
