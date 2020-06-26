{ lib, pkgs, ... } :

{
  name = "slurmPmix";

  nodes.mach = { pkgs, ... } : let
    mpitestC = pkgs.writeText "mpitest.c" ''
      #include <stdio.h>
      #include <stdlib.h>
      #include <mpi.h>

      int
      main (int argc, char *argv[])
      {
        int rank, size, length;
        char name[512];

        MPI_Init (&argc, &argv);
        MPI_Comm_rank (MPI_COMM_WORLD, &rank);
        MPI_Comm_size (MPI_COMM_WORLD, &size);
        MPI_Get_processor_name (name, &length);

        if ( rank == 0 ) printf("size=%d\n", size);

        printf ("%s: hello world from process %d of %d\n", name, rank, size);

        MPI_Finalize ();

        return EXIT_SUCCESS;
      }
    '';

    mpitest = pkgs.runCommandNoCC "mpitest" {} ''
      mkdir -p $out/bin
      ${pkgs.openmpi}/bin/mpicc ${mpitestC} -o $out/bin/mpitest
    '';

  in {
    virtualisation.cores = 2;
    imports = [ ../modules/overlay.nix ];
    services.slurm = {
      client.enable = true;
      server.enable = true;
      controlMachine = "mach";
      nodeName = [ "mach CPUs=2 state=UNKNOWN" ];
      partitionName = [ "d Nodes=mach default=YES state=UP" ];
      extraConfig = ''
        MpiDefault=pmix
      '';
    };

    networking.firewall.enable = false;

    services.munge = {
      enable = true;
      password = "/etc/munge.key";
    };

    systemd.tmpfiles.rules = [
      "f /etc/munge.key 0400 munge munge - 12345678901234567901234567890123"
    ];

    environment.systemPackages = [ pkgs.openmpi pkgs.pmix mpitest pkgs.slurm ];


    #users.users.root.password = "test";

  };

  testScript = ''
    startAll();
    $mach->waitForUnit("default.target");
    $mach->waitForUnit("systemd-tmpfiles-setup.service");
    $mach->succeed("systemctl restart munged");
    $mach->waitForUnit("slurmctld.service");
    $mach->waitForUnit("slurmd.service");

    # plain mpirun
    $mach->succeed("mpirun --allow-run-as-root -np 2 mpitest | grep 'size=2'");

    # basic srun
    $mach->succeed("srun -n2 mpitest | grep size=2");
  '';
}
