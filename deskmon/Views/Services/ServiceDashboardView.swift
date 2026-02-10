import SwiftUI

struct ServiceDashboardView: View {
    let service: ServiceInfo

    var body: some View {
        switch service.pluginId {
        case "pihole":
            PiHoleDashboardView(service: service)
        case "traefik":
            TraefikDashboardView(service: service)
        case "nginx":
            NginxDashboardView(service: service)
        default:
            GenericServiceDashboardView(service: service)
        }
    }
}
