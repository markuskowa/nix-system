{
  lib,
  python3Packages,
  fetchFromGitHub,
  fetchpatch,
  bridge-utils,
  ethtool,
  iproute2,
  kmod,
  mstpd,
  procps,
  psmisc,
}:

python3Packages.buildPythonApplication (finalAttrs: {
  pname = "ifupdown2";
  version = "3.9.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "CumulusNetworks";
    repo = "ifupdown2";
    tag = finalAttrs.version;
    hash = "sha256-YRL8zVZekbOUXwASZafVxTLFNijfkGrMEuqF57aMeSQ=";
  };

  patches = [
    # Remove runtime dependency on setuptools
    (fetchpatch {
      url = "https://github.com/CumulusNetworks/ifupdown2/commit/d7b0952bf9aa5da8be017b6415412d5ca8c482bc.patch";
      hash = "sha256-CmPScm3F5XFUUKJwYx0+GhKywznpi2l1/7IWVKA0mgQ=";
    })

    # do not check for UID when running tools
    ./no-root.patch
  ];

  postPatch = ''
    # The default command paths are Debian specific and only replaced if found
    # in /bin, /sbin, /usr/bin or /usr/sbin. Point them to the Nix store instead.
    substituteInPlace ifupdown2/ifupdown/utils.py \
      --replace-fail "'/sbin/bridge'" "'${lib.getExe' iproute2 "bridge"}'" \
      --replace-fail "'/bin/ip'" "'${lib.getExe' iproute2 "ip"}'" \
      --replace-fail "'/bin/ss'" "'${lib.getExe' iproute2 "ss"}'" \
      --replace-fail "'/sbin/brctl'" "'${lib.getExe' bridge-utils "brctl"}'" \
      --replace-fail "'/bin/pidof'" "'${lib.getExe' procps "pidof"}'" \
      --replace-fail "'/sbin/sysctl'" "'${lib.getExe' procps "sysctl"}'" \
      --replace-fail "'/sbin/modprobe'" "'${lib.getExe' kmod "modprobe"}'" \
      --replace-fail "'/usr/bin/pstree'" "'${lib.getExe' psmisc "pstree"}'" \
      --replace-fail "'/sbin/mstpctl'" "'${lib.getExe' mstpd "mstpctl"}'" \
      --replace-fail "'/sbin/ethtool'" "'${lib.getExe ethtool}'"

    substituteInPlace ifupdown2/ifupdownaddons/modulebase.py \
      --replace-fail "/usr/sbin/ip vrf id" "${lib.getExe' iproute2 "ip"} vrf id"

    # Fall back to the default config files shipped in $out/etc
    substituteInPlace ifupdown2/ifupdown/config.py \
      --replace-fail "'%s%s' % (parent_dir, path_to_file)" "'${placeholder "out"}' + path_to_file"

    # --version queries dpkg
    substituteInPlace ifupdown2/ifupdown/argv.py \
      --replace-fail "dpkg = utils.exec_commandl([utils.dpkg_cmd, '-l', 'ifupdown2'])" \
                     "sys.stdout.write('ifupdown2:${finalAttrs.version}\n'); sys.exit(0)"
  '';

  build-system = [ python3Packages.setuptools ];

  dependencies = [
    python3Packages.six
    python3Packages.systemd-python
  ];

  # Listed in setup.py, but never imported
  pythonRemoveDeps = [ "daemon" ];

  postInstall = ''
    mv $out/${python3Packages.python.sitePackages}/etc $out/etc
  '';

  # The test suite runs against remote test machines via ssh
  doCheck = false;

  pythonImportsCheck = [ "ifupdown2" ];

  meta = {
    description = "Network interface manager for Linux, compatible with ifupdown";
    homepage = "https://github.com/CumulusNetworks/ifupdown2";
    changelog = "https://github.com/CumulusNetworks/ifupdown2/blob/${finalAttrs.src.tag}/debian/changelog";
    license = lib.licenses.gpl2Only;
    maintainers = with lib.maintainers; [ markuskowa ];
    platforms = lib.platforms.linux;
  };
})
