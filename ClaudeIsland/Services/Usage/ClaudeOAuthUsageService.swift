//
//  ClaudeOAuthUsageService.swift
//  ClaudeIsland
//
//  Copyright 2026 Hudie LIU.
//  Licensed under the Apache License, Version 2.0 — see LICENSE.md.
//

import Foundation
import os.log
import Security

/// Fetches Claude subscription usage directly from Anthropic's OAuth usage endpoint.
///
/// Uses the OAuth access token Claude Code stored in macOS Keychain
/// (service: `Claude Code-credentials`). Response matches what `/usage` shows.
actor ClaudeOAuthUsageService {
    static let shared = ClaudeOAuthUsageService()

    private static let logger = Logger(subsystem: "com.claudeisland", category: "ClaudeOAuthUsage")
    private static let keychainService = "Claude Code-credentials"
    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    struct Window: Sendable {
        let utilization: Double  // 0.0–1.0
        let resetsAt: Date
    }

    struct UsagePayload: Sendable {
        let fiveHour: Window?
        let sevenDay: Window?
        let sevenDayOpus: Window?
        let sevenDaySonnet: Window?
    }

    enum FetchError: Error {
        case keychainMissing
        case keychainAccessDenied(OSStatus)
        case tokenMissing
        case requestFailed(Error)
        case httpStatus(Int)
        case malformedResponse
    }

    func fetchUsage() async throws -> UsagePayload {
        let token = try loadAccessToken()

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            Self.logger.error("OAuth usage request failed: \(error.localizedDescription)")
            throw FetchError.requestFailed(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw FetchError.malformedResponse
        }
        guard http.statusCode == 200 else {
            Self.logger.error("OAuth usage HTTP \(http.statusCode)")
            throw FetchError.httpStatus(http.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FetchError.malformedResponse
        }

        let payload = UsagePayload(
            fiveHour: Self.parseWindow(json["five_hour"]),
            sevenDay: Self.parseWindow(json["seven_day"]),
            sevenDayOpus: Self.parseWindow(json["seven_day_opus"]),
            sevenDaySonnet: Self.parseWindow(json["seven_day_sonnet"])
        )

        Self.logger.info(
            "OAuth usage: 5h=\(Self.pctLog(payload.fiveHour)) 7d=\(Self.pctLog(payload.sevenDay)) opus=\(Self.pctLog(payload.sevenDayOpus)) sonnet=\(Self.pctLog(payload.sevenDaySonnet))"
        )
        return payload
    }

    // MARK: - Keychain

    private func loadAccessToken() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            break
        case errSecItemNotFound:
            throw FetchError.keychainMissing
        default:
            throw FetchError.keychainAccessDenied(status)
        }

        guard let data = item as? Data,
              let raw = String(data: data, encoding: .utf8),
              let payloadData = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String,
              !token.isEmpty else {
            throw FetchError.tokenMissing
        }
        return token
    }

    // MARK: - Parsing helpers

    private static func parseWindow(_ raw: Any?) -> Window? {
        guard let dict = raw as? [String: Any] else { return nil }
        let utilizationRaw = dict["utilization"]
        let utilizationDouble: Double
        if let d = utilizationRaw as? Double { utilizationDouble = d }
        else if let i = utilizationRaw as? Int { utilizationDouble = Double(i) }
        else if let n = utilizationRaw as? NSNumber { utilizationDouble = n.doubleValue }
        else { return nil }

        guard let resetsAtStr = dict["resets_at"] as? String else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: resetsAtStr)
            ?? ISO8601DateFormatter().date(from: resetsAtStr)
        guard let resetsAt = date else { return nil }

        // API returns 0–100; clamp to 0.0–1.0.
        return Window(utilization: min(max(utilizationDouble / 100.0, 0), 1.0), resetsAt: resetsAt)
    }

    private static func pctLog(_ w: Window?) -> String {
        guard let w = w else { return "—" }
        return String(format: "%.1f%%", w.utilization * 100)
    }
}
