{
  description = "wasmtime-hs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "aarch64-darwin" "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system overlays; };

        overlays = [
          (self: super: {
            # To use c-api, build by cmake is also required.
            # [wasmtime/crates/c-api at main · bytecodealliance/wasmtime](https://github.com/bytecodealliance/wasmtime/tree/b981b08c3c1c13276df9b3c0dc2cdae1de750572/crates/c-api)
            wasmtime = super.wasmtime.overrideAttrs (oldAttrs: {
              postInstall = ''
                ${oldAttrs.postInstall or ""}
                cmake -S crates/c-api -B target/c-api --install-prefix "$(pwd)/artifacts"
                cmake --build target/c-api
                cmake --install target/c-api
                install -m0644 $(pwd)/artifacts/include/wasmtime/conf.h $dev/include/wasmtime
              '';
            });
          })
        ];

        wasmtime = pkgs.wasmtime;

        haskellPackages = pkgs.haskellPackages;

        # TODO: filter source to only include files added to git and strip flake.* files.
        src = ./.;
        wasmtime-hs = haskellPackages.callCabal2nix "wasmtime-hs" src { };

        # Builds one of the C examples from $wasmtime/examples.
        c_example = name:
          pkgs.runCommandCC name
            {
              inherit name wasmtime;
              buildInputs = [ wasmtime.dev ];
            } ''
            cc $wasmtime/examples/$name.c -lwasmtime -o $out
          '';

        # Runs one of the C $wasmtime/examples.
        check_c_example = name:
          pkgs.runCommand (name + "-check")
            {
              inherit wasmtime;
              example = c_example name;
            } ''
            cd $wasmtime
            $example | tee $out
          '';
      in
      {
        # By default we build the wasmtime-hs package.
        packages.default = wasmtime-hs;

        # We also export libwasmtime so we can quickly inspect it from the CLI.
        packages.wasmtime = wasmtime.dev;

        # We build and run each C example from wasmtime
        # so we can compare them to the Haskell equivalents. Run them using:
        #
        #   nix build --print-out-paths --no-link --rebuild -L .#hello-c
        packages.hello-c = check_c_example "hello";
        packages.gcd-c = check_c_example "gcd";
        packages.memory-c = check_c_example "memory";
        packages.fuel-c = check_c_example "fuel";

        # The default development shell brings in all dependencies of
        # wasmtime-hs (like all Haskell dependencies, libwasmtime, GHC).
        # Additionally we bring in cabal and HLS so VS Code works out of the
        # box.
        devShells.default = haskellPackages.shellFor {
          packages = _: [ wasmtime-hs ];
          nativeBuildInputs =
            [ pkgs.cabal-install haskellPackages.haskell-language-server ];
        };
        # so that we can format .nix code using: nix fmt
        formatter = pkgs.nixpkgs-fmt;
      });
}
