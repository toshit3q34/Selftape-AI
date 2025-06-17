import Cocoa
import FlutterMacOS
import FirebaseCore
@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Initialize Firebase
    FirebaseApp.configure()
    
    super.applicationDidFinishLaunching(notification)
  }
}