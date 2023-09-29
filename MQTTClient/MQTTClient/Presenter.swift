//
//  Presenter.swift
//  MQTTClient
//
//  Created by Всеволод on 15.03.2023.
//

import Foundation


enum RecieveTopicType {
    case recieve
    case status
    case connection
}

enum ConnectionTopicType: String {
    case ping = "ping"
    case pong = "pong"
}

enum RecieveFunction: String {
    case temperature = "temperature"
}

enum SendFunction: String {
    case led = "led"
    case brightness = "brightness"
}

protocol PresenterOutput: AnyObject {
    func update(for function: RecieveFunction, message: String)
    func updateState(for function: SendFunction, message: String)
}

final class Presenter {
    
    private weak var output: PresenterOutput?
    private lazy var model = Model(output: self)
    
    private var recieveFunctions: [String : RecieveFunction] = [:]
    private var statusFunctions: [String : SendFunction] = [:]
    
    private var sendTopics: [SendFunction : String] = [:]
    private var connectionTopics: [ConnectionTopicType : String] = [:]
    
    private var recieveTopicType: [String : RecieveTopicType] = [:]
    
    
    init(output: PresenterOutput) {
        self.output = output
    }
    
    func didLoadView(with functions: [String : String], statusTopics: [String : String], connectionTopics: [String : String]) {
        model.start()
        
        setTopics(from: functions)
        setStatusTopics(from: statusTopics)
        setConnectionTopics(from: connectionTopics)
        
        model.startPing(at: self.connectionTopics)
        
//        model.startRecieving(from: recieveFunctions)
//        model.getStatus(of: statusFunctions)
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
    
    private func setStatusTopics(from statusTopics: [String : String]) {
        statusTopics.forEach { functionString, statusTopic in
            if let function = SendFunction(rawValue: functionString) {
                recieveTopicType[statusTopic] = .status
                statusFunctions[statusTopic] = function
            } else {
                print("[DEBUG] unknown send function of status topic")
            }
            
        }
    }
    
    private func setConnectionTopics(from connectionTopics: [String : String]) {
        connectionTopics.forEach { typeString, connectionTopic in
            if let type = ConnectionTopicType(rawValue: typeString) {
                self.connectionTopics[type] = connectionTopic
                if type == .pong {
                    recieveTopicType[connectionTopic] = .connection
                }
            } else {
                print("[DEBUG] unknown connection type of connection topic")
            }
        }
    }
    
    
    
    func sendMessage(from sender: SendFunction, message: String) {
        model.send(message: message, to: sendTopics[sender]!)
    }
}

extension Presenter: ModelOutput {
    func update(for topic: String, message: String) {
        switch recieveTopicType[topic] {
        case .recieve:
            output?.update(for: recieveFunctions[topic]!, message: message)
        case .status:
            output?.updateState(for: statusFunctions[topic]!, message: message)
        case .connection:
            if message == "pong" {
                model.stopPing(at: connectionTopics)
                model.startRecieving(from: recieveFunctions)
                model.getStatus(of: statusFunctions, with: sendTopics)
            }
        case .none:
            return
        }
    }
    
    func didSubscribedTo(topic: String) {
//        if let _ = recieveFunctions[topic] {
//
//        }
        
        guard let function = statusFunctions[topic] else {
            return
        }
        
        model.send(message: "get", to: sendTopics[function]!)
    }
}

