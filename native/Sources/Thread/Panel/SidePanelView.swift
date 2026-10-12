import SwiftUI

/// The side panel and the handle it leaves behind when tucked away.
///
/// Controls and type come from the system (bordered buttons, rounded text field, text
/// styles, SF Symbols) so the panel reads as part of macOS and follows its appearance,
/// accent colour and accessibility settings.
struct SidePanelView: View {
    enum Metrics {
        static let panelWidth: CGFloat = 340
        /// Gap between the open panel and the screen edges.
        static let margin: CGFloat = 10
        static let cornerRadius: CGFloat = 22
        /// Extra transparent room on the left so the shadow is not clipped.
        static let shadowRoom: CGFloat = 40
        static let windowWidth = panelWidth + margin + shadowRoom
    }

    @Environment(TaskStore.self) private var store
    @Environment(PanelPresentation.self) private var presentation

    var body: some View {
        ZStack(alignment: .trailing) {
            EdgeHandle()
                .opacity(presentation.isOpen ? 0 : 1)
                .onHover { if $0 { presentation.open() } }

            panel
                .padding(Metrics.margin)
                // Tucked away, the panel sits just past the screen edge.
                .offset(x: presentation.isOpen ? 0 : Metrics.panelWidth + Metrics.margin + Metrics.shadowRoom)
                .opacity(presentation.isOpen ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .animation(.smooth(duration: 0.4), value: presentation.isOpen)
    }

    private var panel: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    CurrentTaskSection()
                    if !store.scheduled.isEmpty {
                        Divider()
                        ScheduledSection()
                    }
                    Divider()
                    ReturnPathSection()
                    Divider()
                    QueueSection()
                }
                .padding(16)
            }
            .scrollIndicators(.never)

            Divider()
            QuickAddBar()
        }
        .frame(width: Metrics.panelWidth)
        .frame(maxHeight: .infinity)
        .background { PanelBackground(cornerRadius: Metrics.cornerRadius) }
        .clipShape(.rect(cornerRadius: Metrics.cornerRadius, style: .continuous))
        .contentShape(.rect(cornerRadius: Metrics.cornerRadius, style: .continuous))
        .onHover { presentation.pointerInside($0) }
    }
}

/// The sliver left at the screen edge while the panel is tucked away. Its colour shows
/// at a glance whether a task is in focus.
private struct EdgeHandle: View {
    @Environment(TaskStore.self) private var store

    var body: some View {
        Capsule()
            .fill(store.current == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.accentColor))
            .frame(width: 5, height: 64)
            .padding(.vertical, 28)
            .padding(.leading, 9)
            .padding(.trailing, 3)
            .background { PanelBackground(cornerRadius: 8.5) }
            .accessibilityLabel("显示 Thread 面板")
    }
}

/// Heading above each list, in the style of a sidebar section header.
struct SectionHeading<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            Spacer()
            trailing.font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Rounded highlight behind a list row while the pointer is over it, as in system lists and menus.
struct RowHover: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.primary.opacity(isHovered ? 0.08 : 0), in: .rect(cornerRadius: 8))
            .contentShape(.rect)
            .onHover { isHovered = $0 }
            // Let the highlight reach past the text so rows align with the section headings.
            .padding(.horizontal, -8)
    }
}

extension View {
    func rowHover() -> some View { modifier(RowHover()) }
}
