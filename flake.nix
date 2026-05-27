{
  description = "SABnzbd service image";

  inputs = {
    minimalbase-ng = {
      url = "github:nonrootdocker/minimalbase-ng";
    };

    sabnzbd = {
      url = "github:sabnzbd/sabnzbd";
      flake = false;
    };
  };

  outputs = { self, minimalbase-ng, sabnzbd }:
  let
    system = "x86_64-linux";

    pkgs = minimalbase-ng.packages.${system}.pkgs;

    baseImage =
      minimalbase-ng.packages.${system}.base-image;

  in {
    packages.${system}.default =
      pkgs.dockerTools.buildImage {
        name = "sabnzbd";
        tag = "latest";

        fromImage = baseImage;

        copyToRoot = pkgs.buildEnv {
          name = "root";

          paths = with pkgs; [
            coreutils
            python3
            python3Packages.pip
            par2cmdline
            unrar
            p7zip
          ];
        };

        extraCommands = ''
          mkdir -p /app
          cp -r ${sabnzbd} /app/sabnzbd
          python3 -m venv /app/python-venv
          /app/python-venv/bin/python3 -m pip install -r /app/sabnzbd/requirements.txt
        '';

        config = {
          Entrypoint = [ "/bin/container-init" ];

          Cmd = [
            "/app/python-venv/bin/python3"
            "/app/sabnzbd/SABnzbd.py"
            "--config-file" "/data/sabnzbd.ini"
            "--logging" "0"
            "--console"
            "--browser" "0"
          ];

          Env = [
            "TZ=UTC"
            "LANG=en_US.UTF-8"
            "PYTHONUNBUFFERED=1"
          ];
        };
      };
  };
}
