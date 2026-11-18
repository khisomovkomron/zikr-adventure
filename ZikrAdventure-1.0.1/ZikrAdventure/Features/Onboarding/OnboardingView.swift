import SwiftUI
import ZikrDomain

struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @ObservedObject private var localization: LocalizationService

    init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
        localization = viewModel.localization
    }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            if viewModel.isVisible == nil {
                ProgressView().accessibilityIdentifier("onboarding.loading")
            } else {
                VStack(spacing: Theme.Space.s3) {
                    HStack {
                        Spacer()
                        Button(localization.tr(.onbSkip)) { Task { await viewModel.finish() } }
                            .frame(minWidth: Theme.Size.button, minHeight: Theme.Size.button)
                            .themeFont(.bodyStrong)
                            .accessibilityIdentifier("onboarding.skip")
                    }
                    GeometryReader { geometry in
                      ScrollView {
                        VStack(spacing: Theme.Space.controlX) {
                            illustration
                            Text(localization.tr(titleKey))
                                .themeFont(.headingXL, pointSize: 28)
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityIdentifier("onboarding.title")
                            Text(localization.tr(bodyKey))
                                .foregroundColor(Theme.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if viewModel.page == 0 {
                                Text(localization.tr(.onbLang)).themeFont(.footnote)
                                AppChipFlowLayout(spacing: Theme.Space.s2, centersRows: true) {
                                    ForEach(AppLanguage.allCases, id: \.self) { language in
                                        AppChip(title: LocalizationService.nativeName(of: language),
                                                isSelected: localization.language == language) {
                                            Task { await viewModel.selectLanguage(language) }
                                        }
                                        .accessibilityIdentifier("onboarding.language.\(language.rawValue)")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Space.buttonY)
                        .padding(.vertical, Theme.Space.s6)
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                      }
                    }
                    HStack(spacing: Theme.Space.s2) {
                        ForEach(0..<3) { index in
                            Circle().fill(index == viewModel.page ? Theme.Color.accent : Theme.Color.divider)
                                .frame(width: Theme.Space.s2, height: Theme.Space.s2)
                        }
                    }.accessibilityHidden(true)
                    if viewModel.hasError {
                        Text(localization.tr(.authRetry)).foregroundColor(Theme.Color.danger)
                            .accessibilityIdentifier("onboarding.error")
                    }
                    AppButton(title: localization.tr(viewModel.page < 2 ? .onbNext : .onbStart), kind: .primary) {
                        Task { await viewModel.next() }
                    }.accessibilityIdentifier("onboarding.next")
                }
                .padding(.horizontal, Theme.Space.s5)
                .padding(.bottom, Theme.Space.s5)
                .disabled(viewModel.isBusy)
            }
        }
        .task { await viewModel.start() }
        .foregroundColor(Theme.Color.text)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.screen")
        .accessibilityAddTraits(.isModal)
    }

    private var titleKey: L10nKey { [.onb1t, .onb2t, .onb3t][viewModel.page] }
    private var bodyKey: L10nKey { [.onb1x, .onb2x, .onb3x][viewModel.page] }

    @ViewBuilder private var illustration: some View {
        if viewModel.page == 0 {
            Text("أَسْتَغْفِرُ اللَّهَ").themeFont(.arabic, pointSize: 44)
                .environment(\.layoutDirection, .rightToLeft)
            Text("Astaghfirullah").themeFont(.translit).foregroundColor(Theme.Color.accent)
        } else {
            OnboardingIllustration(isPath: viewModel.page == 1)
                .stroke(Theme.Color.accent, style: StrokeStyle(lineWidth: 1.3 * 64 / 24, lineCap: .round, lineJoin: .round))
                .frame(width: 64, height: 64).accessibilityHidden(true)
        }
    }
}

/// Точные контуры SVG path/sacred из веб-онбординга, viewBox 0 0 24 24.
private struct OnboardingIllustration: Shape {
    let isPath: Bool
    func path(in rect: CGRect) -> Path {
        var p = Path()
        if isPath {
            p.addEllipse(in: CGRect(x: 4, y: 16, width: 4, height: 4))
            p.addEllipse(in: CGRect(x: 16, y: 4, width: 4, height: 4))
            p.move(to: CGPoint(x: 8, y: 18)); p.addLine(to: CGPoint(x: 14, y: 18))
            p.addArc(center: CGPoint(x: 14, y: 15), radius: 3, startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: true)
            p.addLine(to: CGPoint(x: 10, y: 12))
            p.addArc(center: CGPoint(x: 10, y: 9), radius: 3, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
            p.addLine(to: CGPoint(x: 16, y: 6))
        } else {
            p.move(to: CGPoint(x: 5, y: 20)); p.addLine(to: CGPoint(x: 5, y: 8))
            p.addLine(to: CGPoint(x: 12, y: 4)); p.addLine(to: CGPoint(x: 19, y: 8))
            p.addLine(to: CGPoint(x: 19, y: 20)); p.closeSubpath()
            p.move(to: CGPoint(x: 5, y: 11)); p.addLine(to: CGPoint(x: 19, y: 11))
        }
        return p.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}
