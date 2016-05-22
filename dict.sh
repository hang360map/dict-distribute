#!/bin/bash

#merger server config
source /home/search/DICT/config.sh
#复制QCMS的字典到字典库中
scp -r -q IP:/da1/s/apps/map_merger_dict/QCMS/dict/* /home/search/DICT/dict/
if [ $? -ne 0 ];then
    echo "SCP QCMS Failed!!! Must Check."
    exit 1
fi

DICT_DIR="/home/search/DICT/dict"

if [ $# -ne 1 ];then
    echo "[Usage]./dict (\$room|\$server|all)"
    exit 1
fi

NEED_RELOAD=0
if [ ! -d $DICT_DIR ];then
    echo $DICT_DIR " is not dir Error!"
    exit 1
fi
#存放字典文件的md5值
MD5_DIR=$DICT_DIR"_md5/"
if [ ! -d $MD5_DIR ];then
    mkdir $MD5_DIR
fi
#获取每个文件的md5值并根据第二个参数判断是否是第二次产生md5值
function md5(){
    NAME=$1
    find $NAME -type f | xargs md5sum > $MD5_DIR"/"${NAME##*/}"."$2
}
#遍历字典，判断现有文件是否有改动（或增加新字典）
function ergodic(){
for file in `ls $1`
do
    FILE_NAME=$1"/"$file
    if [ -d $FILE_NAME ];then
        ergodic $FILE_NAME
    elif [ ! -f $FILE_NAME ];then
        echo $DICT_DIR "Error!"
        exit 1
    else
        #if [ $NEED_RELOAD ];then
          #  break
        #fi
        MD5=$MD5_DIR"/"${FILE_NAME##*/}".md5"
        MD5_c=$MD5_DIR"/"${FILE_NAME##*/}".md5_current"
        if [ ! -f $MD5 ];then
            md5 $FILE_NAME md5
            NEED_RELOAD=1
        fi
        md5 $FILE_NAME md5_current
        diff $MD5 $MD5_c > /dev/null 2>&1
        if [ $? -eq 1 ];then
            NEED_RELOAD=1
            mv $MD5_c $MD5
        else
            rm -f $MD5_c
        fi
    fi
done
}
#判断字典中是否有给定文件的名字
function comparename(){
for file_c in `ls $1`
do
    FILE_NAME_C=$1"/"$file_c
    if [ -d $FILE_NAME_C ];then
        comparename $FILE_NAME_C $2
        if [ $? -eq 1 ];then
            return 1
        fi
    elif [ ! -f $FILE_NAME_C ];then
        return 0
    elif [ $file_c == $2 ];then
        return 1
    fi
done
}
#根据md5 log判断是否有字典被移除
function ergodic_log(){
for file_e in `ls $1`
do
    FILE_NAME_E=$1"/"$file_e
    if [ ! -f $FILE_NAME_E ];then
        echo $FILE_NAME_E "Error!"
        exit 1
    else
        NAME_E=${file_e%%.md5}
        comparename $DICT_DIR $NAME_E
        if [ $? -ne 1 ];then
            NEED_RELOAD=1
            echo $FILE_NAME_E
            rm -f $FILE_NAME_E
        fi
    fi
done
}
ergodic $DICT_DIR
ergodic_log $MD5_DIR

echo "Need relod:"$NEED_RELOAD

if [ $NEED_RELOAD -eq 0 ];then
    echo "Need not"
    exit 1
fi
#如有改动，进行分发，并reload
REMOTE_SERVER=$1
if [ $REMOTE_SERVER == "all" ];then
    REMOTE_SERVER=$ALL_IDC
elif [ $REMOTE_SERVER == "bjdt" ]; then
    REMOTE_SERVER=$bjdt
elif [ $REMOTE_SERVER == "shjc" ]; then
    REMOTE_SERVER=$shjc
elif [ $REMOTE_SERVER == "gzst" ]; then
    REMOTE_SERVER=$gzst
elif [ $REMOTE_SERVER == "zzzc" ]; then
    REMOTE_SERVER=$zzzc
fi

CUR_SERVER=""
REMOTE_EXEC=""
for server in $REMOTE_SERVER
do
    CUR_SERVER=$server
    REMOTE_EXEC="ssh $CUR_SERVER"
    scp -q -r $DICT_DIR $CUR_SERVER:$EXEC_DIR"/dict_temp"
    if [ $? -ne 0 ];then
        echo "SCP Failed!!! Must Check."
        exit 1
    fi   
    $REMOTE_EXEC "rm -rf $EXEC_DIR'/dict'"
    $REMOTE_EXEC "mv $EXEC_DIR'/dict_temp' $EXEC_DIR'/dict'"
    $REMOTE_EXEC "$EXEC_DIR'/bin/serverctl' reload >> $EXEC_DIR'/log/dict_crontab.log' 2>&1"
done
