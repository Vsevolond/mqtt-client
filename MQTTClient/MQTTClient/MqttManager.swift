//
//  MqttManager.swift
//  MQTTClient
//
//  Created by Всеволод on 04.03.2023.
//

import Foundation
import CocoaMQTT


protocol MqttManagerOutput: AnyObject {
    func update(for topic: String, message: String)
}

final class MQttManager {
    static let notificationKey: NSNotification.Name = .init(rawValue: "ru.vsevond.MQTTClient.subscribed")
    
    private weak var output: MqttManagerOutput?
    
    private let queue = DispatchQueue(label: "MQTT", qos: .utility, attributes: .concurrent)
    
    private static let host = "test.mosquitto.org"
    private static let port = 1883
    
    private var mqtt5: CocoaMQTT5?
    private var state = CocoaMQTTConnState.disconnected {
        didSet {
            if state == .connected {
                queue.resume()
            }
        }
    }
    
    init(output: MqttManagerOutput?) {
        self.output = output
    }
    
    func start() {
        queue.suspend()
        
        let clientID = "CocoaMQTT-" + String(ProcessInfo().processIdentifier)
        let new_mqtt5 = CocoaMQTT5(clientID: clientID, host: "test.mosquitto.org", port: 1883)
        new_mqtt5.delegate = self
        
        state = .connecting
        
        if new_mqtt5.connect() {
            mqtt5 = new_mqtt5
        } else {
            print("[DEBUG] not connected")
            state = .disconnected
        }
    }
    
    func subscribe(to topic: String) {
        if state == .connected {
            mqtt5?.subscribe(topic, qos: .qos1)
        } else {
            queue.async { [weak self] in
                DispatchQueue.main.async {
                    self?.mqtt5?.subscribe(topic, qos: .qos1)
                }
            }
        }
    }
    
    func unsubscribe(from topic: String) {
        if state == .connected {
            mqtt5?.unsubscribe(topic)
        } else {
            queue.async { [weak self] in
                DispatchQueue.main.async {
                    self?.mqtt5?.unsubscribe(topic)
                }
            }
        }
    }
    
    func publish(message: String, to topic: String) {
        if state == .connected {
            mqtt5?.publish(topic, withString: message, qos: .qos1, properties: .init())
        } else {
            queue.async { [weak self] in
                DispatchQueue.main.async {
                    self?.mqtt5?.publish(topic, withString: message, qos: .qos1, properties: .init())
                }
            }
        }
    }
}


extension MQttManager: CocoaMQTT5Delegate {
    
    func mqtt5(_ mqtt5: CocoaMQTT5, didConnectAck ack: CocoaMQTTCONNACKReasonCode, connAckData: MqttDecodeConnAck?) {
        state = .connected
        print("[DEBUG] connected")
    }
    
    func mqtt5(_ mqtt5: CocoaMQTT5, didPublishMessage message: CocoaMQTT5Message, id: UInt16) {
        print("[DEBUG] message published: \(message.string!) ### in topic: \(message.topic)")
    }
    
    func mqtt5(_ mqtt5: CocoaMQTT5, didPublishAck id: UInt16, pubAckData: MqttDecodePubAck?) {
        
    }
    
    func mqtt5(_ mqtt5: CocoaMQTT5, didPublishRec id: UInt16, pubRecData: MqttDecodePubRec?) {
        
    }
    
    func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveMessage message: CocoaMQTT5Message, id: UInt16, publishData: MqttDecodePublish?) {
        print("[DEBUG] message recieved: \(message.string!) ### from topic: \(message.topic)")
        output?.update(for: message.topic, message: message.string!)
    }
    
    func mqtt5(_ mqtt5: CocoaMQTT5, didSubscribeTopics success: NSDictionary, failed: [String], subAckData: MqttDecodeSubAck?) {
        success.forEach { topic in
            if topic.value as? Int == 1 {
                print("[DEBUG] subscribed to topic: \(topic.key as! String)")
                NotificationCenter.default.post(name: Self.notificationKey, object: nil, userInfo: ["topic" : topic.key])
            } else {
                print("[DEBUG] can't subscribe to topic: \(topic.key as! String)")
            }
        }
    }
    
    func mqtt5(_ mqtt5: CocoaMQTT5, didUnsubscribeTopics topics: [String], UnsubAckData: MqttDecodeUnsubAck?) {
        topics.forEach { topic in
            print("[DEBUG] unsubscribed from topic: \(topic)")
        }
    }
    
    
    func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveDisconnectReasonCode reasonCode: CocoaMQTTDISCONNECTReasonCode) {
        
    }
    
    func mqtt5DidPing(_ mqtt5: CocoaMQTT5) {
        
    }
    
    func mqtt5DidReceivePong(_ mqtt5: CocoaMQTT5) {
        
    }
    
    func mqtt5DidDisconnect(_ mqtt5: CocoaMQTT5, withError err: Error?) {
        print("[DEBUG] disconnected")
        state = .disconnected
        
        guard let error = err else {
            return
        }
        
        print(error.localizedDescription)
    }
    
    func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveAuthReasonCode reasonCode: CocoaMQTTAUTHReasonCode) {
        
    }
    
}
