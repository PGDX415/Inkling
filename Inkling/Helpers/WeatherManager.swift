import CoreLocation
import Foundation

/// Weather conditions mapped to localized display keys and SF Symbols
enum WeatherCondition: String, Codable {
    case sunny
    case cloudy
    case overcast
    case fog
    case drizzle
    case rain
    case heavyRain
    case snow
    case thunderstorm

    var symbolName: String {
        switch self {
        case .sunny: return "sun.max.fill"
        case .cloudy: return "cloud.sun.fill"
        case .overcast: return "cloud.fill"
        case .fog: return "cloud.fog.fill"
        case .drizzle: return "cloud.drizzle.fill"
        case .rain: return "cloud.rain.fill"
        case .heavyRain: return "cloud.heavyrain.fill"
        case .snow: return "cloud.snow.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        }
    }

    var localizationKey: String {
        switch self {
        case .sunny: return "weather.sunny"
        case .cloudy: return "weather.cloudy"
        case .overcast: return "weather.overcast"
        case .fog: return "weather.fog"
        case .drizzle: return "weather.drizzle"
        case .rain: return "weather.rain"
        case .heavyRain: return "weather.heavy_rain"
        case .snow: return "weather.snow"
        case .thunderstorm: return "weather.thunderstorm"
        }
    }
}

/// Result containing weather data for a journal entry
struct WeatherData: Sendable {
    let condition: WeatherCondition
    let temperature: Double  // Celsius
    let location: String     // City / district name
}

/// Fetches current weather using device location
@MainActor @Observable
final class WeatherManager: NSObject, CLLocationManagerDelegate {
    static let shared = WeatherManager()

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    private var authContinuation: CheckedContinuation<Bool, Never>?

    private(set) var isFetching = false
    var authorizationDenied = false

    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer  // city-level is enough
    }

    /// Request location + fetch weather. Returns nil if location denied or fetch fails.
    func fetchWeather() async -> WeatherData? {
        guard !isFetching else { return nil }
        isFetching = true
        defer { isFetching = false }

        // Wait for location authorization (timeout after 15s)
        let authorized = await ensureAuthorized()
        guard authorized else {
            authorizationDenied = true
            return nil
        }

        // Get current location (timeout after 10s)
        let location: CLLocation? = await withCheckedContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation()
        }

        guard let location else { return nil }

        // Reverse geocode to get city name
        let cityName = await reverseGeocode(location)

        // Fetch weather from Open-Meteo (free, no API key)
        guard let weather = await fetchOpenMeteoWeather(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude) else {
            return nil
        }

        return WeatherData(
            condition: weather.condition,
            temperature: weather.temperature,
            location: cityName
        )
    }

    // MARK: - Authorization
    private func ensureAuthorized() async -> Bool {
        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            return await withCheckedContinuation { continuation in
                self.authContinuation = continuation
            }
        @unknown default:
            return false
        }
    }

    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            authContinuation?.resume(returning: true)
            authContinuation = nil
        } else if status == .denied || status == .restricted {
            authContinuation?.resume(returning: false)
            authContinuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationContinuation?.resume(returning: locations.last)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }

    // MARK: - Reverse Geocode
    private func reverseGeocode(_ location: CLLocation) async -> String {
        let geocoder = CLGeocoder()
        guard let placemarks = try? await geocoder.reverseGeocodeLocation(location),
              let placemark = placemarks.first else {
            return "Unknown"
        }
        return placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea ?? "Unknown"
    }

    // MARK: - Open-Meteo API
    private func fetchOpenMeteoWeather(latitude: Double, longitude: Double) async -> (condition: WeatherCondition, temperature: Double)? {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current_weather=true"
        guard let url = URL(string: urlString) else { return nil }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let currentWeather = json["current_weather"] as? [String: Any],
              let temperature = currentWeather["temperature"] as? Double,
              let weatherCode = currentWeather["weathercode"] as? Int else {
            return nil
        }

        let condition = mapWeatherCode(weatherCode)
        return (condition, temperature)
    }

    // MARK: - WMO Weather Code Mapping
    private func mapWeatherCode(_ code: Int) -> WeatherCondition {
        switch code {
        case 0: return .sunny
        case 1, 2: return .cloudy
        case 3: return .overcast
        case 45, 48: return .fog
        case 51, 53, 55: return .drizzle
        case 61, 63: return .rain
        case 65, 80, 81, 82: return .heavyRain
        case 71, 73, 75, 77, 85, 86: return .snow
        case 95, 96, 99: return .thunderstorm
        default: return .cloudy
        }
    }
}
