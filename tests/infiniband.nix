#
# Dummy test for checking if modules load
#
{ ... } :

{

  nodes = {
    machine = {
      imports = [ ../modules/overlay.nix ];
      networking.infiniband.enable = true;
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("ibsysstat -V")
  '';
}
