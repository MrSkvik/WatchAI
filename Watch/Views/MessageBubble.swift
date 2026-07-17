import SwiftUI

struct MessageBubble: View {
    let text: String
    let isUser: Bool

    var body: some View {
        HStack(spacing: 0) {
            if isUser { Spacer(minLength: 16) }
            Text(text)
                .font(.system(size: 15))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isUser ? Color.accentColor : Color(white: 0.16))
                .foregroundStyle(isUser ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            if !isUser { Spacer(minLength: 16) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}
