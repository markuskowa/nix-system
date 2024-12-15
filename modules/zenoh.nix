{ lib, config, pkgs, ... } :

let
  inherit (lib)
    types
    mkDefault
    mkOption;

  json = pkgs.formats.json {};

  cfg = config.services.zenoh;

in
{
  options = {
    services.zenoh = {
      enable = lib.mkEnableOption "Zenoh daemon";

      package = mkOption {
        type = types.package;
        default = pkgs.zenoh;
      };

      settings = mkOption {
        description = "Config options for `zenoh.json5` configuration file";
        default = {};
        type = types.submodule {
          freeformType = json.type;
        };
      };

      plugins = mkOption {
        description = "Plugin packages to add to zenohd search paths";
        type = with types; listOf package;
        default = [];
      };

      backends = mkOption {
        description = "Storage backend packages to add to zenohd search paths";
        type = with types; listOf package;
        default = [];
      };

      env = mkOption {
        description = ''
          Set environment variables consumed by zenohd and its plugins,
          such as ZENOH_HOME.
        '';
        type = with types; attrsOf str;
        default = {};
      };

      extraOptions = mkOption {
        description = "Extra command line options for zenohd";
        type = with types; listOf str;
        default = [];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.zenohd = let
      cfgFile = json.generate "zenohd.json" cfg.settings;

    in {
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      environment = cfg.env;

      serviceConfig = {
        type = "simple";
        ExecStart = "${lib.getExe cfg.package} -c ${cfgFile} "
          + (lib.concatStringsSep " " cfg.extraOptions);
      };
    };

    services.zenoh.settings = {
      plugins_loading = {
        enabled = mkDefault true;
        search_dirs = mkDefault ((map (x: "${lib.getLib x}/lib") cfg.plugins)
          ++ [ "${lib.getLib cfg.package}/lib" ]); # needed for internal plugins
      };

      plugins.storage_manager.backend_search_dirs = mkDefault (map (x: "${lib.getLib x}/lib") cfg.backends);
    };
  };
}
