//
//  main.swift
//  Halftone
//
//  Explicit app entry point
//

import Cocoa

print("DEBUG: main.swift starting")

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

print("DEBUG: Starting app run loop")
app.run()
