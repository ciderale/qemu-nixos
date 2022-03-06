function mount_sync() {
  # create bind mounts
  for i in $(comm -1 -3 <(ls -1 /tmp) <(ls /.tmp/)); do
    test -d /.tmp/$i && mkdir /tmp/$i || touch /tmp/$i;
    mount --bind /.tmp/$i /tmp/$i;
    echo "bind mount $i";
  done

  # remove stale bind mounts
  for i in /tmp/*; do
    test ! -e $i && echo "unbind $i" && umount $i && rm -d $i
  done
}

echo "starting listening to docker events"
docker events | while read; do mount_sync; done
