# GenTestFiles
テスト用のファイルをS3バケット内で増殖させるツール





# 作成手順
## 環境準備
### (1) IAMユーザ作成
```
PROFILE=mobilepush
USERNAME=GenTestFIle-S3OperationUser

aws --profile ${PROFILE} iam create-user --user-name ${USERNAME}
aws --profile ${PROFILE} iam wait user-exists --user-name ${USERNAME}
aws --profile ${PROFILE} iam attach-user-policy --user-name ${USERNAME} --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
aws --profile ${PROFILE} iam attach-user-policy --user-name ${USERNAME} --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess

result=$(aws --profile ${PROFILE} iam create-access-key --user-name ${USERNAME})
accesskey=$(echo ${result} | jq -r '.AccessKey.AccessKeyId')
secretkey=$(echo ${result} | jq -r '.AccessKey.SecretAccessKey')
echo "${username},${accesskey},${secretkey}"
```
S３をKMSのCMKで暗号化している場合は、CMKのキーポリシーに作成したIAMユーザを追加する。

### (2) インスタンス準備
S3にアクセス可能なEC2インスタンスを作成する
- OS: Amazon Linux 2
- インスタンスタイプ: 8xlarge(32vcpu)を選択。(このツールのテストでは、m5a.8xlargeを利用))
- 作業用ディスクとして、EBSを１つ追加
    - EBSクラス: gp2 (汎用)
    - EBSサイズ: 100GB
    - デバイス: /dev/sdf

### (3) インスタンス初期設定
インスタンス起動後に、追加したストレージのフォーマットとマウントを実行
```
DEVICE=/dev/sdf
PARTITION=${DEVICE}1
sudo parted ${DEVICE} mklabel gpt
sudo parted ${DEVICE} mkpart data 0% 100%
sleep 3
sudo mkfs.xfs ${PARTITION}
sleep 3
PARTITION_UUID=$(sudo blkid -o value ${PARTITION} |head -n 1)

sudo mkdir /data
sudo sh -c "echo UUID=${PARTITION_UUID} /data xfs defaults,noatime  1   1 >> /etc/fstab"
sudo mount -a

sudo chown ec2-user:ec2-user /data
```

ulimitの拡張(ユーザあたりの同時オープンファイル数と、同時実行プロセス数の引き上げ)
```
sudo -i
cat > /etc/security/limits.d/99-s3-test.conf
*          hard    nofile    500000
*          soft    nofile    500000

*          hard    nproc     100000
*          soft    nproc     100000

別コンソールで、sshログインし下記コマンドで設定反映を確認
ulimit -Ha
```
### (4) AWS CLI、SDK(boto3)セットアップ
AWS CLIとSDK(boto3)のインストールと設定
```
# AWS CLIとboto3(AWS Python SDK)のセットアップ
curl -o "get-pip.py" "https://bootstrap.pypa.io/get-pip.py" 
sudo python get-pip.py
sudo pip install boto3
sudo pip install --upgrade awscli

# AWS CLI設定
aws configure set aws_access_key_id <作成したIAMユーザのアクセスキー>
aws configure set aws_secret_access_key <作成したIAMユーザのシークレットキー>
aws configure set region ap-northeast-1
aws configure set output json
```
### (5) プログラムのダウンロード
```
sudo yum -y install git
cd /data
git clone https://github.com/Noppy/GenTestFiles.git
```

## マスターファイル作成とCopyObjectの実行

### (1) マスターファイル作成/アップロード/コピーリスト作成用pythonツールのためのJSONコンフィグファイル作成
マスターファイルのサイズと分布のリスト(CSV)を作成します。
master_list.csv
```
10,2940
50,2800
100,17850
以下略
"<ファイルサイズ(KB)>,<ファイル比率>"で作成します。
```
CreateMasterFilesAndConfig.shで、マスターファイルの作成、S3アップロード、リスト生成用ツールのconfig作成を行います。
```
NumberOfFiles="300000"
StartDate="2015/1/1"
EndDate="2015/1/2"
Bucket="s3-100million-files-test"

./CreateMasterFilesAndConfig.sh ${NumberOfFiles} ${StartDate} ${EndDate} ${Bucket}
```

### (2) コピーリストの作成
```
#CSV生成
./generate_testfiles_list.py

#生成したCSVの確認
wc -l list_of_copy_files.csv   #行数確認(NumberOfFilesと同じ行数が作成)
```
1億ファイルのリスト作成で15分程度かかり、作成後のCSVファイルは約10−15GB程度になります。
### (3) バケット内のオブジェクトコピー実行
```
nohup ./S3_CopyObject_ParallelExecution.sh &
```