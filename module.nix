{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.services.radicle.update) instances;

  RAD_HOME = "/var/lib/radicle";

  mkSystemdServices = name: cfg: {
    "radicle-update-${name}" = {
      inherit (cfg) enable;

      bindsTo = [ "radicle-node.service" ];
      after = [ "radicle-node.service" ];

      environment = {
        inherit RAD_HOME;
        HOME = "/run/radicle-update/${name}";
      };

      startAt = cfg.schedule;

      serviceConfig = {
        User = config.users.users.radicle.name;
        Group = config.users.groups.radicle.name;

        RuntimeDirectory = "radicle-update/${name}";
        WorkingDirectory = "/run/radicle-update/${name}";

        BindReadOnlyPaths = config.systemd.services.radicle-node.serviceConfig.BindReadOnlyPaths;
        ReadWritePaths = [ RAD_HOME ];
      };

      path = [
        config.services.radicle.package
        config.nix.package
        pkgs.gitMinimal
        pkgs.coreutils
      ];

      script = ''
        rad clone ${cfg.rid} repo
        cd repo
        alias=$(rad self --alias)
        nid=$(rad self --did | cut -d: -f3)
        git config user.name "$alias"
        git config user.email "$alias@$nid"
        ${cfg.script}
      '';
    };
  };
in

{
  options.services.radicle.update = {
    instances = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            enable = lib.mkEnableOption "this radicle-update instance" // {
              default = true;
              example = false;
            };

            rid = lib.mkOption {
              type = lib.types.strMatching "rad:z[a-zA-Z0-9]{27,28}";
              description = ''
                Id of the repository to update.
                The local radicle-node must be seeding this repository.
              '';
              example = "rad:z3gqcJUoA1n9HaHKufZs5FCSGazv5";
            };

            schedule = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "How often to run. See {manpage}`systemd.time(7)` for the format.";
              example = "weekly";
            };

            script = lib.mkOption {
              type = lib.types.lines;
              description = "The script to run.";
              default = ''
                nix run .#update-deps
              '';
            };
          };
        }
      );
      description = "radicle-update instances";
      default = { };
    };
  };

  config = lib.mkIf (instances != { }) {
    assertions = [
      {
        assertion = config.services.radicle.enable;
        message = "radicle-update requires a local radicle node to be running.";
      }
    ];

    systemd.services = lib.mkMerge (lib.mapAttrsToList mkSystemdServices instances);
  };
}
