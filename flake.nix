{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }
  : let
    systems = {
      "aarch64-linux" = "linux_arm";
      "aarch64-darwin" = "macos_arm";
      "x86_64-linux" = "linux_x64";
      "x86_64-darwin" = "macos_x64";
    };
  in
    flake-utils.lib.eachSystem (builtins.attrNames systems) (
      system: let
        ls-system = systems.${system};
        versions = builtins.fromJSON (builtins.readFile ./lua/khulnasoft/versions.json);
        pkgs = import nixpkgs {
          inherit system;
        };
      in rec {
        formatter = pkgs.alejandra;

        packages = with pkgs; {
          khulnasoft-lsp = stdenv.mkDerivation {
            pname = "khulnasoft-lsp";
            version = "v${versions.version}";

            src = pkgs.fetchurl {
              url = "https://github.com/KhulnaSoft/khulnasoft-release/releases/download/language-server-v${versions.version}/language_server_${ls-system}";
              sha256 = versions.hashes.${system};
            };

            sourceRoot = ".";

            phases = ["installPhase" "fixupPhase"];
            nativeBuildInputs =
              [
                stdenv.cc.cc
              ]
              ++ (
                if !stdenv.isDarwin
                then [autoPatchelfHook]
                else []
              );

            installPhase = ''
              mkdir -p $out/bin
              install -m755 $src $out/bin/khulnasoft-lsp
            '';
          };
          vimPlugins.khulnasoft-nvim = vimUtils.buildVimPlugin {
            pname = "khulnasoft";
            version = "v${versions.version}-main";
            src = ./.;
            buildPhase = ''
              cat << EOF > lua/khulnasoft/installation_defaults.lua
              return {
                tools = {
                  language_server = "${packages.khulnasoft-lsp}/bin/khulnasoft-lsp"
                };
              };
              EOF
            '';
          };
          nvimWithKhulnasoft = neovim.override {
            configure = {
              customRC = ''
                lua require("khulnasoft").setup()
              '';
              packages.myPlugins = {
                start = [packages.vimPlugins.khulnasoft-nvim vimPlugins.plenary-nvim vimPlugins.nvim-cmp];
              };
            };
          };
        };

        overlays.default = self: super: {
          vimPlugins =
            super.vimPlugins
            // {
              khulnasoft-nvim = packages.vimPlugins.khulnasoft-nvim;
            };
        };

        apps.default = {
          type = "app";
          program = "${packages.nvimWithKhulnasoft}/bin/nvim";
        };

        devShell = pkgs.mkShell {
          packages = [];
        };
      }
    );
}
