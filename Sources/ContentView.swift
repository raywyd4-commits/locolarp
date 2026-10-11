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

    var body: some View {
        ZStack {
            MapReader { proxy in
                Map(position: $camera) {
                    if let loc = provider.effectiveLocation {
                        Annotation("", coordinate: loc.coordinate) {
                            Circle()
                                .fill(provider.isSimulating ? Color.orange : Color.blue)
                                .frame(width: 18, height: 18)
                                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                                .shadow(radius: 3)
                        }
                    }
                    if let p = picked {
                        Marker("Selected", coordinate: p).tint(.red)
                    }
                }
                .mapStyle(satellite
                          ? MapStyle.hybrid(elevation: .realistic)
                          : MapStyle.standard(elevation: .realistic))
                .onTapGesture { point in
                    if let c = proxy.convert(point, from: .local) { select(c) }
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 8) {
                searchBar
                if !results.isEmpty { resultsList }
                Spacer()
                controlPanel
            }
            .padding(12)
        }
        .onChange(of: provider.realLocation) { _, new in
            if !centered, let c = new?.coordinate {
                centered = true
                camera = .region(MKCoordinateRegion(center: c, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
            }
        }
    }

    // MARK: Views

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search Apple Maps", text: $query)
                .submitLabel(.search)
                .focused($focused)
                .onSubmit { runSearch() }
            Button {
                satellite.toggle()
            } label: {
                Image(systemName: satellite ? "map" : "globe.americas")
            }
            .accessibilityLabel(satellite ? "Standard map" : "Satellite map")
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(results.prefix(5)), id: \.self) { item in
                Button {
                    let c = item.placemark.coordinate
                    select(c)
                    camera = .region(MKCoordinateRegion(center: c, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
                    results = []
                    focused = false
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name ?? "Place").font(.subheadline.weight(.semibold))
                        Text(item.placemark.title ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(provider.isSimulating ? Color.orange : Color.green)
                    .frame(width: 10, height: 10)
                Text(provider.isSimulating ? "Simulated location active" : "Using real location")
                    .font(.subheadline.weight(.semibold))
            }

            if let loc = provider.effectiveLocation {
                Text(String(format: "App reports: %.5f, %.5f", loc.coordinate.latitude, loc.coordinate.longitude))
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                Text(provider.authorization == .denied || provider.authorization == .restricted
                     ? "Location access is off. Enable it in Settings, or just use the simulator."
                     : "Waiting for a location fix...")
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
                Button("Apply") { apply() }
                    .buttonStyle(.borderedProminent)
                Button("Use real location") {
                    provider.useRealLocation()
                    message = "Back to real GPS."
                }
                .buttonStyle(.bordered)
                Spacer()
                if focused {
                    Button("Done") { focused = false }
                }
            }

            if !message.isEmpty {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }

            Text("Only this app sees the simulated location. Other apps still get your real GPS.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Actions

    private func select(_ c: CLLocationCoordinate2D) {
        picked = c
        latText = String(format: "%.6f", c.latitude)
        lngText = String(format: "%.6f", c.longitude)
    }

    private func apply() {
        func parse(_ s: String) -> Double? {
            Double(s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
        }
        guard let la = parse(latText), let lo = parse(lngText),
              (-90.0...90.0).contains(la), (-180.0...180.0).contains(lo) else {
            message = "Enter a latitude from -90 to 90 and a longitude from -180 to 180."
            return
        }
        let c = CLLocationCoordinate2D(latitude: la, longitude: lo)
        picked = c
        provider.simulate(c)
        camera = .region(MKCoordinateRegion(center: c, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
        message = "Simulated location applied."
        focused = false
    }

    private func runSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = []; return }
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = q
        MKLocalSearch(request: req).start { resp, _ in
            DispatchQueue.main.async {
                results = resp?.mapItems ?? []
                if results.isEmpty { message = "No places found." }
            }
        }
    }
}
