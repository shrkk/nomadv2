import CoreLocation

// MARK: - Typed Country Model

struct CountryFeature: Identifiable {
    let id: String                          // ISO_A2 code
    let isoCode: String                     // ISO_A2 code (same as id)
    let name: String
    /// Each inner array is one polygon ring: [[CLLocationCoordinate2D]]
    /// MultiPolygon countries have multiple rings.
    let polygons: [[CLLocationCoordinate2D]]
}

// MARK: - GeoJSON Decodable Types

struct GeoJSONFeatureCollection: Decodable {
    let type: String
    let features: [GeoJSONFeature]
}

struct GeoJSONFeature: Decodable {
    let properties: GeoJSONProperties
    let geometry: GeoJSONGeometry
}

struct GeoJSONProperties: Decodable {
    let ISO_A2: String
    let NAME: String
}

struct GeoJSONGeometry: Decodable {
    let type: String
    let coordinates: GeoJSONCoordinates

    enum GeoJSONCoordinates {
        case polygon([[[Double]]])        // [[[lon, lat]]]
        case multiPolygon([[[[Double]]]]) // [[[[lon, lat]]]]
    }

    enum CodingKeys: String, CodingKey {
        case type
        case coordinates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        switch type {
        case "Polygon":
            let coords = try container.decode([[[Double]]].self, forKey: .coordinates)
            coordinates = .polygon(coords)
        case "MultiPolygon":
            let coords = try container.decode([[[[Double]]]].self, forKey: .coordinates)
            coordinates = .multiPolygon(coords)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unsupported geometry type: \(type)"
            )
        }
    }
}

// MARK: - Conversion from GeoJSON to typed model

extension CountryFeature {
    /// Converts a decoded GeoJSONFeature into a typed CountryFeature.
    /// GeoJSON coordinate order is [longitude, latitude] per RFC 7946.
    init(from feature: GeoJSONFeature) {
        let iso = feature.properties.ISO_A2
        self.id = iso
        self.isoCode = iso
        self.name = feature.properties.NAME

        switch feature.geometry.coordinates {
        case .polygon(let rings):
            // Each ring is an array of [lon, lat] pairs
            self.polygons = rings.map { ring in
                ring.map { pair in
                    CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
                }
            }
        case .multiPolygon(let polys):
            // Flatten all polygon rings from all sub-polygons into a single array of rings
            self.polygons = polys.flatMap { poly in
                poly.map { ring in
                    ring.map { pair in
                        CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
                    }
                }
            }
        }
    }
}
