{ compiler ? "ghc865" }:

let
  overlayShared = pkgsNew: pkgsOld: {
    libtorch_cpu =
      let src = pkgsOld.fetchFromGitHub {
          owner  = "stites";
          repo   = "libtorch-nix";
          rev    = "6b02c3746f6557ceee5d742625b6e04f3559e2a7";
          sha256 = "0nc2la37a2rnssgf36s4gvwq5vz6l3p6sqsck7kasaprr42sfxpb";
        };
      in
      (import "${src}/release.nix" { }).libtorch_cpu;
    haskell = pkgsOld.haskell // {
      packages = pkgsOld.haskell.packages // {
        "${compiler}" = pkgsOld.haskell.packages."${compiler}".override (old: {
            overrides =
              let
                failOnAllWarnings = pkgsOld.haskell.lib.failOnAllWarnings;

                extension =
                  haskellPackagesNew: haskellPackagesOld: {
                    hasktorch-codegen =
                      failOnAllWarnings
                        (haskellPackagesNew.callCabal2nix
                          "codegen"
                          ../codegen
                          { }
                        );
                    hasktorch-ffi =
                      # failOnAllWarnings
                        (haskellPackagesNew.callCabal2nix
                          "ffi"
                          ../ffi
                          { }
                        );
                    hasktorch =
                      # failOnAllWarnings
                        (haskellPackagesNew.callCabal2nix
                          "hasktorch"
                          ../hasktorch
                          { }
                        );
                    inline-c =
                      failOnAllWarnings
                        (haskellPackagesNew.callCabal2nix
                          "inline-c"
                          ../inline-c/inline-c
                          { }
                        );
                    inline-c-cpp =
                      failOnAllWarnings
                        (haskellPackagesNew.callCabal2nix
                          "inline-c-cpp"
                          ../inline-c/inline-c-cpp
                          { }
                        );
                  };

              in
                pkgsNew.lib.fold
                  pkgsNew.lib.composeExtensions
                  (old.overrides or (_: _: {}))
                  [ (pkgsNew.haskell.lib.packagesFromDirectory { directory = ./.; })

                    extension
                  ];
          }
        );
      };
    };
  };

  bootstrap = import <nixpkgs> { };

  nixpkgs = builtins.fromJSON (builtins.readFile ./nixpkgs.json);

  src = bootstrap.fetchFromGitHub {
    owner = "NixOS";
    repo  = "nixpkgs";
    inherit (nixpkgs) rev sha256;
  };

  pkgs = import src {
    config = {};
    overlays = [ overlayShared ];
  };

in
  rec {
    inherit (pkgs.haskell.packages."${compiler}")
      hasktorch-codegen
      hasktorch-ffi
      hasktorch
      inline-c
      inline-c-cpp
    ;

    shell-hasktorch-codegen = (pkgs.haskell.lib.doBenchmark pkgs.haskell.packages."${compiler}".hasktorch-codegen).env;
    shell-hasktorch-ffi = (pkgs.haskell.lib.doBenchmark pkgs.haskell.packages."${compiler}".hasktorch-ffi).env;
    shell-hasktorch = (pkgs.haskell.lib.doBenchmark pkgs.haskell.packages."${compiler}".hasktorch).env;
    shell-inline-c = (pkgs.haskell.lib.doBenchmark pkgs.haskell.packages."${compiler}".inline-c).env;
    shell-inline-c-cpp = (pkgs.haskell.lib.doBenchmark pkgs.haskell.packages."${compiler}".inline-c-cpp).env;
  }
