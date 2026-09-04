# git/

Windows と WSL で Git 設定を共通化するためのディレクトリ。

## なぜ分割するか

`~/.gitconfig` そのものを両OSで共有するのは無理がある。片方にしか実体が無い
外部コマンドに依存する設定（`difftool` の `vimdiff` と WinMerge）があり、
`ghq.root` に至っては OS ごとに置き場所が違う。

そこで「共通部分」と「OS固有部分」を分け、各OSの `~/.gitconfig` からは
`include` で読み込むだけにしている。共通部分の実体が一つなので、
片方だけ更新して差分が生まれることがない。

## ファイル

| ファイル | 内容 |
|---|---|
| `common.gitconfig` | 両OS共通。alias / color / diff.algorithm など |
| `wsl.gitconfig` | WSL固有。difftool, ghq.root |
| `windows.gitconfig` | Windows固有。autocrlf, credential helper |
| `local.gitconfig` | ユーザ情報。**gitignore 済み**（会社/個人でアドレスが違うため） |
| `local.gitconfig.example` | 上記の雛形 |
| `global.ignore` | 全リポジトリ共通の無視リスト。OSごとに参照のさせ方が違う（後述） |

後に読まれたものが勝つので、OS固有ファイルで共通設定を上書きできる。

## 読み込まれ方

どちらも `~/.config/git/config`（XDG）に置いた薄い設定から `include` する。

- **WSL**: `nix/home.nix` の `programs.git.includes` → Home Manager が生成
- **Windows**: `windows/setup.ps1` が生成

存在しない include は Git が黙って無視するため、`local.gitconfig` を作って
いなくてもエラーにはならない。

### ~/.gitconfig を使わない理由

Home Manager が `programs.git` で書き出す先が `~/.config/git/config` なので、
Windows 側もそこに合わせている。

**`~/.gitconfig` が残っていると、そちらが優先される。** Git は XDG 側を先に
読み、`~/.gitconfig` で上書きするため。移行のときに古いファイルを消し忘れると
新しい設定が黙って無効になるので、`git config --show-origin --get <key>` で
どのファイルが効いているか確かめるとよい。

Nix 未適用の WSL では Home Manager が動かないので、`~/.gitconfig` に手で
include を書く形でも構わない（読み込まれ方が違うだけで内容は同じ）。

## global.ignore

どのリポジトリでも無視したいもの（エディタやツールが吐くローカル設定）を
書いてある。他人のリポジトリの .gitignore を汚さずに済ませるためのもの。

`[include]` では読み込めない。include で入るのは設定であって無視リストでは
ないため、`core.excludesFile` で「どのファイルを使うか」を指すか、Git が
既定で見る `~/.config/git/ignore` に実体を置くかのどちらかになる。

WSL と Windows で方法が違う。

| 環境 | 方法 |
|---|---|
| WSL | `~/.config/git/ignore` → `git/global.ignore` の symlink（`doc/installer.sh` が張る） |
| Windows | `windows.gitconfig` の `core.excludesFile` で実体を直接指す |

Windows で symlink を使わないのは、作成に管理者権限（または開発者モード）が
要るため。リンクもコピーもせず設定から直接指している。コピーではないので、
repo を更新すれば即反映される。

パスに `~` が使えるのは、`excludesFile` の値が Git に「パス」として扱われる
ため。一方で**環境変数は展開されない**ので `$LOCALAPPDATA` 等は書けない
（`windows.gitconfig` の `mergetool.cmd` で変数が使えるのは、あちらがシェル
経由で実行されるためで、扱いが違う）。

どちらの方法でも効いているかは `git check-ignore -v <file>` で確認できる。
どのファイルの何行目が効いたかまで出る。

```sh
git check-ignore -v Thumbs.db
```

このファイルは両OSで共有されるので、OS 固有の除外を足すと反対側にも効く。
片側だけで無視したいものは、そのクローンの `.git/info/exclude`（共有されない）
に書く。

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

## pager（delta）

pager は [delta](https://github.com/dandavison/delta)。両OSで同じものを使うので
`common.gitconfig` に置いてある。

以前は WSL 側だけ git 同梱の contrib スクリプト `diff-highlight` を使っていたが、
実体の置き場所が Git のバージョンやインストール方法で変わるため、環境を作り直す
たびに PATH を通し直す必要があった。delta は単体のバイナリなので両OSに同じ手段で
入れられる。行内差分の描き方も変わり、`diff-highlight` で起きていた
`color.diff.whitespace` の潰れ（reverse の二重掛け）も無くなった。

delta が PATH に無いと `git diff` が pager の起動に失敗する。設定だけ取り込んで
本体を入れ忘れないよう、インストール定義も併せて置いてある。

| 環境 | 入れ方 |
|---|---|
| Windows | `windows/winget/fav_tools.json`（`dandavison.delta`） |
| WSL（Nix 適用済み） | `nix/home.nix` の `home.packages` |
| WSL（Nix 未適用） | `sudo apt install git-delta`（バイナリ名は `delta`） |

Ubuntu の apt 版はバージョンが古い（24.04 で 0.16.5）。上の設定は 0.16.5 でも
警告を出さない範囲に収めてある。

### 移動行の色

`diff.colorMoved = zebra` が付ける色は、delta が既定では捨ててしまう。
`delta.map-styles` で「Git がこの色で出した行は delta 側のこの色で描く」と
対応付けて拾っている。`color.diff.*Moved` を変えたら `map-styles` の右辺も
併せて直すこと。

なお zebra の移動判定は一定行数以上のまとまりにしか効かない。数行動かした
程度では通常の追加・削除として出るので、移動色が出なくても設定の不具合とは
限らない。
