import Foundation

/// Shared URL construction for Manifest and Subsonic backends.
enum RemoteURLSupport {
    static func appendingPath(
        _ path: String,
        to components: URLComponents,
        clearQueryAndFragment: Bool = false
    ) -> URL? {
        var components = components
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let requestedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if requestedPath.isEmpty {
            components.path = basePath.isEmpty ? "/" : "/" + basePath
        } else if basePath == requestedPath || basePath.hasSuffix("/" + requestedPath) {
            components.path = "/" + basePath
        } else {
            components.path = "/" + [basePath, requestedPath].filter { !$0.isEmpty }.joined(separator: "/")
        }
        if clearQueryAndFragment {
            components.query = nil
            components.fragment = nil
        }
        return components.url
    }

    static func resolve(_ path: String, relativeTo baseURL: URL) -> URL? {
        URL(string: path, relativeTo: baseURL)?.absoluteURL
    }
}
