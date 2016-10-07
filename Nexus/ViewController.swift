//
//  ViewController.swift
//  Nexus
//
//  Copyright © 2016 Nexus Social Network Pty Ptd. All rights reserved.
//

import SystemConfiguration
import MaterialKit
import UIKit
import ReachabilitySwift
import SVWebViewController
import APAddressBook
import EasyMapping
import APContactEasyMapping
import UserNotifications


var mainUrl:String = "https://nexus.social/"
//var mainUrl:String = "http://10.0.0.98:8080/"
var isLoadedWithShortcuts: Bool = false
var deviceToken:String = ""


class ViewController: UIViewController, UIWebViewDelegate, UNUserNotificationCenterDelegate {
    
    var webView = UIWebView()
    
    @IBOutlet weak var OverlayImage: UIImageView!

    @IBOutlet weak var InternetError: UILabel!
    @IBOutlet weak var LoadError: UILabel!
    
    @IBOutlet weak var NexusLogo: UIImageView!
    
    @IBOutlet weak var reloadButton: MKButton!

    @IBOutlet weak var progressLoading: UIProgressView!
    
    var urlPath:String = mainUrl
    var urlPathConst:String = mainUrl
    
    var isAuthenticated:Bool = false
    
    var appService:String = "social.nexus.nexus"
    
    var hasNetwork = false
    
    var progressTimer = Timer()
    var webviewLoaded:Bool = false
    var loadProgressAmount:Float = 0.0
    var delaySpeed:Double = 0.01667
    
    var keychain: Keychain!
    let reachability = Reachability()!
    let addressBook = APAddressBook()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        keychain = Keychain(service: appService)
        
        //Fixing the logo image to fit all screen sizes
        NexusLogo.contentMode = .scaleAspectFit
        NexusLogo.clipsToBounds = true;
        
        //Creating the WKWebView and sending it to the back of layers
        webView = UIWebView(frame: self.view.frame)
        webView.delegate = self;
        webView.scrollView.delaysContentTouches = false
        
        //Adding the webview to main view and pushing to back
        self.view.addSubview(webView)
        self.view.sendSubview(toBack: webView)
        
        //Checking internet connection
        checkInternetConnection()
        
        //Creating the reload button using MaterialKit
        reloadButton.layer.shadowOpacity = 0.55
        reloadButton.layer.shadowRadius = 5.0
        reloadButton.layer.shadowColor = UIColor.gray.cgColor
        reloadButton.layer.shadowOffset = CGSize(width: 0, height: 2.5)
        self.reloadButton.isHidden = true
        
        //Displaying the loading overlay while webview loads
        self.progressLoading.isHidden = false
        self.OverlayImage.isHidden = false
        self.NexusLogo.isHidden = false
        self.InternetError.isHidden = true
        
        //Update the loading progress while webview loads
        webView.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil)
        
        //Making the progress bar slightly larger in height
        let transform : CGAffineTransform = CGAffineTransform(scaleX: 1.0, y: 2.0)
        progressLoading.transform = transform
        
        webView.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleHeight]
        
        //Add Notification options
        
        
    }
    
    
    func loadWebView(loadUrl: String) {
        let url = NSURL(string: loadUrl)
        let req = NSURLRequest(url:url! as URL)
        webView.loadRequest(req as URLRequest)
    }
    
    //Function to check the users internet connection and hide or show elements
    //Using the 'Reachability' class in Extensions->Reachability
    func checkInternetConnection() {
        hasNetwork = true
        
        self.progressLoading.isHidden = false
        self.InternetError.isHidden = true
        self.LoadError.isHidden = true
        self.reloadButton.isHidden = true
        
        if reachability.isReachable {
            //Does have internet connection
            hasNetwork = true
            self.progressLoading.isHidden = false

            let appDelegate = UIApplication.shared.delegate as! AppDelegate

            if !appDelegate.isLoadedWithShortcuts {
                loadWebView(loadUrl: self.urlPath)
            }
        } else {
            hasNetwork = false
            
            //Does not have internet connection, so display error
            UIView.animate(withDuration: 2, delay:5, options:UIViewAnimationOptions.transitionFlipFromTop, animations: {
                self.InternetError.alpha = 1
                self.reloadButton.alpha = 1
                }, completion: { finished in
                    self.progressLoading.isHidden = true
                    self.InternetError.isHidden = false
                    self.reloadButton.isHidden = false
            })
        }
    }
    
    
    //Try and load the webview again when "Try Again" button pressed
    @IBAction func reloadAgainPress(sender: AnyObject) {
        checkInternetConnection()
    }
    
    
    //Passing through an object selected from the alerts saved credentials and inputting to the login form
    func loadCredentialsToForm(selectedCredentials: AnyObject) {
        let selectedUsername = selectedCredentials["key"] as! String!
        let selectedPassword = try! keychain.getString(selectedUsername!) as String!
        
        //Pushing the username and password to the inputs
        webView.stringByEvaluatingJavaScript(from: "loadSavedCredentialsFromWebview('" + selectedUsername! + "', '" + selectedPassword! + "', true)")
    }
    

    func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        let code = (error as NSError).code
        if(code != -999) {
            progressTimer.invalidate()
            
            //Stop webview
            webView.stopLoading()
            
            //Error for when the website is down
            self.LoadError.isHidden = false
            self.reloadButton.isHidden = false
            self.progressLoading.isHidden = true
        }
    }
    
    
    
    //webView:shouldStartLoadWithRequest:navigationType
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {

        //Opening all new windows/tabs with target="_blank" in safari
        if navigationType == UIWebViewNavigationType.linkClicked {
            if (request.url!.host! == "www.paypal.com"){
                UIApplication.shared.openURL(request.url!)
                return false
            } else {
                if let modalBrowser = SVModalWebViewController(urlRequest: request) {
                    present(modalBrowser, animated: true, completion: nil)
                }
                return false
            }
        }
        
        if (request.url?.absoluteString.hasPrefix("ios:"))! {
            // Call the given selector
            self.perform(#selector(self.webToNativeCall))
            return false
        }
        
        //Evaluate javascript here to get login details since they are about to load new page
        //Check if the header nx-authenticated is false first, since it'll be loaded to be true after
        if !self.isAuthenticated && webviewLoaded {
            let loginData:String = webView.stringByEvaluatingJavaScript(from: "getLoginDataToIosWebview().toString();")!
            
            if(!loginData.isEmpty) {
                //Extracting the username and password from the passed object from the website
                
                let loginUsername = loginData.components(separatedBy: ",")[0]
                let loginPassword = loginData.components(separatedBy: ",")[1]
                
                //Looping through all usernames to see if it already exists within the keychain to overwrite
                let allItems = keychain.allItems()
                var doesUsernameExist = false
                var doesPasswordMatch = false
                for item in allItems {
                    if(item["key"] as! String == loginUsername) {
                        doesUsernameExist = true
                        
                        let thisItemPassword = try! keychain.getString(loginUsername)
                        
                        if(thisItemPassword == loginPassword) {
                            doesPasswordMatch = true
                        }
                    }
                }
                
                if(!doesUsernameExist) {
                    //Username does not exist within Keychain, so ask to create new credential set
                    let alert = UIAlertController(title: "Save Account", message: "Would you like to save these login details for easy login next time?", preferredStyle: UIAlertControllerStyle.alert)
                    self.present(alert, animated: true, completion: nil)
                    alert.addAction(UIAlertAction(title: "No", style: UIAlertActionStyle.default, handler: nil))
                    
                    alert.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.default, handler: { action in
                        
                        //Saving new credentials to the keychain
                        do {
                            try self.keychain.set(loginPassword, key: loginUsername)
                        } catch {
                            print("Can't save to Keychain")
                        }
                    }))
                } else if(doesUsernameExist && !doesPasswordMatch) {
                    //Username exists within Keychain, yet passwords do not match, so ask to overwrite
                    let alert = UIAlertController(title: "Overwrite Password", message: "Would you like to overwrite the password saved for \"\(loginUsername)\"?", preferredStyle: UIAlertControllerStyle.alert)
                    self.present(alert, animated: true, completion: nil)
                    alert.addAction(UIAlertAction(title: "No", style: UIAlertActionStyle.default, handler: nil))
                    
                    alert.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.default, handler: { action in
                        
                        //Removing credentials and then re-adding with new password
                        self.keychain[loginUsername] = nil
                        self.keychain[loginUsername] = loginPassword
                        
                    }))
                }
            }
        }
        return true
    }
    
    
    //On webview finish load, fadeout loading overlay to display the webview
    func webViewDidFinishLoad(_ webView: UIWebView) {
        webviewLoaded = true
        
        self.initializeNotificationServices()
        
        var isLoggedIn:String = webView.stringByEvaluatingJavaScript(from: "getLoginStatus().toString();")!
        if(isLoggedIn == "") {
            isLoggedIn = "true"
        }
        self.isAuthenticated = isLoggedIn.toBool()!
        
        displayWebView()
    }
    
    func webToNativeCall() {
        //This is where we get the users contact details
        /*self.addressBook.filterBlock = {(contact: APContact) -> Bool in
            return (contact.phones?.count)! > 0
        }*/

        self.addressBook.loadContacts { (contacts: [APContact]?, error: Error?) in
            if let uwrappedContacts = contacts {
                // do something with contacts
                //print(uwrappedContacts)
                var serializedContacts = [Any]()
                for contact: APContact in uwrappedContacts {
                    serializedContacts.append(contact.serializeToDictionary())
                }
                
                let escapedJsonContacts = serializedContacts.toJsonString().addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
                print("receiveMobileContacts(\"" + escapedJsonContacts! + "\")")
                
                self.webView.stringByEvaluatingJavaScript(from: "receiveMobileContacts(\"" + escapedJsonContacts! + "\")")
            }
            else if let unwrappedError = error {
                print(unwrappedError)
            }
        }
        
        /*var addressBook = APAddressBook()
        addressBook.fieldsMask = APContactField
        addressBook.loadContacts({(contacts: [APContact], error: Error) -> Void in
            var serializedContacts = [Any]()
            for contact: APContact in contacts {
                serializedContacts.append(contact.serializeToDictionary())
            }
            print(serializedContacts)
        })*/

        
        //var returnvalue = self.webView.stringByEvaluatingJavaScript(from: "getText()")!
        print("here?")
    }
    
    
    //Function to be called after an evaluate Javascript
    func displayWebView() {
        if hasNetwork {
            self.progressLoading.isHidden = false
            self.OverlayImage.isHidden = false
            self.NexusLogo.isHidden = false
            UIView.animate(withDuration: 1, delay:0, options:UIViewAnimationOptions.transitionFlipFromTop, animations: {
                self.OverlayImage.alpha = 0
                self.progressLoading.alpha = 0
                self.NexusLogo.alpha = 0
                }, completion: { finished in
                    self.OverlayImage.isHidden = true
                    self.progressLoading.isHidden = true
                    self.NexusLogo.isHidden = true
                    
                    let items = self.keychain.allItems()
                    
                    //Only display the credentials actionsheet if at least one exists and the user is on the login page
                    if(!self.isAuthenticated && items.count > 0) {
                        let actionSheetController: UIAlertController = UIAlertController(title: "Saved Accounts", message: "Select an account to automatically sign in", preferredStyle: .actionSheet)
                        
                        //Create and add the Cancel action
                        let cancelAction: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel) { action -> Void in
                            //Just dismiss the action sheet
                        }
                        actionSheetController.addAction(cancelAction)
                        //Create and add first option action
                        
                        for item in items {
                            let thisUsername = item["key"] as! String!
                            let credentialItem: UIAlertAction = UIAlertAction(title: thisUsername, style: .default) { action -> Void in
                                self.loadCredentialsToForm(selectedCredentials: item as AnyObject)
                            }
                            actionSheetController.addAction(credentialItem)
                        }
                        
                        //Present the alert bottom sheet with all existing keychain passwords
                        self.present(actionSheetController, animated: true, completion: nil)
                    }
                    
                    //If authenticated (successfully logged in), attempt to save their device ID
                    if(self.isAuthenticated) {
                        self.webView.stringByEvaluatingJavaScript(from: "saveDeviceIdFromWebview('" + deviceToken + "', 'ios')")
                    }
            })
        }
    }
        
    
    func setDeviceTokenId(newToken: String) {
        deviceToken = newToken
        print(deviceToken)
    }

    //Selecting the light status bar with white text
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }
    

    func webViewDidStartLoad(_ webView: UIWebView) {
        progressLoading.progress = 0
        webviewLoaded = false
        
        //Faking the load progress with the displayLoadProgress function
        progressTimer = Timer.scheduledTimer(timeInterval: delaySpeed, target: self, selector: #selector(ViewController.displayLoadProgress), userInfo: nil, repeats: true)
    }
    
    func displayLoadProgress() {
        //Check for completion
        if webviewLoaded {
            if loadProgressAmount >= 1 {
                progressTimer.invalidate()
            }
            else {
                loadProgressAmount = 1
                progressLoading.setProgress(loadProgressAmount, animated: true)
            }
        } else if loadProgressAmount < 0.90 {
            if loadProgressAmount > 1.0 {
                progressLoading.isHidden = true
                progressTimer.invalidate()
            }
            
            //Diffrent speed for range
            if loadProgressAmount < 0.50 {
                delaySpeed = 0.005
            }
            else if loadProgressAmount < 0.75 {
                delaySpeed = 0.01
            }
            else {
                delaySpeed = 0.05
            }
            
            //Increase the progress view by 1/1000  for smooth animation
            loadProgressAmount += 0.001
            progressTimer.invalidate()
            progressTimer = Timer.scheduledTimer(timeInterval: delaySpeed, target: self, selector: #selector(ViewController.displayLoadProgress), userInfo: nil, repeats: true)
            progressLoading.setProgress(loadProgressAmount, animated: true)
        }
    }
    
    
    //Notification stuff?
    func initializeNotificationServices() -> Void {
        let settings = UIUserNotificationSettings(types: [.sound, .alert, .badge], categories: nil)
        UIApplication.shared.registerUserNotificationSettings(settings)
        
        // This is an asynchronous method to retrieve a Device Token
        // Callbacks are in AppDelegate.swift
        // Success = didRegisterForRemoteNotificationsWithDeviceToken
        // Fail = didFailToRegisterForRemoteNotificationsWithError
        UIApplication.shared.registerForRemoteNotifications()
    }
}

//Extension to convert string to boolean
extension String {
    func toBool() -> Bool? {
        switch self {
        case "True", "true", "yes", "1":
            return true
        case "False", "false", "no", "0":
            return false
        default:
            return nil
        }
    }
}

extension Array
{
    func toJsonString()->String
    {
        do
        {
            // convert array to data
            let jsonData = try JSONSerialization.data(withJSONObject: self, options: .prettyPrinted)
            
            // load into string
            guard let string = String.init(data: jsonData, encoding: String.Encoding.utf8) else {
                print("Failed casting json to string...")
                return ""
            }
            return string
        }
        catch
        {
            print(error)
        }
        return ""
    }
}
