let
  # Pin openssl explicitly so you know which output you're getting
  opensslLib = pkgs.openssl.out;
in
{
  # In your jackett derivation buildInputs:
  buildInputs = [
    pkgs.icu
    pkgs.curl
    pkgs.sqlite
    opensslLib          # .out is the runtime lib output
    pkgs.zlib
    pkgs.krb5
    pkgs.lttng-ust_2_12
    pkgs.stdenv.cc.cc.lib
  ];

  # copyToRoot — add opensslLib explicitly so it's in the image closure:
  copyToRoot = pkgs.buildEnv {
    name = "root";
    paths = [
      pkgs.coreutils
      pkgs.tzdata
      pkgs.cacert
      pkgs.icu
      opensslLib          # <-- explicit runtime lib in image
      pkgs.zlib
      pkgs.krb5
      pkgs.lttng-ust_2_12
      pkgs.stdenv.cc.cc.lib
      jackett
      jackettAbi
    ];
    # Ignore collisions from libs appearing in both jackett closure and here
    ignoreCollisions = true;
  };

  # Env — make sure LD_LIBRARY_PATH uses .out:
  Env = [
    "PATH=/bin"
    "TZ=UTC"
    "LANG=en_US.UTF-8"
    "LD_LIBRARY_PATH=${pkgs.icu}/lib:${opensslLib}/lib:${pkgs.zlib}/lib:${pkgs.krb5}/lib:${pkgs.lttng-ust_2_12}/lib:${pkgs.stdenv.cc.cc.lib}/lib"
    # .NET-specific: point it at the OpenSSL libs directly
    "CLR_OPENSSL_VERSION_OVERRIDE=3"
    "DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER=1"
  ];
