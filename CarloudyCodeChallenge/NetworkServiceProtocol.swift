//
//  NetworkServiceProtocol.swift
//  BBVAChallenge
//
//  Created by Molly Tian on 2/24/17.
//  Copyright © 2017 Molly Tian. All rights reserved.
//

import Foundation
import MapboxGeocoder
import MapboxDirections

typealias FetchAddressCompletionHandler = ([Placemark]?, Error?) -> Void
typealias RouteCompletionHandler = ([Waypoint]?, [Route]?, Error?) -> Void

protocol NetworkServiceProtocol {
    func fetchAddresses(with query: String, focalLocation: CLLocation?, completion: @escaping FetchAddressCompletionHandler)
    func route(from startPoint: Waypoint, to endPoint: Waypoint, by midPoint: Waypoint?, completion: @escaping RouteCompletionHandler)
}
