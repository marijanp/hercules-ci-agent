{ haskellPackages
, haskell
, pkgs
, nix
, pre-commit-hooks-nix
, ...
}:
let
  haskellPackages_ = haskellPackages;
  inherit (pkgs) recurseIntoAttrs lib;
  inherit (pkgs.lib) cleanSource makeBinPath optionalAttrs;
  inherit (haskell.lib) overrideSrc addBuildDepends overrideCabal buildFromSdist doJailbreak disableLibraryProfiling addBuildTool;
  callPkg = super: name: srcPath: args: overrideSrc (super.callCabal2nix name srcPath args) { src = srcPath; };

  internal =
    rec {
      inherit pkgs;

      # TODO: upstream the overrides
      haskellPackages =
        haskellPackages_.extend (
          self: super:
            {
              cachix =
                # avoid https://gitlab.haskell.org/ghc/ghc/issues/16477
                haskell.lib.disableLibraryProfiling (
                  self.callPackage ./cachix.nix { }
                );
              cachix-api = self.callPackage ./cachix-api.nix { };
              nix-narinfo = self.callPackage ./nix-narinfo.nix { };

              hercules-ci-api = callPkg super "hercules-ci-api" ../hercules-ci-api { };
              hercules-ci-api-agent = callPkg super "hercules-ci-api-agent" ../hercules-ci-api-agent { };
              hercules-ci-api-core = callPkg super "hercules-ci-api-core" ../hercules-ci-api-core { };

              hercules-ci-agent =
                let
                  basePkg =
                    callPkg super "hercules-ci-agent" ../hercules-ci-agent {
                      bdw-gc = pkgs.boehmgc-hercules;
                    };
                  bundledBins = [ pkgs.gnutar pkgs.gzip pkgs.git nix ] ++ lib.optional (pkgs.stdenv.isLinux) pkgs.runc;

                in
                buildFromSdist (
                  overrideCabal
                    (
                      addBuildDepends basePkg [ pkgs.makeWrapper pkgs.boost pkgs.boehmgc ]
                    )
                    (
                      o:
                      {
                        postInstall =
                          o.postInstall or ""
                          + ''
                            wrapProgram $out/bin/hercules-ci-agent --prefix PATH : ${makeBinPath bundledBins}
                          ''
                        ;
                        passthru =
                          (o.passthru or { })
                          // {
                            inherit nix;
                          }
                        ;

                        # TODO: We had an issue where any overrideCabal would have
                        #       no effect on the package, so we inline the
                        #       definition of justStaticExecutables here.
                        #       Ideally, we'd go back to a call to
                        #       justStaticExecutables, or even better,
                        #       a separate bin output.
                        #
                        # begin justStaticExecutables
                        enableSharedExecutables = false;
                        enableLibraryProfiling = false;
                        isLibrary = false;
                        doHaddock = false;
                        postFixup =
                          "rm -rf $out/lib $out/nix-support $out/share/doc";
                        # end justStaticExecutables
                      }
                    )
                );

              hercules-ci-agent-test =
                callPkg super "hercules-ci-agent-test" ../tests/agent-test { };

              hercules-ci-cli = callPkg super "hercules-ci-cli" ../hercules-ci-cli { };

              inline-c = self.callPackage ./haskell-inline-c.nix { };

              # avoid https://gitlab.haskell.org/ghc/ghc/issues/16477
              inline-c-cpp = overrideCabal (haskell.lib.disableLibraryProfiling (self.callPackage ./haskell-inline-c-cpp.nix { }))
                (
                  o: {
                    preConfigure = ''
                      substituteInPlace inline-c-cpp.cabal --replace " c++ " stdc++ 
                    '';
                  }
                );

              websockets = self.callPackage ./websockets.nix { };

              servant-websockets = self.callPackage ./servant-websockets.nix { };

            }
        );

      hercules-ci-api-swagger =
        pkgs.callPackage ../hercules-ci-api/swagger.nix { inherit (haskellPackages) hercules-ci-api; };

      tests =
        recurseIntoAttrs {
          agent-functional-test = pkgs.nixosTest ../tests/agent-test.nix;
        };

      projectRootSource = ../.;
    };
in
recurseIntoAttrs {
  inherit (internal.haskellPackages) hercules-ci-agent hercules-ci-cli;
  inherit (internal) hercules-ci-api-swagger;
  # isx86_64: Don't run the VM tests on aarch64 to save time
  tests = if pkgs.stdenv.isLinux && pkgs.stdenv.isx86_64 then internal.tests else null;
  pre-commit-check =
    (import (pre-commit-hooks-nix + "/nix") { inherit (pkgs) system; }).packages.run {
      src = ../.;
      tools = {
        inherit (pkgs) ormolu;
      };
      hooks = {
        # TODO: hlint.enable = true;
        ormolu.enable = true;
        ormolu.excludes = [
          # CPP
          "Hercules/Agent/Compat.hs"
          "Hercules/Agent/StoreFFI.hs"
        ];
        shellcheck.enable = true;
        nixpkgs-fmt.enable = true;
        nixpkgs-fmt.excludes = [ "tests/agent-test/testdata/" ];
      };
      settings.ormolu.defaultExtensions = [ "TypeApplications" ];
    };

  # Not traversed for derivations:
  inherit internal;
}
