import SwiftUI
import ZikrCore

struct QiblaView: View {
    @ObservedObject var model: QiblaViewModel
    @ObservedObject var localization: LocalizationService
    @Environment(\.scenePhase) private var phase
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var isPresented = false

    private func tr(_ key: L10nKey) -> String { localization.tr(key) }
    private func degrees(_ value: Double) -> String { localization.format(value, maximumFractionDigits: 0) + "°" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s5) {
                Text(tr(.qiblaTitle)).themeFont(.headingLG).accessibilityAddTraits(.isHeader)
                Text(tr(.qiblaExplain)).themeFont(.footnote).foregroundColor(Theme.Color.textSecondary)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    compass(at: context.date)
                }
                AppCard {
                    VStack(alignment: .leading, spacing: Theme.Space.s3) {
                        Text(tr(.qiblaLocation)).themeFont(.headingSM)
                        if let place = model.place {
                            Text(place.city.map(cityName) ?? tr(.qiblaPhone))
                                .themeFont(.bodyStrong).accessibilityIdentifier("qibla.source")
                            Text("\(localization.format(place.point.latitude, maximumFractionDigits: 4)), \(localization.format(place.point.longitude, maximumFractionDigits: 4))")
                                .themeFont(.footnote)
                            if let accuracy = place.accuracy {
                                Text(tr(.qiblaLocationAccuracy) + " ±" + localization.format(accuracy, maximumFractionDigits: 0) + " " + tr(.unitM))
                                    .themeFont(.footnote)
                            }
                            Text(place.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .themeFont(.caption).foregroundColor(Theme.Color.textSecondary)
                            if place.city == nil { Text(tr(.qiblaCachedNote)).themeFont(.footnote) }
                        }
                        AppButton(title: tr(.qiblaUsePhone), kind: .primary) { model.usePhoneLocation() }
                            .accessibilityIdentifier("qibla.usePhone")
                        if model.isDenied || model.locationFailed {
                            Text(tr(.qiblaPermissionDenied)).themeFont(.footnote)
                            AppButton(title: tr(.qiblaOpenSettings), kind: .secondary) {
                                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                            }
                        }
                        if model.place != nil {
                            AppButton(title: tr(.qiblaForget), kind: .secondary) { model.forget() }
                                .accessibilityIdentifier("qibla.forget")
                        }
                    }
                }
                manualLocation
                AppCard {
                    VStack(alignment: .leading, spacing: Theme.Space.s3) {
                        Text(tr(.qiblaGuideTitle)).themeFont(.headingSM)
                        Text(tr(.qiblaGuideExplanation)).themeFont(.footnote)
                        Link(tr(.qiblaIslamweb), destination: URL(string: "https://www.islamweb.org/ar/fatwa/463630/")!)
                        Link(tr(.qiblaDarIfta), destination: URL(string: "https://www.dar-alifta.org/en/fatwa/details/1721/deviating-from-the-qiblah")!)
                    }.tint(Theme.Color.accent)
                }
            }.padding(Theme.Space.screenX).padding(.bottom, Theme.Space.screenBottom)
        }
        .foregroundColor(Theme.Color.text)
        .background(Theme.Color.bg.ignoresSafeArea())
        .accessibilityIdentifier("qibla.screen")
        .onAppear { isPresented = true; if phase == .active { model.start() } }
        .onDisappear { isPresented = false; model.stop() }
        .onChange(of: phase) { if $0 == .active && isPresented { model.start() } else { model.stop() } }
    }

    private func compass(at now: Date) -> some View {
        let offset = model.offset(at: now)
        let rotation = offset ?? model.bearing ?? 0
        let within = offset.map { QiblaDirection.isWithinGuide(offset: $0, accuracy: model.combinedAccuracy) } ?? false
        return AppCard {
            VStack(spacing: Theme.Space.s4) {
                if let bearing = model.bearing {
                    Text(tr(.qiblaAzimuth) + " " + degrees(bearing)).themeFont(.headingSM)
                        .accessibilityIdentifier("qibla.azimuth")
                    ZStack {
                        Circle().stroke(Theme.Color.divider, lineWidth: Theme.Size.hairline)
                        // Trim 30° вокруг положения 12 часов; вращается относительно телефона.
                        Circle().trim(from: 0, to: 30.0 / 360)
                            .stroke(Theme.Color.accentSoft, lineWidth: Theme.Space.s6)
                            .rotationEffect(.degrees(-105 + rotation))
                            .padding(Theme.Space.s4)
                        Image(systemName: "location.north.fill")
                            .font(.system(size: Theme.Size.iconXl * 2))
                            .foregroundColor(Theme.Color.accent)
                            .rotationEffect(.degrees(rotation))
                        VStack {
                            Text(offset == nil ? tr(.qiblaTrueNorth) : tr(.qiblaPhoneTop)).themeFont(.caption)
                            Spacer()
                            Text("−15°  ·  +15°").themeFont(.caption)
                        }.padding(Theme.Space.s3)
                    }
                    .frame(height: 230)
                    .accessibilityHidden(true)
                    if let offset {
                        Text(tr(.qiblaDeviation) + " " + degrees(abs(offset)))
                            .themeFont(.headingSM).accessibilityIdentifier("qibla.deviation")
                        if abs(offset) >= 1 {
                            Text(tr(offset > 0 ? .qiblaRight : .qiblaLeft) + " " + degrees(abs(offset)))
                                .themeFont(.footnote)
                        }
                        Text(tr(within ? .qiblaWithin : .qiblaTurn))
                            .themeFont(.bodyStrong).foregroundColor(within ? Theme.Color.success : Theme.Color.text)
                    } else {
                        Text(tr(.qiblaNoHeading)).themeFont(.footnote)
                        Text(tr(.qiblaCalibrate)).themeFont(.footnote).foregroundColor(Theme.Color.textSecondary)
                    }
                    if let accuracy = model.headingAccuracy {
                        Text(tr(.qiblaSensorAccuracy) + " ±" + degrees(accuracy)).themeFont(.footnote)
                    }
                } else {
                    Image(systemName: "location.north.circle").font(.system(size: Theme.Size.iconXl * 2)).accessibilityHidden(true)
                    Text(tr(.qiblaChooseLocation)).themeFont(.body)
                }
                Text(tr(.qiblaGuideTitle)).themeFont(.footnote).foregroundColor(Theme.Color.textSecondary)
            }.frame(maxWidth: .infinity)
        }
    }

    private var manualLocation: some View {
        AppCard {
            VStack(alignment: .leading, spacing: Theme.Space.s3) {
                Text(tr(.qiblaManual)).themeFont(.headingSM)
                ForEach(QiblaViewModel.cities, id: \.id) { city in
                    AppButton(title: cityName(city.id), kind: .secondary) { model.choose(city.id, point: city.point) }
                        .accessibilityIdentifier("qibla.city.\(city.id)")
                }
                Text(tr(.qiblaCoordinates)).themeFont(.footnote)
                TextField(tr(.qiblaLatitude), text: $latitude).textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation).accessibilityIdentifier("qibla.latitude")
                TextField(tr(.qiblaLongitude), text: $longitude).textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation).accessibilityIdentifier("qibla.longitude")
                AppButton(title: tr(.qiblaApplyCoordinates), kind: .secondary) {
                    if let point = enteredPoint { model.choose("custom", point: point) }
                }.disabled(enteredPoint == nil)
            }
        }
    }
    private var enteredPoint: GeoPoint? {
        guard let lat = Double(latitude.replacingOccurrences(of: ",", with: ".")),
              let lon = Double(longitude.replacingOccurrences(of: ",", with: ".")) else { return nil }
        let point = GeoPoint(latitude: lat, longitude: lon)
        return point.isValid ? point : nil
    }
    private func cityName(_ id: String) -> String {
        let key: L10nKey
        switch id {
        case "dushanbe": key = .qiblaDushanbe
        case "moscow": key = .qiblaMoscow
        case "istanbul": key = .qiblaIstanbul
        case "london": key = .qiblaLondon
        case "newYork": key = .qiblaNewYork
        default: key = .qiblaCoordinates
        }
        return tr(key)
    }
}
