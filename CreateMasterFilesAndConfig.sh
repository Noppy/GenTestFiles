#!/bin/bash

#要件に応じて引数から設定
NumberOfFiles="${1:-10000}"
StartDate="${2:-2015/1/1}"
EndDate="${3:-2019/12/31}"
Bucket=${4:-s3-100million-files-test}
Profile=${5:-default}
MasterList=${6:-master_list.csv}


#-----------------------------------------------------
# master_list.csvの構成
#    ファイルサイズ(KB),ファイル比率
#    
#-----------------------------------------------------

#固定設定
CONFIG_FILE="config.json"

#メイン
count=0
while IFS=, read size number
do
    #マスターファイル作成
    FILENAME="test-$(printf '%06d' ${size})KB.dat"
    dd if=/dev/urandom of=${FILENAME} bs=1024 count=${size}

    #作成したファイルのアップロード
    hash=$( cat /dev/urandom | base64 | fold -w 10 | sed -e 's/[\/\+\=]/0/g' | head -n 1 )
    DESTPATH="s3://${Bucket}/${hash}-original-data/${FILENAME}"
    aws --profile=${Profile} s3 cp ${FILENAME} ${DESTPATH}

    #config.json作成用データ
    S3MASTER_FILEPATH[$count]="${DESTPATH}"
    S3MASTER_RATIO[$count]="${number}"

    count=$((count+1))
done < ${MasterList}

#JSON生成
echo "{
    \"NumberOfFiles\": \"${NumberOfFiles}\",
    \"Period\": {
        \"StartDate\": \"${StartDate}\",
        \"EndDate\": \"${EndDate}\"
    },
    \"Source\": [" > ${CONFIG_FILE}
TEMP=""
for i in $(seq 0 $((count-1)) )
do
	TEMP="${TEMP}      {\n"
	TEMP="${TEMP}            \"Path\": \"${S3MASTER_FILEPATH[$i]}\",\n"
	TEMP="${TEMP}            \"Ratio\": ${S3MASTER_RATIO[$i]}\n"
	TEMP="${TEMP}      },\n"
done
echo -e "${TEMP%???}" >> ${CONFIG_FILE}
echo "    ],
    \"Destination\": {
      \"DestPath\": \"s3://${Bucket}\"
    }
}" >> ${CONFIG_FILE}


#delete temprary files
rm test-*.dat



