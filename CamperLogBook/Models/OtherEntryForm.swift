import SwiftUI
import CoreData
import PhotosUI

struct OtherEntryForm: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var date = Date()
    @State private var selectedCategory: String = ""
    @State private var customCategory: String = ""
    @State private var showCustomCategoryField = false
    @State private var details: String = ""
    @State private var cost: String = ""
    @State private var receiptImage: UIImage?
    @State private var pdfData: Data?
    
    // Zustände für die Beleg-Auswahl
    @State private var showingReceiptOptions = false
    @State private var receiptSource: ReceiptSource? = nil

    // FetchRequest zur Abfrage der vorhandenen Kategorien (ExpenseCategory)
    @FetchRequest(
        entity: ExpenseCategory.entity(),
        sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]
    ) var categoriesFetched: FetchedResults<ExpenseCategory>

    @FocusState private var focusedField: Field?
    enum Field: Hashable {
        case cost, details, customCategory
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Datum")) {
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                }
                
                Section(header: Text("Kategorie")) {
                    Picker("Kategorie", selection: $selectedCategory) {
                        ForEach(categoriesFetched, id: \.self) { cat in
                            Text(cat.name ?? "Unbekannt").tag(cat.name ?? "")
                        }
                        Text("Neu").tag("Neu")
                    }
                    .onChange(of: selectedCategory) { newValue, _ in
                        showCustomCategoryField = (newValue == "Neu")
                    }
                    if showCustomCategoryField {
                        TextField("Neue Kategorie eingeben", text: $customCategory)
                            .focused($focusedField, equals: .customCategory)
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }
                    }
                }
                
                Section(header: Text("Details")) {
                    TextField("Zusätzliche Informationen", text: $details)
                        .focused($focusedField, equals: .details)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
                }
                
                Section(header: Text("Kosten")) {
                    TextField("Kosten", text: $cost)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .cost)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
                }
                
                Section(header: Text("Beleg (Bild/PDF)")) {
                    if let image = receiptImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                    } else if pdfData != nil {
                        Image(systemName: "doc.richtext")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                    }
                    Button("Beleg auswählen") {
                        showingReceiptOptions = true
                    }
                    .confirmationDialog("Beleg Quelle wählen", isPresented: $showingReceiptOptions, titleVisibility: .visible) {
                        Button("Aus Fotos wählen") { receiptSource = .photo }
                        Button("Aus Dateien (PDF) wählen") { receiptSource = .pdf }
                        Button("Kamera Scannen") { receiptSource = .scanner }
                        Button("Abbrechen", role: .cancel) { }
                    }
                }
                
                Button("Speichern") {
                    saveEntry()
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { focusedField = nil }
                }
            }
            .navigationTitle("Sonstige Kosten")
            .onAppear {
                if let firstCat = categoriesFetched.first?.name {
                    selectedCategory = firstCat
                }
            }
            .sheet(item: $receiptSource) { source in
                ReceiptPickerSheet(source: $receiptSource, receiptImage: $receiptImage, pdfData: $pdfData)
            }
        }
    }
    
    private func saveEntry() {
        let costText = cost.replacingOccurrences(of: ",", with: ".")
        guard let costValue = Double(costText) else { return }
        
        let categoryToSave: String
        if selectedCategory == "Neu" {
            let trimmed = customCategory.trimmingCharacters(in: .whitespaces)
            categoryToSave = trimmed.isEmpty ? "Unbekannt" : trimmed
            if !categoriesFetched.contains(where: { $0.name == categoryToSave }) {
                let newCat = ExpenseCategory(context: viewContext)
                newCat.id = UUID()
                newCat.name = categoryToSave
            }
        } else {
            categoryToSave = selectedCategory
        }
        
        let newEntry = OtherEntry(context: viewContext)
        newEntry.id = UUID()
        newEntry.date = date
        newEntry.category = categoryToSave
        newEntry.details = details
        newEntry.cost = costValue
        if let image = receiptImage {
            newEntry.receiptData = image.jpegData(compressionQuality: 0.8)
            newEntry.receiptType = "image"
        } else if let pdf = pdfData {
            newEntry.receiptData = pdf
            newEntry.receiptType = "pdf"
        }
        
        do {
            try viewContext.save()
            clearFields()
        } catch {
            print("Error saving other entry: \(error)")
        }
    }
    
    private func clearFields() {
        date = Date()
        selectedCategory = categoriesFetched.first?.name ?? ""
        customCategory = ""
        showCustomCategoryField = false
        details = ""
        cost = ""
        receiptImage = nil
        pdfData = nil
    }
}

struct OtherEntryForm_Previews: PreviewProvider {
    static var previews: some View {
        OtherEntryForm()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
