# ⚡ ZUG CHAIN - Enterprise Blockchain Deployment Suite (v8.0)

**ZUG Chain**, Ethereum tabanlı (EVM), Proof-of-Stake (PoS) konsensüs mekanizmasına sahip, yüksek performanslı ve özelleştirilmiş bir blokzincir ağıdır. Bu depo (repository), ağın sıfırdan kurulumu (Master Node) ve ağa katılım (Validator Node) süreçlerini otomatize eden araçları içerir.

Bu yapı **Otomatik Mimari Algılama (Auto-Architecture Detection)** özelliğine sahiptir. Scriptler, sunucunuzun **x86_64** (Intel/AMD) veya **ARM64** olduğunu algılar ve `bin/` klasöründen doğru dosyaları otomatik kullanır.

---

## 📋 İçindekiler
1. [Sistem Gereksinimleri](#-sistem-gereksinimleri)
2. [Repo Mimarisi](#-repo-mimarisi)
3. [Rolünüzü Seçin](#-rolünüzü-seçin)
4. [Bölüm 1: Master Node Kurulumu](#-bölüm-1-master-node-kurulumu-sadece-yönetici)
5. [Bölüm 2: Validator Kurulumu](#-bölüm-2-validator-kurulumu-ağa-katılım)
6. [Operasyon ve Yönetim](#-operasyon-ve-yönetim)
7. [Sorun Giderme](#-sorun-giderme)

---

## 🖥️ Sistem Gereksinimleri

ZUG Chain, yüksek performanslı bir ağdır. Stabilite için aşağıdaki donanım özellikleri önerilir:

| Donanım | Minimum | Önerilen (Prodüksiyon) |
| :--- | :--- | :--- |
| **CPU** | 4 Çekirdek | 8 Çekirdek (AMD Ryzen / Intel Xeon / Apple M-Series) |
| **RAM** | 16 GB | 32 GB+ |
| **Disk** | 500 GB SSD | 2 TB NVMe SSD |
| **OS** | Ubuntu 22.04 LTS | Ubuntu 24.04 LTS |
| **Network** | 100 Mbps | 1 Gbps Fiber (Statik IP Şart) |

---

## 📂 Repo Mimarisi

* **`chain/`**: Master Node (Zincirin ilk halkası) kurulum dosyaları.
* **`validator/`**: Ağa sonradan katılacak node'lar için kurulum dosyaları.
* **`bin/`**: Mimariye özel derlenmiş binary dosyaları (`geth`, `beacon-chain`, `validator`).
    * `bin/x86`: Intel/AMD işlemciler için.
    * `bin/arm64`: ARM (Mac M1/M2, AWS Graviton vb.) işlemciler için.
* **`config/`**: Genesis ve ağ konfigürasyon dosyalarının saklandığı alan.

---

## 🎭 Rolünüzü Seçin

Kuruluma başlamadan önce rolünüzü belirleyin:

1.  **MASTER NODE (Yönetici):** Zinciri sıfırdan kuracak, genesis bloğunu oluşturacak ve token ekonomisini başlatacak kişidir. **(Sadece 1 kişi yapar).**
2.  **VALIDATOR NODE (Katılımcı):** Var olan, çalışan bir ağa bağlanarak validatör (onaylayıcı) olmak isteyen kişidir.

---

## 🚀 BÖLÜM 1: Master Node Kurulumu (Sadece Yönetici)

Bu adımlar, zinciri **İLK KEZ** başlatacak olan yönetici içindir.

### Adım 1: Repoyu İndirin ve Hazırlayın
*(Not: `KULLANICI_ADI` kısmını kendi GitHub kullanıcı adınızla değiştirin)*

```bash
git clone https://github.com/KULLANICI_ADI/zugchain-repo.git
cd zugchain-repo/chain
chmod +x setup_chain.sh
```

### Adım 2: Kurulumu Başlatın
Script interaktiftir. Size validator sayısı, SSL domaini gibi sorular soracaktır.

```bash
sudo ./setup_chain.sh
```

### Adım 3: 🚨 KRİTİK - Konfigürasyon Dağıtımı
Zincir kurulduktan sonra oluşan `genesis.json`, `config.yml` ve `genesis.ssz` dosyaları, diğer insanların ağa bağlanabilmesi için hayati önem taşır. Bu dosyaları repoya yüklemelisiniz:

```bash
# 1. Dosyaları validator klasörüne kopyalayın
cp /opt/zugchain/config/genesis.json ../validator/config/
cp /opt/zugchain/config/config.yml ../validator/config/
cp /opt/zugchain/config/genesis.ssz ../validator/config/

# 2. Değişiklikleri GitHub'a gönderin
cd ..
git add .
git commit -m "Genesis Configs Update for New Chain Launch"
git push origin main
```
> **Uyarı:** Bu adım yapılmazsa, Validator scriptleri çalışmayacaktır!

---

## 🔗 BÖLÜM 2: Validator Kurulumu (Ağa Katılım)

Mevcut çalışan ZUG Chain ağına bağlanmak isteyenler bu adımları izlemelidir.

### Ön Hazırlık (Gerekli Bilgiler)
Kuruluma başlamadan önce Master Node Sahibinden aşağıdaki bilgileri talep edin. Script kurulum sırasında bunları soracaktır:

*   **Master Node IP Adresi:** (Örn: `108.61.119.204`)
*   **Bootnode ENODE:** (`enode://...` ile başlayan uzun kod)
*   **Bootstrap ENR:** (`enr:-...` ile başlayan kod)

### Adım 1: Repoyu İndirin

```bash
git clone https://github.com/KULLANICI_ADI/zugchain-repo.git
cd zugchain-repo/validator
chmod +x join_network.sh
```

### Adım 2: Kurulumu Başlatın
Script, işlemci mimarinizi otomatik algılar ve Master Node'a bağlanmak için gerekli ayarları yapar.

```bash
sudo ./join_network.sh
```

### Adım 3: Cüzdan Import (Validator Aktivasyonu)
Node kurulduktan sonra, validatör cüzdan dosyalarınızı (`keystores`) sunucuya yükleyin (örneğin SFTP ile) ve aşağıdaki komutla içe aktarın:

```bash
# Örnek Kullanım
/usr/local/bin/validator accounts import \
    --keys-dir=/home/kullanici/validator_keys \
    --wallet-dir=/opt/zugchain/data/validators

# Parola soracaktır, cüzdan parolanızı girin.
```

### Adım 4: Servisi Başlatın
Cüzdan import işlemi başarıyla tamamlandıktan sonra validatör servisini başlatın:

```bash
sudo systemctl start zugchain-validator
```

---

## 🛠 Operasyon ve Yönetim
Node yönetimi için aşağıdaki komutları kullanabilirsiniz.

### Servis Durumlarını Kontrol Etme

```bash
# Execution Layer (Geth - Blok İşleme)
systemctl status zugchain-geth

# Consensus Layer (Beacon Chain - P2P ve Senkronizasyon)
systemctl status zugchain-beacon

# Validator Client (Onaylama ve İmza)
systemctl status zugchain-validator
```

### Logları İzleme (Hata Ayıklama)

```bash
# Geth Logları (Canlı Akış)
journalctl -fu zugchain-geth

# Beacon Logları (Peer sayısı, senkronizasyon vb.)
journalctl -fu zugchain-beacon

# Validator Logları (Ödül, Attestation vb.)
journalctl -fu zugchain-validator
```

### Servisleri Durdurma/Yeniden Başlatma

```bash
# Hepsini durdur
sudo systemctl stop zugchain-geth zugchain-beacon zugchain-validator

# Hepsini yeniden başlat
sudo systemctl restart zugchain-geth zugchain-beacon zugchain-validator
```

---

## ❓ Sorun Giderme

### 1. "Peer Sayısı 0 Görünüyor"
*   Portların açık olduğundan emin olun: `30303` (TCP/UDP), `13000` (TCP), `12000` (UDP).
*   Master Node'un `BOOTNODE_ENODE` adresinin doğru girildiğini kontrol edin.
*   Zaman senkronizasyonunu kontrol edin: `sudo timedatectl set-ntp on`.

### 2. "Genesis Hash Mismatch" Hatası
*   Master Node sahibi config dosyalarını güncellememiş olabilir. Repoyu silip (`rm -rf zugchain-repo`) yeniden çekin (`git clone`).

### 3. "Permission Denied" Hatası
*   Scriptleri `sudo` ile çalıştırdığınızdan emin olun.

### 4. Validator "Waiting for beacon chain" diyor
*   Beacon Chain henüz senkronize olmamış olabilir. `journalctl -fu zugchain-beacon` ile senkronizasyon durumunu kontrol edin. Beacon hazır olduğunda validator otomatik başlayacaktır.
