//
//  Helpers.swift
//  PapaDot
//
//  Created by Jeff Pazahanick on 12/11/25.
//


import UIKit
import MessageUI

func openMessages(to name: String) {
    guard let url = URL(string: "sms:") else { return }
    UIApplication.shared.open(url)
}

func openApplePay(to name: String, amount: Int) {
    // Opens Apple Pay with prefilled amount — iOS 17+
    guard let url = URL(string: "https://applepay://pay?amount=\(amount)&note=PapaDot") else { return }
    UIApplication.shared.open(url)
}