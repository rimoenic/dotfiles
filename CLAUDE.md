# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## アーキテクチャ概要

従来の symlink ベースの dotfiles から Nix/Home Manager（Flakes）への移行期にある。

- **レガシー**: `.zshrc`, `zsh/`, `nvim/`, `windows/`
- **Nix/HM（推奨）**: `nix/flake.nix`, `nix/home.nix`

詳細は [doc/nix-patterns.md](doc/nix-patterns.md) / [doc/migration.md](doc/migration.md) を参照。

## 作業時の注意

- `home.nix` を編集したら必ず `home-manager switch --flake .#default --impure` で適用
- `nix/` 配下のファイルを変更する前に既存設定を確認する
- 移行は一度に1ツールずつ、都度コミット
- Nix の設定パターン（変数エスケープ・API 等）は [doc/nix-patterns.md](doc/nix-patterns.md) を参照
