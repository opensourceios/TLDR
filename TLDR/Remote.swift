//
//  Remote.swift
//  TLDR
//
//  Created by Suraj Pathak on 20/1/16.
//  Copyright © 2016 Suraj Pathak. All rights reserved.
//

import Foundation
import SSZipArchive

struct NetworkManager {

    static func cachedZipUrl() -> String {
        return Constant.tldrZipUrl
    }

    static func remoteZipUrl() -> String {
        guard let gitUrl = Constant.remoteConfig["gitUrl"],
            let user = Constant.remoteConfig["user"],
            let repo = Constant.remoteConfig["repo"],
            let branch = Constant.remoteConfig["branch"] else {
                return Constant.tldrZipUrl
        }
        return "\(gitUrl)\(user)/\(repo)/archive/\(branch).zip"
    }

    static func checkAutoUpdate(printVerbose verbose: Bool) {
        if verbose {
            Verbose.addToVerbose("{{🔍 Checking last update time}}")
        }
        guard let localLastUpdateTime = getLastModifiedDate() else {
            Verbose.addToVerbose("Library was never updated. Will update now")
            updateTldrLibrary()
            return
        }
        // Do a head request to see if remote is updated since this date
        let source = cachedZipUrl()
        guard let url = NSURL(string: source) else {
            return
        }
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "HEAD"
        let dateString = localLastUpdateTime.stringInHeaderFormat()
        request.addValue(dateString, forHTTPHeaderField: "If-Modified-Since")
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request) { data, response, error in
            guard let httpResponse = response as? NSHTTPURLResponse else {
                Verbose.addToVerbose("The last modified date could not be found. Updating a new version now anyway.")
                updateTldrLibrary()
                return
            }
            if httpResponse.statusCode == 304 {
                // swiftlint:disable line_length
                if verbose {
                    Verbose.addToVerbose("The current version which was updated at _\(localLastUpdateTime.stringInRedableFormat())_ is the latest version. Not auto updating now.")
                }
                // swiftlint:enable line_length
            } else {
                Verbose.addToVerbose("There is a new update available. Updating a new version now.")
                updateTldrLibrary()
            }
        }
        task.resume()
    }

    static func updateTldrLibrary() {
        Verbose.addToVerbose("{{ 💿 Updating tldr library. This might take few seconds. }}")
        let zipSource = cachedZipUrl()
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), {
            guard let url = NSURL(string: zipSource),
                let data = NSData(contentsOfURL: url) else {
                    Verbose.addToVerbose("Library could not be downloaded at this time. Please try again later.")
                    return
            }
            if data.writeToFile(FileManager.urlToTldrUpdateFolder()!.path!, atomically: true) {
                let destinationUrl = FileManager.urlToTldrUpdateFolder()!.URLByDeletingPathExtension!
                if SSZipArchive.unzipFileAtPath(FileManager.urlToTldrUpdateFolder()!.path!, toDestination: destinationUrl.path!) {
                    Verbose.addToVerbose("{{ 🍺 Library is downloaded and updated. }}")
                    do {
                        try FileManager.fileManager.removeItemAtURL(FileManager.urlToTldrUpdateFolder()!)
                    } catch {}
                    FileManager.copyFromSourceUrl(destinationUrl, to: FileManager.urlToTldrFolder(), replaceIfExist: true)
                    updateLastUpdateDate()
                }
            }
        })
    }

    static func updateLastUpdateDate() {
        NSUserDefaults.standardUserDefaults().setObject(NSNumber(double: NSDate().timeIntervalSince1970), forKey: "LastModifiedDate")
    }

    static func getLastModifiedDate() -> NSDate? {
        guard let date = NSUserDefaults.standardUserDefaults().valueForKey("LastModifiedDate") as? Double else {
            return nil
        }
        return NSDate(timeIntervalSince1970: date)
    }
}

extension NSDate {
    func stringInHeaderFormat() -> String {
        let formatter = NSDateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        formatter.timeZone = NSTimeZone(name: "GMT")
        return formatter.stringFromDate(self) // eg Wed, 20 Jan 2016 23:15:28 GMT
    }

    func stringInRedableFormat() -> String {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .MediumStyle
        formatter.timeStyle = .MediumStyle
        return formatter.stringFromDate(self)
    }
}