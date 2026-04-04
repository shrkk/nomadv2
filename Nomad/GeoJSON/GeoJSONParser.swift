import Foundation

// MARK: - Errors

enum GlobeError: Error {
    case fileNotFound
    case parseError(String)
}

// MARK: - Parser

struct GeoJSONParser {
    /// Loads and parses the bundled GeoJSON file off the main thread.
    /// Filters out features with ISO_A2 == "-99" (disputed/unrecognized territories).
    func loadCountries() async throws -> [CountryFeature] {
        return try await Task.detached(priority: .userInitiated) {
            guard let url = Bundle.main.url(
                forResource: "countries-simplified",
                withExtension: "geojson"
            ) else {
                throw GlobeError.fileNotFound
            }

            let data = try Data(contentsOf: url)
            let collection: GeoJSONFeatureCollection
            do {
                collection = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data)
            } catch {
                throw GlobeError.parseError(error.localizedDescription)
            }

            return collection.features
                .filter { $0.properties.ISO_A2 != "-99" }
                .map { CountryFeature(from: $0) }
        }.value
    }
}
