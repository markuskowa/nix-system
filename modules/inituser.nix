{ config, lib, utils, pkgs, ... }:

with lib;

let
  cfg = config.users;

  script = user :
    ( concatMapStringsSep "" (dir: ''
      dir=${dir}/${user.name}
      if [ ! -d $dir ]; then
        mkdir -p -m750 $dir
        chown ${user.name}:${user.group} $dir
      fi
    '') cfg.clusterSetupEnv.extraUserDirs )
  + optionalString (stringLength cfg.clusterSetupEnv.configNix != 0)
  ''
    dir=${user.home}/.nixpkgs
    if [ ! -f $dir/config.nix ]; then
      mkdir -p -m750 $dir
      echo "${cfg.clusterSetupEnv.configNix}" > $dir/config.nix
      chown -R ${user.name}:${user.group} $dir
    fi
  ''
  + optionalString cfg.clusterSetupEnv.createSshKey
  ''
    dir=${user.home}/.ssh
    if [ ! -d $dir ]; then
      mkdir -p -m700 $dir
      chown -R ${user.name}:${user.group} $dir
    fi
    if [ ! -f $dir/id_rsa ]; then
      ${pkgs.openssh}/bin/ssh-keygen -C "cluster key (${user.name})" -f $dir/id_rsa -N ""
      chown ${user.name}:${user.group} $dir/id_rsa*
    fi
  ''
  + optionalString cfg.clusterSetupEnv.sshKeySelfAuthorized ''
    dir=${user.home}/.ssh
    if [ ! -f $dir/authorized_keys ]; then
      cat $dir/id_rsa.pub >> $dir/authorized_keys
      chown ${user.name}:${user.group} $dir/authorized_keys
    else
      grep "`cat $dir/id_rsa.pub`" $dir/authorized_keys >/dev/null;
      if  [ ! $? ]; then
        cat $dir/id_rsa.pub >> $dir/authorized_keys
      fi
    fi
  '';

in {
  options = {
    users.clusterSetupEnv = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Create scratch directories and default files in home.
        '';
      };
      configNix = mkOption {
        type = types.str;
        default = "";
        description = ''
          The content of the initial config.nix that is placed in the home directory.
        '';
      };
      extraUserDirs = mkOption {
        type = with types; listOf str;
        default = [];
        description = ''
          List of additional per-user directories.
          A sub directory with the users name is created at these paths
          if it does not already exist.
        '';
      };
      createSshKey = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Create a ssh key pair if does not already exists.
        '';
      };
      sshKeySelfAuthorized = mkOption {
        type = types.bool;
        default = false;
        description = ''
          If createSshKey is selected, add the public key to the authorized_keys file in home
        '';
      };
    };
  };

  config = {
    system.activationScripts.clusterSetupEnv = mkIf cfg.clusterSetupEnv.enable ( stringAfter [ "users" "groups" ] (
       with lib;
         foldr (user: str: str + (optionalString user.isNormalUser (script user) ))
               "" (mapAttrsToList (n: v: v) cfg.users)
    ));
  };
}
