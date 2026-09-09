{ config, pkgs, lib, ... }:


{
  # ユーザー情報（環境変数から動的に取得）
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";

  # Home Managerのバージョン（変更しないでください）
  home.stateVersion = "24.11";

  # Home Manager自身を有効化
  programs.home-manager.enable = true;

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
    noto-fonts        # 日本語フォント
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
  ];

  # Zsh設定は既存の.zshrcを使用するため、Home Managerでは管理しない
  # 将来的にHome Managerに移行する場合は、上記のコメントを解除して設定を追加
}
