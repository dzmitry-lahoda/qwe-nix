devnet-check =
              let
                user = "postgres";
                uid = "1000";
                gid = "1000";
                group = "postgres";
                dir = "/home/${user}";
                mkTmp = pkgs.runCommand "mkTmp" { } ''
                  mkdir -p $out/tmp
                  touch $out/tmp/test1.txt
                  touch $out/tmp/test2.txt
                '';

                mkUser = pkgs.runCommand "mkUser" { } ''
                  mkdir -p $out/etc/pam.d

                  echo "${user}:x:${uid}:${gid}::" > $out/etc/passwd
                  echo "${user}:!x:::::::" > $out/etc/shadow

                  echo "${group}:x:${gid}:" > $out/etc/group
                  echo "${group}:x::" > $out/etc/gshadow

                  cat > $out/etc/pam.d/other <<EOF
                  account sufficient pam_unix.so
                  auth sufficient pam_rootok.so
                  password requisite pam_unix.so nullok sha512
                  session required pam_unix.so
                  EOF

                  touch $out/etc/login.defs
                  mkdir -p $out/${dir}
                '';
              in
              nix2containerPkgs.nix2container.buildImage {
                name = "devnet-check";
                tag = "latest";
                initializeNixDatabase = true;
                nixUid = pkgs.lib.toInt uid;
                nixGid = pkgs.lib.toInt gid;
                config = {
                  WorkingDir = dir;
                  entrypoint = [ "${self'.packages.devnet-headless}/bin/devnet-headless" ];
                  User = user;
                  Env = [
                    "HOME=/home/${user}"
                    "USER=${user}"
                    "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                  ];
                };

                perms = [
                  {
                    path = mkUser;
                    regex = dir;
                    mode = "0744";
                    uid = pkgs.lib.toInt uid;
                    gid = pkgs.lib.toInt gid;
                    uname = user;
                    gname = group;
                  }
                  {
                    path = mkTmp;
                    regex = "/tmp";
                    mode = "0777";
                    uid = pkgs.lib.toInt uid;
                    gid = pkgs.lib.toInt gid;
                    uname = user;
                    gname = group;
                  }
                ];
                copyToRoot = [
                  (pkgs.buildEnv {
                    name = "root";
                    paths = [
                      pkgs.bashInteractive
                      pkgs.nix
                      pkgs.findutils
                      pkgs.nano
                      pkgs.unixtools.netstat
                      pkgs.ps
                      pkgs.git
                      pkgs.gawk
                      pkgs.curl
                      pkgs."solc-${solc-version}"
                    ] ++ buildInputs ++ devShellInputs;
                    pathsToLink = [ "/bin" ];
                  })
                  mkUser
                  mkTmp
                ];
                layers = [
                  (nix2containerPkgs.nix2container.buildLayer {
                    deps = [
                      self'.packages.devnet-headless
                      self'.packages.all-services
                    ];
                  })
                ];
              };
