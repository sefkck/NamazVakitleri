import CoreLocation
import MapKit

/// Ekranda gösterilen yer adı.
/// Türkiye: "İl İlçe" (ör. "İstanbul Fatih").
/// Yurt dışı: "Semt/Şehir, Bölge" (ör. "Lakemba, NSW"). Eskiden yurt
/// dışında ilçe yerine belediye adı çıkıyordu ("NY Kings County",
/// "NSW Canterbury-Bankstown Council").
enum PlaceName {
    static func format(country: String?, locality: String?, subLocality: String?,
                       subAdministrativeArea: String?, administrativeArea: String?) -> String? {
        if country == "TR" || country == nil {
            let province = administrativeArea ?? locality
            let district = subAdministrativeArea ?? locality
            if let province, let district, district != province { return "\(province) \(district)" }
            return province ?? district
        }
        let place = locality ?? subLocality ?? subAdministrativeArea
        let region = administrativeArea
        if let place, let region, region != place { return "\(place), \(region)" }
        return place ?? region
    }

    /// MapKit'in yeni adres bilgisinden (iOS 26). Ölçülen örnekler:
    /// TR: şehir "Fatih", bağlam "Fatih İstanbul" → "İstanbul Fatih";
    /// AU: "Lakemba", "Lakemba NSW" → "Lakemba, NSW"; US: bağlam boş → "Brooklyn".
    static func format(region: String?, cityName: String?, cityWithContext: String?) -> String? {
        let city = cityName?.trimmingCharacters(in: .whitespaces)
        let context = cityWithContext?.trimmingCharacters(in: .whitespaces)
        guard let city, !city.isEmpty else { return (context?.isEmpty == false) ? context : nil }
        guard let context, !context.isEmpty, context != city else { return city }
        guard context.hasPrefix(city) else { return context }
        let rest = String(context.dropFirst(city.count)).trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
        guard !rest.isEmpty else { return city }
        return region == "TR" ? "\(rest) \(city)" : "\(city), \(rest)"
    }

    static func format(_ item: MKMapItem) -> String? {
        let r = item.addressRepresentations
        return format(region: r?.region?.identifier, cityName: r?.cityName, cityWithContext: r?.cityWithContext(.short))
    }

    /// Koordinattan yer adı ve saat dilimi (MapKit ters adres araması).
    static func resolve(_ location: CLLocation) async -> (name: String?, timeZone: TimeZone?) {
        guard let request = MKReverseGeocodingRequest(location: location),
              let item = try? await request.mapItems.first else { return (nil, nil) }
        return (format(item), item.timeZone)
    }
}
