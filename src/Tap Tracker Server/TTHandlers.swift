//
//  TTHandlers.swift
//  Tap Tracker
//
//  Created by Kyle Jessup on 2015-10-23.
//	Copyright (C) 2015 PerfectlySoft, Inc.
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Perfect.org open source project
//
// Copyright (c) 2015 - 2016 PerfectlySoft Inc. and the Perfect project authors
// Licensed under Apache License v2.0
//
// See http://perfect.org/licensing.html for license information
//
//===----------------------------------------------------------------------===//
//


import PerfectLib

protocol RoutingCreator {
    static func createRouting()
}

public func PerfectServerModuleInit() {
    Routing.Handler.registerGlobally()
    Company.createRouting()
    SQLManager.DefaultManager
    do {
        try Company.createCompanyTable()
    } catch {
        print("Failed to create DB.")
    }
}

/// Company struct represent a company's info.
public struct Company {
    /// InfoTable value enum.
    public enum CompanyInfoTableValue {
        case Invalid
        case TableID(Int)
    }
    /// The name of the company.
    public let name: String
    /// Unique indentifier for the company.
    public let companyID: Int
    /// The related info table id if any.
    public var infoTableID: CompanyInfoTableValue = .Invalid
    /// The base url for a company. e.g http://www.eng.facebook.com/
    public var baseURL: String?
}

extension Company: RoutingCreator {
    static func createRouting() {
        Routing.Routes["POST", "/Company"] = { (_: WebResponse) in
            return PostCompanyHandler()
        }
        
        Routing.Routes["GET", "/Company"] = { (_: WebResponse) in
            return GetCompanyHandler()
        }
    }
}

extension Company {
    static func createCompanyTable() throws {
        guard let db = SQLManager.DefaultManager?.sqliteDB else {
            return
        }
        try db.execute(
            "CREATE TABLE IF NOT EXISTS Company(" +
                "CompanyID INT PRIMARY KEY NOT NULL," +
                "Name CHAR(255)," +
                "BaseURL CHAR(255)," +
                "CompanyBlogURL CHAR(255)," +
            "InfoTableID INT);"
        )
    }
}

class PostCompanyHandler: RequestHandler {
    func handleRequest(request: WebRequest, response: WebResponse) {
        let reqData = request.postBodyString
        let jsonDecoder = JSONDecoder()
        do {
            let json = try jsonDecoder.decode(reqData) as! JSONDictionaryType
            print("received request JSON: \(json.dictionary)")
            
            guard let companyName = json.dictionary["name"] as? String else {
                response.setStatus(400, message: "Bad Request")
                response.requestCompletedCallback()
                return
            }
            guard let db = SQLManager.DefaultManager?.sqliteDB else {
                return
            }
            
            try db.execute("INSERT INTO Company (CompanyID, Name, BaseURL, CompanyBlogURL, InfoTableID) VALUES (?, ?, ?, ?, ?);",
                           doBindings: { (statement) in
                            // TODO: nil check
                            try statement.bind(1, json.dictionary["companyID"] as! Int)
                            try statement.bind(2, companyName)
                            try statement.bind(3, json.dictionary["baseURL"] as? String ?? "")
                            try statement.bind(4, json.dictionary["companyBlogURL"] as? String ?? "")
                            try statement.bind(5, json.dictionary["infotableID"] as? Int ?? 0)
            })
            response.setStatus(200, message: "Created")
        } catch {
            print("Error decoding json from data: \(reqData)")
            response.setStatus(400, message: "Bad Request")
        }
        response.requestCompletedCallback()
    }
}

// End Point    : /company
// Method       : GET
// Parameters:
//      - name  : company name
//      - id    : known company id
class GetCompanyHandler: RequestHandler {
    func handleRequest(request: WebRequest, response: WebResponse) {
        do {
            guard let db = SQLManager.DefaultManager?.sqliteDB else {
                response.setStatus(400, message: "NO DB")
                response.requestCompletedCallback()
                return
            }
            var resultsJSON: [JSONValue] = []
            
            try db.forEachRow("SELECT * FROM Company", handleRow: { (statement, i) in
                var currentCompanyDict: [String: JSONValue] = [:]
                currentCompanyDict["companyID"] = statement.columnInt(0)
                currentCompanyDict["name"] = statement.columnText(1)
                currentCompanyDict["baseURL"] = statement.columnText(2)
                currentCompanyDict["companyBlogURL"] = statement.columnText(3)
                currentCompanyDict["infotableID"] = statement.columnInt(4)
                resultsJSON.append(currentCompanyDict)
            })
            let jsonEncoder = JSONEncoder()
            let resultsString = try jsonEncoder.encode(resultsJSON)
            response.appendBodyString(resultsString)
            response.addHeader("Content-Type", value: "application/json")
            response.setStatus(200, message: "OK")
        } catch {
            response.setStatus(400, message: "Bad Request!")
        }
        response.requestCompletedCallback()
    }
}

/// SQLManager
public class SQLManager {
    /// Shared instance
    public static let DefaultManager = SQLManager()
    /// The sqliteDB to provided connect to this DB.
    public var sqliteDB: SQLite {
        get {
            return dbHandler
        }
    }
    /// The private variable keeps db handler.
    private let dbHandler: SQLite
    
    private init?() {
        //        var path = NSSearchPathForDirectoriesInDomains(
        //            .DesktopDirectory, .UserDomainMask, true
        //            ).first! + "PerfectEngineeringTestDB"
        let path = PerfectServer.staticPerfectServer.homeDir() + serverSQLiteDBs + "TapTrackerDb"
        //        do {
        //            try NSFileManager.defaultManager().createDirectoryAtPath(
        //                path, withIntermediateDirectories: true, attributes: nil
        //            )
        //        }catch {
        //            print("Fail to creat directory \(path)")
        //        }
        //
        //        path += "/db.sqlite3"
        do {
            dbHandler = try SQLite(path)
        } catch {
            print("Fail creating database at \(path)")
            return nil
        }
    }
    
    deinit {
        dbHandler.close()
    }
}
