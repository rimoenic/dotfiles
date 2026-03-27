{
  description = "Home Manager configuration";

  inputs = {
    # Nixパッケージのソース（unstableブランチ = 最新版）
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }: {
    # 汎用的な名前を使用（どの環境でも利用可能）
    homeConfigurations.default = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [ ./home.nix ];
    };
  };
}
