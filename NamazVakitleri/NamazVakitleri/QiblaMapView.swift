import SwiftUI
import MapKit

/// Kıble haritası: kullanıcının konumundan Kâbe'ye en kısa yol çizgisi
/// (dünya yuvarlak olduğu için "geodezik" çizgi). Harita, kıble yönü ekranın
/// üstüne gelecek şekilde döndürülür. Pusulası olmayan ya da pusulası
/// şaşan telefonlarda bina, yol gibi yer işaretleriyle yön bulmayı sağlar.
struct QiblaMapView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    let origin: CLLocationCoordinate2D
    let bearing: Double

    @State private var position: MapCameraPosition = .automatic
    @State private var northUp = false
    /// "Tüm yol": düz harita yeterince uzaklaşamıyor; küre görünümüne geçilir.
    @State private var wholeRoute = false

    static let kaaba = CLLocationCoordinate2D(latitude: QiblaViewModel.kaabaLatitude, longitude: QiblaViewModel.kaabaLongitude)

    /// Konumdan Kâbe'ye uzaklık (km).
    static func distanceKm(from origin: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            .distance(from: CLLocation(latitude: kaaba.latitude, longitude: kaaba.longitude)) / 1000
    }

    /// "Tüm yol" görünümü: kamera yolun ortasına, yol uzunluğunun ~4 katı
    /// yükseğe konur; uzak şehirlerde (New York, Tokyo) harita küre gibi görünür
    /// ve iki uç birlikte görünür (küre görünümü). Eskiden düz haritada uçlar kesiliyordu.
    static func wholeRouteCamera(origin: CLLocationCoordinate2D, path: MKGeodesicPolyline) -> MapCamera {
        let points = path.points()
        let mid = path.pointCount > 0 ? points[path.pointCount / 2].coordinate : origin
        let km = distanceKm(from: origin)
        return MapCamera(centerCoordinate: mid, distance: max(km * 1000 * 4, 2_500_000), heading: 0, pitch: 0)
    }

    private var geodesic: MKGeodesicPolyline {
        var points = [origin, Self.kaaba]
        return MKGeodesicPolyline(coordinates: &points, count: points.count)
    }

    /// Yakın görünüm: kullanıcı ortada, kıble yönü yukarıda.
    private var nearCamera: MapCamera {
        MapCamera(centerCoordinate: origin, distance: 1500, heading: bearing, pitch: 0)
    }

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                MapPolyline(geodesic)
                    .stroke(AppTheme.accent, lineWidth: 4)
                Marker(loc.t("qibla_kaaba", fallback: "Kâbe"), systemImage: "building.columns.fill", coordinate: Self.kaaba)
                    .tint(AppTheme.accent)
                Annotation(loc.t("qibla_you", fallback: "Sen"), coordinate: origin) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                }
            }
            .mapStyle(wholeRoute ? .hybrid(elevation: .realistic) : .standard)
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Text(loc.tf("qibla_map_info2", "Kıble: kuzeyden %d° · Kâbe'ye %@", Int(bearing.rounded()),
                                DisplayFormat.longDistance(km: Self.distanceKm(from: origin), kmUnit: loc.language == .arabic ? "كم" : "km")))
                        .font(AppTheme.body(14, weight: .semibold))
                    Text(loc.t(northUp ? "qibla_map_hint_north" : "qibla_map_hint", fallback: northUp
                               ? "Harita kuzey yukarı. Kırmızı çizgi kıble yönüdür."
                               : "Harita, kıble yukarıda olacak şekilde döndürüldü. Kırmızı çizgi kıble yönüdür. Çevrendeki bir bina ya da yolu çizgiyle eşleştirerek yönü bul."))
                        .font(AppTheme.body(12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 12) {
                        Button(loc.t("qibla_map_near", fallback: "Yakın")) {
                            northUp = false
                            wholeRoute = false
                            withAnimation { position = .camera(nearCamera) }
                        }
                        Button(loc.t("qibla_map_north", fallback: "Kuzey yukarı")) {
                            northUp = true
                            wholeRoute = false
                            withAnimation { position = .camera(MapCamera(centerCoordinate: origin, distance: 1500, heading: 0, pitch: 0)) }
                        }
                        Button(loc.t("qibla_map_whole", fallback: "Tüm yol")) {
                            northUp = true
                            wholeRoute = true
                            withAnimation { position = .camera(Self.wholeRouteCamera(origin: origin, path: geodesic)) }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .foregroundStyle(.white)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .navigationTitle(loc.t("qibla_map_title", fallback: "Kıble Haritası"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(loc.t("common_close", fallback: "Kapat"))
                }
            }
            .onAppear { position = .camera(nearCamera) }
        }
    }
}
