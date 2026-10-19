{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.ifupdown2;

  format = pkgs.formats.keyValue {
    mkKeyValue = lib.generators.mkKeyValueDefault { } " = ";
  };

  multiValueType = with lib.types; nullOr (coercedTo str lib.singleton (listOf str));

  inherit (lib)
    attrsToList
    mkEnableOption
    mkOption
    mkDefault
    types
    escapeShellArgs
  ;
in
{
  options.services.ifupdown2 = {
    enable = mkEnableOption "ifupdown2";

    package = mkOption {
      type = types.package;
      default = pkgs.ifupdown2;
      defaultText = lib.literalExpression "pkgs.ifupdown2";
      description = ''
        The package to use for `ifupdown2`.
      '';
    };

    debug = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    extraArgs = mkOption {
      type = with types; listOf str;
      default = [ ];
      example = [
        "--timeout"
        "60"
      ];
      description = ''
        Additional arguments to pass to `ifupdown2`. See {manpage}`ifupdown(8)`
        for additional details.
      '';
    };

    settings = mkOption {
      type = format.type;
      default = { };
      description = ''
        `ifupdown2` configuration. See {manpage}`ifupdown2.conf(5)`
        for additional details.
      '';
    };

    auto = mkOption {
      type = with types; listOf str;
      default = [ ];
      example = [
        "eth0"
        "br0"
      ];
      description = ''
        Designates interfaces that should be automatically configured by the system when appropriate.
      '';
    };

    iface = mkOption {
      type = types.attrsOf (lib.types.submodule {
        # freeformType allows any arbitrary keys/values inside each interface block
        freeformType = types.attrsOf types.unspecified;
      });
      default = { };
      description = "Interface-specific configurations.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          (lib.length (lib.attrsToList (lib.intersectAttrs config.networking.interfaces cfg.iface))) == 0;
        message = "Interface configured via ifupdown2 cannot be configured via scripted networking";
      }
      {
        assertion =
          (lib.length (lib.attrsToList (lib.intersectAttrs config.networking.bridges cfg.iface))) == 0;
        message = "Bridges configured via ifupdown2 cannot be configured via scripted networking";
      }
    ];

    # ifreload requires the vrf tables
    networking.iproute2.enable = true;

    services.ifupdown2.extraArgs = [ "-a" "-L" "/run/ifupdown2/network.lock" ] ++ lib.optionals cfg.debug [ "-v" ];
    services.ifupdown2.auto = mkDefault (map (x: x.name) (attrsToList cfg.iface));

    environment.systemPackages = [ cfg.package ];
    nixpkgs.overlays = [ (import ../default.nix) ];

    environment.etc."network/ifupdown2.conf".source = format.generate "ifupdown2.conf" cfg.settings;
    environment.etc."network/interfaces".text =
      let
        # prepare attrs for toKeyValue generation:
        # - filter out null values and false bools
        # - convert true bools to "" (key only, no value)
        # - join space-separated keys into single string (except for address)
        prepareAttrs =
          attrs:
          lib.mapAttrs (
            k: v:
            if (v == true) then
              "on"
            else if (v == false) then
              "off"
            else if k != "address" && lib.isList v then
              lib.concatStringsSep " " (map (x: toString x) v)
            else if !lib.isList v then
              toString v
            else v
          ) (lib.filterAttrs (k: v: v != null) attrs);

        toKeyValue' = lib.generators.toKeyValue {
          mkKeyValue = k: v: if v == "" then "  ${k}" else "  ${k} ${v}";
          listsAsDuplicateKeys = true;
        };

        autoSection = lib.concatMapStringsSep "\n" (name: "auto ${name}") cfg.auto;
        ifaceBlocks = lib.mapAttrsToList (
          name: iface: "iface ${name}\n${lib.removeSuffix "\n" (toKeyValue' (prepareAttrs iface))}"
        ) cfg.iface;
      in
      lib.concatStringsSep "\n\n" (lib.optional (cfg.auto != [ ]) autoSection ++ ifaceBlocks);

    systemd.services.ifupdown2 = {
      wantedBy = [ "network.target" ];
      partOf = [ "network.target" ];

      serviceConfig = {
        RuntimeDirectory = "ifupdown2";
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStart = "${lib.getExe' cfg.package "ifup"} " + escapeShellArgs cfg.extraArgs;
        ExecReload = "${lib.getExe' cfg.package "ifreload"} " + escapeShellArgs cfg.extraArgs;
        ExecStop = "${lib.getExe' cfg.package "ifdown"} ${escapeShellArgs cfg.extraArgs}";
      };
    };

  };
}
