pkgs: config: let
  cfg = pkgs.writeText "ssh.conf" config;
  expectScript = pkgs.writeText "ssh-copy-id.expect" ''
      set host [lindex $argv 0];
      set password $env(PASSWORD)
      spawn ssh-copy-id -F ${cfg} "$host"; expect Password: { send "$password\n"; exp_continue; exit }
  '';
  waitForSsh = pkgs.writeShellScriptBin "waitForSsh" ''
    DELAY=''${2:-1}
    while ! ssh -F ${cfg} -o PubkeyAuthentication=no -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o ChallengeResponseAuthentication=no "$@" 2>&1 | grep "Permission denied"; do
      echo -n ".";
      sleep $DELAY;
    done
  '';
in
  pkgs.symlinkJoin {
    name = "ssh-vm";
    paths = [ pkgs.openssh waitForSsh ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for b in ssh ssh-copy-id scp; do
        wrapProgram $out/bin/$b \
          --add-flags "-F ${cfg}"
      done

      echo "${pkgs.expect}/bin/expect -f ${expectScript} \$@" > $out/bin/ssh-copy-id-password
      chmod +x $out/bin/ssh-copy-id-password
      #wrapProgram $out/bin/ssh-copy-id-password --set PATH $out
    '';
  }
