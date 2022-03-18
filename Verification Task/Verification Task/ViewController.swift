//
//  ViewController.swift
//  Verification Task
//
//  Created by Никита Хламов on 09.03.2022.
//

import UIKit
import CoreLocation
import SnapKit

class ViewController: UIViewController, CLLocationManagerDelegate {
    
    private weak var t1: DispatchQueue?
    private weak var t2: DispatchQueue?
    private weak var t3: DispatchQueue?
    private weak var resultQueue = DispatchQueue.global(qos: .background)
    
    private let startButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)
    
    private lazy var manager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        return manager
    }()
    
    private var timeIntervalA: Double
    private var timeIntervalB: Double
    private var maxItemsNumberC: Int
    private var url: URL
    private var resultsList = [String]()
    private var gpsTimer: DispatchSourceTimer?
    private var batteryTimer: DispatchSourceTimer?
    private var isAlreadyStarted = false
    
    init(timeIntervalA: Double, timeIntervalB: Double, maxItemsNumberC: Int, url: URL) {
        self.timeIntervalA = timeIntervalA
        self.timeIntervalB = timeIntervalB
        self.maxItemsNumberC = maxItemsNumberC
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        adjustUI()
    }
    
    @objc private func didTapStart() {
        guard isAlreadyStarted == false else {
            return
        }
        isAlreadyStarted = true
        
        t1 = DispatchQueue.global(qos: .background)
        t1?.async { [weak self] in
            guard let self = self else {
                return
            }
            self.getGPS(timeInterval: self.timeIntervalA, queue: self.t1)
        }
        
        t2 = DispatchQueue.global(qos: .background)
        t2?.async { [weak self] in
            guard let self = self else {
                return
            }
            self.getPercentageOfBattery(timeInterval: self.timeIntervalB, queue: self.t2)
        }
    }
    
    @objc private func didTapStop() {
        if isAlreadyStarted == false {
            return
        }
        isAlreadyStarted = false
        t1 = nil
        t2 = nil
        t3 = nil
        gpsTimer?.cancel()
        gpsTimer = nil
        batteryTimer?.cancel()
        batteryTimer = nil
        print("STOP")
    }
    
    private func getGPS(timeInterval a: Double, queue: DispatchQueue?) {
        gpsTimer = DispatchSource.makeTimerSource(queue: queue)
        gpsTimer?.setEventHandler { [weak self] in
            guard let self = self else {
                return
            }
            self.manager.startUpdatingLocation()
            guard let coordinate = self.manager.location?.coordinate else {
                return
            }
            let coordinates = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
            self.addToList(result: "\(coordinates)")
        }
        gpsTimer?.schedule(deadline: .now(), repeating: a)
        gpsTimer?.activate()
    }
    
    func getPercentageOfBattery(timeInterval b: Double, queue: DispatchQueue?) {
        batteryTimer = DispatchSource.makeTimerSource(queue: queue)
        batteryTimer?.setEventHandler { [weak self] in
            guard let self = self else {
                return
            }
            let batteryPercentage = Int(UIDevice.current.batteryLevel * (-100))
            self.addToList(result: "Battery percentage = \(batteryPercentage)%")
        }
        batteryTimer?.schedule(deadline: .now(), repeating: b)
        batteryTimer?.activate()
    }
    
    private func addToList(result: String) {
        resultQueue?.sync {
            resultsList.append(result)
            print(result)
            if resultsList.count > maxItemsNumberC {
                t3 = DispatchQueue.global(qos: .background)
                let resultsListToSend = resultsList
                t3?.async { [weak self] in
                    guard let self = self else {
                        return
                    }
                    self.sendToServer(list: resultsListToSend, url: self.url)
                }
                resultsList = []
            }
        }
    }
    
    func sendToServer(list: [String], url: URL) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: AnyHashable] = ["Result": list]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: .fragmentsAllowed)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil, let status = (response as? HTTPURLResponse)?.statusCode, status >= 200 && status <= 299 else {
                return
            }
            do {
                let response = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
                print("SUCCESS \(response)")
            }
            catch {
                print(error)
            }
        }.resume()
    }
    
    private func adjustUI() {
        view.backgroundColor = .systemBackground
        
        startButton.setTitle("START", for: .normal)
        startButton.backgroundColor = .systemGreen
        startButton.tintColor = .systemBackground
        startButton.layer.cornerRadius = 8
        startButton.addTarget(self, action: #selector(didTapStart), for: .touchUpInside)
        
        view.addSubview(startButton)
        startButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-40)
            make.width.equalTo(200)
            make.height.equalTo(50)
        }
        
        stopButton.setTitle("STOP", for: .normal)
        stopButton.backgroundColor = .systemRed
        stopButton.tintColor = .systemBackground
        stopButton.layer.cornerRadius = 8
        stopButton.addTarget(self, action: #selector(didTapStop), for: .touchUpInside)
        
        view.addSubview(stopButton)
        stopButton.snp.makeConstraints { make in
            make.centerX.equalTo(startButton)
            make.top.equalTo(startButton.snp.bottom).offset(40)
            make.width.height.equalTo(startButton)
        }
    }
}
