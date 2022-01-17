#!/usr/bin/expect -f
spawn ssh-copy-id -F vm.ssh.config nixos@vm
expect {
  Password: {
    send_user "asked for password"
    send "$env(SETUP_PASSWORD)\r"
    exp_continue
  } eof {
    send_user "done"
    exit
  }
}
