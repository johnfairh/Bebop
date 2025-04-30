//
//  URL.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation
#if canImport(FoundationNetworking) // ...
import FoundationNetworking
#endif

private final class State: @unchecked Sendable {
    var data: Data?
    var error: Error?
    var response: URLResponse?
    var completed: Bool

    init() {
        completed = false
    }
}

// Didn't expect to have to write anything like this, not thought at all
// about what queue we're running on throughout -- blocks all over the place
// I suppose so no foul in explicitly blocking it here.
extension URL {
    func fetch() throws -> Data {
        if let data = try Self.harness.check(url: self) {
            return data
        }
        let state = State()

        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do {
                let answer = try await URLSession.shared.data(from: self)
                state.data = answer.0
                state.response = answer.1
            } catch {
                state.error = error
            }
            semaphore.signal()
        }
        semaphore.wait()

        if let data = state.data,
           let response = state.response as? HTTPURLResponse,
            response.statusCode == 200 {
            return data
        }
        let errStr = state.error.flatMap { String(describing: $0) } ?? "??"
        let rspStr = state.response?.description ?? "??"
        throw BBError(.errUrlFetch, self, rspStr, errStr)
    }

    // MARK: Unit test harness

    final class Harness {
        typealias Result = Swift.Result<String, BBError>
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

    static nonisolated(unsafe) let harness = Harness()
}
