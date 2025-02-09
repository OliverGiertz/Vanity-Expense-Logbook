import SwiftUI
import CoreData

struct EditCategoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @ObservedObject var expenseCategory: ExpenseCategory
    
    @State private var name: String = ""
    
    var body: some View {
        Form {
            Section(header: Text("Kategorie bearbeiten")) {
                TextField("Kategorie Name", text: $name)
            }
            Button("Speichern") {
                saveChanges()
            }
            Section {
                Button(role: .destructive) {
                    deleteCategory()
                } label: {
                    Text("Kategorie löschen")
                }
            }
        }
        .navigationTitle("Kategorie")
        .onAppear {
            name = expenseCategory.name ?? ""
        }
    }
    
    private func saveChanges() {
        expenseCategory.name = name.trimmingCharacters(in: .whitespaces)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving category: \(error)")
        }
    }
    
    private func deleteCategory() {
        viewContext.delete(expenseCategory)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error deleting category: \(error)")
        }
    }
}

struct EditCategoryView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        let expenseCategory = ExpenseCategory(context: context)
        expenseCategory.id = UUID()
        expenseCategory.name = "Beispiel"
        return NavigationView {
            EditCategoryView(expenseCategory: expenseCategory)
        }
        .environment(\.managedObjectContext, context)
    }
}
