{
  description = "minimalbase + jackett service";
  inputs = {
    nixpkgs.follows = "minimalbase/nixpkgs";
    minimalbase.url = "github:nonrootdocker/minimalbase";
    jackett-src = {
      url = "https://github.com/Jackett/Jackett/releases/latest/download/Jackett.Binaries.LinuxAMDx64.tar.gz";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, minimalbase, jackett-src }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
      };
    };
    opensslLib = pkgs.openssl.out;
    # ----------------------------
    # Jackett version (read from the release's deps.json, so it always
    # matches the exact binary pinned by the jackett-src lock entry)
    # ----------------------------
    jackettDeps =
      let
        p1 = "${jackett-src}/jackett.deps.json";
        p2 = "${jackett-src}/Jackett/jackett.deps.json";
      in if builtins.pathExists p1 then p1 else p2;
    jackettVersion =
      let
        deps = builtins.fromJSON (builtins.readFile jackettDeps);
        keys = builtins.attrNames deps.libraries;
        key = builtins.head (builtins.filter (k: builtins.match "jackett/.*" k != null) keys);
      in pkgs.lib.removePrefix "jackett/" key;
    # ----------------------------
    # Jackett package
    # ----------------------------
    jackett = pkgs.stdenv.mkDerivation {
      pname = "jackett";
      version = jackettVersion;
      src = jackett-src;
      nativeBuildInputs = [
        pkgs.autoPatchelfHook
      ];
      buildInputs = [
        pkgs.icu
        pkgs.curl
        pkgs.sqlite
        opensslLib
        pkgs.zlib
        pkgs.lttng-ust_2_12
        pkgs.stdenv.cc.cc.lib
      ];
      installPhase = ''
        mkdir -p $out/app/Jackett
        cp -r . $out/app/Jackett/
      '';
    };
    # ----------------------------
    # ABI generator (Points directly to Nix Store)
    # ----------------------------
    jackettAbi = pkgs.writeTextFile {
      name = "jackett-abi.json";
      text = builtins.toJSON {
        version = 2;
        process = {
          exec = "${jackett}/app/Jackett/jackett";
          args = [
            "--DataFolder"
            "/data"
          ];
        };
      };
      destination = "/app/main";
    };
  in {
    packages.${system} = {
      default = self.packages.${system}.jackett-image;
      jackett-image = pkgs.dockerTools.buildImage {
        name = "minimalbase";
        tag = jackettVersion;
        fromImage = minimalbase.packages.${system}.base-image;
        copyToRoot = pkgs.buildEnv {
          name = "root";
          paths = [
            pkgs.coreutils
            pkgs.tzdata
            pkgs.cacert
            jackett
            jackettAbi
          ];
        };
        config = {
          Entrypoint = [ "${minimalbase.packages.${system}.container-init}/bin/container-init" ];
          User = "1000:1000";
          Env = [
            "PATH=/bin"
            "TZ=UTC"
            "LANG=en_US.UTF-8"
            "LD_LIBRARY_PATH=${pkgs.icu}/lib:${opensslLib}/lib:${pkgs.zlib}/lib:${pkgs.lttng-ust_2_12}/lib"
          ];
        };
      };
    };
  };
}
