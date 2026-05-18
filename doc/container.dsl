workspace "Coastal Containers Container Diagram" "Рівень 2: Контейнери та сервіси системи" {

    model {
        captain = person "Капітан судна (Ship Captain)" "Користувач, що має обмежений доступ лише до свого судна."
        supervisor = person "Диспетчер флоту (Fleet Supervisor)" "Користувач із повним доступом до всіх маніфестів."
        externalCloud = softwareSystem "Зовнішня Хмара (AWS/GCP)" "Зовнішня хмарна інфраструктура."

        coastalSystem = softwareSystem "Coastal Containers Platform" {
            
            # Вхідна група та мережа
            ingress = container "Contour Ingress (Envoy)" "Вхідний шлюз кластера. Термінує зовнішній TLS, динамічно отримує identity через SDS." "Go/Envoy" "Ingress"
            
            # Навантаження (Workloads)
            vesselClient = container "Vessel Client Application" "Додаток на борту судна для автоматичної відправки маніфестів." "Go (Go-SPIFFE)" "Workload"
            portAuthority = container "Port Authority Server" "Внутрішній Go-мікросервіс обробки портових записів." "Go" "Workload"
            
            # Безпека (Sidecars / PEP & PDP)
            sidecarEnvoy = container "Envoy Proxy (Sidecar / PEP)" "Точка перехоплення трафіку, термінації mTLS та передачі контексту в OPA." "Envoy" "Security"
            sidecarOpa = container "OPA Engine (Sidecar / PDP)" "Обчислює декларативні політики доступу (Rego) на основі SPIFFE ID та токенів." "Open Policy Agent" "Security"
            
            # Дані
            database = container "Port Records DB (HA)" "Високодоступна база даних портових маніфестів." "PostgreSQL" "Database"

            # Інфраструктура безпеки SPIRE
            spireServer = container "SPIRE Server Cluster (HA)" "Центр видачі та керування ідентифікаторами (Identity Provider)." "Go / SPIRE" "ControlPlane"
            spireAgent = container "SPIRE Agent (DaemonSet)" "Локальний агент на ноді Kubernetes. Виконує атестацію та хостить Workload API." "Go / SPIRE" "ControlPlane"
            oidcProvider = container "SPIRE OIDC Discovery Provider" "Публікує OIDC метадані та JWKS для зовнішньої верифікації токенів." "Go / SPIRE" "ControlPlane"
        }

        # Взаємодія користувачів через Ingress
        captain -> ingress "Перегляд маніфесту [HTTPS/TLS]"
        supervisor -> ingress "Повний адмін-доступ до записів [HTTPS/TLS]"
        ingress -> sidecarEnvoy "Маршрутизує запит до Port Authority"

        # Взаємодія між сервісами (mTLS Mesh)
        vesselClient -> sidecarEnvoy "Надсилає дані судна (mTLS за допомогою go-spiffe / Cilium)"

        # Внутрішня логіка пода (PEP/PDP паттерн)
        sidecarEnvoy -> sidecarOpa "Запитує рішення про допуск (gRPC ExtAuthz із передачею SPIFFE ID)"
        sidecarEnvoy -> portAuthority "Проксіює дозволений трафік [Localhost]"
        portAuthority -> database "Читає/пише портові записи"

        # Стрічки доставки ідентичності (SPIRE Control Plane)
        spireAgent -> spireServer "Проходить Node Attestation (k8s_psat)"
        vesselClient -> spireAgent "Отримує SVID через Workload API Unix Socket"
        sidecarEnvoy -> spireAgent "Автоматично оновлює сертифікати через SDS API"
        
        # Зовнішня федерація
        spireServer -> oidcProvider "Синхронізує відкриті ключі підпису (JWKS)"
        oidcProvider -> externalCloud "Надає ключі через /.well-known/openid-configuration"
    }

    views {
        container coastalSystem "Containers" "Діаграма контейнерів архітектури Zero Trust (Level 2)" {
            include *
            autolayout tb
        }

        theme default

        styles {
            element "Ingress" {
                background #43a047
                color #ffffff
            }
            element "Workload" {
                background #1565c0
                color #ffffff
            }
            element "Security" {
                background #e65100
                color #ffffff
            }
            element "Database" {
                background #795548
                color #ffffff
            }
            element "ControlPlane" {
                background #6a1b9a
                color #ffffff
            }
        }
    }
}