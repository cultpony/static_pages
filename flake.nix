{
  inputs = {
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = { self, fenix, flake-utils, nixpkgs }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        toolchain = fenix.packages.${system}.stable.toolchain;
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs =
            [
              pkgs.cargo-nextest
              fenix.packages.${system}.stable.toolchain
            ];
        };

        nixosModules =
          rec {
            cultponyStaticSites = import ./service.nix self;
            default = cultponyStaticSites;
          };

        packages = rec {
          cultponyStaticSites =

            (pkgs.makeRustPlatform {
              cargo = toolchain;
              rustc = toolchain;
              withComponents = with pkgs; [
                nixpkgs.cargo-nextest
              ];
            }).buildRustPackage
              {
                pname = "static_pages";
                version = "0.1.0";

                src = ./.;

                cargoLock.lockFile = ./Cargo.lock;

                # disable networked tests
                checkNoDefaultFeatures = true;
                checkFeatures = [ ];

                useNextest = true;
              };
          default = cultponyStaticSites;
        };
      });
}
