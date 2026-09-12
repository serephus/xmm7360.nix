{ lib, stdenv, fetchFromGitHub, kernel, python3 }:

let
  python = python3.withPackages (ps:
    [ ps.configargparse ps.pyroute2 ps.dbus-python ]);
in stdenv.mkDerivation {
  pname = "xmm7360-pci";
  version = "2024-02-24";

  src = fetchFromGitHub {
    owner = "xmm7360";
    repo = "xmm7360-pci";
    rev = "a8ff2c6ceee84cbe74df8a78cfaa5a016d362ed4";
    sha256 = "sha256-wwm9ELALiJrC54azyJ95Rm3pcGLYzhxEe9mcCUvSVKk=";
  };

  patches = [
    ./kernel-compat.patch
    ./open_xdatachannel.patch
  ];

  nativeBuildInputs = kernel.moduleBuildDependencies;

  prePatch = ''
    substituteInPlace rpc/open_xdatachannel.py \
      --replace-fail '#!/usr/bin/env python3' '#!${python}/bin/python3'
  '';

  makeFlags = [
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  installPhase = ''
    runHook preInstall

    install -Dm644 xmm7360.ko \
      "$out/lib/modules/${kernel.modDirVersion}/misc/xmm7360.ko"
    mkdir -p "$out/bin"
    cp rpc/*.py "$out/bin/"

    runHook postInstall
  '';

  meta = with lib; {
    description =
      "PCI driver for the Fibocom L850-GL modem based on the Intel XMM7360 modem";
    homepage = "https://github.com/xmm7360/xmm7360-pci";
    license = with licenses; [ gpl2Only bsd3 ];
    platforms = [ "x86_64-linux" ];
  };
}
