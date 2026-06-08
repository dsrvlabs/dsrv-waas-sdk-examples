import Foundation

public enum HttpHelper {
    public static func post(url: String, jsonBody: [String: Any]) async throws -> String {
        guard let url = URL(string: url) else {
            throw HttpError.invalidURL(url)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let jsonData = try JSONSerialization.data(withJSONObject: jsonBody)
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HttpError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw HttpError.httpError(httpResponse.statusCode, errorBody)
        }

        guard let responseString = String(data: data, encoding: .utf8) else {
            throw HttpError.invalidResponse
        }

        return responseString
    }

    public static func get(url: String, queryItems: [URLQueryItem]) async throws -> String {
        guard var components = URLComponents(string: url) else {
            throw HttpError.invalidURL(url)
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw HttpError.invalidURL(url)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HttpError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw HttpError.httpError(httpResponse.statusCode, errorBody)
        }

        guard let responseString = String(data: data, encoding: .utf8) else {
            throw HttpError.invalidResponse
        }

        return responseString
    }

    public enum HttpError: Error {
        case invalidURL(String)
        case invalidResponse
        case httpError(Int, String)
    }
}
