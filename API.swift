//
//  API.swift
//
//  Created by db0 on 5/19/15.
//
//

import Alamofire

public struct API {
    static var verbose = 1
    static var url = ""

    static let notConnectedErrors = [NSURLErrorNotConnectedToInternet, NSURLErrorCannotConnectToHost, NSURLErrorTimedOut, NSURLErrorCannotFindHost, NSURLErrorNetworkConnectionLost, NSURLErrorDataNotAllowed, NSURLErrorDNSLookupFailed, NSURLErrorHTTPTooManyRedirects, NSURLErrorResourceUnavailable, NSURLErrorRedirectToNonExistentLocation, NSURLErrorInternationalRoamingOff, NSURLErrorCallIsActive, NSURLErrorSecureConnectionFailed, NSURLErrorCannotLoadFromNetwork]

    class Object {
        private var json : JSON

        init(json: JSON) {
            self.json = json
        }

        subscript(identifier: String) -> API.Object {
            get {
                return self.object(identifier)
            }
        }

        func int(identifier : String, defaultInt : Int = 0) -> Int {
            if let int = self.json[identifier].asInt {
                return int
            }
            return defaultInt
        }
        func nullableInt(identifier : String) -> Int? {
            return self.json[identifier].asInt
        }

        func string(identifier : String, defaultString : String = "") -> String {
            if let string = self.json[identifier].asString {
                return string
            }
            return defaultString
        }
        func nullableString(identifier : String) -> String? {
            return self.json[identifier].asString
        }
        func nullableNotEmptyString(identifier : String) -> String? {
            return self.nullableString(identifier) == "" ? nil : self.nullableString(identifier)
        }

        func bool(identifier: String, defaultBool: Bool = false) -> Bool {
            if let bool = self.json[identifier].asBool {
                return bool
            }
            return defaultBool
        }
        func nullableBool(identifier: String) -> Bool? {
            return self.json[identifier].asBool
        }

        func object(identifier : String) -> API.Object {
            return API.Object(json: self.json[identifier])
        }
        func nullableObject(identifier : String) -> API.Object? {
            if self.json[identifier].isDictionary {
                return API.Object(json: self.json[identifier])
            }
            return nil
        }

        func array(identifier : String) -> [API.Object] {
            if let array = self.json[identifier].asArray {
                return array.map({ json in API.Object(json: json) })
            }
            return []
        }

    }

    static private func vprint(message: String, level : Int = 1) {
        if level <= API.verbose {
            println(message)
        }
    }

    static func onNotConnected(url: String, endpoint : String, parameters : [String : AnyObject]? = nil, cbSuccess : (API.Object -> Void), cbError : (API.Error -> Void)?, viewController : UIViewController?) {
        if let viewController = viewController {
            var alert = UIAlertController(title: "Connection failed", message: "Please check your internet connection and try again", preferredStyle: UIAlertControllerStyle.Alert)
            var action = UIAlertAction(title: "Retry", style: UIAlertActionStyle.Default, handler: { action in
                API.go(url: url, endpoint: endpoint, parameters: parameters, cbSuccess: cbSuccess, cbError: cbError, viewController: viewController)
            })
            alert.addAction(action)
            viewController.presentViewController(alert, animated: true, completion: nil)
        } else {
            API.vprint("Error: not connected.")
        }
    }

    static func onError(error : API.Error, viewController : UIViewController?) {
        var message = error.details
        if let statusCode = error.statusCode {
            message += String(statusCode)
        }
        if let viewController = viewController {
            var alert = UIAlertController(title: "Error", message: message, preferredStyle: UIAlertControllerStyle.Alert)
        } else {
            API.vprint("Error: " + message)
        }
    }

    class Error {
        var details : String
        var statusCode : Int?
        init() {
            self.details = "Unexpected unknown error"
        }
        init(error : NSError) {
            self.details = error.localizedDescription
            self.statusCode = error.code
        }
        init(details : String) {
            self.details = details
        }
        init(json : JSON) {
            if let fallback = json["fallback"].asString {
                self.details = fallback
            } else if let error = json["error"].asString {
                self.details = error
            } else if let details = json["detail"].asString {
                self.details = details
            } else if let status = json["status"].asString {
                self.details = status
            } else if json.toString(pretty: false) == "null" {
                self.details = "Unexpected unknown error"
            } else {
                self.details = json.toString(pretty: true)
            }
        }
    }

    static func go(url: String = API.url, endpoint : String = "", parameters : [String : AnyObject]? = nil, cbSuccess : (API.Object -> Void) = { _ in }, cbError : (API.Error -> Void)? = nil, viewController : UIViewController? = nil) {
        let cbErrorWrapper : (API.Error -> Void) = { error in
            if let statusCode = error.statusCode {
                if contains(API.notConnectedErrors, statusCode) {
                    API.vprint("Not connected error code: \(statusCode)")
                    API.onNotConnected(url, endpoint: endpoint, parameters: parameters, cbSuccess: cbSuccess, cbError: cbError, viewController: viewController)
                }
            }
            if let cbError = cbError {
                cbError(error)
            } else {
                API.onError(error, viewController: viewController)
            }
        }

        Alamofire.request(.GET, self.url + endpoint, parameters: parameters)
            .responseJSON { request, response, data, error in
                if let response = response {
                    var json : JSON = JSON(data == nil ? "null" : data!)
                    if response.statusCode >= 200 && response.statusCode < 300 {
                        API.vprint("API Success")
                        API.vprint("API Response: \(json.toString(pretty: true))", level: 3)
                        cbSuccess(API.Object(json: json))
                        return
                    }
                    API.vprint("API Error")
                    API.vprint("API Response: \(json.toString(pretty: true))", level: 3)
                    return cbErrorWrapper(API.Error(json: json))
                } else {
                    if let error = error {
                        API.vprint("API Error")
                        return cbErrorWrapper(API.Error(error: error))
                    }
                    API.vprint("API Unknown Error")
                    return cbErrorWrapper(API.Error())
                }
        }
    }
}