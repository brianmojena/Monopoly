import SwiftUI

struct AmountInputView: View {
    let title: String
    var note: String?
    let onConfirm: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Monto", text: $amountText)
#if os(iOS)
                        .keyboardType(.numberPad)
#endif
                } header: {
                    Text("Introduce el monto manualmente")
                } footer: {
                    Text(note ?? "El dominio validará el monto y el saldo disponible.")
                }
            }
            .navigationTitle(title)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") {
                        confirm()
                    }
                    .disabled(Int(amountText) == nil)
                }
            }
        }
    }

    private func confirm() {
        guard let amount = Int(amountText) else {
            return
        }
        onConfirm(amount)
        dismiss()
    }
}
