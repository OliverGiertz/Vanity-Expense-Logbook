# Widget Extension einrichten

Die Swift-Dateien in diesem Ordner sind vollständig implementiert und müssen nur noch in ein
Xcode Widget Extension Target eingebunden werden.

## Schritte in Xcode

1. **Neues Target anlegen**
   - File → New → Target → Widget Extension
   - Product Name: `CamperLogBookWidget`
   - "Include Configuration App Intent" → **deaktivieren**

2. **Dateien zum Target hinzufügen**
   Die folgenden Dateien aus `CamperLogBook/Features/Widget/` zum neuen Target hinzufügen
   (Target Membership im File Inspector):
   - `ExpenseWidget.swift`
   - `ExpenseWidgetEntry.swift`
   - `ExpenseWidgetProvider.swift`
   - `ExpenseWidgetView.swift`

3. **Shared Code zugänglich machen**
   `PersistenceController.swift` und `Models.swift` ebenfalls zum Widget-Target hinzufügen
   (Target Membership → auch `CamperLogBookWidget` anhaken).

4. **App Group für CoreData (empfohlen)**
   Damit das Widget auf denselben CoreData-Store zugreift:
   - Haupt-App-Target: Signing & Capabilities → + Capability → App Groups → `group.de.vanityontour.camperlogbook`
   - Widget-Target: dasselbe App Group hinzufügen
   - In `Persistence.swift` die Container-URL auf die App Group umstellen:
     ```swift
     let containerURL = FileManager.default
         .containerURL(forSecurityApplicationGroupIdentifier: "group.de.vanityontour.camperlogbook")!
         .appendingPathComponent("CamperLogBook.sqlite")
     container.persistentStoreDescriptions.first?.url = containerURL
     ```

5. **Bundle Identifier**
   Widget-Target Bundle ID: `de.vanityontour.camperlogbook.widget`
