//
//  RxSwiftDemoTests.swift
//  RxSwiftDemoTests
//
//  Created by Blake Tucker on 3/15/16.
//  Copyright © 2016 Blake Tucker. All rights reserved.
//

import XCTest

import RxSwift
import RxTests
import RxCocoa


let resolution: NSTimeInterval = 0.2 // seconds

class RxSwiftDemoTests: XCTestCase {
    
    let booleans = ["t" : true, "f" : false]
    let events = ["x" : ()]
    let errors = [
        "#1" : NSError(domain: "Some unknown error maybe", code: -1, userInfo: nil),
        "#u" : NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
    ]
    let validations = [
        "e" : ValidationResult.Empty,
        "f" : ValidationResult.Failed(message: ""),
        "o" : ValidationResult.OK(message: "Validated"),
        "v" : ValidationResult.Validating
    ]
    
    let stringValues = [
        "u1" : "verysecret",
        "u2" : "secretuser",
        "u3" : "secretusername",
        "p1" : "huge secret",
        "p2" : "secret",
        "e" : ""
    ]
    
    func testGitHubSignup_vanillaObservables_1_testEnabledUserInterfaceElements() {
        let scheduler = TestScheduler(initialClock: 0, resolution: resolution, simulateProcessingDelay: false)
        
        // mock the universe
        let mockAPI = mockGithubAPI(scheduler)
        
        // expected events and test data
        let (
        usernameEvents,
        passwordEvents,
        repeatedPasswordEvents,
        loginTapEvents,
        
        expectedValidatedUsernameEvents,
        expectedSignupEnabledEvents
        ) = (
            scheduler.parseEventsAndTimes("e---u1----u2-----u3-----------------", values: stringValues).first!,
            scheduler.parseEventsAndTimes("e----------------------p1-----------", values: stringValues).first!,
            scheduler.parseEventsAndTimes("e---------------------------p2---p1-", values: stringValues).first!,
            scheduler.parseEventsAndTimes("------------------------------------", values: events).first!,
            
            scheduler.parseEventsAndTimes("e---v--f--v--f---v--o----------------", values: validations).first!,
            scheduler.parseEventsAndTimes("f--------------------------------t---", values: booleans).first!
        )
        
        let wireframe = MockWireframe()
        let validationService = GitHubDefaultValidationService(API: mockAPI)
        
        let viewModel = GithubSignupViewModel1(
            input: (
                username: scheduler.createHotObservable(usernameEvents).asObservable(),
                password: scheduler.createHotObservable(passwordEvents).asObservable(),
                repeatedPassword: scheduler.createHotObservable(repeatedPasswordEvents).asObservable(),
                loginTaps: scheduler.createHotObservable(loginTapEvents).asObservable()
            ),
            dependency: (
                API: mockAPI,
                validationService: validationService,
                wireframe: wireframe
            )
        )
        
        // run experiment
        let recordedSignupEnabled = scheduler.record(viewModel.signupEnabled)
        let recordedValidatedUsername = scheduler.record(viewModel.validatedUsername)
        
        scheduler.start()
        
        // validate
        XCTAssertEqual(recordedValidatedUsername.events, expectedValidatedUsernameEvents)
        XCTAssertEqual(recordedSignupEnabled.events, expectedSignupEnabledEvents)
    }
    
    func testGitHubSignup_drivers_2_testEnabledUserInterfaceElements() {
        let scheduler = TestScheduler(initialClock: 0, resolution: resolution, simulateProcessingDelay: false)
        
        // mock the universe
        let mockAPI = mockGithubAPI(scheduler)
        
        // expected events and test data
        let (
        usernameEvents,
        passwordEvents,
        repeatedPasswordEvents,
        loginTapEvents,
        
        expectedValidatedUsernameEvents,
        expectedSignupEnabledEvents
        ) = (
            scheduler.parseEventsAndTimes("e---u1----u2-----u3-----------------", values: stringValues).first!,
            scheduler.parseEventsAndTimes("e----------------------p1-----------", values: stringValues).first!,
            scheduler.parseEventsAndTimes("e---------------------------p2---p1-", values: stringValues).first!,
            scheduler.parseEventsAndTimes("------------------------------------", values: events).first!,
            
            scheduler.parseEventsAndTimes("e---v--f--v--f---v--o----------------", values: validations).first!,
            scheduler.parseEventsAndTimes("f--------------------------------t---", values: booleans).first!
        )
        
        let wireframe = MockWireframe()
        let validationService = GitHubDefaultValidationService(API: mockAPI)
        
        let viewModel = GithubSignupViewModel2(
            input: (
                username: scheduler.createHotObservable(usernameEvents).asDriver(onErrorJustReturn: ""),
                password: scheduler.createHotObservable(passwordEvents).asDriver(onErrorJustReturn: ""),
                repeatedPassword: scheduler.createHotObservable(repeatedPasswordEvents).asDriver(onErrorJustReturn: ""),
                loginTaps: scheduler.createHotObservable(loginTapEvents).asDriver(onErrorJustReturn: ())
            ),
            dependency: (
                API: mockAPI,
                validationService: validationService,
                wireframe: wireframe
            )
        )
        
        /**
        This is important because driver will try to ensure that elements are being pumped on main scheduler,
        and that sometimes means that it will get queued using `dispatch_async` to main dispatch queue and
        not get flushed until end of the test.
        
        This method enables using mock schedulers for while testing drivers.
        */
        driveOnScheduler(scheduler) {
            // run experiment
            let recordedSignupEnabled = scheduler.record(viewModel.signupEnabled)
            let recordedValidatedUsername = scheduler.record(viewModel.validatedUsername)
            
            scheduler.start()
            
            // validate
            XCTAssertEqual(recordedValidatedUsername.events, expectedValidatedUsernameEvents)
            XCTAssertEqual(recordedSignupEnabled.events, expectedSignupEnabledEvents)
        }
    }
}


extension RxSwiftDemoTests {
    func mockGithubAPI(scheduler: TestScheduler) -> GitHubAPI {
        return MockGitHubAPI(
            usernameAvailable: scheduler.mock(booleans, errors: errors) { (username) -> String in
                if username == "secretusername" {
                    return "---t"
                }
                else if username == "secretuser" {
                    return "---#1"
                }
                else {
                    return "---f"
                }
            },
            signup: scheduler.mock(booleans, errors: errors) { (username, password) -> String in
                if username == "secretusername" && password == "secret" {
                    return "--t"
                }
                else {
                    return "--f"
                }
            }
        )
    }
}
