import SwiftUI
import CoreData
import PhotosUI

struct OtherEntryForm: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var selectedCategory: String = ""
    @State private var customCategory: String = ""
    @State private var showCustomCategoryField = false
    @State private var details: String = ""
    @State private var cost: String = ""
    @State private var receiptImage: UIImage?
    @State private var pdfData: Data?

    @State private var showingReceiptOptions = false
    @State private var receiptSource: ReceiptSource? = nil

    @FetchRequest(
        entity: ExpenseCategory.entity(),
        sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]
    ) var categoriesFetched: FetchedResults<ExpenseCategory>

    @FocusState private var focusedField: Field?
    enum Field: Hashable {
        case cost, details, customCategory
    }

    @State private var showErrorAlert: Bool = false
    @State private var errorAlertMessage: String = ""
    @State private var showMailView: Bool = false
    @State private var showSuccessToast: Bool = false

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
                        HapticFeedback.selectionChanged()
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

                ReceiptPickerSection(
                    receiptImage: $receiptImage,
                    pdfData: $pdfData,
                    showingReceiptOptions: $showingReceiptOptions,
                    receiptSource: $receiptSource
                )

                SaveSection(title: "Speichern", action: saveEntry)
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
        }
        .receiptPickerSheet(receiptSource: $receiptSource, receiptImage: $receiptImage, pdfData: $pdfData)
        .errorAlert(isPresented: $showErrorAlert, message: errorAlertMessage, showMailView: $showMailView)
        .toast(isPresented: $showSuccessToast, title: "Eintrag gespeichert", subtitle: nil, systemImage: "checkmark.circle.fill", duration: 2.0, alignment: .bottom)
    }

    private func saveEntry() {
        let costText = cost.replacingOccurrences(of: ",", with: ".")
        guard let costValue = Double(costText) else {
            HapticFeedback.error()
            return
        }

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
            HapticFeedback.success()
            clearFields()
            withAnimation { showSuccessToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                dismiss()
            }
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Speichern OtherEntry in OtherEntryForm")
            HapticFeedback.error()
            errorAlertMessage = "Fehler beim Speichern des Eintrags: \(error.localizedDescription)"
            showErrorAlert = true
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
