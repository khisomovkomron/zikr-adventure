import SwiftUI
import ZikrCore

private extension HijriEvent {
    var key: L10nKey {
        switch self {
        case .ramadan: return .calendarRamadan
        case .eidFitr: return .calendarFitr
        case .arafah: return .calendarArafah
        case .eidAdha: return .calendarAdha
        }
    }
}

struct HijriCalendarView: View {
    @ObservedObject var model: HijriCalendarModel
    @ObservedObject var localization: LocalizationService
    @State private var selected = HijriCalendarEngine.ordinal(.now)
    @State private var visible: HijriMonth?
    @State private var events = false
    @State private var settings = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var engine: HijriCalendarEngine { model.engine }
    @State private var today = HijriCalendarEngine.ordinal(.now)
    @Environment(\.scenePhase) private var scenePhase
    private var month: HijriMonth { visible ?? engine.month(on: clamped(today)) }
    private func clamped(_ day: Int) -> Int { min(max(day, HijriCalendarEngine.bounds.lowerBound), HijriCalendarEngine.bounds.upperBound) }
    private func tr(_ key: L10nKey) -> String { localization.tr(key) }
    private func civil(_ day: Int) -> String { CalendarText.civil(day, locale: localization.locale) }
    private func title(_ m: HijriMonth) -> String { CalendarText.month(m, engine: engine, locale: localization.locale) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s5) {
                HStack {
                    Label(tr(.calendarTitle), systemImage: "moon.stars").themeFont(.headingLG)
                    Spacer()
                    Button { settings = true } label: { Image(systemName: "slider.horizontal.3").frame(minWidth: 44, minHeight: 44) }
                        .accessibilityLabel(tr(.calendarLocal)).accessibilityIdentifier("calendar.local")
                }
                Text(tr(.calendarNote)).themeFont(.footnote).foregroundColor(Theme.Color.textSecondary)
                if model.storageError { Text(tr(.calendarStorageError)).themeFont(.footnote).foregroundColor(Theme.Color.textSecondary) }
                HStack {
                    Picker(tr(.calendarYear), selection: Binding(get: {
                        HijriCalendarEngine.civil.component(.year, from: HijriCalendarEngine.date(engine.month(on: selected) == month ? selected : clamped(engine.start(month))) )
                    }, set: { year in
                        selected = HijriCalendarEngine.day(year: year, month: 1, day: 1)
                        visible = engine.month(on: selected)
                    })) {
                        ForEach(2000...2050, id: \.self) { Text(String($0)).tag($0) }
                    }.pickerStyle(.menu)
                    Spacer()
                    Button(tr(.calendarToday)) { selected = clamped(today); visible = engine.month(on: selected) }
                        .disabled(!HijriCalendarEngine.bounds.contains(today))
                }
                Picker(tr(.calendarTitle), selection: $events) {
                    Text(tr(.calendarMonth)).tag(false)
                    Text(tr(.calendarEvents)).tag(true)
                }.pickerStyle(.segmented)
                HStack {
                    Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .disabled(month == engine.months.first).accessibilityLabel(tr(.calendarPrevious))
                    Spacer()
                    Text(title(month)).themeFont(.headingSM).multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                        .disabled(month == engine.months.last).accessibilityLabel(tr(.calendarNext))
                }
                if events { eventList }
                else if dynamicTypeSize.isAccessibilitySize {
                    ForEach(Array(engine.days(month)).filter { HijriCalendarEngine.bounds.contains($0) }, id: \.self) { day in
                        Button { selected = day } label: {
                            VStack(alignment: .leading) {
                                Text("\(engine.number(on: day)) · \(title(month))")
                                Text(civil(day))
                                if let event = engine.event(on: day) { Text(tr(event.key)) }
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, Theme.Space.s3)
                        }.buttonStyle(.plain).accessibilityAddTraits(day == selected ? .isSelected : [])
                    }
                } else { grid }
                AppCard {
                    VStack(alignment: .leading, spacing: Theme.Space.s3) {
                        Text("\(engine.number(on: selected)) · \(title(engine.month(on: selected)))").themeFont(.headingSM)
                        Text(civil(selected)).themeFont(.body)
                        if let event = engine.event(on: selected) { Text(tr(event.key)).themeFont(.bodyStrong) }
                        Text(source(engine.month(on: selected))).themeFont(.footnote).foregroundColor(Theme.Color.textSecondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding(Theme.Space.screenX).padding(.bottom, Theme.Space.screenBottom)
        }
        .foregroundColor(Theme.Color.text).background(Theme.Color.bg.ignoresSafeArea())
        .navigationTitle(tr(.calendarTitle)).accessibilityIdentifier("calendar.screen")
        .onAppear { refreshToday(); selected = clamped(selected) }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in refreshToday() }
        .onChange(of: scenePhase) { if $0 == .active { refreshToday() } }
        .sheet(isPresented: $settings) {
            NavigationStack { HijriLocalDatesView(model: model, localization: localization, year: month.year) }
        }
    }
    private func refreshToday() {
        let next = HijriCalendarEngine.ordinal(.now)
        if selected == today && next != today {
            selected = clamped(next); visible = engine.month(on: selected)
        }
        today = next
    }
    private func source(_ m: HijriMonth) -> String {
        if m.month == 10 && engine.isEidPending(year: m.year) { return tr(.calendarPending) }
        return tr(engine.isUserDate(m) ? .calendarUser : engine.isAdjusted(m) ? .calendarAdjusted : .calendarCalculated)
    }
    private func move(_ amount: Int) {
        guard let i = engine.months.firstIndex(of: month), engine.months.indices.contains(i + amount) else { return }
        visible = engine.months[i + amount]
    }
    private var grid: some View {
        let days = Array(engine.days(month))
        let offset = (HijriCalendarEngine.civil.component(.weekday, from: HijriCalendarEngine.date(days[0])) + 5) % 7
        let symbols = CalendarText.weekdays(locale: localization.locale)
        return VStack(spacing: Theme.Space.s2) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: Theme.Space.s2) {
                ForEach(0..<7, id: \.self) { i in Text(symbols[i]).themeFont(.caption).foregroundColor(Theme.Color.textSecondary) }
                ForEach(0..<(offset + days.count), id: \.self) { i in
                    if i < offset { Color.clear.frame(height: 48).accessibilityHidden(true) }
                    else { dayCell(days[i - offset]) }
                }
            }
        }
    }
    private func dayCell(_ day: Int) -> some View {
        let enabled = HijriCalendarEngine.bounds.contains(day)
        let marked = engine.event(on: day) != nil
        return Button { selected = day } label: {
            VStack(spacing: 2) {
                Text(localization.format(engine.number(on: day))).themeFont(.bodyStrong)
                Text(CalendarText.shortCivil(day, locale: localization.locale)).font(.caption2)
                Circle().fill(marked ? Theme.Color.accent : .clear).frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(day == selected ? Theme.Color.primary : month.month == 9 ? Theme.Color.accentSoft : Theme.Color.surface)
            .foregroundColor(day == selected ? Theme.Color.textOnPrimary : Theme.Color.text)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(day == today ? Theme.Color.accent : .clear, lineWidth: 1))
            .opacity(enabled ? 1 : 0.3)
        }.buttonStyle(.plain).disabled(!enabled)
            .accessibilityLabel("\(engine.number(on: day)), \(title(month)), \(civil(day))\(engine.event(on: day).map { ", " + tr($0.key) } ?? "")")
            .accessibilityAddTraits(day == selected ? .isSelected : [])
    }
    private var eventList: some View {
        VStack(spacing: Theme.Space.s3) {
            ForEach(HijriEvent.allCases, id: \.rawValue) { event in
                let m = HijriMonth(year: month.year, month: event.month)
                let day = engine.start(m) + event.day - 1
                if HijriCalendarEngine.bounds.contains(day) {
                    Button { selected = day; visible = m; events = false } label: {
                        AppCard {
                            VStack(alignment: .leading, spacing: Theme.Space.s2) {
                                Text(tr(event.key)).themeFont(.headingSM)
                                Text(civil(day)).themeFont(.body)
                                Text(source(m)).themeFont(.footnote).foregroundColor(Theme.Color.textSecondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}

enum CalendarText {
    static func shortCivil(_ day: Int, locale: Locale) -> String {
        let f = DateFormatter(); f.locale = locale; f.calendar = HijriCalendarEngine.civil
        f.timeZone = .init(secondsFromGMT: 0); f.setLocalizedDateFormatFromTemplate("dMM")
        return f.string(from: HijriCalendarEngine.date(day))
    }
    static func civil(_ day: Int, locale: Locale) -> String {
        let f = DateFormatter(); f.locale = locale; f.calendar = HijriCalendarEngine.civil
        f.timeZone = .init(secondsFromGMT: 0); f.dateStyle = .long
        return f.string(from: HijriCalendarEngine.date(day))
    }
    static func month(_ month: HijriMonth, engine: HijriCalendarEngine, locale: Locale) -> String {
        let f = DateFormatter(); f.locale = locale
        f.calendar = Calendar(identifier: .islamicUmmAlQura); f.timeZone = .init(secondsFromGMT: 0)
        f.dateFormat = "LLLL"
        return "\(f.string(from: HijriCalendarEngine.date(engine.baseline(month)))) \(month.year)"
    }
    static func weekdays(locale: Locale) -> [String] {
        let f = DateFormatter(); f.locale = locale; f.calendar = HijriCalendarEngine.civil
        let s = f.shortWeekdaySymbols!
        return Array(s[1...6]) + [s[0]]
    }
}
