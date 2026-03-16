{
  outputs =
    { self }:
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

          sourceUpdater =
            pkgs: updater:
            if builtins.isFunction self.lib.updaters.${updater} then
              "source ${self.lib.updaters.${updater} pkgs}"
            else
              "source ${self.lib.updaters.${updater}}";
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

          mkUpdater =
            {
              name ? "update-deps",
              pkgs,
              updaters,
            }:
            pkgs.writers.writeNuBin name # nu
              ''
                source ${self.lib.rad-update}
                ${pkgs.lib.concatMapStringsSep "\n" (sourceUpdater pkgs) updaters}

                def main [
                  --no-patch,
                ] {
                  rad update --no-patch=$no_patch {
                    ${pkgs.lib.concatMapStringsSep "\n    " (x: "rad update ${x}") updaters}
                  }
                }
              '';
        };

      nixosModules.default = ./module.nix;
    };
}
