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
        '';
      };
    };

    node = { ... } : {
      services.openssh = {
        enable = true;
      };
    };
  };

  testScript = ''
    shared_dir = "/tmp/shared"

    start_all()
    node.wait_for_unit("multi-user.target")
    server.wait_for_unit("multi-user.target")

    # Generate CA certificate
    server.succeed('ssh-keygen -t rsa -N "" -f {}/ca_host_key -I CA'.format(shared_dir))

    # Sign host keys
    server.succeed("ssh-keygen -s {}/ca_host_key -h -I server /etc/ssh/ssh_host_ed25519_key.pub".format(shared_dir))
    server.succeed("ssh-keygen -s {}/ca_host_key -h -I server /etc/ssh/ssh_host_rsa_key.pub".format(shared_dir))
    server.succeed("systemctl restart sshd")

    # Generate client key
    node.succeed('ssh-keygen -N "" -f {}/root-key'.format(shared_dir))

    # Setup user key
    # copy(node, "/tmp", server, "/tmp", "key.pub")
    server.succeed("mkdir -p /root/.ssh; cat {}/root-key.pub > /root/.ssh/authorized_keys".format(shared_dir))

    # Trust CA certificates
    # copy(server, "/etc/ssh", node, "/tmp", "ca_host_key.pub")
    node.succeed("mkdir -p /root/.ssh")
    node.succeed('echo "@cert-authority * $(cat {}/ca_host_key.pub)" > /root/.ssh/known_hosts'.format(shared_dir))

    # Login should succeed and server is accepted by means of CA signature
    node.succeed('ssh -i {}/root-key -o "StrictHostKeyChecking yes" server true'.format(shared_dir))
  '';
}
