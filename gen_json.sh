#!/bin/bash


#要件に応じて設定
NumberOfFiles=$1
StartDate=$2
EndDate=$3
Bucket=$4
DestS3BucketAndPrefix="s3://${Bucket}/original-data/"
#固定設定
CONFIG_FILE="config.json"

#マスターファイルの取得
MASTER_FILES=""
for i in $(aws s3 ls "s3://${Bucket}" |grep "${MasterPrefix}"|awk -e '{print $2}')
do
    MASTER_FILES="${MASTER_FILES} $(aws s3 ls s3://${Bucket}/${i} --recursive | awk '{print $4}')"
done

#JSON生成
echo "{
    \"NumberOfFiles\": \"${NumberOfFiles}\",
    \"Period\": {
        \"StartDate\": \"${StartDate}\",
        \"EndDate\": \"${EndDate}\"
    },
    \"Source\": [" > ${CONFIG_FILE}
TEMP=""
for i in ${MASTER_FILES}
do
	TEMP="${TEMP}      {\n"
	TEMP="${TEMP}            \"Path\": \"s3://${Bucket}/${i}\",\n"
	TEMP="${TEMP}            \"Ratio\": 1\n"
	TEMP="${TEMP}      },\n"
done
echo -e "${TEMP%???}" >> ${CONFIG_FILE}
echo "    ],
    \"Destination\": {
      \"DestPath\": \"s3://${Bucket}\"
    }
}" >> ${CONFIG_FILE}

