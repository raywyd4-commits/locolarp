
import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @EnvironmentObject var provider: LocationProvider

    @State private var camera: MapCameraPosition = .automatic
    @State private var picked: CLLocationCoordinate2D?
    @State private var latText = ""
    @State private var lngText = ""
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var satellite = false
    @State private var message = ""
    @State private var centered = false

    @FocusState private var focused: Bool

    private let mapSpan = MKCoordinateSpan(
        latitudeDelta: 0.05,
        longitudeDelta: 0.05
    )

    var body: some View {
        ZStack {
            MapReader { proxy in
                Map(position: $camera) {
                    if let location = provider.effectiveLocation {
                        Annotation(
                            provider.isSimulating ? "Simulated Location" : "Current Location",
                            coordinate: location.coordinate
                        ) {
                            Circle()
                                .fill(
                                    provider.isSimulating
                                    ? Color.orange
                                    : Color.blue
                                )
                                .frame(width: 18, height: 18)
                                .overlay {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                }
                                .shadow(radius: 3)
                        }
                    }

                    if let coordinate = picked {
                        Marker("Selected", coordinate: coordinate)
                            .tint(.red)
                    }
                }
                .mapStyle(
                    satellite
                    ? MapStyle.hybrid(elevation: .realistic)
                    : MapStyle.standard(elevation: .realistic)
                )
                .onTapGesture { point in
                    if let coordinate = proxy.convert(point, from: .local) {
                        select(coordinate)
                    }
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 8) {
                searchBar

                if !results.isEmpty {
                    resultsList
                }

                Spacer()

                controlPanel
            }
            .padding(12)
        }
        .onChange(of: provider.effectiveLocation) { _, newLocation in
            guard let coordinate = newLocation?.coordinate else {
                return
            }

            // Center on the initial location, and whenever simulation
            // changes the effective location.
            if !centered || provider.isSimulating {
                centered = true
                camera = .region(
                    MKCoordinateRegion(
                        center: coordinate,
                        span: mapSpan
                    )
                )
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search Apple Maps", text: $query)
                .submitLabel(.search)
                .focused($focused)
                .onSubmit {
                    runSearch()
                }

            Button {
                satellite.toggle()
            } label: {
                Image(
                    systemName: satellite
                    ? "map"
                    : "globe.americas"
                )
            }
            .accessibilityLabel(
                satellite ? "Standard map" : "Satellite map"
            )
        }
        .padding(12)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 12)
        )
    }

    // MARK: - Search Results

    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(results.prefix(5)), id: \.self) { item in
                Button {
                    let coordinate = item.placemark.coordinate

                    select(coordinate)

                    camera = .region(
                        MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(
                                latitudeDelta: 0.02,
                                longitudeDelta: 0.02
                            )
                        )
                    )

                    results = []
                    focused = false
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name ?? "Place")
                            .font(.subheadline.weight(.semibold))

                        Text(item.placemark.title ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                }
                .buttonStyle(.plain)

                Divider()
            }
        }
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 12)
        )
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(
                        provider.isSimulating
                        ? Color.orange
                        : Color.green
                    )
                    .frame(width: 10, height: 10)

                Text(
                    provider.isSimulating
                    ? "Simulated location active"
                    : "Using real location"
                )
                .font(.subheadline.weight(.semibold))
            }

            if let location = provider.effectiveLocation {
                Text(
                    String(
                        format: "App location: %.5f, %.5f",
                        location.coordinate.latitude,
                        location.coordinate.longitude
                    )
                )
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            } else {
                Text(
                    provider.authorization == .denied ||
                    provider.authorization == .restricted
                    ? "Location access is disabled. You can still enter simulated coordinates."
                    : "Waiting for a location fix, or enter simulated coordinates below."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                TextField("Latitude", text: $latText)
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)

                TextField("Longitude", text: $lngText)
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
            }

            HStack(spacing: 8) {
                Button("Apply") {
                    apply()
                }
                .buttonStyle(.borderedProminent)

                Button("Use real location") {
                    provider.useRealLocation()
                    message = "Switched to real GPS."
                }
                .buttonStyle(.bordered)

                Spacer()

                if focused {
                    Button("Done") {
                        focused = false
                    }
                }
            }

            if !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text(
                "Simulation changes the location used by this app only. It does not change GPS for Snapchat or other apps."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 16)
        )
    }

    // MARK: - Actions

    private func select(_ coordinate: CLLocationCoordinate2D) {
        picked = coordinate

        latText = String(
            format: "%.6f",
            coordinate.latitude
        )

        lngText = String(
            format: "%.6f",
            coordinate.longitude
        )
    }

    private func apply() {
        func parse(_ value: String) -> Double? {
            Double(
                value
                    .replacingOccurrences(of: ",", with: ".")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        guard
            let latitude = parse(latText),
            let longitude = parse(lngText),
            (-90.0...90.0).contains(latitude),
            (-180.0...180.0).contains(longitude)
        else {
            message = "Enter a valid latitude (-90 to 90) and longitude (-180 to 180)."
            return
        }

        let coordinate = CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        )

        picked = coordinate
        provider.simulate(coordinate)

        camera = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(
                    latitudeDelta: 0.02,
                    longitudeDelta: 0.02
                )
            )
        )

        centered = true
        message = "Simulated location applied."
        focused = false
    }

    private func runSearch() {
        let searchText = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !searchText.isEmpty else {
            results = []
            return
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText

        MKLocalSearch(request: request).start { response, error in
            DispatchQueue.main.async {
                if let error {
                    message = "Search failed: \(error.localizedDescription)"
                    results = []
                    return
                }

                results = response?.mapItems ?? []

                if results.isEmpty {
                    message = "No places found."
                } else {
                    message = ""
                }
            }
        }
    }
}
