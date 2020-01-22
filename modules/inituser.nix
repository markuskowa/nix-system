{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.users.setupEnv;


in {
  options = {
    users.setupEnv = {
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
        description = ''
          List of additional per-user directories.
          A sub directory with the users name is created at these paths
          if it does not already exist.
        '';
        default = [];
        type = types.listOf (types.submodule ({ prefix , node, ...} : {
          options = {
            dir = mkOption {
              type = types.str;
              default = null;
              description = "Absolute path.";
            };
            mode = mkOption {
              type = types.strMatching "[0-7]{3}[0-7]*";
              default = "0700";
              description = "Access mode (octal). Is enforced";
            };
          };
        }));
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

  config = mkIf cfg.enable {
    # setup extra dirs
    systemd.tmpfiles.rules =
      flatten (
        map ( dir:
          map (user:
            "v ${dir.dir}/${user.name} ${dir.mode} ${user.name} ${user.group} "
          ) ( lib.filter (u: u.isNormalUser)
            ( mapAttrsToList (name: value: value) config.users.users ))
        ) cfg.extraUserDirs
      );


    # User environment setup is checked on login
    environment.loginShellInit = mkIf (cfg.createSshKey ||
                                       cfg.sshKeySelfAuthorized ||
                                      ( stringLength cfg.configNix > 0 )) (
    ''
      if [ `id -u` != 0 ]; then
    '' +  optionalString cfg.createSshKey ''
      dir=$HOME/.ssh
      if [ ! -d $dir ]; then
        mkdir -p -m700 $dir
      fi
      if [ ! -f $dir/id_rsa ]; then
        echo "Creating SSH keypair..."
        ${pkgs.openssh}/bin/ssh-keygen  -f $dir/id_rsa -N ""
      fi
    '' + optionalString (cfg.sshKeySelfAuthorized && cfg.sshKeySelfAuthorized )''
      dir=$HOME/.ssh
      if [ ! -f $dir/authorized_keys ]; then
        echo "Creating authorized_keys..."
        cat $dir/id_rsa.pub >> $dir/authorized_keys
      else
        grep "`cat $dir/id_rsa.pub`" $dir/authorized_keys > /dev/null
        if  [ $? != 0 ]; then
          echo "Adding id_rsa.pub to authorized_keys..."
          cat $dir/id_rsa.pub >> $dir/authorized_keys
        fi
      fi
    '' + optionalString (stringLength cfg.configNix > 0) ''
      dir=$HOME/.nixpkgs
      if [ ! -f $dir/config.nix ]; then
        mkdir -p -m750 $dir
        echo "${cfg.configNix}" > $dir/config.nix
      fi
    '' + ''
      #touch $HOME/.initialized
      fi
    '');

  };
}
