//
//  Lock.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// Dumb unfair non-reentrant mutex.
final class Lock {
    var mutex = pthread_mutex_t()
    init() {
        let rc = pthread_mutex_init(&mutex, nil)
        precondition(rc == 0)
    }

    func lock() {
        let rc = pthread_mutex_lock(&mutex)
        precondition(rc == 0)
    }

    func unlock() {
        let rc = pthread_mutex_unlock(&mutex)
        precondition(rc == 0)
    }

    func withLock<T>(_ call: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try call()
    }
}
