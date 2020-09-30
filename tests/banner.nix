{ ... } :
{
  name = "ssh-banner";

  nodes = {
    server = { ... } :
    {
      imports = [ ../modules/overlay.nix ];


      environment.loginBanner.enable = true;

      services.openssh = {
        enable = true;
      };

      users.users = {
        root.openssh.authorizedKeys.keys = [
            (builtins.readFile ./testkeys/dummy-ssh.pub)
        ];

        testUser = {
          isNormalUser = true;
          openssh.authorizedKeys.keys = [
            (builtins.readFile ./testkeys/dummy-ssh.pub)
          ];
        };
      };

    };

    client = { ... } :
    {
      users.users.testUser = {};

      environment.etc ={
        dummy-ssh-u = {
          mode = "0400";
          user = "testUser";
          text = builtins.readFile ./testkeys/dummy-ssh;
        };

        dummy-ssh-r = {
          mode = "0400";
          user = "root";
          text = builtins.readFile ./testkeys/dummy-ssh;
        };
      };
    };
  };


  testScript = ''
    server.wait_for_unit("sshd")
    client.wait_for_unit("multi-user.target")

    # Dump login screen to log
    client.succeed(
        "sudo -u testUser ssh -i /etc/dummy-ssh-u -o 'StrictHostKeyChecking no' -t server true 1>&2"
    )

    # Check for banner
    client.succeed(
        "sudo -u testUser ssh -i /etc/dummy-ssh-u -o 'StrictHostKeyChecking no' -t server true | grep NixOS"
    )

    # Ensure no banner is plotted when no terminal is allocated
    client.succeed(
        "sudo -u testUser ssh -i /etc/dummy-ssh-u -o 'StrictHostKeyChecking no' server true | wc -l | grep '^0'"
    )

    # Ensure no banner is plotted for root whatsoever
    client.succeed(
        "ssh -i /etc/dummy-ssh-r -o 'StrictHostKeyChecking no' -t server true | wc -l | grep '^0'"
    )
  '';
}

