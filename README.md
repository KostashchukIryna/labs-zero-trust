# Zero Trust Інфраструктура Безпеки для "Coastal Containers Ltd згідно туторіалу lfs482-labs в скоупі предмету Корпоративні Архітектури ПЗ
."

##  Архітектурні рішення, впроваджені поступово протягом практикуму

1. **Identity Control Plane (SPIRE):** Відмова від традиційного статичного PKI (де компрометація Root CA руйнує все) на користь динамічної ідентифікації робочих навантажень (Workload Identity). SPIRE Server та Agent реалізують двохетапну атестацію (Node Attestation через `k8s_psat` та Workload Attestation).
2. **Поділ обов'язків (PEP/PDP):** Авторизація повністю відокремлена від коду додатків. **Envoy Proxy** виступає як *Policy Enforcement Point (PEP)*, перехоплюючи трафік та перевіряючи X.509-SVID, а **OPA** діє як *Policy Decision Point (PDP)*, обчислюючи декларативні правила на мові Rego.
3. **Масштабування та Ієрархія (Nested & Federated SPIRE):** - **HA Mode:** База даних SPIRE Server перенесена з SQLite на високодоступний PostgreSQL, забезпечуючи стійкість до відмов.
   - **Nested SPIRE:** Використано ієрархічну модель (патерн Parent-Child), де глобальний SPIRE Server керує довірою для регіональних/локальних серверів.
   - **Federation & OIDC:** Реалізовано транскордонну довіру між незалежними компаніями за допомогою SPIFFE Federation, а також випуск JWT-SVID через OIDC Discovery Provider для безсекретної інтеграції з публічними хмарами (AWS, GCP).
4. **Мережева автентифікація на рівні ядра (Cilium):** Інтеграція SPIRE з Cilium Service Mesh дозволяє виконувати mTLS взаємодію на рівні eBPF, минаючи оверхед традиційних sidecar-проксі.

---

## Архітектурні Діаграми (C4 Model)

Код для діаграм знаходиться в директорії `/docs` у форматі Structurizr DSL.

---

##  Інструкція із запуску 

 використовується локальний кластер `Kind` та утиліта `make`.

### вимоги
- Linux environment (AMD64/ARM64)
- Docker & Kind
- Helm, Kubectl, Jq

### 1. Локальне розгортання інфраструктури (SPIRE + Envoy + OPA)
```shell
# Підняття кластеру Kind
make cluster-up
kubectl create -n kube-system secret generic cilium-ipsec-keys \
    --from-literal=keys="3 rfc4106(gcm(aes)) $(echo $(dd if=/dev/urandom count=20 bs=1 2> /dev/null | xxd -p -c 64)) 128"
helm repo add cilium https://helm.cilium.io/

# Розгортання базового SPIRE за допомогою Helm
make deploy-spire spire-wait-for-agent
# Cilium Agent
kubectl exec -n spire spire-server-0 -- \
    /opt/spire/bin/spire-server entry create \
    -spiffeID spiffe://coastal-containers.example/cilium-agent \
    -parentID spiffe://coastal-containers.example/agent/spire-agent \
    -selector k8s:ns:kube-system \
    -selector k8s:sa:cilium

# Cilium Operator
kubectl exec -n spire spire-server-0 -- \
    /opt/spire/bin/spire-server entry create \
    -spiffeID spiffe://coastal-containers.example/cilium-operator \
    -parentID spiffe://coastal-containers.example/agent/spire-agent \
    -selector k8s:ns:kube-system \
    -selector k8s:sa:cilium-operator

# Client Workload
kubectl exec -n spire spire-server-0 -- \
    /opt/spire/bin/spire-server entry create \
    -spiffeID spiffe://coastal-containers.example/workload/client \
    -parentID spiffe://coastal-containers.example/agent/spire-agent \
    -selector k8s:ns:default \
    -selector k8s:sa:client \
    -ttl 60

# Server Workload
kubectl exec -n spire spire-server-0 -- \
    /opt/spire/bin/spire-server entry create \
    -spiffeID spiffe://coastal-containers.example/workload/server \
    -parentID spiffe://coastal-containers.example/agent/spire-agent \
    -selector k8s:ns:default \
    -selector k8s:sa:server \
    -ttl 60

# Створення записів реєстрації для сервісів (В Vessel Client та Port Authority)
make create-registration-entries

# Компіляція та деплой мікросервісів з OPA/Envoy sidecars
make workload-images
make deploy-workloads

# Кінець роботи
make cluster down
