import SwiftUI

/// Основная навигация отделена от адресов существующих экранов TabItem.
enum MainSection: String, CaseIterable, Identifiable {
    case home, services, settings
    var id: String { rawValue }
    var titleKey: L10nKey {
        switch self {
        case .home: return .navHome
        case .services: return .navServices
        case .settings: return .tabSettings
        }
    }
    var symbol: String {
        switch self {
        case .home: return "house"
        case .services: return "square.grid.2x2"
        case .settings: return "gearshape"
        }
    }
}

struct MainSectionBar: View {
    @Binding var selected: MainSection
    @ObservedObject var localization: LocalizationService
    var onDebugLongPress: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Theme.Space.s2) {
            ForEach(MainSection.allCases) { section in
                Button { selected = section } label: {
                    VStack(spacing: Theme.Space.s1) {
                        Image(systemName: section.symbol)
                            .font(.system(size: Theme.Size.iconTab))
                            .accessibilityHidden(true)
                        Text(localization.tr(section.titleKey))
                            .themeFont(selected == section ? .tabSelected : .tab)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundColor(selected == section ? Theme.Color.accent : Theme.Color.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
                    .padding(.vertical, Theme.Space.s1)
                    .background(selected == section ? Theme.Color.accentSoft : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab.\(section.rawValue)")
                .accessibilityAddTraits(selected == section ? .isSelected : [])
#if DEBUG
                .simultaneousGesture(LongPressGesture(minimumDuration: 1.2).onEnded { _ in
                    onDebugLongPress?()
                })
#endif
            }
        }
        .padding(.horizontal, Theme.Space.s3)
        .padding(.top, Theme.Space.s2)
        .padding(.bottom, Theme.Space.s1)
        .background(Theme.Color.surface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Theme.Color.divider.frame(height: Theme.Size.hairline) }
    }
}

/// Все значения читаются из той же модели, что и счётчик. Отдельного writer нет.
struct HomeView: View {
    @ObservedObject var calendar: HijriCalendarModel
    @ObservedObject var progress: ZikrViewModel
    @ObservedObject private var localization: LocalizationService
    let open: (TabItem) -> Void

    init(progress: ZikrViewModel, calendar: HijriCalendarModel, open: @escaping (TabItem) -> Void) {
        self.calendar = calendar
        self.progress = progress
        self.localization = progress.localization
        self.open = open
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s6) {
                VStack(alignment: .leading, spacing: Theme.Space.s2) {
                    Text("ZIKR ADVENTURE").themeFont(.caption).foregroundColor(Theme.Color.accent)
                    Text(localization.tr(.homeMyDay)).themeFont(.headingLG)
                        .accessibilityAddTraits(.isHeader)
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Text(context.date.formatted(.dateTime.weekday(.wide).day().month(.wide)
                            .locale(localization.locale)))
                            .themeFont(.footnote).foregroundColor(Theme.Color.textSecondary)
                    }
                }
                if progress.isAvailable {
                    zikrPreview
                    preview(title: .tabPath, destination: .path) {
                        VStack(alignment: .leading, spacing: Theme.Space.s3) {
                            Label(localization.tr(.homeJourney), systemImage: "book")
                                .themeFont(.headingSM)
                            Text(localization.tr(.pathOpened,
                                                 localization.format(progress.openedCount),
                                                 localization.format(progress.chapterCount)))
                                .themeFont(.body)
                                .accessibilityIdentifier("home.opened")
                            AppProgressBar(progress: Double(progress.openedCount) / Double(max(1, progress.chapterCount)),
                                           label: localization.tr(.tabPath))
                            Text(localization.tr(.homeSiraSummary))
                                .themeFont(.footnote).foregroundColor(Theme.Color.textSecondary)
                        }
                    }
                    preview(title: .tabMap, destination: .map) {
                        VStack(alignment: .leading, spacing: Theme.Space.s3) {
                            Label(localization.tr(.homePlaces), systemImage: "map")
                                .themeFont(.headingSM)
                            Text(localization.tr(.homeMapSummary))
                                .themeFont(.footnote).foregroundColor(Theme.Color.textSecondary)
                            HStack(spacing: Theme.Space.s2) {
                                Text(localization.tr(.cityMecca))
                                Text("·").accessibilityHidden(true)
                                Text(localization.tr(.cityMedina))
                            }.themeFont(.body).foregroundColor(Theme.Color.accent)
                        }
                    }
                    preview(title: .calendarTitle, destination: .calendar) {
                        HijriHomePreview(model: calendar, localization: localization)
                    }
                    preview(title: .qiblaTitle, destination: .qibla) {
                        Label(localization.tr(.qiblaHomeSummary), systemImage: "location.north.circle")
                            .themeFont(.body)
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                        .accessibilityIdentifier("home.loading")
                }
            }
            .padding(Theme.Space.screenX)
            .padding(.bottom, Theme.Space.screenBottom)
        }
        .foregroundColor(Theme.Color.text)
        .background(Theme.Color.bg.ignoresSafeArea())
        .accessibilityIdentifier("home.screen")
        .onAppear { progress.refreshDay() }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in progress.refreshDay() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in progress.refreshDay() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in progress.refreshDay() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in progress.refreshDay() }
    }

    private var zikrPreview: some View {
        Button { open(.zikr) } label: {
            VStack(alignment: .leading, spacing: Theme.Space.s3) {
                HStack {
                    Text(localization.tr(.tabZikr)).themeFont(.headingSM)
                    Spacer()
                    Image(systemName: "arrow.up.right").accessibilityHidden(true)
                }
                Text(localization.tr(.homeZikrMoment)).themeFont(.headingLG)
                    .fixedSize(horizontal: false, vertical: true)
                if progress.settings?.translit != false {
                    Text("Astaghfirullah").themeFont(.translit)
                }
                Text(localization.format(Int(clamping: progress.today)))
                    .themeFont(.displayCounter)
                    .accessibilityIdentifier("home.today")
                Text(localization.tr(.zikrToday)).themeFont(.footnote)
                HStack {
                    Text(localization.tr(.zikrTotal))
                    Text(localization.format(Int(clamping: progress.total)))
                        .accessibilityIdentifier("home.total")
                }.themeFont(.body)
                Text(localization.tr(.homeOpenCounter)).themeFont(.footnote)
            }
            .padding(Theme.Space.s5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundColor(Theme.Color.textOnPrimary)
            .background(Theme.Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sheet))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.open.zikr")
    }

    private func preview<Content: View>(title: L10nKey, destination: TabItem,
                                       @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s3) {
            Text(localization.tr(title)).themeFont(.headingSM).accessibilityAddTraits(.isHeader)
            AppCard {
                VStack(alignment: .leading, spacing: Theme.Space.s4) {
                    content()
                    AppButton(title: localization.tr(.homeOpenSection), kind: .secondary) { open(destination) }
                        .accessibilityIdentifier("home.open.\(destination.rawValue)")
                }
            }
        }
    }
}

struct ServicesView: View {
    @ObservedObject var localization: LocalizationService
    let open: (TabItem) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s5) {
                Text(localization.tr(.navServices)).themeFont(.headingLG).accessibilityAddTraits(.isHeader)
                Text(localization.tr(.servicesIntro)).themeFont(.footnote).foregroundColor(Theme.Color.textSecondary)
                Text(localization.tr(.servicesPractice)).themeFont(.headingSM).accessibilityAddTraits(.isHeader)
                service(.zikr, symbol: "circle.dotted", summary: .homeOpenCounter)
                service(.calendar, symbol: "calendar", summary: .calendarSummary)
                service(.qibla, symbol: "location.north.circle", summary: .qiblaHomeSummary)
                Text(localization.tr(.servicesKnowledge)).themeFont(.headingSM).accessibilityAddTraits(.isHeader)
                service(.path, symbol: "book", summary: .homeSiraSummary)
                service(.map, symbol: "map", summary: .homeMapSummary)
            }.padding(Theme.Space.screenX).padding(.bottom, Theme.Space.screenBottom)
        }
        .foregroundColor(Theme.Color.text)
        .background(Theme.Color.bg.ignoresSafeArea())
        .accessibilityIdentifier("services.screen")
    }

    private func service(_ item: TabItem, symbol: String, summary: L10nKey) -> some View {
        Button { open(item) } label: {
            AppCard {
                HStack(alignment: .center, spacing: Theme.Space.s4) {
                    Image(systemName: symbol)
                        .font(.system(size: Theme.Size.iconXl))
                        .foregroundColor(Theme.Color.accent).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Theme.Space.s2) {
                        Text(localization.tr(item.titleKey)).themeFont(.bodyStrong)
                        Text(localization.tr(summary)).themeFont(.footnote).foregroundColor(Theme.Color.textSecondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").foregroundColor(Theme.Color.accent).accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("service.\(item.rawValue)")
    }
}
