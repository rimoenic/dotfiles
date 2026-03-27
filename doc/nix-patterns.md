# Nix / Home Manager 設定パターン

## 基本コマンド

```bash
# 設定の適用
cd ~/.dotfiles/nix
home-manager switch --flake .#default --impure

# 依存関係の更新
nix flake update
```

`--impure` フラグが必須。`home.nix` が `builtins.getEnv` で `USER`/`HOME` を動的取得しているため。

## 動的なユーザー情報

ユーザー名をハードコードせず環境変数から取得することで、マシン間で移植可能にする：

```nix
home.username = builtins.getEnv "USER";
home.homeDirectory = builtins.getEnv "HOME";
```

## extraConfig での変数エスケープ

`${VAR}` を含むシェル設定は Nix の二重シングルクォートでエスケープ：

```nix
extraConfig = ''
  if-shell 'test -n ''${WSLENV}' 'echo "In WSL"'
'';
```

## Home Manager API の注意点

Git 設定は `settings` API を使用。`aliases` / `extraConfig` 属性は非推奨：

```nix
programs.git = {
  enable = true;
  settings = {
    alias = { ... };
    core = { ... };
  };
};
```

## ファイル配置（XDG Base Directory）

Home Manager が生成するファイルはすべて `/nix/store/...` へのsymlink：

| ツール | パス |
|---|---|
| Git | `~/.config/git/config`（`~/.gitconfig` ではない） |
| Tmux | `~/.config/tmux/tmux.conf`（`~/.tmux.conf` ではない） |

## Zsh 設定の読み込み順

`zsh/` ディレクトリ内を glob 順で自動ロード（`.zshrc` の `_load_settings` 関数）：

```
00_common.zsh → 10_aliases.zsh → 20_misc.zsh → zinit.zsh
```
