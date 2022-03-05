{
  pkgs,
  qemu-monitor-address,
}:
let
  grep = "${pkgs.gnugrep}/bin/grep";
  sed = "${pkgs.gnused}/bin/sed";
  qemu-monitor = pkgs.writeShellScriptBin "qemu-monitor" ''
    ${pkgs.socat}/bin/socat - ${qemu-monitor-address};
  '';
  qemu-pipe = pkgs.writeShellScriptBin "qemu-pipe" ''
    DELAY=${DELAY:-0.2}
    (cat; sleep $DELAY) | ${qemu-monitor}/bin/qemu-monitor
  '';
  qemu-cmd = pkgs.writeShellScriptBin "qemu-cmd" ''
    echo $* | ${qemu-pipe}/bin/qemu-pipe
  '';
  qemu-type = pkgs.writeShellScriptBin "qemu-type" ''
    (echo -n $1 | ${grep} -o . | ${sed} -e 's/^/sendkey /';
     echo "sendkey ret") \
    | ${qemu-pipe}/bin/qemu-pipe
  '';
in
  pkgs.symlinkJoin {
    name = "qemu-tools";
    paths = [qemu-monitor qemu-cmd qemu-pipe qemu-type];
  }
