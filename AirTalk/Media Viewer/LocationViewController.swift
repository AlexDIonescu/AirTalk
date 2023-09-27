//
//  LocationViewController.swift
//  AirTalk
//
//  Created by Alex Ionescu on 27.02.2023.
//

import UIKit
import CoreLocation
import MapKit

class LocationViewController: UIViewController {
    
    let locationMg = CLLocationManager()
    var completition : ((CLLocationCoordinate2D) -> Void)?
    var coordinates : CLLocationCoordinate2D?
    var userCanPickLocation = true
    let mapPin = MKPointAnnotation()
    let map: MKMapView = {
        let map = MKMapView()
        return map
    }()
    let button : UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.backgroundColor = .systemMint
        button.tintColor = .white
        button.layer.cornerRadius = 25
        return button
    }()
    let userLocationButton : UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "location.fill"), for: .normal)
        button.backgroundColor = .white
        button.tintColor = .systemBlue
        button.layer.borderColor = UIColor.systemGray.cgColor
        button.layer.borderWidth = 1.5
        button.layer.cornerRadius = 15
        button.layer.transform = CATransform3DMakeScale(1.5, 1.5, 1.5)
        return button
    }()
    init(coordinates: CLLocationCoordinate2D?) {
        if coordinates != nil {
            self.coordinates = coordinates
            self.userCanPickLocation = false
        }
        super.init(nibName: nil, bundle: nil)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        map.isUserInteractionEnabled = true
        locationMg.requestWhenInUseAuthorization()
        locationMg.desiredAccuracy = kCLLocationAccuracyBest
        locationMg.distanceFilter = kCLDistanceFilterNone
        locationMg.startUpdatingLocation()
        map.showsUserLocation = true
        map.userTrackingMode = .followWithHeading      //follow user location
        if let coordinates = self.coordinates {
            let region = MKCoordinateRegion(center: coordinates, latitudinalMeters: 200, longitudinalMeters: 200)
            map.setRegion(region, animated: true)
        }
        
        if userCanPickLocation {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send", style: .done, target: self, action: #selector(sendButttonTap))
            let gesture = UITapGestureRecognizer(target: self, action: #selector(mapTapped))
            gesture.numberOfTouchesRequired = 1
            gesture.numberOfTapsRequired = 1
            map.addGestureRecognizer(gesture)
        } else {
            guard let coordinates = self.coordinates else {
                return
            }
            
            
            mapPin.coordinate = coordinates
            map.addAnnotation(mapPin)
        }
        self.hidesBottomBarWhenPushed = true
        view.addSubview(map)
        view.addSubview(button)
        view.addSubview(userLocationButton)
        button.addTarget(self, action: #selector(presentMapOptions), for: .touchUpInside)
        userLocationButton.addTarget(self, action: #selector(goToUserLocation), for: .touchUpInside)
    }
    
    
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        map.frame = CGRect(x: 0, y: view.safeAreaInsets.top, width: view.frame.width, height: view.frame.height)
        
        button.frame = CGRect(x: view.frame.size.width - 70, y: view.frame.size.height - 75, width: 50, height: 50)
        
        userLocationButton.frame = CGRect(x: view.frame.size.width - 55, y: navigationItem.accessibilityFrame.minY + 120, width: 30, height:30)
    }
    @objc func sendButttonTap() {
        guard let coordinates = coordinates else {
            return
        }
        navigationController?.popViewController(animated: true)
        completition?(coordinates)
        
    }
    @objc func goToUserLocation() {
        self.map.setUserTrackingMode( .follow, animated: true)
    }
    @objc func presentMapOptions() {
        if self.coordinates == nil {
            let alert = UIAlertController(title: "No location selected!", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
        } else {
            let alert = UIAlertController(title: "Open in:", message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Apple Maps", style: .default, handler: { action in       //open location in Apple maps
                guard let coordinates = self.coordinates else {
                    return
                }
                guard let url = URL(string: "maps://?saddr=&daddr=\(coordinates.latitude),\(coordinates.longitude)") else {
                    return
                }
                UIApplication.shared.open(url)
            }))
            alert.addAction(UIAlertAction(title: "Google Maps", style: .default, handler: { action in
                guard let coordinates = self.coordinates else {
                    return
                }
                guard let url = URL(string: "comgooglemaps://?saddr=&daddr=\(coordinates.latitude),\(coordinates.longitude)&directionsmode=driving") else {   //open location in Google Maps
                    return
                }
                UIApplication.shared.open(url) { success in
                    if !success {
                        let alert = UIAlertController(title: "Google Maps not installed!", message: nil, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
                        self.present(alert, animated: true)
                    }
                }

            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        }
    }
    
    //MARK: Add pin to map
    @objc func mapTapped(gesture: UITapGestureRecognizer) {
        let locationInView = gesture.location(in: map)
        self.coordinates = map.convert(locationInView, toCoordinateFrom: map)
        
        for annotation in map.annotations {
            map.removeAnnotation(annotation)
        }
        let mapPin = MKPointAnnotation()
        guard let coordinates = coordinates else {
            return
        }
        mapPin.coordinate = coordinates
        map.addAnnotation(mapPin)
    }
}
