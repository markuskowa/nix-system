{ pkgs, lib } :

with lib;

{
  listSep ? " "
, trueVal ? "true"
, falseVal ? "false"
, allowedTypes ? with types; [ bool int float str ]
} :

let
  valueToString = val:
    if isList val then concatStringsSep listSep (map (x: valueToString x) val)
    else if isBool val then (if val then trueVal else falseVal)
    else toString val;

in {
  type = with types; let
    valueType = oneOf ([
      (listOf valueType)
    ] ++ allowedTypes) // {
      description = "Flat key-value file";
    };
  in attrsOf valueType;

  generate = name: value:
    pkgs.writeText name ( lib.concatStringsSep "\n" (
      lib.mapAttrsToList (key: val: "${key} = ${valueToString val}") value ));
}
