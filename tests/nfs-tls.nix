{ pkgs, ... } :

{
  name = "nfs-tls";

  nodes = let
    caCert = pkgs.writeText "caCert.pem" ''
      -----BEGIN CERTIFICATE-----
      MIICkDCCAfmgAwIBAgIUOcdmgndKsbmPSF4AHkn4+DJ6l+MwDQYJKoZIhvcNAQEL
      BQAwWjELMAkGA1UEAwwCQ0ExCzAJBgNVBAYTAlNFMQ4wDAYDVQQIDAVsb2NhbDEO
      MAwGA1UEBwwFbG9jYWwxDjAMBgNVBAoMBU5peE9TMQ4wDAYDVQQLDAVUZXN0czAe
      Fw0yNTEwMTUyMTA1MzZaFw0zNTEwMTMyMTA1MzZaMFoxCzAJBgNVBAMMAkNBMQsw
      CQYDVQQGEwJTRTEOMAwGA1UECAwFbG9jYWwxDjAMBgNVBAcMBWxvY2FsMQ4wDAYD
      VQQKDAVOaXhPUzEOMAwGA1UECwwFVGVzdHMwgZ8wDQYJKoZIhvcNAQEBBQADgY0A
      MIGJAoGBAKP6ZqWwzrh48bKu8CJJe/a+NXNZLOm1SqtAHBc4F2/2q37RIt+h0GKk
      1CcJBFT8MxtrkjFetGb1JuQP58dF/FQuOE3LOotFcfgoPRP3DXpVddfuR8CBUlrT
      tkPkBr58mxPx8rl/8RmqKadl49ENQYDI6Gj1so6DGYuxoO8w7nr7AgMBAAGjUzBR
      MB0GA1UdDgQWBBRNsWxzy0Kx/lzo7QmxADdhTu7UPDAfBgNVHSMEGDAWgBRNsWxz
      y0Kx/lzo7QmxADdhTu7UPDAPBgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBCwUA
      A4GBAGdzFSbhGfFsE5D3BCM8TSUcaZxVeIW+2UaKcIEFJtpP310Zend6fr9fTUCt
      2Zm74xK0PHYEoLyWSyBkn1j9/zrkJY/df66SAw7KubTVAIrWZ0X8KPUq0z9XI+h/
      SjYAcfk/NqDYHBlr/ZS9D7HDQ/YgsSMbyervO2sogMUqGErz
      -----END CERTIFICATE-----
    '';
  in {
    server = { pkgs, ...} : let
      cert = pkgs.writeText "serverCert.pem" ''
        -----BEGIN CERTIFICATE-----
        MIICazCCAdSgAwIBAgIBATANBgkqhkiG9w0BAQsFADBaMQswCQYDVQQDDAJDQTEL
        MAkGA1UEBhMCU0UxDjAMBgNVBAgMBWxvY2FsMQ4wDAYDVQQHDAVsb2NhbDEOMAwG
        A1UECgwFTml4T1MxDjAMBgNVBAsMBVRlc3RzMB4XDTI1MTAxNTIxMTAwOVoXDTM1
        MTAxMzIxMTAwOVowTjELMAkGA1UEBhMCU0UxDjAMBgNVBAgMBWxvY2FsMQ4wDAYD
        VQQKDAVOaXhPUzEOMAwGA1UECwwFVGVzdHMxDzANBgNVBAMMBnNlcnZlcjCBnzAN
        BgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAvcYPcDqENz5ByxAMUmeCS3qksNMmEchk
        vk3hsOYZJKcoi1sjkQOVWtRxEIjG0P+wfRQBsAjTxb5TzzcaA+v4O59nT4booJkA
        rQ9tyvOaeSUCzqO8onEENlB6BUU521T8sF9X+sRZjALE71T3dyAsfPahS8+I0N6V
        7RM0S+Mx3BcCAwEAAaNNMEswCQYDVR0TBAIwADAdBgNVHQ4EFgQUVXHgZdPj8kkP
        lQ8797UDcBWKtCswHwYDVR0jBBgwFoAUTbFsc8tCsf5c6O0JsQA3YU7u1DwwDQYJ
        KoZIhvcNAQELBQADgYEAijjmEHJ0Tztfb6TZU6MrzWN67U2mGSx1WjuhTWx6JLHs
        FePujqvhHlCWNUlBgwaSZ+GRUh9FQhcSGriCAlTTpcVlne17P0/4xznCqAE6tB8Y
        H7LegEEf+6UJoE+/GiJrjdkpLyxLTav9IukqLXaFQbuSnnF42eyaoRLiPxZxhDU=
        -----END CERTIFICATE-----
      '';

      key = pkgs.writeText "serverKey.pem" ''
        -----BEGIN PRIVATE KEY-----
        MIICdQIBADANBgkqhkiG9w0BAQEFAASCAl8wggJbAgEAAoGBAL3GD3A6hDc+QcsQ
        DFJngkt6pLDTJhHIZL5N4bDmGSSnKItbI5EDlVrUcRCIxtD/sH0UAbAI08W+U883
        GgPr+DufZ0+G6KCZAK0PbcrzmnklAs6jvKJxBDZQegVFOdtU/LBfV/rEWYwCxO9U
        93cgLHz2oUvPiNDele0TNEvjMdwXAgMBAAECgYAxHFBiesI8iZ/9LOoDaUYOwm5c
        VEhF0dZAaWc+oE1hbuDPL4bEwGimWNPps3vAGmtR8xt8sswbIGYP+fKBkU9rrFz3
        l8Xdqvwt8SCnKOqFpJ/0lv/4lVuEWU909AnzQpmKV6ziiVlcQubA68JLAT+fydgN
        /8LYTNRz33fj8JpGAQJBAOd7uz0FFIMRUpHhUaWovz/m5EVdhbcNZkg4HjwtjNw5
        NjPirG4tif9rHcTcCIQlrz+x7R4s7HlzsbUenIPRPLMCQQDR33GuZSfYrzf+xwkZ
        guUjVX9GZKxYF0UXakLBk+y2ZZOCiLbQ666B2zXAXEvHVnxsrFp4G8U+yGE5rkR/
        SJ0NAkAuz5m0pENaofUlpQAC1RYf0QxWbqwssVv+vMJ4fumeWz93zJ38Bd+DNGEn
        vytFte0zn0KJOKJ1iQzlyJP0ICr7AkA2+mG9XaJikQQKKfmoRTHhX7RHrHe5W98t
        kxiJvUZ1QYay2z2I3TSJr/MUwRjYzz8o+L16WUwCdluB0LUA4vTBAkBRgak6RDV0
        jvn/6tTByeOfK6rVlIhtBQb3xMWy6XvjOPetxsq3InbCnxd/df1AIULb4KU21tZ/
        zHE3gxlc1RGd
        -----END PRIVATE KEY-----
      '';

    in {
      imports = [ ../modules/tlshd.nix ];

      services.nfs.server = {
        enable = true;
        exports = ''
          /data 192.168.1.0/255.255.255.0(rw,no_root_squash,no_subtree_check,xprtsec=mtls,fsid=0)
        '';
        createMountPoints = true;
      };

      networking.firewall.enable = false;

      services.tlshd = {
        enable = true;
        settings = {
          debug.loglevel=3;

          "authenticate.server" = {
            "x509.truststore" = toString caCert;
            "x509.certificate" = toString cert;
            "x509.private_key" = toString key;
          };
        };
      };
    };

    client = {...} : let
      cert = pkgs.writeText "clientCert.pem" ''
        -----BEGIN CERTIFICATE-----
        MIICazCCAdSgAwIBAgIBAjANBgkqhkiG9w0BAQsFADBaMQswCQYDVQQDDAJDQTEL
        MAkGA1UEBhMCU0UxDjAMBgNVBAgMBWxvY2FsMQ4wDAYDVQQHDAVsb2NhbDEOMAwG
        A1UECgwFTml4T1MxDjAMBgNVBAsMBVRlc3RzMB4XDTI1MTAxNzIyMDcwMFoXDTM1
        MTAxNTIyMDcwMFowTjELMAkGA1UEBhMCU0UxDjAMBgNVBAgMBWxvY2FsMQ4wDAYD
        VQQKDAVOaXhPUzEOMAwGA1UECwwFVGVzdHMxDzANBgNVBAMMBmNsaWVudDCBnzAN
        BgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA9cR5O4TXoQQbKVfRWnv/nUSXYU6TQvl6
        aUpEOAf6++BmuRH5AnAFLDk4BY2Rk0Zls1vhM7hZl2Q8LqBJ3gPsqNRQu3lJYM5H
        eUZ2xD6SG+TcK3rxocwEVwBjIVhcDr7oL4GtUKKTQ1UzWHXV0PoOcMDsGIMGW1T4
        T/M9vrhvolMCAwEAAaNNMEswCQYDVR0TBAIwADAdBgNVHQ4EFgQU/1wCFddZ9rVK
        4e+b403X8OS5uZMwHwYDVR0jBBgwFoAUTbFsc8tCsf5c6O0JsQA3YU7u1DwwDQYJ
        KoZIhvcNAQELBQADgYEAciaYK13HsUjowGvCGuNoqPvxOeHZJ0WG+a5SG2/phxEV
        z4bNm+VfWCl6260087P4t1b8QYBbGORgp+LRhiCoi/PQ/iZSzDvIKAcJ6+KEDebS
        BMtvtcMauHuT86E0kw/F7dJmmaeIyjatA2OPU983T3aJi0IKVyxHS1hr6qZ4Ix0=
        -----END CERTIFICATE-----
      '';

      key = pkgs.writeText "clientKey.pem" ''
        -----BEGIN PRIVATE KEY-----
        MIICdgIBADANBgkqhkiG9w0BAQEFAASCAmAwggJcAgEAAoGBAPXEeTuE16EEGylX
        0Vp7/51El2FOk0L5emlKRDgH+vvgZrkR+QJwBSw5OAWNkZNGZbNb4TO4WZdkPC6g
        Sd4D7KjUULt5SWDOR3lGdsQ+khvk3Ct68aHMBFcAYyFYXA6+6C+BrVCik0NVM1h1
        1dD6DnDA7BiDBltU+E/zPb64b6JTAgMBAAECgYEA6+xvdHNRi4Alksp6biIafx4Z
        M4/6TZCvseNZGXCPvrrr4T0fjPd7/7ftz2bXGEm71zGcPcn6NxpBq4CzaCzcQFPq
        b4mHB7HVKd3xMzbvE9KB1o2A75PJV/hH612ycgOhpiGk+lxwOzRun5CRWzzjVj6D
        i5a+VVHMHxgFbe6r7gECQQD/KEjZ2Lho82uwbNylCnGtXFtXzmPElmzPjbQYji2+
        VGY+7NKjcJDoBJZodoB/msbtUgZevTxw8hOkBpjorj0dAkEA9pRAJh6NmdE0s+Cv
        9yTrUTGEjQk2IcLlfxewzqhQPr1I21Es/3uquZP7nCXXlQVsv7RVOZmsf10E86gm
        HtHyLwJAVBuQYBb7OsU6s04/MTwPGsk95uTGqE+5kHUyb4G2fG3PwmBIUs3RRln0
        xnyBgQ6hEiueo+4XFVgGt2PhVZnR1QJAC9Bmkmz8U9ZWNBgb1jeKnsVEmI1Mbqmr
        3T8BVaVy0s624usswMDoGSQh9gVKIvWzlCvLuYrHXQLT7eisiuV8OQJASxWbqii1
        nQ9nMSJAQPOJHk82fqCOyZ9q4CPXEE8hHvt7QP9ImzD4G60aamggzABKB3XeVDSO
        jBGwXUd/KjqaTg==
        -----END PRIVATE KEY-----
      '';

    in {
      imports = [ ../modules/tlshd.nix ];

      virtualisation.fileSystems  = {
        "/data" = {
          device = "server:/";
          fsType = "nfs";
          options = [ "vers=4.2" "xprtsec=mtls" ];
        };
      };

      networking.firewall.enable = false;

      services.tlshd = {
        enable = true;
        settings = {
          debug.loglevel=3;

          "authenticate.client" = {
            "x509.truststore" = toString caCert;
            "x509.certificate" = toString cert;
            "x509.private_key" = toString key;
          };
        };
      };
    };
  };

  testScript = ''
    server.wait_for_unit("nfs-server.service");
    client.wait_for_unit("data.mount");
    client.succeed("echo hallo > /data/foo");
    server.succeed("grep hallo /data/foo");
  '';
}

