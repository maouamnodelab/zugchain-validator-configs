#!/bin/bash
# ==========================================================
# ZUG CHAIN - VALIDATOR JOINER v8.9 (CLEAN & LOCAL)
# ==========================================================

set -e
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- DİZİN YAPILANDIRMASI (YEREL) ---
ZUG_DIR="/opt/zugchain"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Script 'validator/' klasöründeyse, REPO_ROOT bir üst klasördür.
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# --- GUNCEL AG BILGILERI (MASTER'DAN ALINAN) ---
BOOTSTRAP_NODE="enr:-Mq4QPpJQUobFlSMEhThMxIP8V0ebubpPpvVwAx4I1Ivs8zSDimzaPADhmK6jnxynVqBARF3LsS1fsrAe5tmjA8UoUuGAZxxDbW0h2F0dG5ldHOIAABgAAAAAACEZXRoMpCBoWmuIAAABABMBgAAAAAAgmlkgnY0gmlwhGw9d8yEcXVpY4IyyIlzZWNwMjU2azGhAoK5g4shpHW3Fyay7kSXSKPNJ7o2M3nn9qzHHIFWXKcXiHN5bmNuZXRzD4N0Y3CCMsiDdWRwgi7g"
BOOTNODE_ENODE="enode://224395d45815cb18e08ccb844cc9902c79094e58dd64f5fbb789066e56025d8501d04f4dc84c19cff52dbb210a3c6ae7a8db6a56577214234118591d9252a588@108.61.119.204:30303"
# --- INTERAKTIF GIRDI ---
echo -e "${GREEN}>>> ZUG Chain Validator Kurulumuna Hosgeldiniz.${NC}"
echo ""
echo -e "${YELLOW}>>> Lutfen Blok Odullerinin (Fee Recipient) yatacagi cuzdan adresini girin:${NC}"
read -p "Cuzdan Adresi [Varsayilan: 0x98CE9...]: " USER_FEE_RECIPIENT

# Kullanıcı boş bırakırsa varsayılan adresi ata
FEE_RECIPIENT=${USER_FEE_RECIPIENT:-"0x98CE9a541aFCfCa53804702F9d273FE1bB653eA9"}
echo -e "${GREEN}>>> Secilen Cuzdan: ${FEE_RECIPIENT}${NC}"
echo ""

PUBLIC_IP=$(curl -s ifconfig.me)

echo -e "${GREEN}>>> ZUG Chain Validator (Smart Install) Basliyor...${NC}"

# --- 1. MIMARI ALGILAMA ---
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    ARCH_DIR="x86"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    ARCH_DIR="arm64"
else
    echo -e "${RED}HATA: Desteklenmeyen mimari: $ARCH${NC}"
    exit 1
fi
echo -e "${GREEN}>>> Mimari: $ARCH ($ARCH_DIR)${NC}"

# --- 2. TEMIZLIK ---
echo -e "${YELLOW}>>> Eski veriler temizleniyor...${NC}"
systemctl stop zugchain-* 2>/dev/null || true
rm -rf ${ZUG_DIR}/config ${ZUG_DIR}/data
mkdir -p ${ZUG_DIR}/{data,config,logs}
mkdir -p ${ZUG_DIR}/data/{geth,beacon,validators}

# --- 3. YEREL DOSYA KONTROLÜ VE KOPYALAMA ---
# Binaryler ana dizindeki bin/ klasöründen alınır
BIN_SOURCE="${REPO_ROOT}/bin/${ARCH_DIR}"
# Configler scriptin yanındaki config/ klasöründen alınır
CONFIG_SOURCE="${SCRIPT_DIR}/config"

echo -e "${GREEN}>>> Dosyalar yerel repo klasörlerinden kopyalanıyor...${NC}"

# Binary Kontrolü
if [ ! -f "$BIN_SOURCE/beacon-chain" ]; then
    echo -e "${RED}HATA: Binary bulunamadı: $BIN_SOURCE/beacon-chain${NC}"
    exit 1
fi

# Kopyala (Yerelden Sisteme)
cp -f "$BIN_SOURCE/beacon-chain" /usr/local/bin/
cp -f "$BIN_SOURCE/validator" /usr/local/bin/
chmod +x /usr/local/bin/beacon-chain /usr/local/bin/validator

# Config Kopyala (Yerelden /opt/zugchain'e)
if [ -d "$CONFIG_SOURCE" ]; then
    cp -f "$CONFIG_SOURCE"/* "${ZUG_DIR}/config/"
else
    echo -e "${RED}HATA: Config klasörü bulunamadı: $CONFIG_SOURCE${NC}"
    exit 1
fi

# --- 4. AYARLAR VE INIT ---
openssl rand -hex 32 > ${ZUG_DIR}/data/jwt.hex
chmod 600 ${ZUG_DIR}/data/jwt.hex
geth init --datadir "${ZUG_DIR}/data/geth" --state.scheme=path "${ZUG_DIR}/config/genesis.json"

# --- 5. SERVISLER (SYSTEMD) ---
# (Buradaki servis blokları senin v5.0 stabilite ayarlarınla aynıdır)

# Geth
cat > /etc/systemd/system/zugchain-geth.service <<EOF
[Unit]
Description=ZUG Chain Geth
After=network.target
[Service]
User=root
ExecStart=/usr/bin/geth \\
    --datadir=${ZUG_DIR}/data/geth \\
    --networkid=19024561 \\
    --http --http.addr=0.0.0.0 --http.port=8545 \\
    --authrpc.addr=127.0.0.1 --authrpc.port=8551 \\
    --authrpc.jwtsecret=${ZUG_DIR}/data/jwt.hex \\
    --syncmode=full --gcmode=archive \\
    --bootnodes="${BOOTNODE_ENODE}" \\
    --port 30303
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

# Beacon
cat > /etc/systemd/system/zugchain-beacon.service <<EOF
[Unit]
Description=ZUG Chain Beacon
After=zugchain-geth.service
[Service]
User=root
ExecStart=/usr/local/bin/beacon-chain \\
    --datadir=${ZUG_DIR}/data/beacon \\
    --genesis-state=${ZUG_DIR}/config/genesis.ssz \\
    --chain-config-file=${ZUG_DIR}/config/config.yml \\
    --execution-endpoint=http://127.0.0.1:8551 \\
    --jwt-secret=${ZUG_DIR}/data/jwt.hex \\
    --accept-terms-of-use \\
    --rpc-host=0.0.0.0 \\
    --p2p-host-ip=${PUBLIC_IP} \\
    --p2p-tcp-port=13000 \\
    --p2p-udp-port=12000 \\
    --min-sync-peers=1 \\
    --bootstrap-node="${BOOTSTRAP_NODE}"
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

# Validator
cat > /etc/systemd/system/zugchain-validator.service <<EOF
[Unit]
Description=ZUG Chain Validator
After=zugchain-beacon.service
[Service]
User=root
ExecStart=/usr/local/bin/validator \\
    --datadir=${ZUG_DIR}/data/validators \\
    --beacon-rpc-provider=127.0.0.1:4000 \\
    --chain-config-file=${ZUG_DIR}/config/config.yml \\
    --accept-terms-of-use \\
    --wallet-dir=${ZUG_DIR}/data/validators \\
    --suggested-fee-recipient=${FEE_RECIPIENT}
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zugchain-geth zugchain-beacon zugchain-validator
systemctl start zugchain-geth
sleep 5
systemctl start zugchain-beacon

echo -e "${GREEN}>>> ZUG Chain Validator Basariyla Kuruldu!${NC}"
echo -e "${YELLOW}>>> Artik 'git clone' döngüsünden kurtulduk, yerel repo kullanılıyor.${NC}"
