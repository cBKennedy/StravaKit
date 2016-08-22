//
//  Strava.swift
//  StravaKit
//
//  Created by Brennan Stehling on 8/18/16.
//  Copyright © 2016 SmallSharpTools LLC. All rights reserved.
//
// Implementation influenced by LyftKit created by Genady Okrain.
//
// Strava API
// See: http://strava.github.io/api/

import Foundation

public enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
}

public enum StravaErrorCode: Int {
    case NoAccessToken = 501
    case NoResponse = 502
    case InvalidResponse = 503
}

public class Strava {
    static let sharedInstance = Strava()
    static let stravaBaseURL = "https://www.strava.com"
    internal var clientId: String?
    internal var clientSecret: String?
    internal var redirectURI: String?
    internal var accessToken: String?
    internal var athlete: Athlete?

    public static var isAuthenticated: Bool {
        get {
            return sharedInstance.accessToken != nil && sharedInstance.athlete != nil
        }
    }

    public static var currentAthlete: Athlete? {
        get {
            return sharedInstance.athlete
        }
    }

    public static func request(method: HTTPMethod, authenticated: Bool, path: String, params: [String: AnyObject]?, completionHandler: ((response: [String: AnyObject]?, error: NSError?) -> ())?) -> NSURLSessionTask? {
        if let url = urlWithString(stravaBaseURL + path, parameters: method == .GET ? params : nil) {
            let request = NSMutableURLRequest(URL: url)
            request.HTTPMethod = method.rawValue
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            do {
                // Place parameters in body for POST and PUT methods
                if let params = params  where method == .POST || method == .PUT {
                    let body = try NSJSONSerialization.dataWithJSONObject(params, options: [])
                    request.HTTPBody = body
                }

                return processRequest(request, authenticated: authenticated, completionHandler: completionHandler)
            } catch {
                completionHandler?(response: nil, error: NSError(domain: "Body JSON Serialization Failed", code: StravaErrorCode.InvalidResponse.rawValue, userInfo: nil))
                return nil
            }
        }

        return nil
    }

    // MARK: Helper functions

    internal static func processRequest(request: NSURLRequest, authenticated: Bool, completionHandler: ((response: [String: AnyObject]?, error: NSError?) -> ())?) -> NSURLSessionTask? {
        let sessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
        if authenticated {
            guard let accessToken = sharedInstance.accessToken else {
                completionHandler?(response: nil, error: NSError(domain: "No Access Token", code: StravaErrorCode.NoAccessToken.rawValue, userInfo: nil))
                return nil
            }
            sessionConfiguration.HTTPAdditionalHeaders = ["Authorization": "Bearer \(accessToken)"]
        }
        let session = NSURLSession(configuration: sessionConfiguration)
        let task = session.dataTaskWithRequest(request) { data, response, error in
            if let data = data {
                if data.length == 0 {
                    completionHandler?(response: [:], error: error)
                } else {
                    do {
                        if let response = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as? [String: AnyObject] {
                            completionHandler?(response: response, error: error)
                        } else {
                            completionHandler?(response: nil, error: NSError(domain: "No Response", code: StravaErrorCode.NoResponse.rawValue, userInfo: nil))
                        }
                    } catch {
                        completionHandler?(response: nil, error: NSError(domain: "Response JSON Serialization Failed", code: StravaErrorCode.InvalidResponse.rawValue, userInfo: nil))
                    }
                }
            } else if let error = error {
                completionHandler?(response: nil, error: error)
            } else {
                completionHandler?(response: nil, error: NSError(domain: "No Data", code: StravaErrorCode.NoResponse.rawValue, userInfo: nil))
            }
        }
        task.resume()
        return task
    }

    internal static func urlWithString(string: String?, parameters: [String : AnyObject]?) -> NSURL? {
        guard let string = string else {
            return nil
        }

        let URL = NSURL(string: string)
        if let parameters = parameters {
            return appendQueryParameters(parameters, URL: URL)
        }
        else {
            return URL
        }
    }

    internal static func appendQueryParameters(parameters: [String : AnyObject], URL: NSURL?) -> NSURL? {
        guard let URL = URL,
            let components = NSURLComponents(URL: URL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        var queryItems: [NSURLQueryItem] = []

        for key in parameters.keys {
            let value = parameters[key]
            if let stringValue = value as? String {
                let queryItem : NSURLQueryItem = NSURLQueryItem(name: key, value: stringValue)
                queryItems.append(queryItem)
            }
            else if let value = value {
                let stringValue = "\(value)"
                let queryItem : NSURLQueryItem = NSURLQueryItem(name: key, value: stringValue)
                queryItems.append(queryItem)
            }
        }

        components.queryItems = queryItems

        return components.URL
    }

}
