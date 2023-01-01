{
  description = "A basic Go web server setup";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";

    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "utils";
    };
  };

  outputs = { self, nixpkgs, utils, naersk, rust-overlay }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ rust-overlay.overlays.default ];
      };
      version = builtins.substring 0 0 self.lastModifiedDate;
      rust = (pkgs.rust-bin.stable."1.64.0".default.override {
        extensions = [ "rust-src" ];
      });
      naersk' = pkgs.callPackage naersk {
        rustc = rust;
        cargo = rust;
      };
    in {
      packages.x86_64-linux.default = naersk'.buildPackage {
        src = ./.;
      };

      nixosModules.static-pages = import ./service.nix self;

      apps.x86_64-linux.default =
        utils.lib.mkApp { drv = self.packages.x86_64-linux.static-pages; exePath = "/bin/static_pages"; };

      devShells.x86_64-linux.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          rust
        ];
      };
  };
}