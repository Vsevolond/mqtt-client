//
//  ViewController.swift
//  MQTTClient
//
//  Created by Всеволод on 01.03.2023.
//

import UIKit
import PinLayout
import CocoaMQTT


enum ButtonState: String {
    case on = "on"
    case off = "off"
    case disabled
    
    mutating func switchState() {
        if self == .on {
            self = .off
        } else if self == .off {
            self = .on
        }
    }
}


class ViewController: UIViewController {
    private lazy var presenter = Presenter(output: self)
    
    private let tempLabel = UILabel()

    private let button = UIButton()
    private var buttonState: ButtonState = .disabled
    
    private let brightSlider = UISlider()
    
    private var functions: [String : String] = [
        "temperature" : "device_97F4A9/temp",
        "led" : "device_97F4A9/led",
        "brightness" : "device_97F4A9/led/bright",
    ]
    
    private var statusTopics: [String : String] = [
        "led" : "device_97F4A9/led/status",
        "brightness" : "device_97F4A9/led/bright/status",
    ]
    
    private var connectionTopics = [
        "ping" : "device_97F4A9/ping",
        "pong" : "device_97F4A9/pong",
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setup()
        presenter.didLoadView(with: functions, statusTopics: statusTopics, connectionTopics: connectionTopics)
    }
    
    private func setup() {
        view.backgroundColor = .white
        title = "Test"
        
        tempLabel.text = "temperature"
        tempLabel.font = UIFont(name: "Marker Felt", size: 24)
        tempLabel.textAlignment = .center
        tempLabel.textColor = .systemMint
        
        button.layer.borderWidth = 2
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(didTapButton), for: .touchUpInside)
        setupButton()
        
        brightSlider.minimumValue = 0
        brightSlider.maximumValue = 100
        brightSlider.value = 50
        brightSlider.addTarget(self, action: #selector(didSliderValueChanged), for: .touchUpInside)
        setupSlider()
        
        view.addSubview(tempLabel)
        view.addSubview(button)
        view.addSubview(brightSlider)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        tempLabel.pin
            .vCenter()
            .horizontally(32)
            .sizeToFit(.width)
        
        button.pin
            .below(of: tempLabel)
            .marginTop(30)
            .height(32)
            .horizontally(32)
        
        brightSlider.pin
            .below(of: button)
            .marginTop(30)
            .horizontally(32)
    }
    
    @objc func didTapButton() {
        buttonState.switchState()
        setupButton()
        setupSlider()
        presenter.sendMessage(from: .led, message: buttonState.rawValue)
    }
    
    @objc func didSliderValueChanged() {
        presenter.sendMessage(from: .brightness, message: String(Int(brightSlider.value)))
    }
    
    private func setupButton() {
        switch buttonState {
        case .off:
            button.setTitle("ON", for: .normal)
            button.setTitleColor(.systemBlue.withAlphaComponent(0.8), for: .normal)
        case .on:
            button.setTitle("OFF", for: .normal)
            button.setTitleColor(.systemRed.withAlphaComponent(0.8), for: .normal)
        case .disabled:
            button.setTitle("Checking...", for: .normal)
            button.setTitleColor(.systemGray3, for: .normal)
            button.isUserInteractionEnabled = false
        }
        button.layer.borderColor = button.currentTitleColor.cgColor
    }
    
    private func setupSlider() {
        switch buttonState {
        case .on:
            brightSlider.isUserInteractionEnabled = true
        case .off:
            brightSlider.isUserInteractionEnabled = false
        case .disabled:
            brightSlider.isUserInteractionEnabled = false
        }
    }
    
}

extension ViewController: PresenterOutput {
    func update(for function: RecieveFunction, message: String) {
        switch function {
        case .temperature:
            tempLabel.text = message + " °C"
        }
    }
    
    func updateState(for function: SendFunction, message: String) {
        switch function {
        case .led:
            guard let state = ButtonState(rawValue: message) else {
                buttonState = .disabled
                return
            }
            
            if buttonState != state {
                buttonState = state
                setupButton()
                setupSlider()
            }
            
            if !button.isUserInteractionEnabled {
                button.isUserInteractionEnabled = true
            }
            
        case .brightness:
            if message.isNumber {
                brightSlider.value = Float(message)!
            }
        }
    }
}

