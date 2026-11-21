import SwiftUI
import ZikrCore

struct HijriLocalDatesView: View {
    @ObservedObject var model: HijriCalendarModel
    @ObservedObject var localization: LocalizationService
    @State var year: Int
    @State private var editing: Int?
    @State private var draft = Date()
    @State private var error = false
    @Environment(\.dismiss) private var dismiss
    private func tr(_ key: L10nKey) -> String { localization.tr(key) }
    private var years: [Int] { Array(Set(model.engine.months.map(\.year))).sorted() }
    var body: some View {
        Form {
            Section {
                Picker(tr(.calendarHijriYear), selection: $year) {
                    ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                }.onChange(of: year) { _ in editing = nil }
                Text(tr(.calendarLocalNote)).foregroundColor(Theme.Color.textSecondary)
            }
            field(9, title: .calendarRamadan)
            field(10, title: .calendarFitr)
            field(12, title: .calendarDhul)
            if let editing {
                Section {
                    DatePicker(tr(.calendarDate), selection: $draft, in: window(editing), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                    Button(tr(.calendarSave)) {
                        let day = HijriCalendarEngine.ordinal(draft, timeZone: .init(secondsFromGMT: 0)!)
                        if model.set(.init(year: year, month: editing), day: day) { self.editing = nil }
                        else { error = true }
                    }
                    Button(tr(.calendarCancel)) { self.editing = nil }
                }
            }
            Section {
                Button(tr(.calendarReset)) { model.reset(year: year); editing = nil }
                Text(tr(.calendarPendingNote)).foregroundColor(Theme.Color.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Color.bg.ignoresSafeArea())
        .foregroundColor(Theme.Color.text)
        .environment(\.calendar, HijriCalendarEngine.civil)
        .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
        .environment(\.locale, localization.locale)
        .navigationTitle(tr(.calendarLocal)).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(tr(.calendarDone)) { dismiss() } } }
        .alert(tr(.calendarConflict), isPresented: $error) {
            Button(tr(.calendarDone), role: .cancel) { }
        } message: { Text(tr(.calendarConflictNote)) }
        .tint(Theme.Color.accent)
        .accessibilityIdentifier("calendar.localDates")
    }
    private func window(_ month: Int) -> ClosedRange<Date> {
        let base = model.engine.baseline(.init(year: year, month: month))
        let lo = max(base - 2, HijriCalendarEngine.bounds.lowerBound)
        let hi = min(base + 2, HijriCalendarEngine.bounds.upperBound)
        return HijriCalendarEngine.date(lo)...HijriCalendarEngine.date(max(lo, hi))
    }
    private func field(_ month: Int, title: L10nKey) -> some View {
        let m = HijriMonth(year: year, month: month)
        let day = model.engine.start(m)
        let available = HijriCalendarEngine.bounds.contains(model.engine.baseline(m))
        return Section(header: Text(tr(title))) {
            Text(CalendarText.civil(day, locale: localization.locale))
            Text(tr(model.engine.isUserDate(m) ? .calendarUser : month == 10 && model.engine.isEidPending(year: year) ? .calendarPending : .calendarCalculated))
                .font(.footnote).foregroundColor(Theme.Color.textSecondary)
            Button(tr(.calendarChoose)) {
                editing = month
                draft = min(max(HijriCalendarEngine.date(day), window(month).lowerBound), window(month).upperBound)
            }.disabled(!available)
            if model.engine.isUserDate(m) {
                Button(tr(.calendarUseCalculated)) {
                    if !model.set(m, day: nil) { error = true }
                    editing = nil
                }
            }
            if month == 12 {
                Text("\(tr(.calendarArafah)): \(CalendarText.civil(day + 8, locale: localization.locale))")
                Text("\(tr(.calendarAdha)): \(CalendarText.civil(day + 9, locale: localization.locale))")
            }
        }
    }
}

struct HijriHomePreview: View {
    @ObservedObject var model: HijriCalendarModel
    @ObservedObject var localization: LocalizationService
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let today = HijriCalendarEngine.ordinal(context.date)
            if HijriCalendarEngine.bounds.contains(today) {
                let month = model.engine.month(on: today)
                VStack(alignment: .leading, spacing: Theme.Space.s3) {
                    Text("\(model.engine.number(on: today)) · \(CalendarText.month(month, engine: model.engine, locale: localization.locale))")
                        .themeFont(.headingSM)
                    Text(CalendarText.civil(today, locale: localization.locale)).themeFont(.body)
                    if let next = nextEvent(today: today) {
                        Text("\(localization.tr(next.key)) · \(CalendarText.civil(next.day, locale: localization.locale))")
                            .themeFont(.footnote)
                        Text(source(model.engine.month(on: next.day))).themeFont(.footnote)
                            .foregroundColor(Theme.Color.textSecondary)
                    }
                    Text(source(month)).themeFont(.footnote).foregroundColor(Theme.Color.textSecondary)
                }
            } else { Text(localization.tr(.calendarSummary)).themeFont(.body) }
        }
    }
    private func source(_ month: HijriMonth) -> String {
        if month.month == 10 && model.engine.isEidPending(year: month.year) { return localization.tr(.calendarPending) }
        return localization.tr(model.engine.isUserDate(month) ? .calendarUser : model.engine.isAdjusted(month) ? .calendarAdjusted : .calendarCalculated)
    }
    private func nextEvent(today: Int) -> (day: Int, key: L10nKey)? {
        let year = model.engine.month(on: today).year
        var candidates: [(Int, L10nKey)] = []
        for y in year...(year + 1) {
            for (m, d, key) in [(9, 1, L10nKey.calendarRamadan), (10, 1, .calendarFitr), (12, 9, .calendarArafah), (12, 10, .calendarAdha)] {
                let day = model.engine.start(.init(year: y, month: m)) + d - 1
                if day >= today && HijriCalendarEngine.bounds.contains(day) { candidates.append((day, key)) }
            }
        }
        return candidates.min { $0.0 < $1.0 }
    }
}
