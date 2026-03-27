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
  programs.git = {
    enable = true;

    # ユーザー情報（環境変数から取得、または手動設定）
    # userName = "Your Name";
    # userEmail = "your@email.com";

    settings = {
      # エイリアス
      alias = {
        st = "status";
        co = "checkout";
        ci = "commit";
        typechange = "status -s | awk '$1==\"T\"{print $2}' | xargs git checkout";
        graph = "log --graph --date-order --all --pretty=format:'%h %Cred%d %Cgreen%ad %Cblue%cn %Creset%s' --date=short";
        br = "switch";
        review = "diff origin/master...";
        review-files = "diff origin/master... --name-only";
        lg = "log --color=always --max-count=10 --oneline origin/master...";
        delete-merged-branches = "!git branch --merged | grep -v \\\\* | xargs -I % git branch -d %";
      };

      # 各種設定
      core = {
        preloadindex = true;
        autocrlf = false;
      };

      color = {
        ui = "auto";
        diff = {
          meta = "242 238";
          frag = "239 236";
          old = "167 normal";
          new = "030 normal";
          context = "240";
          commit = "246 024";
        };
      };

      help = {
        autocorrect = 1;
      };

      push = {
        default = "matching";
      };

      pager = {
        log = "diff-highlight | less -RX";
        show = "diff-highlight | less -RX";
        diff = "diff-highlight | less -RX";
      };

      diff = {
        tool = "vimdiff";
        algorithm = "histogram";
        compactionHeuristic = true;
      };

      ghq = {
        root = "~/src";
        vcs = "git";
      };

      merge = {
        tool = "vimdiff";
      };

      github = {
        user = "rimoenic";
      };
    };
  };
  programs.neovim.enable = true;

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

  # 開発ツール
  programs.fzf.enable = true;
  programs.direnv.enable = true;

  # ghq/zshはHome Managerのprogramsにないので、packagesで管理
  home.packages = with pkgs; [
    ghq
    zsh
    awscli2
    aws-sam-cli
    uv
    tenv              # terraform version manager
    ruby              # roadworker gem のため
    dig               # DNS lookup (bind9-dnsutils相当)
    fq                # バイナリフォーマット解析
    jq                # JSON処理
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
    tree
    subversion
    qrencode
    jc                # JSON化CLIツール
  ];

  # Zsh設定は既存の.zshrcを使用するため、Home Managerでは管理しない
  # 将来的にHome Managerに移行する場合は、上記のコメントを解除して設定を追加
}
