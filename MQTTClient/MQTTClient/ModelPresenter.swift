//
//  ModelPresenter.swift
//  MQTTClient
//
//  Created by Всеволод on 05.03.2023.
//

import Foundation

enum RecieveTopicType {
    case recieve
    case status
}

enum RecieveFunction: String {
    case temperature = "temperature"
    case adjustment = "adjustment"
}

enum SendFunction: String {
    case led = "led"
    case brightness = "brightness"
}

protocol PresenterOutput: AnyObject {
    func update(for function: RecieveFunction, message: String)
    func updateState(for function: SendFunction, message: String)
}

final class Presenter: MqttManagerOutput {
    
    private weak var output: PresenterOutput?
    private lazy var mqttManager = MQttManager(output: self)
    
    private var recieveFunctions: [String : RecieveFunction] = [:]
    private var statusFunctions: [String : SendFunction] = [:]
    
    private var sendTopics: [SendFunction : String] = [:]
    
    private var recieveTopicType: [String : RecieveTopicType] = [:]
    
    
    init(output: ModelPresenterOutput) {
        self.output = output
    }
    
    func didLoadView(with functions: [String : String], status: [String : String]) {
        mqttManager.start()
        
        setTopics(from: functions)
        setStatus(from: status)
        
        startRecieving()
        checkingStatus()
    }
    
    private func setTopics(from functions: [String : String]) { // funcStr : topic
        functions.forEach { functionString, topic in
            if let function = RecieveFunction(rawValue: functionString) {
                recieveTopicType[topic] = .recieve
                recieveFunctions[topic] = function
            } else if let function = SendFunction(rawValue: functionString) {
                sendTopics[function] = topic
            } else {
                print("[DEBUG] unknown function")
            }
        }
    }
    
    private func setStatus(from status: [String : String]) {
        status.forEach { functionString, checkTopic in
            if let function = SendFunction(rawValue: functionString) {
                recieveTopicType[checkTopic] = .status
                statusFunctions[checkTopic] = function
            } else {
                print("[DEBUG] unknown state")
            }
            
        }
    }
    
     private func startRecieving() {
        recieveFunctions.forEach { topic, _ in
            mqttManager.subscribe(to: topic)
        }
    }
    
    private func checkingStatus() {
        statusFunctions.forEach { topic, _ in
            mqttManager.subscribe(to: topic)
        }
    }
    
    func sendMessage(from sender: SendFunction, message: String) {
        switch sender {
        case .led:
            mqttManager.publish(message: message, to: sendTopics[sender]!)
        case .brightness:
            return
        }
    }
    
    func update(for topic: String, message: String) {
        switch recieveTopicType[topic] {
        case .recieve:
            output?.update(for: recieveFunctions[topic]!, message: message)
        case .status:
            output?.updateState(for: statusFunctions[topic]!, message: message)
        case .none:
            return
        }
    }
}
