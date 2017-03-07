//
//  ViewController.swift
//  CarloudyCodeChallenge
//
//  Created by Molly Tian on 3/5/17.
//  Copyright © 2017 Molly Tian. All rights reserved.
//

import UIKit
import Mapbox
import MapboxGeocoder
import MapboxDirections

class MapViewController: UIViewController {
    
    //MARK: - Properties
    
    var mapView: MGLMapView!
    
    var annotations: [MGLPointAnnotation]? {
        willSet {
            if let annotations = annotations {
                mapView.removeAnnotations(annotations)
            }
        }
        didSet {
            mapView.addAnnotations(annotations!)
        }
    }
    
    var routeLine: MGLPolyline? {
        willSet {
            if let routeLine = routeLine {
                mapView.removeAnnotation(routeLine)
            }
        }
    }

    let networkService: NetworkServiceProtocol = NetworkService()
    var setMapCenterToCurrentLocation = true
    var keepUpdatingMapCenter = false
    
    var startPoint: Waypoint?
    var endPoint: Waypoint?
    var steps: [RouteStep]? {
        didSet {
            if let step = steps?.first {
                acionsBeforeNextTurnLabel.text = step.instructions
                distanceToNextTurnLabel.text = "Drive: \(LengthFormatter().string(fromMeters: step.distance))"                
            }
        }
    }
    
    let searchController : UISearchController! = {
        var searchController = UISearchController(searchResultsController: nil)
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.dimsBackgroundDuringPresentation = true
        return searchController
    }()
    
    //MARK: - UI Outlet
    
    @IBOutlet weak var routeInfoView: UIView!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var etaLabel: UILabel!
    
    @IBOutlet weak var navigationInfoView: UIView!
    @IBOutlet weak var distanceToNextTurnLabel: UILabel!
    @IBOutlet weak var acionsBeforeNextTurnLabel: UILabel!
    
    //MARK: - IBAction
    
    @IBAction func startNavigation(_ sender: UIButton) {
        let location = mapView.userLocation
        let center = location?.coordinate
        let _ = location?.heading?.trueHeading // always nil... looks like a bug from Mapbox
        let camera = MGLMapCamera(lookingAtCenter: center!, fromDistance: 4500, pitch: 15, heading: 180)
        mapView.setCamera(camera, withDuration: 2, animationTimingFunction: CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut))
        
        routeInfoView.isHidden = true
        navigationInfoView.isHidden = false
        navigationItem.titleView = nil
        navigationItem.title = endPoint?.name
        keepUpdatingMapCenter = true
    }

    @IBAction func exitNaviMode(_ sender: UIButton) {
        navigationInfoView.isHidden = true
        navigationItem.titleView = searchController.searchBar
        keepUpdatingMapCenter = false
    }
    
    //MARK: - View Controller Life Cycle Functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let mapView = self.view as? MGLMapView {
            self.mapView = mapView
            mapView.delegate = self
            mapView.showsUserLocation = true
            mapView.setUserTrackingMode(.followWithHeading, animated: true)
            mapView.setCenter(CLLocationCoordinate2D(latitude: 39.8282, longitude: -98.5795), zoomLevel: 2, animated: false)
            
            navigationItem.titleView = searchController.searchBar
            definesPresentationContext = true
            searchController.searchResultsUpdater = self
            searchController.delegate = self
            searchController.searchBar.delegate = self
        }
        self.routeInfoView.isHidden = true
        self.navigationInfoView.isHidden = true
    }
    
    func cancelCurrentRoute() {
        routeLine = nil
        routeInfoView.isHidden = true
    }
}

    //MARK: - Extensions

extension MapViewController: MGLMapViewDelegate {
    func mapViewDidFinishLoadingMap(_ mapView: MGLMapView) {
        // should have udpated the mapView center in this method, by camera zooming out, move camera location
        // to current location, then camera zooming in. Due to the time constraint, the mapView center is updated
        // in mapView:didUpdate userLocation: instead.
    }
    
    func mapView(_ mapView: MGLMapView, didUpdate userLocation: MGLUserLocation?) {
        if setMapCenterToCurrentLocation {
            if let currentLocation = userLocation?.location {
                setMapCenterToCurrentLocation = false
                mapView.setCenter(currentLocation.coordinate, zoomLevel: 9, animated: true)
            }
        }
        
        if keepUpdatingMapCenter {
            if let currentLocation = userLocation {
                let coordinate = currentLocation.coordinate
                
//                It looks like there is a bug on Mapbox side, the heading information is always nil, so I can't use it to udpate the mapView camera as I should

//                let heading = currentLocation.heading?.trueHeading
//                let camera = MGLMapCamera(lookingAtCenter: center, fromDistance: 4500, pitch: 15, heading: heading!)
//                mapView.setCamera(camera, withDuration: 1, animationTimingFunction: CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut))
                
                mapView.setCenter(coordinate, zoomLevel: 15, animated: true)
                print("\(currentLocation.coordinate.latitude) \(currentLocation.coordinate.longitude)")
                
                var rmIndices = [Int]()
                if let steps = self.steps {
                    for step in steps {
                        if let firstCoordiante  = step.coordinates?.first {
                            print("\(firstCoordiante.distance(from: coordinate)) 米！")
                            
                            if firstCoordiante.distance(from: coordinate) < 15 {
                                //self.steps!.removeFirst()
                                rmIndices.append(steps.index(of: step)!)
                            }
                        }
                    }
                    if rmIndices.count != 0, let max = rmIndices.max() {
                        self.steps = steps.remove(to: max)
                    }
                }
            }
        }
    }
    
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        return true
    }
    
    func mapView(_ mapView: MGLMapView, didSelect annotation: MGLAnnotation) {
        cancelCurrentRoute()
        mapView.setCenter(annotation.coordinate, zoomLevel: 12, animated: true)
    }
    
    func mapView(_ mapView: MGLMapView, tapOnCalloutFor annotation: MGLAnnotation) {
        print(annotation.coordinate)
        if let currentCoordinate = mapView.userLocation?.coordinate {
            startPoint = Waypoint(coordinate: currentCoordinate, name: "Your Location")
            endPoint = Waypoint(coordinate: annotation.coordinate, name: annotation.title!)
            
            networkService.route(from: startPoint!, to: endPoint!, by: nil, completion: { (waypoints, routes, error) in
                guard error == nil, let _ = waypoints, let routes = routes else {
                    return
                }
                
                if let route = routes.first, let leg = route.legs.first {
                    self.steps = leg.steps
                    
                    let distanceFormatter = LengthFormatter()
                    let formattedDistance = distanceFormatter.string(fromMeters: route.distance)
                    
                    let travelTimeFormatter = DateComponentsFormatter()
                    travelTimeFormatter.unitsStyle = .short
                    let formattedTravelTime = travelTimeFormatter.string(from: route.expectedTravelTime)
                    
                    self.distanceLabel.text = formattedDistance
                    self.etaLabel.text = formattedTravelTime
                    
                    if route.coordinateCount > 0 {
                        var routeCoordinates = route.coordinates!
                        self.routeLine = MGLPolyline(coordinates: &routeCoordinates, count: route.coordinateCount)
                        mapView.addAnnotation(self.routeLine!)
                        mapView.setVisibleCoordinates(&routeCoordinates, count: route.coordinateCount, edgePadding: UIEdgeInsetsMake(25, 25, 45, 25), animated: true)
                    }
                }
                self.routeInfoView.isHidden = false
            })
        }
    }
}

extension MapViewController: UISearchControllerDelegate, UISearchResultsUpdating, UISearchBarDelegate {
    func updateSearchResults(for searchController: UISearchController) {
        //TODO: can return suggestion results
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        cancelCurrentRoute()
        networkService.fetchAddresses(with: searchController.searchBar.text!, focalLocation: mapView.userLocation?.location) { (placemarks, erorr) in
            if let placemars = placemarks {
                var points = [MGLPointAnnotation]()
                for placemark in placemars {
                    let point = MGLPointAnnotation()
                    if let coordinate = placemark.location?.coordinate {
                        point.coordinate = coordinate
                        point.title = placemark.name
                        point.subtitle = placemark.qualifiedName
                    }
                    points.append(point)
                }
                self.annotations = points
            }
        }
        searchController.dismiss(animated: true, completion: nil)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        cancelCurrentRoute()
    }
}

extension CLLocationCoordinate2D {
    func distance(from coordiate: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: coordiate.latitude, longitude: coordiate.longitude)
        let location2 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        return location1.distance(from: location2)
    }
}

extension Array {
    func remove(to index: Int) -> Array {
        var indexes = [Int]()
        for i in 0...index {
            indexes.append(i)
        }
        return self.enumerated().filter({ !indexes.contains($0.0) }).map { $0.1 }
    }
}
