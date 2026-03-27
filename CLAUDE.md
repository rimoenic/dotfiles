# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 概要

このリポジトリは**Nix と Home Manager（Flakes使用）**で管理されているdotfilesです。従来のsymlinkベース
のdotfilesから宣言的なNix設定への移行期にあります。

## アーキテクチャ

### 二段階構造

**レガシーdotfiles**（まだ使用中）:
- `.zshrc`, `zsh/` - Zsh設定（zinitでプラグイン管理）
- `nvim/` - Neovim設定
- `windows/` - Windows固有の設定（WSL、Windows Terminal）

**Nix/Home Manager**（アクティブ、推奨）:
- `nix/flake.nix` - Flakes設定（inputs定義：nixpkgs, home-manager）
- `nix/home.nix` - メイン設定ファイル（全パッケージと設定を宣言）
- `nix/flake.lock` - 依存関係バージョンのロック

### 移行状況

✅ **Home Managerに移行済み:**
- パッケージ管理: git, neovim, tmux, fzf, ghq, direnv
- Git設定（`.gitconfig` → `~/.config/git/config`）
- Tmux設定（`.tmux.conf` → `~/.config/tmux/tmux.conf`）

🚧 **レガシー設定を使用中:**
- Zsh設定（`.zshrc`と`zsh/`ディレクトリ）
- Neovim設定（`nvim/init.vim`を使用）

## 主要コマンド

### Home Manager設定の適用

```bash
cd ~/.dotfiles/nix
home-manager switch --flake .#default --impure

重要: --impureフラグが必須です。home.nixがbuiltins.getEnvを使ってUSERとHOME環境変数を動的に取得してい
るためです。

依存関係の更新

cd ~/.dotfiles/nix
nix flake update

設定パターン

動的なユーザー情報

設定ではハードコードされたユーザー名の代わりに環境変数を使用：

home.username = builtins.getEnv "USER";
home.homeDirectory = builtins.getEnv "HOME";

これにより、異なるマシンやユーザー間で設定を移植可能にします。

extraConfigでの変数エスケープ

変数（${VAR}など）を含むシェル設定を追加する場合、Nixでは二重シングルクォートでエスケープ：

extraConfig = ''
if-shell 'test -n ''${WSLENV}' 'echo "In WSL"'
'';

Home Manager APIの変更

Git設定では新しいsettings APIを使用：

programs.git = {
enable = true;
settings = {
    alias = { ... };
    core = { ... };
};
};

非推奨のaliasesとextraConfig属性は使用しないこと。

ファイル配置

Home ManagerはXDG Base Directory仕様に従って設定ファイルを配置：
- Git: ~/.config/git/config（~/.gitconfigではない）
- Tmux: ~/.config/tmux/tmux.conf（~/.tmux.confではない）

生成されたファイルは全て/nix/store/xxx-home-manager-files/...へのsymlinkです。

Zsh設定の読み込み

.zshrcはカスタムローダーパターンを使用：

_load_settings() {
    _dir="$1"
    for config in "$_dir"/**/*(N-.); do
        case "$config" in
            *.zwc) : ;;
            *) . $config ;;
        esac
    done
}
_load_settings "${DOTFILESPATH}/zsh"

これはzsh/ディレクトリ内の全ファイルをglob順（00_common.zsh, 10_aliases.zsh, 20_misc.zsh,
zinit.zsh）で読み込みます。

今後の移行時の重要事項

1. 既存ファイルを先に読む - home.nixに移行する前に必ず既存ファイルを確認
2. 古いsymlinkを削除 - Home Manager適用前に削除して競合を回避
3. 段階的にテスト - 一度に1つのツールずつ移行
4. 頻繁にcommit - 各移行は個別のcommitにする
5. home.nix修正時はhome-manager switchを使用（nix buildだけでは不十分）

クリーンアップ対象のレガシーファイル

以下のファイルは不要の可能性がありますが、削除前にユーザーに確認が必要：
- .vimrc（vimは未インストール、nvimを使用）
- .ackrc（ackを使用していない可能性）
- .curlrc（curl設定が不要の可能性）
- .bash_profile（zsh使用中、bashは不使用）
- windows/ディレクトリ（Windows固有、必要性を確認）
- zsh/10_aliases.zsh内の古いDNS関連関数（dignifty, roadwork等）

