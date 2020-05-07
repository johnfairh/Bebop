//
//  URL.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
#if canImport(FoundationNetworking) // ...
import FoundationNetworking
#endif

// Didn't expect to have to write anything like this, not thought at all
// about what queue we're running on throughout -- blocks all over the place
// I suppose so no foul in explicitly blocking it here.
extension URL {
    func fetch() throws -> Data {
        if let data = try Self.harness.check(url: self) {
            return data
        }

        var outData: Data?
        var outError: Error?
        var outResponse: URLResponse?

        var completed = false
        let cv = NSCondition()

        let task = URLSession.shared.dataTask(with: self) { data, response, error in
            outData = data
            outResponse = response
            outError = error
            cv.lock()
            completed = true
            cv.signal()
            cv.unlock()
        }

        logDebug("Trying to fetch URL \(self)...")
        task.resume()

        cv.lock()
        while !completed {
            cv.wait()
        }
        cv.unlock()

        if let data = outData,
            let response = outResponse as? HTTPURLResponse,
            response.statusCode == 200 {
            return data
        }
        let rspStr = outResponse?.description ?? "??"
        let errStr = outError.flatMap { String(describing: $0) } ?? "??"
        throw J2Error(.errUrlFetch, self, rspStr, errStr)
    }

    // MARK: Unit test harness

    final class Harness {
        typealias Result = Swift.Result<String, J2Error>
        private var rules: [String: Result] = [:]

        func set(_ url: URL, _ result: Result) {
            rules[url.absoluteString] = result
        }

        func clear(url: URL) {
            rules.removeValue(forKey: url.absoluteString)
        }

        func reset() {
            rules = [:]
        }

        func check(url: URL) throws -> Data? {
            guard let res = rules[url.absoluteString] else {
                return nil
            }
            switch res {
            case .failure(let error): throw error
            case .success(let string): return string.data(using: .utf8)!
            }
        }
    }

    static let harness = Harness()
}
