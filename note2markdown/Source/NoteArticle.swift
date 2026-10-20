import Foundation

/// A note article as returned by the note API (https://note.com/api/v3/notes/<key>).
struct NoteArticle {
    let key: String
    let title: String
    let body: String
    let url: String
    let price: Int
    /// Hashtags set on the article ("#Mac"), in the order note returns them.
    var keywords: [String] = []
    /// The paid part is included (own or bought article, read while signed in).
    var isFull = false

    enum Failure: Error, Equatable {
        case invalidURL
        case notFound
        case forbidden
        case noBody
        case badResponse(Int)
        case network(String)
    }

    /// The article key (n + 12 characters) from a note URL, including custom domains, or the bare key itself.
    static func key(from input: String) -> String? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.range(of: #"^n[0-9a-z]{12}$"#, options: .regularExpression) != nil { return text }
        guard let components = URLComponents(string: text), let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https", components.host?.isEmpty == false else { return nil }
        let parts = components.path.split(separator: "/").map(String.init)
        // …/n/<key> (articles) and editor.note.com/notes/<key>/edit (the editor).
        for (index, part) in parts.enumerated() where (part == "n" || part == "notes") && index + 1 < parts.count {
            let candidate = parts[index + 1]
            if candidate.range(of: #"^n[0-9a-z]{12}$"#, options: .regularExpression) != nil { return candidate }
        }
        return nil
    }

    static func apiURL(_ key: String) -> URL { URL(string: "https://note.com/api/v3/notes/\(key)")! }

    /// Reads the API response. Throws `.noBody` for article types without a text body (images, talk).
    static func parse(_ data: Data, key: String) throws -> NoteArticle {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let info = object["data"] as? [String: Any] else { throw Failure.badResponse(200) }
        let body = info["body"] as? String ?? ""
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Failure.noBody }
        var keywords: [String] = []
        for item in info["hashtag_notes"] as? [[String: Any]] ?? [] {
            guard let name = ((item["hashtag"] as? [String: Any])?["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { continue }
            let tag = name.hasPrefix("#") ? name : "#" + name
            if !keywords.contains(tag) { keywords.append(tag) }
        }
        return NoteArticle(key: key, title: info["name"] as? String ?? "", body: body,
                           url: info["note_url"] as? String ?? "https://note.com/n/\(key)", price: info["price"] as? Int ?? 0, keywords: keywords,
                           isFull: info["is_my_note"] as? Bool == true || info["is_purchased"] as? Bool == true)
    }

    /// `cookie` (note.com session, only with the sign-in option) lets note return the paid part of own or bought articles.
    static func fetch(key: String, cookie: String? = nil, session: URLSession = .shared) async throws -> NoteArticle {
        var request = URLRequest(url: apiURL(key), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let cookie {
            request.httpShouldHandleCookies = false
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw Failure.network(error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200: return try parse(data, key: key)
        case 400, 404: throw Failure.notFound
        case 401, 403: throw Failure.forbidden
        default: throw Failure.badResponse(status)
        }
    }

    /// Titles of embedded note articles, fetched in parallel. Failures are left out (the link text falls back).
    static func titles(for urls: [String], session: URLSession = .shared) async -> [String: String] {
        await withTaskGroup(of: (String, String?).self) { group in
            for url in urls.prefix(50) {
                group.addTask {
                    guard let key = key(from: url), let article = try? await fetch(key: key, session: session) else { return (url, nil) }
                    return (url, article.title)
                }
            }
            var result: [String: String] = [:]
            for await (url, title) in group { if let title, !title.isEmpty { result[url] = title } }
            return result
        }
    }

    /// A file name from the title: characters macOS or other systems reject are replaced, length is limited.
    static func fileName(for title: String, key: String) -> String {
        var name = title.replacingOccurrences(of: #"[/:\\?%*|"<>\u0000-\u001F]"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        while name.hasPrefix(".") { name.removeFirst() }
        if name.count > 120 { name = String(name.prefix(120)).trimmingCharacters(in: .whitespaces) }
        return (name.isEmpty ? key : name) + ".md"
    }
}
