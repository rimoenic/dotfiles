# rimoenic's dotfiles

Nix と Home Manager（Flakes）で管理する dotfiles。従来の symlink ベースから宣言的な Nix 設定への移行期にある。

## セットアップ

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/rimoenic/dotfiles/master/doc/installer.sh)
```

> 今後 `bootstrap.sh` としてルート直下に移動予定。

## 構成

```
nix/
  flake.nix     # Flakes 設定
  home.nix      # Home Manager メイン設定
zsh/            # Zsh 設定（レガシー）
nvim/           # Neovim 設定（レガシー）
windows/        # WSL / Windows Terminal 設定
doc/
  installer.sh  # ブートストラップスクリプト
  nix-patterns.md
  migration.md
```

## ドキュメント

- [Nix/Home Manager 設定パターン](doc/nix-patterns.md)
- [移行ロードマップ・クリーンアップ候補](doc/migration.md)
