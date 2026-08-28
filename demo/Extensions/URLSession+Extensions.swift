//
//  URLSession+Extensions.swift
//  bex-litesdk-demo
//

import Foundation

enum HTTPMethod {
  case get
  case post([String: Any])
}

extension URLSession {
  struct DecodingError: LocalizedError {
    var errorDescription: String?
  }
  
  static let decoder = JSONDecoder()
  
  func request<T: Decodable>(url: URL, method: HTTPMethod, headers: [String: String]? = nil) async throws -> T {
    var request = URLRequest(url: url)
    let baseHeaders: [String: String] = [
      "Content-Type": "application/json"
    ]
    
    if let headers {
      request.allHTTPHeaderFields = baseHeaders.merging(headers, uniquingKeysWith: { $1 })
    } else {
      request.allHTTPHeaderFields = baseHeaders
    }
    
    switch method {
    case .get:
      request.httpMethod = "GET"
    case let .post(dictionary):
      request.httpMethod = "POST"
      let bodyData = try JSONSerialization.data(withJSONObject: dictionary)
      print("request body", String(data: bodyData, encoding: .utf8) ?? "")
      request.httpBody = bodyData
    }
    
    let (data, response) = try await self.data(for: request)
    guard let response = response as? HTTPURLResponse
    else {
      throw DecodingError(errorDescription: "response is not a valid http response.")
    }
    
    print("response received: \n\nStatus Code: \(response.statusCode) \n\n\(String(data: data, encoding: .utf8) ?? "")")
    
    guard
      let jsonObj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      throw DecodingError(errorDescription: "invalid response.")
    }
    
    if let response = jsonObj["data"] as? [String: Any] {
      let responseData = try JSONSerialization.data(withJSONObject: response, options: [])
      return try Self.decoder.decode(T.self, from: responseData)
    } else if let error = jsonObj["error"] as? [String: Any], let message = error["message"] as? String {
      throw DecodingError(errorDescription: message)
    } else {
      throw DecodingError(errorDescription: "invalid response.")
    }
  }
}
