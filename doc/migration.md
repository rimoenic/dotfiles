# Nix 移行ロードマップ

## 移行状況

✅ **Home Manager に移行済み:**
- パッケージ管理: git, neovim, tmux, fzf, ghq, direnv
- Git 設定（`.gitconfig` → `~/.config/git/config`）
- Tmux 設定（`.tmux.conf` → `~/.config/tmux/tmux.conf`）

🚧 **レガシー設定を使用中:**
- Zsh 設定（`.zshrc` と `zsh/` ディレクトリ）
- Neovim 設定（`nvim/init.vim`）

## 移行手順の原則

1. 移行前に既存ファイルを必ず読む
2. Home Manager 適用前に競合する symlink を削除
3. 一度に1ツールずつ移行し、都度 `home-manager switch` でテスト
4. `home.nix` 修正時は `home-manager switch` を使用（`nix build` だけでは不十分）
5. 各移行は個別のコミットにする

## クリーンアップ候補

削除前に要確認：

| ファイル | 理由 |
|---|---|
| `.vimrc` | vim 未インストール、nvim を使用 |
| `.ackrc` | ack を使用していない可能性 |
| `.curlrc` | curl 設定が不要の可能性 |
| `.bash_profile` | zsh 使用中、bash は不使用 |
| `windows/` | Windows 固有、必要性を確認 |
| `zsh/10_aliases.zsh` 内の DNS 関連関数 | `dignifty`, `roadwork` 等が古い可能性 |
