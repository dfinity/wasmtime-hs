{
  description = "wasmtime-hs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-23.05";
    flake-utils.url = "github:numtide/flake-utils";
    wasmtime = {
      url = "github:bytecodealliance/wasmtime/v9.0.2";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, wasmtime }:
    flake-utils.lib.eachSystem [ "aarch64-darwin" "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };

        haskellPackages = pkgs.haskellPackages;

        # TODO: filter source to only include files added to git and strip flake.* files.
        src = ./.;
        wasmtime-hs = haskellPackages.callCabal2nix "wasmtime" src { };

        # Builds one of the C examples from $wasmtime/examples.
        c_example = name: pkgs.runCommandCC name
          {
            inherit name wasmtime;
            buildInputs = [ pkgs.wasmtime.dev ];
          } ''
          cc $wasmtime/examples/$name.c -lwasmtime -o $out
        '';

        # Runs one of the C $wasmtime/examples.
        check_c_example = name: pkgs.runCommand (name + "-check")
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
        packages.wasmtime = pkgs.wasmtime.dev;

        # We build and run each C example from wasmtime
        # so we can compare them to the Haskell equivalents. Run them using:
        #
        #   nix build --print-out-paths --no-link --rebuild -L .#hello-c
        packages.hello-c = check_c_example "hello";
        packages.gcd-c = check_c_example "gcd";

        # The default development shell brings in all dependencies of
        # wasmtime-hs (like all Haskell dependencies, libwasmtime, GHC).
        # Additionally we bring in cabal and HLS so VS Code works out of the
        # box.
        devShells.default = haskellPackages.shellFor {
          packages = _: [ wasmtime-hs ];
          nativeBuildInputs = [
            pkgs.cabal-install
            haskellPackages.haskell-language-server
          ];
        };
        # so that we can format .nix code using: nix fmt
        formatter = pkgs.nixpkgs-fmt;
      }
    );
}
