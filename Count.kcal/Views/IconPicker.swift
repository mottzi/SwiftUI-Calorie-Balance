import SwiftUI

enum IconPickerStyle {

    case rectangle
    case capsule

}

struct IconPicker<T: RawRepresentable>: View where T.RawValue == Int {

    @Environment(\.colorScheme) private var scheme: ColorScheme

    var firstIcon: String
    var secondIcon: String
    var pickedColor: Color = Color(white: 0.1)
    var unpickedColor: Color = Color(white: 0.3)
    var iconFontSize: CGFloat = 20
    var bgColor: Color = Color("IconPickerBackground")
    var bgColorSelected: Color = Color("IconPickerSelected")
    var style: IconPickerStyle = .rectangle
    var exclusiveLabel = false

    @Binding var selection: T

    var body: some View {
        GeometryReader { geo in
            
            Group {
                if style == .rectangle {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(bgColor.opacity(scheme == .light ? 0.2 : 1))
                        .overlay(alignment: selection.rawValue == 0 ? .leading : .trailing) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(bgColorSelected.brighten(scheme == .light ? 0.1 : 0))
                                    .padding([.leading, .vertical], selection.rawValue == 0 ? 2 : 0)
                                    .padding([.trailing, .vertical], selection.rawValue == 1 ? 2 : 0)
                                    .frame(width: geo.size.width / 2, height: geo.size.height)
                            }
                        }
                } else {
                    Capsule()
                        .fill(bgColor.opacity(scheme == .light ? 0.2 : 1))
                        .overlay(alignment: selection.rawValue == 0 ? .leading : .trailing) {
                            ZStack {
                                Capsule()
                                    .fill(bgColorSelected.brighten(scheme == .light ? 0.1 : 0))
                                    .padding([.leading, .vertical], selection.rawValue == 0 ? 2 : 0)
                                    .padding([.trailing, .vertical], selection.rawValue == 1 ? 2 : 0)
                                    .frame(width: geo.size.width / 2, height: geo.size.height)
                                
                                if exclusiveLabel {
                                    Image(systemName: selection.rawValue == 0 ? firstIcon : secondIcon)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: iconFontSize, height: iconFontSize)
                                        .fontWeight(.heavy)
                                        .foregroundStyle(pickedColor)
                                        .contentTransition(.symbolEffect(.replace))
                                }
                            }
                        }
                }
            }
            .overlay {
                if !exclusiveLabel {
                    HStack(spacing: 0) {
                        Spacer()

                        Image(systemName: firstIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: iconFontSize, height: iconFontSize)
                            .fontWeight(selection.rawValue == 0 ? .heavy : .regular)
                            .foregroundStyle(
                                selection.rawValue == 0
                                    ? (firstIcon == "heart.fill" ? Color.pink.gradient : pickedColor.gradient)
                                    : unpickedColor.gradient
                            )
                            .opacity(selection.rawValue == 1 && exclusiveLabel ? 0 : 1)
                        

                        Spacer()
                        Spacer()

                        Image(systemName: secondIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: iconFontSize, height: iconFontSize)
                            .fontWeight(selection.rawValue == 1 ? .heavy : .regular)
                            .foregroundStyle(selection.rawValue == 1 ? pickedColor : unpickedColor)
                            .opacity(selection.rawValue == 0 && exclusiveLabel ? 0 : 1)

                        Spacer()
                    }
                }
            }
            .animation(.spring(duration: 0.3), value: selection.rawValue)
            .contentShape(.rect)
            .onTapGesture {
                if selection.rawValue == 0 {
                    if let v = T(rawValue: 1) {
                        selection = v
                    }
                } else if selection.rawValue == 1 {
                    if let v = T(rawValue: 0) {
                        selection = v
                    }
                } else {
                    if let v = T(rawValue: 0) {
                        selection = v
                    }
                }
            }
        }
    }

}

enum PagerSelection: String {

    case first
    case second
    
    mutating func toggle() {
        if self == .first {
            self = .second
        } else {
            self = .first
        }
        
    }

}

#Preview {
    NavigationView {
        SettingsPage()
            .environmentObject(Settings.shared)
    }
}
