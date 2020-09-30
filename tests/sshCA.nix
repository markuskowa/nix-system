{ ... } :

#
# Test the procedure for deploying ssh CA signed keys
# to ensure we do not lock ourselves out.
#
{
  name = "sshCA";

  nodes = {
    server = { ... } : {
      environment.etc = {
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

      services.openssh.enable = true;
    };

    node = { ... } : {
      services.openssh = {
        enable = true;
        extraConfig = ''
          HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub
          HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
        '';
      };

      users.users = {
        root.openssh.authorizedKeys.keys = [
            (builtins.readFile ./testkeys/dummy-ssh.pub)
          ];
      };
    };
  };

  testScript = ''
    node.wait_for_unit("sshd.service")
    server.wait_for_unit("multi-user.target")
    server.succeed('ssh-keygen -t rsa -N "" -f ca_host_key -I CA')
    server.succeed(
        "scp -i /etc/dummy-ssh-r -o 'StrictHostKeyChecking no' node:/etc/ssh/ssh_host_ed25519_key.pub ."
    )
    server.succeed("ssh-keygen -s ca_host_key -h -I node ssh_host_ed25519_key.pub")
    server.succeed(
        "scp -i /etc/dummy-ssh-r -o 'StrictHostKeyChecking no' ssh_host_ed25519_key-cert.pub node:/etc/ssh/ "
    )

    # Should fail without trusting the host
    # $server.fail("rm ~/.ssh/known_hosts; ssh -n -i /etc/dummy-ssh-r node true")

    # Now trust the CA
    server.succeed('echo "@cert-authority * `cat ca_host_key.pub`" > ~/.ssh/known_hosts')
    server.succeed("ssh -i /etc/dummy-ssh-r node true")
  '';
}
