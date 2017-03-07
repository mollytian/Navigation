//
//  NetworkService.swift
//  BBVAChallenge
//
//  Created by Molly Tian on 2/24/17.
//  Copyright © 2017 Molly Tian. All rights reserved.
//

import Foundation
import MapboxGeocoder
import MapboxDirections
import Mapbox


class NetworkService: NSObject, NetworkServiceProtocol {
    
    let geocoder = Geocoder.shared
    let directions = Directions.shared
    
    func fetchAddresses(with query: String, focalLocation: CLLocation?, completion: @escaping ([Placemark]?, Error?) -> Void) {
        let options = ForwardGeocodeOptions(query: query)
        options.allowedISOCountryCodes = ["us"]
        options.maximumResultCount = 11
        
        if let focalLocation = focalLocation {
            options.focalLocation = focalLocation
        }
        
        let task = geocoder.geocode(options) { (placemarks, attribution, error) in
            guard let placemarks = placemarks else {
                completion(nil, error)
                return
            }
            completion(placemarks, nil)
        }
        
        task.resume()
    }
    
     // this function can calculate the route with or without a mid stop point
    func route(from startPoint: Waypoint, to endPoint: Waypoint, by midPoint: Waypoint?, completion: @escaping RouteCompletionHandler) {
        
        var waypoints = [Waypoint]();
        if let mid = midPoint {
            waypoints = [startPoint, mid, endPoint];
        } else {
            waypoints = [startPoint, endPoint];
        }
        
        let options = RouteOptions(waypoints: waypoints, profileIdentifier: MBDirectionsProfileIdentifier.automobile)
        options.includesSteps = true
        
        let task = directions.calculate(options) { (waypoints, routes, error) in
            guard error == nil, let waypoints = waypoints, let routes = routes else {
                print("Error calculating directions: \(error!)")
                completion(nil, nil, error)
                return
            }
            completion(waypoints, routes, nil)
        }
        task.resume()
    }
}
