{
  description = "minimalbase-ng + sabnzbd service";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };

    # ----------------------------
    # SABnzbd package
    # ----------------------------
    sabnzbd = pkgs.stdenv.mkDerivation {
      pname = "sabnzbd";
      version = "latest";

      src = ./sabnzbd-src;

      buildInputs = [
        pkgs.python3
        pkgs.python3Packages.virtualenv
        pkgs.python3Packages.pip
      ];

      installPhase = ''
        mkdir -p $out/app
        mkdir -p $out/data

        # Python venv
        python3 -m venv $out/app/python-venv
        $out/app/python-venv/bin/pip install --upgrade pip

        if [ -f requirements.txt ]; then
          $out/app/python-venv/bin/pip install -r requirements.txt
        fi

        # SABnzbd source
        cp -r . $out/app/sabnzbd-src

        # REQUIRED ENTRYPOINT
        if [ -f SABnzbd.py ]; then
          cp SABnzbd.py $out/app/main.py
        else
          echo "ERROR: SABnzbd.py not found"
          exit 1
        fi
      '';
    };

    # ----------------------------
    # ABI generator (NO shell)
    # ----------------------------
    sabAbi = pkgs.writeText "sabnzbd-abi.json" (builtins.toJSON {
      version = 2;

      process = {
        exec = "python";
        args = [
          "--config-file"
          "/data/sabnzbd.ini"
          "--logging"
          "0"
          "--console"
          "--browser"
          "0"
        ];
      };
    });

    # ----------------------------
    # Rust PID1
    # ----------------------------
    container-init = pkgs.rustPlatform.buildRustPackage {
      pname = "container-init";
      version = "0.2.0";

      src = ./rust-init;

      cargoLock = {
        lockFile = ./rust-init/Cargo.lock;
      };
    };

  in {
    packages.${system} = {
      base-image = pkgs.dockerTools.buildImage {
        name = "minimalbase-ng";
        tag = "latest";

        copyToRoot = pkgs.buildEnv {
          name = "root";
          paths = [
            pkgs.coreutils
            pkgs.tzdata
            pkgs.cacert

            container-init
            sabnzbd
            sabAbi
          ];
        };

        config = {
          Entrypoint = [ "${container-init}/bin/container-init" ];

          Cmd = [ sabAbi ];

          Env = [
            "TZ=UTC"
            "LANG=en_US.UTF-8"
          ];
        };
      };
    };
  };
}
