//
//  PhotoViewController.swift
//  PortablePhotoStudio360
//
//  Created by ChangChao-Tang on 2017/8/1.
//  Copyright © 2017年 ChangChao-Tang. All rights reserved.
//

import UIKit
import PinLayout
import AVFoundation
import CoreBluetooth
import PromiseKit


class PhotoViewController: UIViewController ,UIPopoverPresentationControllerDelegate {
    
    var mediator: AppMediator?
    var pService: BluetoothPeripheralService?
    let session = AVCaptureSession()
    let deviceSession = AVCaptureDeviceDiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaTypeVideo, position: .back)
    var videoView:PreviewView?
    let testButton = UIButton()
    let testLED = UIButton()
    let popoButton = UIButton()
    let slider1 = UISlider()
    let slider2 = UISlider()
    let slider3 = UISlider()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        captureSessionConfig()
        setupUI()
        NotificationCenter.default.addObserver(self, selector: #selector(onDeviceDisconnect), name: .BluetoothDisconnect, object: nil)
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        session.startRunning()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        session.stopRunning()
    }
    
    func captureSessionConfig() {
        session.beginConfiguration()
        if session.canSetSessionPreset(AVCaptureSessionPresetHigh) {
            session.sessionPreset = AVCaptureSessionPresetHigh
        }else if session.canSetSessionPreset(AVCaptureSessionPresetMedium){
            session.sessionPreset = AVCaptureSessionPresetMedium
        }else{
            session.sessionPreset = AVCaptureSessionPresetLow
        }
        if let device = deviceSession?.devices.first {
            let input = try! AVCaptureDeviceInput(device: device)
            session.addInput(input)
        }
        session.commitConfiguration()
    }
    
    func setupUI() {
        view.backgroundColor = UIColor.black
        videoView = PreviewView(frame: view.bounds, session: session)
        view.addSubview(videoView!)
        testButton.setTitle("testMotor", for: .normal)
        view.addSubview(testButton)
        testButton.addTarget(self, action: #selector(onTestMotor), for: .touchUpInside)
        view.addSubview(testLED)
        testLED.setTitle("testLED", for: .normal)
        testLED.addTarget(self, action: #selector(onTestLED), for: .touchUpInside)
        popoButton .setTitle("Po", for: .normal)
        popoButton.addTarget(self, action: #selector(onPopoView), for: .touchUpInside)
        view.addSubview(popoButton)
        
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoView?.pin.top(44).left(0).right(0).bottom(122)
        testButton.pin.bottom(20).right(20).width(60).height(40)
        testLED.pin.bottom(20).left(20).width(60).height(40)
        popoButton.pin.bottom(20).right(100).width(60).height(60)
    }
    
    func onDeviceDisconnect() {
        mediator?.toRoute(route: .BluetoothList, fromController: self, userInfo: nil)
    }
    
    func fetchCharateristicValue<T:BluetoothValueProtocol>(uuid:CBUUID, type:T.Type) -> T? {
        guard let pS = pService, let service = pS.peripheral.serviceWithUUID(uuid: pS.serviceUUID) else {
            return nil
        }
        guard let char = service.characteristics?.filter({ (c) -> Bool in return c.uuid == uuid}).first,
            let value = char.value else {
            return nil
        }
        let r = type.init(withValue: value)
        return r
    }
    
    func onTestMotor() {
        guard let pS = pService, let service = pS.peripheral.serviceWithUUID(uuid: pS.serviceUUID),
            let char = service.characteristic(withUUID: pS.motorCharUUID) else {
            return
        }
        
        let motorR = MotorRequest(isClockwise: false, angle: 180)
        pS.write(data: motorR.data(), charateristic: char).then { (c) -> Promise<CBCharacteristic> in
            return pS.read(charateristic: char)
        }.then(execute: { (c) -> Void in
            guard let value = c.value else {return}
            let req = MotorRequest(withValue: value)
            print(req)
        }).catch { (err) in
            print(err)
        }
    }
    
    func onTestLED() {
        guard let pS = pService, let service = pS.peripheral.serviceWithUUID(uuid: pS.serviceUUID),
            let char = service.characteristic(withUUID: pS.ledCharUUID) else {
            return
        }
        let ledR = LEDRequest(LED1: 0.1, LED2: 0.1, LED3: 0.1)
        pS.write(data: ledR!.data(), charateristic: char)
        .then { (c) -> Void in
            
        }.catch { (err) in
            print(err)
        }
        
    }
    func onPopoView() {

        let controller = SliderViewController()
        controller.view.backgroundColor = UIColor.white
        controller.preferredContentSize = CGSize(width: 500, height: 200)
        controller.modalPresentationStyle = .popover
    

        controller.popoverPresentationController?.delegate = self
        controller.popoverPresentationController?.sourceView = view
        controller.popoverPresentationController?.sourceRect = popoButton.frame
        controller.popoverPresentationController?.permittedArrowDirections = .any
        
        controller.delegate = self
        present(controller, animated: true, completion: nil)
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
    
//    func adaptivePresentationStyleForPresentationController(controller: UIPresentationController!, traitCollection: UITraitCollection!) -> UIModalPresentationStyle{
//        return UIModalPresentationStyle.none
//    }
    
    func prepareForPopoverPresentation(_ popoverPresentationController: UIPopoverPresentationController){
        print("prepareForPopoverPresentation")
    }
    
    func popoverPresentationController(_ popoverPresentationController: UIPopoverPresentationController, willRepositionPopoverTo rect: UnsafeMutablePointer<CGRect>, in view: AutoreleasingUnsafeMutablePointer<UIView>) {
        
    }
}


extension PhotoViewController:SliderViewControllerDelegate {
    func sliderDidUpdated(led1: Float, led2: Float, led3: Float){
        print("led1: " + String(led1) + ", led2: " + String(led2) + ", led3: " + String(led3))
        guard let pS = pService, let service = pS.peripheral.serviceWithUUID(uuid: pS.serviceUUID),
            let char = service.characteristic(withUUID: pS.ledCharUUID) else {
                return
        }
        let ledR = LEDRequest(LED1: led1, LED2: led2, LED3: led3)
        pS.write(data: ledR!.data(), charateristic: char)
            .then { (c) -> Promise<CBCharacteristic> in
                return pS.read(charateristic: c)
            }
            .then(execute: { (c) -> Void in
                guard let value = c.value, let ledRes = LEDRequest(withValue: value) else {
                    return
                }
                print(ledRes)
            })
            .catch { (err) in
                print(err)
            }
    }

}



//    func presentationController(controller: UIPresentationController, viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle) -> UIViewController? {
//        let navigationController = UINavigationController(rootViewController: controller.presentedViewController)
//         return navigationController
//    }
