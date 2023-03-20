#!/bin/bash

function usage() {
    echo -n -e "\nUsage: sahw2.sh {--sha256 hashes ... | --md5 hashes ...} -i files ...\n\n--sha256: SHA256 hashes to validate input files.\n--md5: MD5 hashes to validate input files.\n-i: Input files.\n"
}

sha256=0
md5=0
cnt_hash=0
cnt_file=0
#my_array=()
input_files=()

while getopts ":hi:-:" opt; do
    case ${opt} in
      \? ) # 未知指令
      echo "Error: Invalid arguments." 1>&2
      usage
      exit 1
      ;;
    : ) # 沒有給參數
      echo "Error: Invalid arguments." 1>&2
      usage
      exit 1
      ;;
   # * )
    #  echo "Error: Invalid arguments." 1>&2
    #  usage
    #  exit 1
    esac
done

until [ $# == 0 ]
do
    case "$1" in 
        -h)
            usage
            exit 0
            ;;
        --sha256)
            sha256=1
            shift
            while [[ $# != 0 && "$1" != -* ]]; do #  $1 $2 $3
                my_array+=("$1")
                cnt_hash=$((cnt_hash + 1))
                shift
            done
            ;;
        --md5)
            md5=1
            shift
            while [[ $# != 0 && "$1" != -* ]]; do
                my_array+=("$1")
                cnt_hash=$((cnt_hash + 1))
                shift
            done
            ;;
        -i)
            shift
            while [[ $# != 0 && "$1" != -* ]]; do
                input_files+=("$1")
                cnt_file=$((cnt_file + 1))
                shift
            done
            ;;
        *) #default
            echo "Error: Invalid arguments." 1>&2
            usage
            exit 1
        ;;
    esac
done

if [ "$sha256" = 1 ] && [ "$md5" = 1 ]; then
    echo "Error: Only one type of hash function is allowed." 1>&2
    exit 1
fi

if [ "$sha256" -ge 1 ] && [ "$cnt_file" != "$cnt_hash" ]; then
    echo "Error: Invalid values." 1>&2
    exit 1
fi
if [ "$md5" -ge 1 ] && [ "$cnt_file" != "$cnt_hash" ]; then
    echo "Error: Invalid values." 1>&2
    exit 1
fi

# md5sum 與 sha256sum 回傳 {hash} 與 {filename}，透過 awk 只提取 {hash} 的值
# -b 是以二進位處理，-z 是在回傳的文件結尾增加 NULL

idx=0

if [ $sha256 = 1 ]; then
  
  for expected_hash in "${my_array[@]}"; do
    actual_hash=$(sha256sum "${input_files[${idx}]}" | awk '{print $1}')
    idx=$((idx + 1))
    if [ "$actual_hash" != "$expected_hash" ]; then
      echo "Error: Invalid checksum." 1>&2
      exit 1
    fi
  done
fi

if [ $md5 = 1 ]; then
  for expected_hash in "${my_array[@]}"; do # @ 可以用來展開陣列
    actual_hash=$(md5sum "${input_files[${idx}]}" | awk '{print $1}')
    idx=$((idx + 1))
    if [ "$actual_hash" != "$expected_hash" ]; then
      echo "Error: Invalid checksum." 1>&2
      exit 1
    fi
  done
fi

index=0

for i in "${input_files[@]}"; do
    total_user=$(jq -r '.[] | {username: .username, password: .password, shell: .shell, groups: .groups | join(",")}' "${i}" 2>/dev/null ) 
    take_user+= $(jq -r ".username" <<< "${total_user}" 2>/dev/null | xargs )
    total_user+=" "
done

for i in "${input_files[@]}"; do

    check_file_type=$(head -5 "${i}")

    if [ "${check_file_type:0:1}" == '[' ]; then
        
        total_user=$(jq -r '.[] | {username: .username, password: .password, shell: .shell, groups: .groups | join(",")}' "${i}" 2>/dev/null ) 
        take_user=$(jq -r ".username" <<< "${total_user}" 2>/dev/null | xargs )
        
        echo -n "This script will create the following user(s): ${take_user} Do you want to continue? [y/n]:"
        read answer
        case $answer in
            [y])
            ;;
            [n])
                exit 0
            ;;
        esac
        USERS=$(jq -r '.[0] | {username: .username, password: .password, shell: .shell, groups: .groups | join(",")}' "${i}" 2>/dev/null )
        USERNAME=$(jq -r ".username" <<< "${USERS}" 2>/dev/null )
        until [ "${USERNAME}" == "" ]
        do
            PASSWORD=$(jq -r ".password" <<< "${USERS}" 2>/dev/null)
            SHELL=$(jq -r ".shell" <<< "${USERS}" 2>/dev/null)
            GROUPS=$(jq -r ".groups" <<< "${USERS}" 2>/dev/null)
            index=$((index + 1))

            # 在沒有 user 的情況下，輸出會是空的，得到的結果就會是 false
            if id "$USERNAME" >/dev/null 2>&1; then # 把 標準錯誤輸出 指向 標準輸出 這樣才可以判斷輸出是否為空 
                echo "Warning: user ${USERNAME} already exists."
            else
                useradd -m -s "$SHELL" -G "$GROUPS" "$USERNAME"
                echo "$USERNAME:$PASSWORD" | chpasswd #chpasswd 可以批量修改 user 的密碼
            fi


            USERS=$(jq -r '.['"${index}"'] | {username: .username, password: .password, shell: .shell, groups: .groups | join(",")}' "${i}" 2>/dev/null )
            USERNAME=$(jq -r ".username" <<< "${USERS}" 2>/dev/null )
        done
    
    fi

done 




