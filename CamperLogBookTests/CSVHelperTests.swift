import Testing
import Foundation
import CoreData
@testable import CamperLogBook

@Suite("CSVHelper")
struct CSVHelperTests {

    // MARK: - Helper

    private func tempCSV(_ content: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("csv")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - FuelEntry Import

    @Test func importFuel_tabSeparated() throws {
        let stack = CoreDataTestStack()
        let header = "date\tisDiesel\tisAdBlue\tcurrentKm\tliters\tcostPerLiter\ttotalCost\tlatitude\tlongitude"
        let row    = "15.03.25\ttrue\tfalse\t125000\t60,5\t1,729\t104,60\t48,1234\t11,5678"
        let url = try tempCSV(header + "\n" + row)

        let count = try CSVHelper.importCSV(for: .fuel, from: url, in: stack.context)
        #expect(count == 1)

        let entries = try stack.context.fetch(FuelEntry.fetchAll())
        let entry = try #require(entries.first)
        #expect(entry.isDiesel == true)
        #expect(entry.isAdBlue == false)
        #expect(entry.currentKm == 125_000)
        #expect(abs(entry.liters - 60.5) < 0.001)
        #expect(abs(entry.costPerLiter - 1.729) < 0.001)
        #expect(abs(entry.totalCost - 104.60) < 0.001)
        #expect(abs(entry.latitude - 48.1234) < 0.00001)
        #expect(abs(entry.longitude - 11.5678) < 0.00001)
    }

    @Test func importFuel_semicolonSeparated() throws {
        let stack = CoreDataTestStack()
        let csv = "date;isDiesel;isAdBlue;currentKm;liters;costPerLiter;totalCost\n01.01.2024;false;false;50000;45,0;1,85;83,25"
        let url = try tempCSV(csv)

        let count = try CSVHelper.importCSV(for: .fuel, from: url, in: stack.context)
        #expect(count == 1)
    }

    @Test func importFuel_isoDate() throws {
        let stack = CoreDataTestStack()
        let csv = "date\tliters\tcostPerLiter\ttotalCost\tcurrentKm\tisDiesel\tisAdBlue\n2024-06-15\t50,0\t1,80\t90,0\t80000\ttrue\tfalse"
        let url = try tempCSV(csv)

        let count = try CSVHelper.importCSV(for: .fuel, from: url, in: stack.context)
        #expect(count == 1)
    }

    @Test func importFuel_invalidDate_skipped() throws {
        let stack = CoreDataTestStack()
        let csv = "date\tliters\tcostPerLiter\ttotalCost\tcurrentKm\tisDiesel\tisAdBlue\nnot-a-date\t50,0\t1,80\t90,0\t80000\ttrue\tfalse"
        let url = try tempCSV(csv)

        let count = try CSVHelper.importCSV(for: .fuel, from: url, in: stack.context)
        #expect(count == 0)
    }

    @Test func importFuel_bomStripped() throws {
        let stack = CoreDataTestStack()
        let csv = "\u{feff}date\tliters\tcostPerLiter\ttotalCost\tcurrentKm\tisDiesel\tisAdBlue\n01.03.25\t55,0\t1,75\t96,25\t90000\tfalse\tfalse"
        let url = try tempCSV(csv)

        let count = try CSVHelper.importCSV(for: .fuel, from: url, in: stack.context)
        #expect(count == 1)
    }

    @Test func importFuel_withEntryTypeColumn_filtersOtherTypes() throws {
        let stack = CoreDataTestStack()
        let header  = "entryType\tdate\tliters\tcostPerLiter\ttotalCost\tcurrentKm\tisDiesel\tisAdBlue"
        let rowFuel = "FuelEntry\t01.03.25\t50,0\t1,80\t90,0\t80000\ttrue\tfalse"
        let rowGas  = "GasEntry\t01.03.25\t0\t0\t0\t0\tfalse\tfalse"
        let url = try tempCSV([header, rowFuel, rowGas].joined(separator: "\n"))

        let count = try CSVHelper.importCSV(for: .fuel, from: url, in: stack.context)
        #expect(count == 1)
    }

    @Test func importFuel_emptyFile_returnsZero() throws {
        let stack = CoreDataTestStack()
        let url = try tempCSV("")

        let count = try CSVHelper.importCSV(for: .fuel, from: url, in: stack.context)
        #expect(count == 0)
    }

    // MARK: - GasEntry Import

    @Test func importGas_basic() throws {
        let stack = CoreDataTestStack()
        let csv = "date\tcostPerBottle\tbottleCount\n15.03.25\t29,90\t2"
        let url = try tempCSV(csv)

        let count = try CSVHelper.importCSV(for: .gas, from: url, in: stack.context)
        #expect(count == 1)

        let entries = try stack.context.fetch(GasEntry.fetchAll())
        let entry = try #require(entries.first)
        #expect(abs(entry.costPerBottle - 29.90) < 0.001)
        #expect(entry.bottleCount == 2)
    }

    @Test func importGas_euroSymbol() throws {
        let stack = CoreDataTestStack()
        let csv = "date\tcostPerBottle\tbottleCount\n01.01.25\t€ 32,50\t1"
        let url = try tempCSV(csv)

        let count = try CSVHelper.importCSV(for: .gas, from: url, in: stack.context)
        #expect(count == 1)

        let entries = try stack.context.fetch(GasEntry.fetchAll())
        let entry = try #require(entries.first)
        #expect(abs(entry.costPerBottle - 32.50) < 0.001)
    }

    // MARK: - OtherEntry Import

    @Test func importOther_basic() throws {
        let stack = CoreDataTestStack()
        let csv = "date\tcategory\tdetails\tcost\n15.03.25\tReparatur\tOelwechsel\t120,00"
        let url = try tempCSV(csv)

        let count = try CSVHelper.importCSV(for: .other, from: url, in: stack.context)
        #expect(count == 1)

        let entries = try stack.context.fetch(OtherEntry.fetchAll())
        let entry = try #require(entries.first)
        #expect(entry.category == "Reparatur")
        #expect(entry.details == "Oelwechsel")
        #expect(abs(entry.cost - 120.0) < 0.001)
    }

    @Test func importOther_euroSymbol() throws {
        let stack = CoreDataTestStack()
        let csv = "date\tcategory\tcost\n01.02.25\tSonstiges\t€ 45,00"
        let url = try tempCSV(csv)

        let count = try CSVHelper.importCSV(for: .other, from: url, in: stack.context)
        #expect(count == 1)

        let entries = try stack.context.fetch(OtherEntry.fetchAll())
        let entry = try #require(entries.first)
        #expect(abs(entry.cost - 45.0) < 0.001)
    }

    // MARK: - importCSVAllTypes

    @Test func importAllTypes_dispatchesByEntryType() throws {
        let stack = CoreDataTestStack()
        let cols = "entryType\tdate\tliters\tcostPerLiter\ttotalCost\tcurrentKm\tisDiesel\tisAdBlue\tcostPerBottle\tbottleCount\tcategory\tdetails\tcost"
        let fuel  = "FuelEntry\t01.03.25\t50,0\t1,80\t90,0\t80000\ttrue\tfalse\t\t\t\t\t"
        let gas   = "GasEntry\t02.03.25\t\t\t\t\t\t\t29,90\t2\t\t\t"
        let other = "OtherEntry\t03.03.25\t\t\t\t\t\t\t\t\tReparatur\tOelwechsel\t120,00"
        let url = try tempCSV([cols, fuel, gas, other].joined(separator: "\n"))

        let summary = try CSVHelper.importCSVAllTypes(from: url, in: stack.context)
        #expect(summary.fuel == 1)
        #expect(summary.gas == 1)
        #expect(summary.other == 1)
        #expect(summary.total == 3)
    }

    @Test func importAllTypes_emptyFile_returnsZero() throws {
        let stack = CoreDataTestStack()
        let url = try tempCSV("")

        let summary = try CSVHelper.importCSVAllTypes(from: url, in: stack.context)
        #expect(summary.total == 0)
    }

    @Test func importSummary_total_computed() {
        let summary = CSVHelper.ImportSummary(fuel: 3, gas: 2, other: 5)
        #expect(summary.total == 10)
    }

    // MARK: - generateCSV

    @Test func generateCSV_containsExpectedHeader() throws {
        let stack = CoreDataTestStack()
        let csv = CSVHelper.generateCSV(forTypes: [.fuel], in: stack.context)
        let firstLine = try #require(csv.components(separatedBy: "\n").first)
        #expect(firstLine.contains("entryType"))
        #expect(firstLine.contains("date"))
        #expect(firstLine.contains("liters"))
        #expect(firstLine.contains("costPerLiter"))
    }

    @Test func generateCSV_roundtrip_fuel() throws {
        let stack = CoreDataTestStack()

        let entry = FuelEntry(context: stack.context)
        entry.id = UUID()
        entry.date = Calendar.current.date(from: DateComponents(year: 2025, month: 3, day: 15))!
        entry.isDiesel = true
        entry.isAdBlue = false
        entry.currentKm = 100_000
        entry.liters = 50.5
        entry.costPerLiter = 1.75
        entry.totalCost = 88.375
        try stack.context.save()

        let csv = CSVHelper.generateCSV(forTypes: [.fuel], in: stack.context)
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 2) // header + 1 data row

        let dataLine = try #require(lines.last)
        #expect(dataLine.hasPrefix("FuelEntry"))
        #expect(dataLine.contains("15.03.25"))
        #expect(dataLine.contains("true"))
        #expect(dataLine.contains("100000"))
    }

    @Test func generateCSV_emptyContext_headerOnly() throws {
        let stack = CoreDataTestStack()
        let csv = CSVHelper.generateCSV(forTypes: [.fuel, .gas, .other], in: stack.context)
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 1)
    }
}
