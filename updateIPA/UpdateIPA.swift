// The MIT License (MIT)
//
// Copyright (c) 2015 Regis Bridon
//    
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
// the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Foundation

class UpdateIPA
{
    var m_trace : Bool = false
    // Handle arguments
    var m_sourceIPA : String? = nil       // Required: name of the source IPA
    var m_newName: String? = nil          // New application name
    var m_copyFiles : [String] = []       // List of files to copy
    var m_version : String?               // new version
    var m_shortVersion : String?          // short version
    var m_bundleId : String?              // the new bundle ID
    var m_identity : String?              // the idendity to use when signing
    var m_provisioning : String?               // the provisioning profile name to use when signing
    
    // MARK: - General methods   
    init()
    {
        let argNumber = Process.arguments.count
        for var argIndex = 1;argIndex<argNumber;argIndex++
        {
            let argument = Process.arguments[argIndex]
            if !argument.hasPrefix("-")
            {
                // Source file
                m_sourceIPA = argument
            }
            else
            {
                // Single argument
                if argument == "-trace" || argument == "-t"
                {
                    m_trace = true
                    continue
                }
                // Verify that there is another argument following this one
                if argIndex+1 > Process.arguments.count
                {
                    printStderr("option \(argument) must be followed by a string")
                    exit(1)
                }
                let nextArgument = Process.arguments[argIndex+1]
                switch argument
                {
                case "-name", "-n":
                    m_newName = nextArgument
                    break
                case "-copy", "-c":
                    m_copyFiles.append(nextArgument)
                    break
                case "-version", "-v":
                    m_version = nextArgument
                    break
                case "-shortVersion", "-s":
                    m_shortVersion = nextArgument
                    break
                case "-bundleId", "-b":
                    m_bundleId = nextArgument
                    break
                case "-identity", "-i":
                    m_identity = nextArgument
                    break
                case "-provisioning", "-p":
                    m_provisioning = nextArgument
                    break
                default:
                    print("Unknown option \(argument)")
                    printHelp()
                    exit(0)
                    break
                }
            }
        }
        // Verify that the required arguments are valid
        if m_sourceIPA==nil
        {
            printStderr("UpdateIPA expects a source IPA")
            printHelp()
            exit(1)
        }
        if m_identity==nil || m_provisioning == nil
        {
            printStderr("UpdateIPA expects an identity AND a provisioning profile in order to re-sign the IPA")
            printHelp()
            exit(1)
        }
        do
        {
            try buildArchive()
        }
        catch let error as NSError
        {
            printStderr("Error in \(error.domain) : \(error.description)")
            exit(1)
        }
    }
    func verifyArguments(sourceIPA : String) throws
    {
        
        let infoPath = sourceIPA.stringByAppendingPathComponent("Info.plist")
        let infoDict = NSMutableDictionary(contentsOfFile: infoPath)
        
        if infoDict==nil
        {
            throw NSError(domain: "UpdateIPA", code: 0, userInfo: [ NSLocalizedDescriptionKey :  "Can't retrieve the info.plist (\(infoPath))."])
        }
        if m_version == nil
        {
            m_version = infoDict?.objectForKey("CFBundleVersion") as? String
        }
        if m_shortVersion == nil
        {
            m_shortVersion = infoDict?.objectForKey("CFBundleShortVersionString") as? String
        }
        
        if m_bundleId == nil
        {
            m_bundleId = infoDict?.objectForKey("CFBundleIdentifier") as? String
            if m_bundleId == nil
            {
                m_bundleId = ""
            }
        }
    }
    func verifyIdentity(identityName : String) throws
    {
        let result = try executeCommnand("/usr/bin/security", directoryPath: nil, arguments: ["find-identity", "-v"])
        
        var identities : [ (String, String)] = []    // GUID + Readable
        
        // Retrieve the identities
        let lines = result.0.componentsSeparatedByString("\n")
        
        for line in lines
        {
            // Skip the white space
            let newLine = line.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            
            var guid : String = ""
            var name : String = ""
            var ext : String = ""
            
            // Skip the first part of the text
            var index = 0
            while index < newLine.length && newLine[index] != " "
            {
                index++
            }
            while index < newLine.length && newLine[index] == " "
            {
                index++
            }
            // Get the UID
            while index < newLine.length && newLine[index] != " "
            {
                guid += String(newLine[index])
                index++
            }
            while index < newLine.length && newLine[index] != "\""
            {
                index++
            }
            if index < newLine.length
            {
                index++
            }
            
            while index < newLine.length && newLine[index] != "\""
            {
                name += String(newLine[index])
                index++
            }
            
            while index < newLine.length && newLine[index] == " "
            {
                index++
            }
            while index < newLine.length
            {
                ext += String(newLine[index])
                index++
            }
            if guid.length != 40
            {
                continue
            }
            if ext.containsString("CERT_REVOKED")
            {
                continue
            }
            // Store the UUID + description
            identities.append((guid, name))
        }
        // Check if the identity is valid
        for identity in identities
        {
            if identity.0 == identityName || identity.1 == identityName
            {
                return; // Good to go
            }
        }
        // Identity not found. 
        throw NSError(domain: "UpdateIPA", code: 0, userInfo: [ NSLocalizedDescriptionKey :  "Identity '\(identityName) was not found."])
    }
    // Display an error message
    func printStderr(errorString : String)
    {
        let stderr = NSFileHandle.fileHandleWithStandardError()
        let data = errorString.dataUsingEncoding(NSUTF8StringEncoding)
        stderr.writeData(data!)
    }
    func printHelp()
    {
        print("Syntax: updateIPA <application.ipa> -identity <identity name> -profile <profile name> [<options>, <options>,...]")
        print("\t<file.IPA>: (required) path to the IPA")
        print("\t-profile <profile name>: (required) the profile to use for signature")
        print("\t-identity <profile name>: (required) the identity to use for signature")
        print("\t-bundleId <string>: the new bundle ID")
        print("\t-name <app name>: the new name of the application")
        print("\t-copy <file name>: automatically copy the <file name> in the bundle of the IPA. Multiple copy are permitted")
        print("\t-version <string>: update the version number")
        print("\t-shortVersion <string>: update the short version")
    }
    // MARK: - Provisionings   
    /*!
    Return the list of all the provisionings
    
    :returns: an array of tupples
        0. Full path to the provisioning profile
        1. Dictionary of the profile
        2. Name of the profile
    */
    func findProvisioningProfile(bundleIdentifier : String) -> [(String, NSDictionary, String)]
    {
        // Retrieve all the existing provisioning profiles
        let provisionings = findAllProvisioningProfiles(bundleIdentifier)
        
        // Now, select the appropriate provisioning based on the bundleIdentifier
        var result : [ (String, NSDictionary, String) ] = []
        
        for profile in provisionings
        {
            if let entitlements = profile.1.objectForKey("Entitlements") as? NSDictionary
            {
                if let appIdentifier = entitlements.objectForKey("application-identifier") as? String
                {
                    // Check if the bundle is part of it
                    if appIdentifier.hasSuffix(bundleIdentifier)
                    {
                        result.append(profile)
                    }
                }
            }
        }
        return result
    }
    /*!
        Return the list of all the provisionings
    
        :returns: an array of tupples:
                        0. Full path to the provisioning profile
                        1. Dictionary of the profile
                        2. Name of the profile
    */
    func findAllProvisioningProfiles(bundleIdentifier : String) -> [ (String, NSDictionary, String) ]
    {
        var array : [(String, NSDictionary, String)] = []
        
        let plistPath = NSHomeDirectory().stringByAppendingPathComponent("Library/MobileDevice/Provisioning Profiles")
        
        let fileManager = NSFileManager.defaultManager()
        let enumerator:NSDirectoryEnumerator = fileManager.enumeratorAtPath(plistPath)!
        
        while let element = enumerator.nextObject() as? String
        {
            if element.hasSuffix("mobileprovision")
            {
                let path = plistPath.stringByAppendingPathComponent(element)
                do
                {
                    let result = try loadProvisioningFile(path)
                    if let dict = result
                    {
                        print("profile =\(dict.objectForKey("Name"))")
                        let result = verifyMobileProvisioning(dict, bundleIdentifier: bundleIdentifier)
                        if result
                        {
                            array.append( (path, dict, dict.objectForKey("Name") as! String) )
                        }
                    }
                }
                catch
                {
                    // Can ignore error in this loop
                }
            }
        }
        array.sortInPlace({ $0.2 < $1.2 })
        return array
    }
    /*!
        Load a provisioning profile and returns it contents.
            :param: provisioningPath the absolute path to the provisioning profile
            :returns: a dictionary content 
    */
    func loadProvisioningFile(provisioningPath : String) throws -> NSDictionary?
    {
        let fileContent = try NSString(contentsOfFile: provisioningPath, encoding: NSASCIIStringEncoding)
        
        var startPosition = fileContent.rangeOfString("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
        let endPosition = fileContent.rangeOfString("</plist>")
        
        if startPosition.length == 0 || endPosition.length == 0
        {
            throw NSError(domain: "UpdateIPA", code: 0, userInfo: [ NSLocalizedDescriptionKey :  "File does not contain a readable xml section"])
        }
        startPosition.length = endPosition.location + endPosition.length
        let subString = fileContent.substringWithRange(startPosition)
        
        
        let tempName = "\(NSProcessInfo.processInfo().globallyUniqueString)_provisioningDecoding.txt"
        let cachePath = NSTemporaryDirectory().stringByAppendingString(tempName)
        
        try subString.writeToFile(cachePath, atomically: true, encoding: NSUTF8StringEncoding)
        
        let dictFromDisk = NSDictionary.init(contentsOfFile: cachePath)
        return dictFromDisk
            
    }
    /*!
        Verify that the profile is correct and contains the bundle identifier
        :param: profile the NSDictionary containing the profile
        :bundleIdentifier: the bundle identifier
        :returns: a BOOL to indicate with the profile is correct or not
    */
    func verifyMobileProvisioning(profile : NSDictionary, bundleIdentifier : String) -> Bool
    {
        if let name = profile.objectForKey("Name") as? String
        {
            if name.hasPrefix("XC")
            {
                return false  // Skip XCode profiles
            }
        }
        // Check the platform
        let platform = profile.objectForKey("Platform") as? NSArray
        if let platformArray = platform
        {
            var found = false
            for name in platformArray
            {
                if name as! String == "iOS"
                {
                    found = true
                    break
                }
            }
            if !found
            {
                return false  // Incorrect platform
            }
        }
        // Check if the bundle identifier is the correct one
        let entitlements = profile.objectForKey("Entitlements") as? NSDictionary
        if entitlements == nil
        {
            return false  // The entitlements file is missing the section 'Entitlements'
        }
        // Retrieve the application identifier
        let appIdentifier = entitlements!.objectForKey("application-identifier") as? String
        
        print("appIdentifier =\(appIdentifier)")
        if let identifier = appIdentifier
        {
            if identifier.containsString(bundleIdentifier)
            {
                return true
            }
        }
        return false
    }
    // MARK: - Build Archive   

    // Returns the application path
    func buildArchive() throws
    {
        // Copy the existing app to a temp folder
        let tempName = "\(NSProcessInfo.processInfo().globallyUniqueString)_application.ipa"
        let unpackDirectory = NSTemporaryDirectory().stringByAppendingString(tempName)
        
        var newApplicationPath : String = ""
        
        do
        {
            var directory : String? = nil
            if !m_sourceIPA!.hasPrefix("/")
            {
                // Move to a relative directory
                directory = NSFileManager.defaultManager().currentDirectoryPath
            }
            
            try executeCommnand("/usr/bin/unzip", directoryPath: directory, arguments: [m_sourceIPA!, "-d", unpackDirectory])
            
            let payload = unpackDirectory.stringByAppendingPathComponent("Payload")
            
            // Search for the .app file
            let files = try NSFileManager.defaultManager().contentsOfDirectoryAtPath(payload)
            var applicationFile : String? = nil
            
            for file in files
            {
                if file.pathExtension == "app"
                {
                    applicationFile = file  
                    break
                }
            }
            if applicationFile == nil
            {
                throw NSError(domain: "UpdateIPA", code: 0, userInfo: [ NSLocalizedDescriptionKey :  "Cannot find a valid application inside the IPA '\(m_sourceIPA!)'"])
            }
            newApplicationPath = unpackDirectory.stringByAppendingPathComponent("Payload").stringByAppendingPathComponent(applicationFile!)
            
            // Rename the IPA
            if let newName = m_newName
            {
                let destPath = newApplicationPath.stringByDeletingLastPathComponent.stringByAppendingPathComponent(newName.stringByDeletingPathExtension.stringByAppendingPathExtension("app"))
                try NSFileManager.defaultManager().moveItemAtPath(newApplicationPath, toPath: destPath)
                newApplicationPath = destPath
            }
            // Check if all arguments are ok
            try verifyArguments(newApplicationPath)
            
            // Copy the files to the bundle directory (if any)
            for file in m_copyFiles
            {
                let destinationPath = newApplicationPath.stringByAppendingPathComponent(file.lastPathComponent)
                do 
                {
                    try NSFileManager.defaultManager().removeItemAtPath(destinationPath)
                }
                catch {}
                try NSFileManager.defaultManager().copyItemAtPath(file, toPath: destinationPath)
            }
        
            // Verify the current identity
            try verifyIdentity(m_identity!)

            // Get the provisioning profile based on the path & identity
            let provisioningArray = findProvisioningProfile(m_bundleId!)
            if(provisioningArray.count==0)
            {
                throw NSError(domain: "UpdateIPA", code: 0, userInfo: [ NSLocalizedDescriptionKey :  "Couldn't find any provisioning profile matching '\(m_bundleId)'"])
            }
            
            // Search the matching provisioning profiles
            var provisioning : (String, NSDictionary, String)? = nil
            if m_provisioning == nil
            {
                provisioning = provisioningArray[0]
            }
            else
            {
                for profile in provisioningArray
                {
                    if profile.2.uppercaseString == m_provisioning!.uppercaseString
                    {
                        provisioning = profile
                        break
                    }
                }
            }
            if provisioning == nil
            {
                throw NSError(domain: "UpdateIPA", code: 0, userInfo: [ NSLocalizedDescriptionKey :  "No Provisioning Profile found matching the name '\(m_provisioning)'"])
            }
            
            let provisioningDict = provisioning!.1   // Profile dictionary
            let entitlements = provisioningDict.objectForKey("Entitlements")
        
            // Update the pList
            let oldBundleName = try updateApplicationInformation(newApplicationPath)
            
            // Rename the application bundle
            if let newIPAName = m_newName
            {
                let oldApplicationBundle = newApplicationPath.stringByAppendingPathComponent(oldBundleName)
                let newApplicationBundle = newApplicationPath.stringByAppendingPathComponent(newIPAName)
                    
                try NSFileManager.defaultManager().moveItemAtPath(oldApplicationBundle, toPath: newApplicationBundle)

            }
            
            // Copy the provisioning file into the archive
            let provisioningPath = provisioning!.0
            let destPath = newApplicationPath.stringByAppendingPathComponent("embedded.provisionprofile")
            try NSFileManager.defaultManager().copyItemAtPath(provisioningPath, toPath: destPath)

            // Create the file archived-expanded-entitlements.xcent
            let xcentEntitlements = NSMutableDictionary()
            let appIdentifier = entitlements?.valueForKey("application-identifier") as? String
        
            xcentEntitlements.setValue(appIdentifier!, forKey : "application-identifier")
        
            let array = NSMutableArray()
        
            array.addObject(appIdentifier!)
            xcentEntitlements.setValue(array, forKey: "keychain-access-groups")
        
            let xcentEntitlementsPath = newApplicationPath.stringByAppendingPathComponent("archived-expanded-entitlements.xcent")

            let dataXML = try NSPropertyListSerialization.dataWithPropertyList(xcentEntitlements, format: NSPropertyListFormat.XMLFormat_v1_0, options: 0)
            dataXML.writeToFile(xcentEntitlementsPath, atomically: true)
        
            // Save the entitlements file
            let entitlementPath = unpackDirectory.stringByAppendingPathComponent("entitlements.plist")
            let entitlementsXML = try NSPropertyListSerialization.dataWithPropertyList(xcentEntitlements, format: NSPropertyListFormat.XMLFormat_v1_0, options: 0)
            entitlementsXML.writeToFile(entitlementPath, atomically: true)
        
            //
            // Ok -- everything is ready -- Sign the app
            //
        
            try doCodeSigning(newApplicationPath, identity: m_identity!, entitlementPath: entitlementPath)
            
            //
            // Create the final IPA
            //
            var destIPA : String
            if let newName = m_newName
            {
                destIPA = m_sourceIPA!.stringByDeletingLastPathComponent.stringByAppendingPathComponent(newName.stringByDeletingPathExtension).stringByAppendingPathExtension("ipa")
            }
            else
            {
                destIPA = m_sourceIPA!.stringByDeletingPathExtension + "-resigned"
                destIPA = destIPA.stringByAppendingPathExtension("ipa")
            }
       
            try executeCommnand("/usr/bin/zip", directoryPath: unpackDirectory, arguments: ["-qry", destIPA, "Payload"])
            
            // Clean up directory
            try NSFileManager.defaultManager().removeItemAtPath(unpackDirectory)
        }
        catch let error as NSError
        {
            throw error
        }
    }
    // MARK: - Code Signing   
    /*!
    Sign the application bundle and each of the frameworks
    
    :applicationPath: absolute path to the application IPA
    :identity: the current identity
    :entitlementPath: the plist containing the entitlement
    
    :returns: a BOOL to indicate if the application was signed or not
    */
    
    func doCodeSigning(applicationPath : String, identity : String, entitlementPath : String) throws
    {
        let frameworksPath = applicationPath.stringByAppendingPathComponent("Frameworks")
        do
        {
            let files = try NSFileManager.defaultManager().contentsOfDirectoryAtPath(frameworksPath)
            for framework in files
            {
                if framework.pathExtension == "framework" || framework.pathExtension == "dylib"
                {
                    try signApplication(frameworksPath.stringByAppendingPathComponent(framework), identity: identity, entitlementPath: entitlementPath)
                }
            }
            // Sign the application
            try signApplication(applicationPath, identity: identity, entitlementPath: entitlementPath)
        }
        catch let error as NSError
        {
            throw error
        }
    }
    func signApplication(filePath : String, identity : String, entitlementPath : String) throws
    {
        var args : [String] = []
        
        args.append("-fs")
        args.append(identity)
        
        let infoPath = filePath.stringByAppendingPathComponent("Info.plist")
        let infoDict = NSMutableDictionary(contentsOfFile: infoPath)
        if let _ = infoDict?.objectForKey("CFBundleResourceSpecification") as? String
        {
            infoDict?.removeObjectForKey("CFBundleResourceSpecification")
            infoDict?.writeToFile(infoPath, atomically: true)
        }
        args.append("--no-strict")// http://stackoverflow.com/a/26204757

        args.append("--entitlements=" + entitlementPath)
        args.append(filePath)

        do
        {
            try executeCommnand("/usr/bin/codesign", directoryPath: nil, arguments: args)
        }
        catch let error as NSError
        {
            throw error
        }
    }
    func updateApplicationInformation(applicationPath : String) throws -> String
    {
        // Read the existing info.plist
        let settingsPath = applicationPath.stringByAppendingPathComponent("Info.plist")
        let settings : NSMutableDictionary? = NSMutableDictionary(contentsOfFile: settingsPath)
        
        if settings == nil
        {
            throw NSError(domain: "UpdateIPA", code: 0, userInfo: [ NSLocalizedDescriptionKey :  "Cannot read the info.plist from the application at \(settingsPath)"])
        }
        // Update the bundle identifier
        settings?.setValue(m_bundleId , forKey: "CFBundleIdentifier")
        
        // Update the bundle name
        let oldBundleName = settings?.objectForKey("CFBundleName")
        
        if m_newName != nil
        {
            settings!.setValue(m_newName! , forKey: "CFBundleDisplayName")
            settings!.setValue(m_newName! , forKey: "CFBundleName")
            settings!.setValue(m_newName! , forKey: "CFBundleExecutable")
        }
        if m_shortVersion != nil
        {
            settings!.setValue(m_shortVersion, forKey: "CFBundleShortVersionString")
        }
        if m_version != nil
        {
            settings!.setValue(m_version, forKey: "CFBundleVersion")
        }
        do
        {
            do
            {
                try NSFileManager.defaultManager().removeItemAtPath(settingsPath)
            }
            catch
            {
            }
            let dataXML = try NSPropertyListSerialization.dataWithPropertyList(settings!, format: NSPropertyListFormat.XMLFormat_v1_0, options: 0)
            dataXML.writeToFile(settingsPath, atomically: true)
            
        }
        catch let error as NSError
        {
            throw error
        }
        return oldBundleName as! String
    }
    // MARK: - Call Shell commands   

    /*!
    * Execute the current shell command with a list of parameters. Throws if the command was terminated on an error.
        :param: command the full path of the command to execute
        :directoryPath: the directory to execute the command into, can be nil
        :arguments: a list of aguments to be passed to the command
    
        :returns: a composite of stdout and stderr.
    
    */  
    func executeCommnand(command : String, directoryPath: String?, arguments : [String]) throws -> (String, String)
    {
        let shellTask = NSTask()
        shellTask.arguments = arguments
        
        if(m_trace)
        {
            // Debugging the command
            var string = command + " "
            for arg in arguments
            {
                if arg.containsString(" ")
                {
                    string += "\"\(arg)\" "
                }
                else
                {
                    string += arg + " "
                }
            }
            Swift.print(string)
        }
        var error = false
        let outputPipe = NSPipe()
        let errorPipe = NSPipe()
        shellTask.standardOutput = outputPipe
        shellTask.standardError = errorPipe
        shellTask.launchPath = command
        shellTask.terminationHandler = { (t: NSTask) -> Void in
            if t.terminationStatus != 0
            {
                error = true
            }
        };

        
        if let path = directoryPath
        {
            shellTask.currentDirectoryPath = path
        }
        shellTask.launch()
        shellTask.waitUntilExit()
        
        if error
        {
            throw NSError(domain: "UpdateIPA", code: -2, userInfo: [ NSLocalizedDescriptionKey :  "Command \(command) was terminated."])
        }
        
        return (readFromPipe(outputPipe), readFromPipe(errorPipe))
    }
    func readFromPipe(pipe : NSPipe?) -> String
    {
        let blockSize = 4096
        var mutableString = String()
        
        // Get the result from the output
        if pipe != nil
        {
            let file = pipe!.fileHandleForReading
            
            let length = blockSize
            while(true)
            {
                let outputData = file.readDataOfLength(length)
                let str = NSString.init(data: outputData, encoding: NSUTF8StringEncoding) as! String
                mutableString += str
                if outputData.length < length
                {
                    break
                }
            }
        }
        return mutableString
    }
}