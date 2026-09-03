# git/

Windows と WSL で Git 設定を共通化するためのディレクトリ。

## なぜ分割するか

`~/.gitconfig` そのものを両OSで共有するのは無理がある。外部コマンドに依存する
設定（`pager` の `diff-highlight`、`difftool` の `vimdiff`）は Windows 側に
実体が無く、`core.autocrlf` に至っては OS ごとに逆の値が要る。

そこで「共通部分」と「OS固有部分」を分け、各OSの `~/.gitconfig` からは
`include` で読み込むだけにしている。共通部分の実体が一つなので、
片方だけ更新して差分が生まれることがない。

## ファイル

| ファイル | 内容 |
|---|---|
| `common.gitconfig` | 両OS共通。alias / color / diff.algorithm など |
| `wsl.gitconfig` | WSL固有。pager, difftool, ghq.root |
| `windows.gitconfig` | Windows固有。autocrlf, credential helper |
| `local.gitconfig` | ユーザ情報。**gitignore 済み**（会社/個人でアドレスが違うため） |
| `local.gitconfig.example` | 上記の雛形 |
| `global.ignore` | 全リポジトリ共通の無視リスト。**コピーして使う**（後述） |

後に読まれたものが勝つので、OS固有ファイルで共通設定を上書きできる。

## 読み込まれ方

- **WSL**: `nix/home.nix` の `programs.git.includes`
- **Windows**: `windows/setup.ps1` が生成する `~/.gitconfig` の `[include]`

存在しない include は Git が黙って無視するため、`local.gitconfig` を作って
いなくてもエラーにはならない。

## global.ignore

どのリポジトリでも無視したいもの（エディタやツールが吐くローカル設定）を
書いてある。他人のリポジトリの .gitignore を汚さずに済ませるためのもの。

include はしない。`~/.config/git/ignore` が Git の探す既定の場所なので、
そこにコピーすれば `core.excludesFile` の設定すら要らない。

```sh
mkdir -p ~/.config/git && cp git/global.ignore ~/.config/git/ignore
```

Windows も同じパスでよい（Git for Windows は `~` を `%USERPROFILE%` に
解決する）。無視したいものが OS で違う場合は、コピー先で各自編集する。

## 素のINIで持つ理由

Nix で生成すると Windows 側が WSL の `home-manager switch` に依存してしまう。
Windows 単体で完結させたいので、どちらからも読める素の INI にしている。

## ユーザ情報の設定

```sh
cp git/local.gitconfig.example git/local.gitconfig
$EDITOR git/local.gitconfig
```

リポジトリごとにアドレスを変えたい場合は `includeIf "gitdir:"` を使う
（`local.gitconfig.example` にコメントで例がある）。

## 今後の予定: delta への移行

現在 pager に `diff-highlight`（git 同梱の contrib スクリプト）を使っているが、
これが行内差分を reverse で強調し直すため、`color.diff.whitespace` の背景色が
潰れて明るい塊に見える。色を変えても回避できない。

行末空白を確実に拾いたい場合は、色に頼らず `git diff --check` を使う。

将来的には [delta](https://github.com/dandavison/delta) に移行する。色管理が
明示的で、この干渉が起きない。移行時は `wsl.gitconfig` の `[pager]` を
差し替え、`whitespace` の見え方を再確認すること。
