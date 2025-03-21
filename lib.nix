{
  pkgs,
  lib ? pkgs.lib,
}:

rec {
  pow = lib.fix (
    self: base: power:
      if power != 0
      then base * (self base (power - 1))
      else 1
  );

  bitmask = bits: lib.foldl (l: r: l+r) 0 (lib.genList (x: pow 2 (32 - x - 1)) bits);

  ipTohex = ipAddress: (lib.concatStrings (map (byte:
          lib.pipe byte [
            (x: lib.toHexString (lib.toInt x))
            (x: if lib.stringLength x < 2 then "0"+x else x)
          ]
          ) (lib.splitString "." ipAddress)));

  hexToip = ipAddress:
    let
      match = "[0-9A-Fa-f]{2}";
    in
      lib.pipe ipAddress [
        (x: if lib.stringLength x < 8 then "0" + x else x)
        (lib.split "(${match})(${match})(${match})(${match})")
        (lib.filter lib.isList)
        lib.flatten
        (map (x: toString (lib.fromHexString x)))
        (lib.concatStringsSep ".")
      ];

  # Generate an IPv4 address from a subnet and an host address index
  genAddress = subnet: index:
    lib.pipe subnet
    [
      ipTohex
      lib.fromHexString
      (x: x + index)
      lib.toHexString
      hexToip
    ];

  # Generate a DNS zone file
  genZoneFile = {
    zone,
    records,
    domainMeta ? [{ type = "NS"; value = primaryMaster; }],
    primaryMaster ?  "ns.${lib.concatStringsSep "." zone}",
    serial ? 1,
    ttl ? 604800,
    refresh ? 604800,
    retry ? 86400,
    expire ? 2419200,
    negativeCacheTTL ? 604800,
    } :
    let
      zoneStr = lib.concatStringsSep "." zone;
    in pkgs.writeText "zone"
      (''
        $ORIGIN ${zoneStr}.
        $TTL    ${toString ttl}
        @       IN      SOA     ${primaryMaster}. hostmaster.${zoneStr}. (
               ${toString serial}
               ${toString refresh}
               ${toString retry}
               ${toString expire}
               ${toString negativeCacheTTL}
        )
      '' +
      (lib.pipe domainMeta [
        (lib.map (x: "IN ${x.type} ${x.value}"))
        (lib.concatStringsSep "\n")
      ]) + "\n" +
      (lib.pipe records [
        (lib.getAttrFromPath zone)
        (lib.mapAttrsToList (name: r:
          (lib.mapAttrsToList (type: value: "${name} IN ${type} ${value}" ) r)
        ))
        lib.flatten
        (lib.concatStringsSep "\n")
      ]));
}
