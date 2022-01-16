#!/usr/bin/expect -f
spawn ssh-copy-id -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -p "$env(SSH_PORT)" nixos@localhost
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
