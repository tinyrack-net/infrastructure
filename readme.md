# 타이니랙 인프라

`*.tinyrack.net` 서비스의 쿠버네티스 배포용 GitOps 프로젝트에요. 저장소의 변경사항 발생 시 [Flux](https://fluxcd.io/)를 통해 리모트 서버와 동기화 돼요.

현재 제 인프라는 저비용 운영을 위해 단일 머신에서 동작하고 있어요. 그런데도 쿠버네티스를 쓰는 이유는 Git 으로 인프라를 관리하고 재현성과 재해 복구성을 높이기 위함이에요.

이 클러스터는 클라우드플레어 터널과 테일스케일을 활용해서 **제로 트러스트**로 구축되어 있어요. 그래서 인그레스 컨트롤러(Ingress Controller)나 로드 밸런서(Load Balencer)는 사용하지 않아요.

서비스의 모든 영구 데이터(Persistant Data)는 클러스터 내부에 저장돼요. 다시 말해서, 모두가 기피하는 **상태가 있는(Stateful) 쿠버네티스에요.** 모든 영구 볼륨은 [Longhorn](https://longhorn.io/)을 통해 관리되며, 일정 주기마다 외부 오브젝트 스토리지로 백업되도록 구성되어 있어요.

본 문서는 현재 클러스터의 구조와 설치 과정과 함께, 인프라 이동이나 재해 복구 상황에서의 복원 과정을 안내하고 있어요.

---

# 인프라 구성

- etcd: 클러스터 데이터베이스
- cloudflared: 클라우드플레어 프록시 서버와 연결, 로드 밸런싱
- tailscale: 쿠버네티스 API를 안전하게 노출
- Sealed Secrets: 쿠버네티스 시크릿 관리
- Longhorn: 블록 스토리지 관리/백업/복원

# 서비스 구성

- [Ghost](https://ghost.org/): 타이니랙 블로그 (https://tinyrack.net)
- [Discourse](https://www.discourse.org/): 타이니랙 포럼 (https://forum.tinyrack.net)
- [Memos](https://www.usememos.com/): 타이니랙 작업 노트 (https://notes.tinyrack.net)

---

# 하드웨어 요구사항

- open-isci 와 nfsv4 를 지원하는 리눅스 ([Longhorn 요구사항](https://longhorn.io/docs/1.9.0/deploy/install/#installing-open-iscsi))
  - 우분투 24.04 이상이라면 nfs-common 을 설치하면 돼요.

---

# 설치

## Tailscale 설치

```bash
sudo tailscale up --accept-dns=false
```

## K3S 설치

쿠버네티스는 [K3S](https://k3s.io/)라는 가벼운 배포판을 사용하고 있어요. 설치는 다음의 명령어를 통해 간단히 할 수 있어요.

```bash
curl -fL https://get.k3s.io | \
sh -s - server \
  --cluster-init \
  --cluster-cidr=10.53.0.0/16 \
  --service-cidr=10.54.0.0/16 \
  --disable traefik \
  --disable servicelb \
  --disable local-storage \
  --tls-san "$(tailscale ip -4)" \
  --tls-san "127.0.0.1"
```

설치에는 두가지 옵션을 사용해요.

- `--cluster-init`: 추후 고가용성 확장을 위해 `SQLite` 대신 `etcd` 를 클러스터 데이터베이스로 사용해요.
- `--cluster-cidr=10.53.0.0/16`: 클러스터의 노드가 할당받는 IP 주소 범위를 변경해요.
- `--service-cidr=10.54.0.0/16`: 클러스터의 서비스가 할당받는 IP 주소 범위를 변경해요.
- `--disable traefik`: 기본 인그레스 컨트롤러를 비활성화해요. 이는 클라우드플레어가 대신해요.
- `--disable servicelb`: 기본 로드 밸런서를 비활성화해요. 이는 클라우드플레어가 대신해요.
- `--disable local-storage`: 로컬 스토리지를 비활성화해요. 대신 Longhorn 을 사용해요.
- `--tls-san IP`: Tailscale IP를 통해서만 쿠버네티스 API를 호출할 수 있도록 제한해요.

## Sealed Secrets 키 등록

저장소 내의 모든 키는 `sealed-secrets`를 통해 암호화되어 전달됩니다. 인프라를 옮긴다면 먼저 사용하던 복호화 키(비밀키)를 복원해야 합니다.

```bash
# sealed secrets 이 설치될 네임스페이스 생성
sudo kubectl create namespace sealed-secrets
# 기존 키 복원
sudo kubectl -n sealed-secrets apply -f main.key.yaml --force
```

## Flux 부트스트랩

Flux 를 통해 모든 인프라를 복원합니다.

```bash
flux bootstrap github \
  --owner=tinyrack94 \
  --repository=infrastructure \
  --branch=main \
  --path=./clusters/production \
  --owner=tinyrack-net
```

ETCD 백업을 활성화 합니다.

## ETCD 백업 활성화

```bash
sudo -s

cat > /etc/rancher/k3s/config.yaml << EOF
etcd-s3: true
etcd-s3-config-secret: k3s-etcd-s3-secret
EOF

systemctl restart k3s
```

---

```bash
curl -fL https://get.k3s.io | sh -s - server --cluster-init --disable traefik --disable servicelb 
```

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

```bash
curl -fL https://get.k3s.io | K3S_TOKEN=MYSECRET sh -s - server --disable traefik --disable servicelb --server https://k3s-1.server.lan:6443
```

# kubeconfig

```bash
sudo vi /etc/rancher/k3s/k3s.yaml
```

# Seal

```bash
kubectl create secret generic docmost-secret \
        --namespace docmost-system \
        --dry-run=client \
        --from-literal=SOME_SECRET_KEY=SOME_SECRET_VALUE \
        --from-literal=SOME_SECRET_KEY=SOME_SECRET_VALUE \
        --from-literal=SOME_SECRET_KEY=SOME_SECRET_VALUE -o yaml \
        | kubeseal --cert ./tinyrack-production-key.crt \
        > ./some.secret.yaml
```

# Backup & Restore

키 백업
```
kubectl get secret -n selaled-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > main.key
```

키 복원
```
kubectl apply -f main.key
kubectl delete pod -n sealed-secrets -l name=sealed-secrets-controller
```

# require

- kubeseal
- flux

# 재해 복구

클러스터가 완전히 망가지거나, 인프라 전체를 옮겨야 하는 시나리오에서의 복원 과정입니다.

먼저 위 설치 과정을 참고해 K3S를 설치하고 `sealed-secret` 키를 복원합니다. 그 다음 프로젝트에서 `clusters/production/apps.yaml` 파일의 확장자 뒤에 `.bak` 을 붙여 커밋합니다.

이는 `Flux CD`를 부트스트랩 할 때, 서비스가 설치되며 새로운 `PVC` 볼륨이 할당되지 않도록 하기 위함입니다.

```bash

```


# Longhorn

우분투에 설치된 multipathd 와 longhorn 이 충돌할 수 있어서 비활성화

```bash
systemctl disable multipathd
systemctl stop multipathd
```