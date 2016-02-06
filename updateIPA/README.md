# UpdateIPA

I always had some challenges to have my clients make minor changes in the IPA after releasing the application. I had some who wanted to update the icons or splashscreen and others who just wanted to update some files in the bundle. This tool can change the bundle ID, the name of the executable, update some text files and repackage all of it to a new IPA. It is designed to be used within a command shell and is written in Swift.

## Using UpdateIPA

The basic syntax is:

updateIPA <application.ipa> -identity <identity name> -provisioning <provisioning name> [<options>, <options>,...]

where:

**<application.ipa>** is the complete path to the IPA to update

**-identity <identity name>** is the identity that is available on the machine where updateIPA is running. updateIPA checks either the GUID or the name of the entity. The available identities can be retrieved using the following command:

    */usr/bin/security find-identity -v*

**-provisioning <provisioning name>** is the name of the provisioning profile. updateIPA will scan the directory *"Library/MobileDevice/Provisioning Profiles"* to find the appropriate profile and will validate the bundleId found in the provisioning profile. Note that the '*' format is ignored -- only absolute names are matched

__-bundleId <bundle ID>__ [optional] update the bundle ID of the IPA

__-name <bundle name>__  [optional] rename the bundle and the IPA to this new bundle name

__-version, -shortVersion <version>__ [optional] specify a version and a short version

__-copy <file name>__ [optional] copy a file into the bundle. Several -copy options can be used

__-trace__ [optional] displays the execution of the different shell commands

## Examples

updateIPA 

