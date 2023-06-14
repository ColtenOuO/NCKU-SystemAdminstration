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

function check_user() {
    username=$1
    getent passwd $username > null 2>&1
    if [ $? -eq 0 ]; then
        user_exist=1
    fi
}

check_group() { # 檢查 group 是否存在
    while [ $# -ge 1 ] ; do
        group=$1
        getent group $1 > null 2>&1
        if [ $? -ne 0 ] ; then # 如果 group 不存在，要先建立這個 group
            pw groupadd ${group} # 建立群組
        fi

        shift
    done
}

add_user_json(){

    username=$(echo "$1" | jq -r '.username')
    password=$(echo "$1" | jq -r '.password')
    shell=$(echo "$1" | jq -r '.shell')
    groups=$(echo "$1" | jq -r '.groups' | tr -d ']' | tr -d '[' | tr -d '\n' | tr -d ' ' | tr -d '"') # 把 [] " " 這些東西都去掉

    user_exist=0
    check_user $username

    if [ $user_exist = 1 ] ; then
        echo "Warning: user $username already exists."
    else
        check_group ${groups//,/ } # 把逗號都換成空格
        sudo pw useradd "$username" -m -s "$shell" -G "$groups" -h - # -h - 設置 home 目錄為空字串
        echo "$password" | pw mod user "$username" -h 0 # -h 0 不使用 shadow password XD
        # 將 echo 的輸出放入 pw 指令
    fi
}
add_user_csv(){
    IFS=',' read -ra data <<< "$1" # 以 , 為分隔，將 $1 分隔結果儲存在 data 裡面
    username="${data[0]}"
    password="${data[1]}"
    shell="${data[2]}"
    groups=$(echo "${data[3]}" | tr ' ' ',') # 把空格改成逗號，等等處理 : D

    user_exist=0
    check_user $username

    if [ $user_exist = 1 ] ; then
        echo "Warning: user $username already exists."
    else
        check_group ${groups//,/ } # 把逗號都換成空格
        sudo pw useradd "$username" -m -s "$shell" -G "$groups" -h - # -h - 設置 home 目錄為空字串
        echo "$password" | pw mod user "$username" -h 0 # -h 0 不使用 shadow password XD
        # 將 echo 的輸出放入 pw 指令
    fi
}

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
            while [[ $# != 0 && "$1" != -* ]]; do
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
f=0

for i in "${input_files[@]}"; do
    ok1=0
    ok2=0  # 可以改用 sed 來單獨讀取，比較不浪費資源
    txt=$(cat $i | head -1 | tail -1) # 一定要 $(指令)，否則不會回傳字串回來
    txt2="username,password,shell,groups"
    
    check=$(file $i)
    file $i | grep -q "CSV" 1>/dev/null
    
     if [ $? -eq 0 ]; then # 1>/dev/null 把標準錯誤輸出引入正確輸出
        ok1=1
    fi

    check=$(file $i)
    file $i | grep -q "JSON" 1>/dev/null

    if [ $? -eq 0 ]; then # 1>/dev/null 把標準錯誤輸出引入正確輸出
        ok2=1
    fi

    if [ $ok1 == 0 ] && [ $ok2 == 0 ]; then
        echo "Error: Invalid file format." 1>&2
        exit 1
    fi

    if [ $ok1 == 1 ]; then
        lines=$(awk 'END {print NR}' "${i}") 1>/dev/null
        line_index=2
        until [ "$((line_index))" -gt "$((lines))" ] # 使用 $(()) 作強制轉型，比較起來比較保險
        do
            txt=$(cat "${i}" | head -$line_index | tail -1 ) 1>/dev/null
            str=""

            ouo=$(awk -v line=$line_index -F, 'NR==line {print $1}' $i)
            if [ $f == 1 ]; then take_user+=" "
            fi
            f=1
            take_user+=$ouo
            line_index=$((line_index + 1))
        done
    fi

    if [ $ok2 == 1 ]; then
        if [ $f == 1 ]; then take_user+=" "
        fi
        f=1
        total_user=$(jq -r '.[] | {username: .username, password: .password, shell: .shell, groups: .groups | join(",")}' "${i}" 2>/dev/null ) 
        take_user+=$(jq -r ".username" <<< "${total_user}" 2>/dev/null | xargs )
    fi
done

# -n 不換行

echo -n "This script will create the following user(s): ${take_user} Do you want to continue? [y/n]:"
read answer
case $answer in
    [y])
    ;;
    [n])
        exit 0
    ;;
    *)
        exit 0
    ;;
esac

for i in "${input_files[@]}"; do

    check_file_type=$(head -5 "${i}")

    file $i | grep -q "JSON" 1>/dev/null

    if [ $? -eq 0 ]; then
        user_data=$(jq -c '.[]' "$i") # 把每一個 JSON 物件拆下來，放到 user_data 裡面
        for k in $user_data; do
            add_user_json "$k"
        done
    else # 先列出第 2 行 ~ 最後一行然後再 read
        tail -n +2 "$i" | while read -r user_data; do # 從第 2 行讀到最後一行，依序把每一行讀取的資訊儲存到 user_data 裡面
            add_user_csv "$user_data"
        done
    fi
done 
