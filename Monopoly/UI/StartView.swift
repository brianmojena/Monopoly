import SwiftUI

struct StartView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "building.2.crop.circle")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                VStack(spacing: 8) {
                    Text("Monopoly")
                        .font(.largeTitle.bold())
                    Text("Banca local para tu partida")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    NavigationLink {
                        HostSetupView()
                    } label: {
                        Label("Alojar partida", systemImage: "antenna.radiowaves.left.and.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    NavigationLink {
                        JoinView()
                    } label: {
                        Label("Unirse a partida", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
            }
            .padding(24)
            .navigationTitle("Inicio")
        }
    }
}

#Preview {
    StartView()
}
