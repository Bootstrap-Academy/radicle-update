{
  outputs =
    { ... }:
    {
      lib =
        let
          makeNuBinPath = pkgs: builtins.toJSON (map (pkg: "${pkg.bin or pkg.out or pkg}/bin") pkgs);
          extNuPath = packages: ''
            use std "path add"
            path add ${makeNuBinPath packages}
          '';

          withPath =
            file: f:
            { pkgs, writers, ... }:
            writers.writeNu (builtins.baseNameOf file) ''
              ${extNuPath (f pkgs)}
              ${builtins.readFile file}
            '';
        in

        {
          inherit makeNuBinPath extNuPath;

          rad-update = ./rad-update.nu;
          updaters = {
            cargo = withPath ./updaters/cargo.nu (pkgs: [
              pkgs.cargo
              pkgs.cargo-edit
            ]);
            nix-flake = ./updaters/nix-flake.nu;
          };
        };

      nixosModules.default = ./module.nix;
    };
}
