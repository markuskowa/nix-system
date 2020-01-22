{ pkgs, ... } :
{
  name = "userInit";

  nodes = {
    server = { ... } :
    {
      imports = [ ../modules/overlay.nix ];

      services.openssh = {
        enable = true;
      };

      users.setupEnv = {
        enable = true;
        extraUserDirs = [ { dir="/extra"; mode="750"; } ];
        createSshKey = true;
        sshKeySelfAuthorized = true;
      };

      users.users = {
        test = {
          isNormalUser = true;
          openssh.authorizedKeys.keys = [
            (builtins.readFile ./testkeys/dummy-ssh.pub)
          ];
        };
      };


    };

    #client = { ... } :
    #{
    #  users.users.test.isNormalUser = true;
    #};
  };


  testScript = ''

    $server->waitForUnit("sshd");

    # Check for extra dir
    $server->succeed("stat -c %a /extra/test | grep 750");
    $server->succeed("stat -c %U /extra/test | grep test");

    my $key=`${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f key -N ""`;

    # Deploy key
    $server->succeed("mkdir -p -m 0700 /home/test/.ssh");
    $server->copyFileFromHost("key.pub", "/home/test/.ssh/authorized_keys");
    $server->succeed("chown -R test /home/test/");

    # Initate create of SSH setup
    $server->succeed("sudo -i -u test stat /home/test/.ssh/id_rsa");

    # Make sure self ssh login works now
    $server->succeed("sudo -u test ssh -o 'StrictHostKeyChecking no' -t server true");

  '';
}

