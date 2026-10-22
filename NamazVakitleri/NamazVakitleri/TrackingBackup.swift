import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Namaz takibi kayıtlarını (Kıldım, özel günler, kaza, zikir) tek bir JSON
/// dosyasına yedekler ve geri yükler. Dosya sadece kullanıcının seçtiği yere
/// gider (Dosyalar, iCloud Drive, mesaj); sunucuya bir şey gönderilmez.
enum TrackingBackup {
    struct Payload: Codable, Equatable {
        var app = "Safa"
        var version = 1
        var created: Date
        var prayerLog: [String: [String]]
        var excusedDays: [String]
        var kaza: [String: Int]
        var zikir: [String: Int]
    }

    enum BackupError: Error { case invalid }

    static let prayerLogKey = "prayer_log"
    static let excusedKey = "excused_days"
    static var kazaKeys: [String: String] {
        Dictionary(uniqueKeysWithValues: (PrayerTracker.kazaNames + [PrayerTracker.fastingKazaName]).map { ($0, "kaza_count_\($0)") })
    }
    static let zikirKeys = ["zikir_completedRounds", "zikir_rounds_99", "zikir_rounds_custom", "zikir_rounds_tesbihat",
                            "zikir_count_33", "zikir_count_99", "zikir_customGoal"]

    static func make(from d: UserDefaults = .standard, now: Date = Date()) -> Payload {
        Payload(created: now,
                prayerLog: d.dictionary(forKey: prayerLogKey) as? [String: [String]] ?? [:],
                excusedDays: d.stringArray(forKey: excusedKey) ?? [],
                kaza: kazaKeys.reduce(into: [:]) { $0[$1.key] = d.integer(forKey: $1.value) },
                zikir: zikirKeys.reduce(into: [:]) { $0[$1] = d.integer(forKey: $1) })
    }

    static func encode(_ p: Payload) throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return try e.encode(p)
    }

    static func decode(_ data: Data) throws -> Payload {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let p = try? dec.decode(Payload.self, from: data), p.app == "Safa", p.version == 1 else { throw BackupError.invalid }
        return p
    }

    /// Bu cihazdaki kayıtların yerine yedektekileri yazar.
    static func apply(_ p: Payload, to d: UserDefaults = .standard) {
        d.set(p.prayerLog, forKey: prayerLogKey)
        d.set(p.excusedDays, forKey: excusedKey)
        for (name, key) in kazaKeys { d.set(max(0, p.kaza[name] ?? 0), forKey: key) }
        for key in zikirKeys where p.zikir[key] != nil { d.set(max(0, p.zikir[key] ?? 0), forKey: key) }
        if d == .standard { NotificationCenter.default.post(name: PrayerTracker.didChange, object: nil) }
    }

    /// Paylaşım için geçici dosya: "Safa-yedek-2026-10-22.json".
    static func writeFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Safa-yedek-\(PrayerTracker.dayKey(Date())).json")
        try encode(make()).write(to: url, options: .atomic)
        return url
    }
}

/// ShareLink'in paylaştığı dosya (dokununca o anki kayıtlarla oluşturulur).
struct TrackingBackupFile: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { _ in
            SentTransferredFile(try TrackingBackup.writeFile())
        }
    }
}
