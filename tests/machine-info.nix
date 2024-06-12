{ ... } :

{
  name = "networkmap";

  nodes.machine = { pkgs, ... } : {
    imports = [ ../modules/machine-info.nix ];

    environment.systemPackages = [ pkgs.jq ];
    system.machine-info = {
      enable = true;
      prettyHostname = "A NixOS Machine";
      deployment = "development";
      location = "In the box";
      hardwareVendor = "NixOS-vm";
      hardwareModel = "NixOS-vm-test";
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    machine.succeed("hostnamectl --json=short | jq '.PrettyHostname' | grep 'A NixOS Machine'")
    machine.succeed("hostnamectl --json=short | jq '.Deployment' | grep development")
    machine.succeed("hostnamectl --json=short | jq '.Location' | grep 'In the box'")
    machine.succeed("hostnamectl --json=short | jq '.HardwareVendor' | grep 'NixOS-vm'")
    machine.succeed("hostnamectl --json=short | jq '.HardwareModel' | grep 'NixOS-vm-test'")
  '';
}
