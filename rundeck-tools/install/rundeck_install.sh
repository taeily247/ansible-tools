RDECK_SERVER_IP="192.168.1.1"
### 폴더 생성
mkdir -p /APP/{rundeck.d,pkgs}

### Rundeck war파일 다운로드
wget https://packagecloud.io/pagerduty/rundeck/packages/java/org.rundeck/rundeck-5.8.0-20241205.war/artifacts/rundeck-5.8.0-20241205.war/download?distro_version_id=167 \
-O /APP/rundeck.d/rundeck-5.8.0-20241205.war

### Rundeck 홈경로 지정
export RDECK_BASE="/APP/rundeck.d"

cd $RDECK_BASE
java -Xmx4g -jar rundeck-5.8.0-20241205.war

expoirt PATH=$PATH:$RDECK_BASE/tools/bin
export MANPATH=$MANPATH:$RDECK_BASE/docs/man

### war파일 실행, 종료
java -Xmx4g -jar rundeck-5.8.0-20241205.war
# ctrl + c

### rundeck-config.properties파일 수정후 재기동
cp -p $RDECK_BASE/server/config/rundeck-config.properties $RDECK_BASE/server/config/rundeck-config.properties.bk_$(date +%y%m%d_%H%M%S)
sed -i 's/server.address/#&/g' $RDECK_BASE/server/config/rundeck-config.properties
sed -i '/^#server.address/a\server.address=0.0.0.0' $RDECK_BASE/server/config/rundeck-config.properties

sed -i 's/grails.serverURL/#&/g' $RDECK_BASE/server/config/rundeck-config.properties
sed -i '/^#grails.serverURL/a\grails.serverURL=http://${RDECK_SERVER_IP}:4440' $RDECK_BASE/server/config/rundeck-config.properties

### 업데이트 후 다시 수행
java -Xmx4g -jar rundeck-5.8.0-20241205.war

### Ansible 설정
mkdir -p /DATA/ansible.d/os_hardenning