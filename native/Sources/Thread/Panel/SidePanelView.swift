import SwiftUI

/// Root of the side panel: either the full panel or, when collapsed, the rail.
///
/// Glass is used once, for the floating surface itself. Everything inside stays flat,
/// following Apple's guidance not to layer Liquid Glass on Liquid Glass.
struct SidePanelView: View {
    @Environment(TaskStore.self) private var store

    var body: some View {
        if store.isCollapsed {
            CollapsedRail()
        } else {
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        CurrentTaskSection()
                        ReturnPathSection()
                        QueueSection()
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                }
                .scrollIndicators(.never)
                QuickAddBar()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
        }
    }

    private var header: some View {
        HStack(spacing: 11) {
            AppIcon(size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text("Thread").font(.system(size: 14, weight: .semibold))
                Text("保持工作连续").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                store.isCollapsed = true
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("收起面板")
            .accessibilityLabel("收起面板")
        }
        .padding(.leading, 18)
        .padding(.trailing, 12)
        .frame(height: 62)
    }
}

/// The panel reduced to a strip at the screen edge. Shows how many tasks are in play.
struct CollapsedRail: View {
    @Environment(TaskStore.self) private var store

    var body: some View {
        Button {
            store.isCollapsed = false
        } label: {
            VStack {
                AppIcon(size: 30)
                Spacer()
                Text("\(store.interrupted.count + (store.current == nil ? 0 : 1))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.accentColor, in: .circle)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .help("展开 Thread 面板")
        .accessibilityLabel("展开 Thread 面板")
    }
}

/// The app mark: a ring with a hand leaving it, on the system accent gradient.
struct AppIcon: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "arrow.uturn.backward")
            .font(.system(size: size * 0.44, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.accentColor.gradient, in: .rect(cornerRadius: size * 0.25))
            .accessibilityHidden(true)
    }
}

/// Heading above each list: a title on the left and an optional detail or action on the right.
struct SectionHeading<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            Spacer()
            trailing.font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(minHeight: 20)
    }
}

/// Capsule button used for the two actions on the current task.
struct CapsuleActionStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(prominent ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary), in: .capsule)
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
