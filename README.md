# NCKU-SystemAdminstration
111 學年度國立成功大學 計算機系統管理課程紀錄

## HW3

### General
- dmesg 看看現在有什麼硬碟
- zpool create sz_pool ada1 ada2 ada3
- 在 /etc/rc.conf 加入 zfs_enable="YES"

### ZFS Configuration
- zfs create sa_pool/data
- zfs set compression=lz4 sa_pool/data
- zfs set copies=2 sa_pool/data
- zfs set atime=off sa_pool/data
- zfs set mountpoint=/sa_data sa_pool/data

#### Set /sa_data permission to drwxr-xr-x.

- chmod 755 /sa_data

#### Change the /sa_data directory owner and group to root/wheel

- chown root:wheel /sa_data

