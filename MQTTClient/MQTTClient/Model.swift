//
//  Model.swift
//  MQTTClient
//
//  Created by Всеволод on 15.03.2023.
//

import Foundation


protocol ModelOutput: AnyObject {
    func update(for topic: String, message: String)
    func didSubscribedTo(topic: String)
}


final class Model {
    private var messages: [String : String] = [:]
    
    private weak var output: ModelOutput?
    
    private lazy var mqttManager = MQttManager(output: self)
    
    private var pingTimer: Timer?
    
    init(output: ModelOutput) {
        self.output = output
    }
    
    func start() {
        mqttManager.start()
    }
    
    func subscribe(to topic: String) {
        mqttManager.subscribe(to: topic)
    }
    
    func send(message: String, to topic: String) {
        mqttManager.publish(message: message, to: topic)
    }
    
    func startRecieving(from functions: [String : RecieveFunction]) {
        functions.forEach { topic, _ in
            mqttManager.subscribe(to: topic)
        }
    }
    
    func getStatus(of functions: [String : SendFunction], with sendTopics: [SendFunction : String]) {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didSubscribed(_:)),
                                               name: MQttManager.notificationKey,
                                               object: nil)
        
        functions.forEach { topic, _ in
            mqttManager.subscribe(to: topic)
        }
    }
    
    @objc
    private func didSubscribed(_ notification: Notification) {
        guard let userInfo = notification.userInfo, let topic = userInfo["topic"] as? String else {
            return
        }
        
        output?.didSubscribedTo(topic: topic)
    }
    
    func startPing(at connectionTopics: [ConnectionTopicType : String]) {
        mqttManager.subscribe(to: connectionTopics[ConnectionTopicType.pong]!)
        pingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) {[weak self] _ in
            self?.mqttManager.publish(message: "ping", to: connectionTopics[ConnectionTopicType.ping]!)
        }
    }
    
    func stopPing(at connectionTopics: [ConnectionTopicType : String]) { // оставить проверку соединения!
        pingTimer?.invalidate()
        mqttManager.publish(message: "ready", to: connectionTopics[ConnectionTopicType.ping]!)
        mqttManager.unsubscribe(from: connectionTopics[ConnectionTopicType.pong]!)
    }
}


extension Model: MqttManagerOutput {
    func update(for topic: String, message: String) {
        messages[topic] = message
        output?.update(for: topic, message: message)
    }
}
