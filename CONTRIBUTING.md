# Contributing to Vanity Expense Logbook

Vielen Dank für dein Interesse, zum Vanity Expense Logbook beizutragen! 🚀

## 📋 Inhaltsverzeichnis

- [Code of Conduct](#code-of-conduct)
- [Wie kann ich beitragen?](#wie-kann-ich-beitragen)
- [Development Setup](#development-setup)
- [Pull Request Prozess](#pull-request-prozess)
- [Coding Guidelines](#coding-guidelines)
- [Testing](#testing)

---

## Code of Conduct

### Unsere Standards

- Respektvoller Umgang mit allen Contributors
- Konstruktives Feedback geben und annehmen
- Fokus auf das Beste für die Community
- Empathie gegenüber anderen zeigen

---

## Wie kann ich beitragen?

### 🐛 Bugs melden

Bugs werden über [GitHub Issues](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues) verwaltet.

**Vor dem Erstellen eines Bug-Reports:**
- Prüfe, ob der Bug bereits gemeldet wurde
- Sammle relevante Informationen (iOS Version, Device, Steps to Reproduce)

**Guter Bug-Report enthält:**
- Klare Beschreibung des Problems
- Schritte zur Reproduktion
- Erwartetes vs. tatsächliches Verhalten
- Screenshots (falls relevant)
- Umgebungsinformationen

### 💡 Feature Requests

Feature-Vorschläge sind willkommen!

**Bitte beachte:**
- Erkläre das "Warum" hinter dem Feature
- Beschreibe mögliche Implementierungen
- Überlege, wer davon profitieren würde

### 🔧 Code beitragen

1. **Fork das Repository**
2. **Erstelle einen Feature Branch** (`git checkout -b feature/AmazingFeature`)
3. **Committe deine Änderungen** (`git commit -m 'Add some AmazingFeature'`)
4. **Push zum Branch** (`git push origin feature/AmazingFeature`)
5. **Öffne einen Pull Request**

---

## Development Setup

### Voraussetzungen

- **Xcode:** 15.0 oder höher
- **iOS:** Deployment Target 15.0+
- **Swift:** 5.9+
- **macOS:** 13.0+ (Ventura)

### Setup-Schritte

1. **Repository klonen**
   ```bash
   git clone https://github.com/OliverGiertz/Vanity-Expense-Logbook.git
   cd Vanity-Expense-Logbook
   ```

2. **Xcode öffnen**
   ```bash
   open CamperLogBook.xcodeproj
   ```

3. **Dependencies installieren** (falls SPM verwendet wird)
   - Xcode installiert automatisch beim ersten Build

4. **Build & Run**
   - Wähle ein Simulator oder Device
   - Cmd + R zum Starten

### Projekt-Struktur

```
CamperLogBook/
├── Models/              # CoreData Entities
├── Views/               # SwiftUI Views
│   ├── Entry/          # Eintrags-Formulare
│   ├── Overview/       # Übersichts-Views
│   ├── Analysis/       # Statistik-Views
│   └── Profile/        # Profil & Settings
├── Managers/            # Business Logic
│   ├── LocationManager
│   ├── BackupManager
│   └── PremiumFeatureManager
├── Helpers/             # Utilities
└── Resources/           # Assets, Localizations
```

---

## Pull Request Prozess

### Checkliste vor dem PR

- [ ] Code kompiliert ohne Warnungen
- [ ] Alle Tests laufen durch
- [ ] Code folgt den Style Guidelines
- [ ] Kommentare für komplexe Logik
- [ ] README/Docs aktualisiert (falls nötig)
- [ ] Screenshots für UI-Änderungen

### PR-Beschreibung Template

```markdown
## Beschreibung
Was ändert dieser PR?

## Motivation
Warum ist diese Änderung notwendig?

## Typ der Änderung
- [ ] Bug Fix
- [ ] Neues Feature
- [ ] Breaking Change
- [ ] Dokumentation

## Testing
Wie wurde getestet?

## Screenshots (optional)
Bei UI-Änderungen bitte Screenshots hinzufügen

## Checklist
- [ ] Code kompiliert
- [ ] Tests hinzugefügt/aktualisiert
- [ ] Dokumentation aktualisiert
```

### Review-Prozess

1. Maintainer reviewed innerhalb von 3-5 Tagen
2. Feedback wird konstruktiv gegeben
3. Nach Approval: Merge durch Maintainer

---

## Coding Guidelines

### Swift Style Guide

Wir folgen den [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/).

#### Naming Conventions

```swift
// ✅ Gut
class UserProfileManager { }
func fetchUserData() async throws -> User { }
var isBackupEnabled: Bool = false

// ❌ Schlecht
class UPM { }
func getData() -> Any { }
var flag: Bool = false
```

#### SwiftUI Best Practices

```swift
// ✅ Gut: Kleine, wiederverwendbare Views
struct EntryCard: View {
    let entry: FuelEntry
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(entry.date, style: .date)
            Text(entry.totalCost, format: .currency(code: "EUR"))
        }
    }
}

// ❌ Schlecht: Alles in einem View
struct MassiveView: View {
    var body: some View {
        // 500 Zeilen Code...
    }
}
```

#### Async/Await statt Closures

```swift
// ✅ Gut
func loadData() async throws {
    let data = try await networkManager.fetch()
    await MainActor.run {
        self.items = data
    }
}

// ❌ Vermeiden (außer bei Legacy Code)
func loadData(completion: @escaping (Result<[Item], Error>) -> Void) {
    networkManager.fetch { result in
        DispatchQueue.main.async {
            completion(result)
        }
    }
}
```

#### Memory Management

```swift
// ✅ Gut: [weak self] in Closures
button.action = { [weak self] in
    self?.performAction()
}

// ❌ Retain Cycle Gefahr
button.action = {
    self.performAction()
}
```

### CoreData Best Practices

```swift
// ✅ Gut: Batch Operations für viele Objekte
let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
try context.execute(batchDelete)

// ❌ Schlecht: Einzeln löschen
for item in items {
    context.delete(item)
}
```

### Code Organization

```swift
// ✅ Gut: Extensions für Protokoll-Konformität
extension MyView: Equatable {
    static func == (lhs: MyView, rhs: MyView) -> Bool {
        // ...
    }
}

// MARK: - Private Methods
private extension MyView {
    func setupUI() { }
    func loadData() { }
}
```

---

## Testing

### Unit Tests

```swift
import Testing

@Suite("FuelEntry Tests")
struct FuelEntryTests {
    
    @Test("Calculate average consumption")
    func calculateConsumption() async throws {
        let entry = FuelEntry(context: context)
        entry.liters = 50.0
        entry.currentKm = 1000
        
        let consumption = entry.calculateConsumption()
        #expect(consumption > 0)
    }
}
```

### UI Tests

```swift
@Test("Create new fuel entry")
func createFuelEntry() async throws {
    let app = XCUIApplication()
    app.launch()
    
    app.tabBars.buttons["Eintrag"].tap()
    app.buttons["Tanken"].tap()
    
    // Fill form
    app.textFields["Liter"].tap()
    app.textFields["Liter"].typeText("50.5")
    
    app.buttons["Speichern"].tap()
    
    #expect(app.navigationBars["Übersicht"].exists)
}
```

### Test Coverage Ziele

- Unit Tests: > 70%
- Critical Paths: 100% (Backup, Payment, Data Loss Prevention)

---

## Commit Messages

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: Neues Feature
- `fix`: Bug Fix
- `docs`: Dokumentation
- `style`: Formatierung
- `refactor`: Code-Umstrukturierung
- `test`: Tests hinzufügen
- `chore`: Wartung

### Beispiele

```
feat(backup): Add iCloud backup encryption

- Implement AES-256 encryption
- Store keys in Keychain
- Add user setting to enable/disable

Closes #123
```

```
fix(map): Prevent crash when no GPS data available

Added nil check for location data before rendering map pins.

Fixes #456
```

---

## Branches

### Branch-Naming

- `feature/feature-name` - Neue Features
- `fix/bug-description` - Bug Fixes
- `docs/documentation-update` - Dokumentation
- `refactor/code-improvement` - Refactoring

### Beispiele

```
feature/widgets-implementation
fix/backup-crash-on-restore
docs/update-readme
refactor/async-await-migration
```

---

## Release-Prozess

1. **Version bump** in Xcode (CFBundleShortVersionString)
2. **CHANGELOG.md** aktualisieren
3. **Tag erstellen** (`git tag v1.2.0`)
4. **Tag pushen** (`git push origin v1.2.0`)
5. **GitHub Release** erstellen mit Release Notes
6. **TestFlight Build** hochladen
7. **App Store Submission**

---

## Fragen?

Bei Fragen kannst du:
- Ein [GitHub Issue](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues) erstellen
- In [Discussions](https://github.com/OliverGiertz/Vanity-Expense-Logbook/discussions) fragen

---

## Lizenz

Indem du zu diesem Projekt beiträgst, stimmst du zu, dass deine Beiträge unter derselben Lizenz wie das Projekt lizenziert werden.

---

**Vielen Dank für deine Unterstützung! 🎉**
