import CoreLocation

/// Ekranda gösterilen yer adı.
/// Türkiye: "İl İlçe" (ör. "İstanbul Fatih").
/// Yurt dışı: "Semt/Şehir, Bölge" (ör. "Brooklyn, NY", "Lakemba, NSW"). Eskiden yurt
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

    static func format(_ p: CLPlacemark) -> String? {
        format(country: p.isoCountryCode, locality: p.locality, subLocality: p.subLocality,
               subAdministrativeArea: p.subAdministrativeArea, administrativeArea: p.administrativeArea)
    }
}
