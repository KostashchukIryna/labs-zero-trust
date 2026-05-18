workspace "Coastal Containers System Context" "Рівень 1: Загальний контекст системи безпеки Zero Trust" {

    model {
        # Зовнішні актори
        captain = person "Капітан судна (Ship Captain)" "Користувач, що має обмежений доступ лише до свого судна."
        supervisor = person "Диспетчер флоту (Fleet Supervisor)" "Користувач із повним доступом до всіх маніфестів."
        
        # Зовнішні системи
        externalCloud = softwareSystem "Зовнішня Хмара (AWS/GCP)" "Зовнішня хмарна інфраструктура компанії, що перевіряє права через OIDC. Емульовано локально через curl-тести"

        # Наша система як єдиний елемент
        coastalSystem = softwareSystem "Coastal Containers Platform" "Головна Zero Trust інфраструктура управління портами, суднами та безпекою (SPIFFE/SPIRE + OPA)."

        # Взаємодії
        captain -> coastalSystem "Відправляє маніфести судна та переглядає дозволені записи [HTTPS]"
        supervisor -> coastalSystem "Переглядає та керує всією базою портових маніфестів [HTTPS]"
        coastalSystem -> externalCloud "Автентифікує локальні навантаження у хмарі через OIDC Федерацію без статичних секретів"
    }

    views {
        systemContext coastalSystem "SystemContext" "Діаграма загального контексту системи (Level 1)" {
            include *
            autolayout lr
        }

        theme default
        
        styles {
            element "Person" {
                background #08427b
                color #ffffff
            }
            element "Software System" {
                background #1168bd
                color #ffffff
            }
        }
    }
}