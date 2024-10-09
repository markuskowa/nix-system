{ ... } :

#
# Test the procedure for deploying ssh CA signed keys
# to ensure we do not lock ourselves out.
#
  {
    name = "sshCA";

    nodes = {
      server = { ... } : {
        services.openssh = {
          enable = true;
          extraConfig = ''
            HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub
            HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub

            TrustedUserCAKeys /tmp/shared/ca_host_key.pub
          '';
        };
      };

      client = { ... } : {
        services.openssh = {
          enable = true;
        };
      };
    };

    testScript = ''
      shared_dir = "/tmp/shared"

      start_all()
      client.wait_for_unit("multi-user.target")
      server.wait_for_unit("multi-user.target")

      # Generate CA certificate
      server.succeed("ssh-keygen -t rsa -N \"\" -f {}/ca_host_key -I CA".format(shared_dir))

      # Sign host keys
      server.succeed("ssh-keygen -s {}/ca_host_key -h -I server /etc/ssh/ssh_host_ed25519_key.pub".format(shared_dir))
      server.succeed("ssh-keygen -s {}/ca_host_key -h -I server /etc/ssh/ssh_host_rsa_key.pub".format(shared_dir))
      server.succeed("systemctl restart sshd")

      # Generate client key
      client.succeed('ssh-keygen -N "" -f {}/root-key'.format(shared_dir))

      # Setup user key
      # copy(client, "/tmp", server, "/tmp", "key.pub")
      server.succeed("mkdir -p /root/.ssh; cat {}/root-key.pub > /root/.ssh/authorized_keys".format(shared_dir))

      # Trust CA certificates
      # copy(server, "/etc/ssh", client, "/tmp", "ca_host_key.pub")
      client.succeed("mkdir -p /root/.ssh")
      client.succeed('echo "@cert-authority * $(cat {}/ca_host_key.pub)" > /root/.ssh/known_hosts'.format(shared_dir))

      # Login should succeed and server is accepted by means of CA signature
      client.succeed('ssh -i {}/root-key -o "StrictHostKeyChecking yes" server true'.format(shared_dir))

      # User login with user CA key
      server.succeed("ssh-keygen -s {}/ca_host_key -n root -I root@client {}/root-key.pub".format(shared_dir, shared_dir))
      server.succeed("rm /root/.ssh/authorized_keys")

      client.wait_for_file("{}/root-key-cert.pub".format(shared_dir))
      client.succeed('ssh -i {}/root-key -o "StrictHostKeyChecking yes" server true'.format(shared_dir))
  '';
}
