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
