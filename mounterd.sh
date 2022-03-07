function mount_sync() {
  echo "# cleanup stale files/folders"

  IFS=$'\n\t'
  for HOST_TMP in /.tmp/*; do
    if [ ! \( -f "$HOST_TMP" -o -d "$HOST_TMP" \) ]; then
      echo "skipping $HOST_TMP"
      continue
    fi
    VM_TMP=${HOST_TMP/.tmp/tmp}

    if [ -f "$VM_TMP" ]; then
      # triggers potential network read issue in 9p
      dd if=$VM_TMP count=1 bs=1 >/dev/null 2>/dev/null
      if [ $? != 0 ]; then
        echo "remove stale file"
        umount $VM_TMP
        rm -d $VM_TMP
      fi
    fi

    if [ -d "$VM_TMP" ]; then
      # triggers potential network read issue in 9p
      ls $VM_TMP >/dev/null 2>/dev/null
      if [ $? != 0 ]; then
        echo "remove stale folder"
        umount $VM_TMP
        rm -d $VM_TMP
      fi
    fi

    if [ ! -e "$VM_TMP" ]; then
      # create mount point
      test -d $HOST_TMP && mkdir $VM_TMP || touch $VM_TMP
      # bind mount
      mount --bind $HOST_TMP $VM_TMP
      echo "bind mount $i";
    fi

  done
}

echo "starting listening to docker events"
(echo;docker events) | while read; do mount_sync; done
