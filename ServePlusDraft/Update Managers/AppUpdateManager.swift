//
//  AppUpdateManager.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 10/9/21.
//


import Foundation

class AppUpdateManager {

    // MARK: - Enumerations
    enum Status {
        case required
        case optional
        case noUpdate
    }

    // MARK: - Initializers
    init(bundle: BundleType = Bundle.main) {
        self.bundle = bundle
    }

    // MARK: - Public methods
    func updateStatus(for bundleId: String) -> Status {

        // Get the version of the app
        let appVersionKey = "CFBundleShortVersionString"
        guard let appVersionValue = bundle.object(forInfoDictionaryKey: appVersionKey) as? String else {
            return .noUpdate
        }

        guard let appVersion = try? Version(from: appVersionValue) else {
            return .noUpdate
        }

        // Get app info from App Store
        let iTunesURL = URL(string: "http://itunes.apple.com/lookup?bundleId=\(bundleId)")

        guard let url = iTunesURL, let data = NSData(contentsOf: url) else {
            return .noUpdate
        }

        // Decode the response
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let response = try? decoder.decode(iTunesInfo.self, from: data as Data) else {
            return .noUpdate
        }

        // Verify that there is at least on result in the response
        guard response.results.count == 1, let appInfo = response.results.first else {
            return .noUpdate
        }

        let appStoreVersion = appInfo.version
        let releaseDate = appInfo.currentVersionReleaseDate

        let oneWeekInSeconds: TimeInterval = 7 * 24 * 60 * 60
        let dateOneWeekAgo = Date(timeIntervalSinceNow: -oneWeekInSeconds)

        // Decide if it's a required or optional update based on the release date and the version change
        if case .orderedAscending = releaseDate.compare(dateOneWeekAgo) {
            if appStoreVersion.major > appVersion.major {
                return .required
            } else if appStoreVersion.minor > appVersion.minor {
                return .optional
            } else if appStoreVersion.patch > appVersion.patch {
                return .optional
            }
        }
        return .noUpdate
    }

    // MARK: - Private properties
    private let bundle: BundleType
}
