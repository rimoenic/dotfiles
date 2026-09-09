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

## プラットフォーム別の設定分割

WSL(WSLg) と native Linux で挙動が異なる設定は、共通部分を `home.nix` に残し、
固有部分を別ファイルに切り出して条件付き import する：

| ファイル | 役割 |
|---|---|
| `nix/home.nix` | 両環境共通。`imports` で下記を自動選択 |
| `nix/wsl.nix` | WSL 固有（Windows フォント共有、fcitx5 の X11 経路固定など） |
| `nix/linux.nix` | native Linux 固有（Wayland フロントエンド、CJK フォント） |

```nix
let
  # WSL は WSL_DISTRO_NAME を必ず設定する
  isWSL = builtins.getEnv "WSL_DISTRO_NAME" != "";
in
{
  imports =
    lib.optional isWSL ./wsl.nix
    ++ lib.optional (!isWSL) ./linux.nix;
}
```

適用コマンドは分岐後も変わらない（`.#default` のまま）。

**注意**: flake は git 管理下のファイルしかストアにコピーしない。新規ファイルを
追加した直後は `path '...' does not exist` で評価が失敗するため、
`git add -N <file>`（intent-to-add）か通常の `git add` が必要。

片方の環境にいると他方の分岐が評価されず壊れていても気付けない。
`env -u WSL_DISTRO_NAME` で強制的に反対側を評価して確認できる：

```bash
env -u WSL_DISTRO_NAME nix eval --impure   '.#homeConfigurations.default.config.i18n.inputMethod.fcitx5.waylandFrontend'
```

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
