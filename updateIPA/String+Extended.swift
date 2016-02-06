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
import Cocoa

/**
Extension for class String
*/
extension String
{
    var pathExtension: String
    {
        return (self as NSString).pathExtension
    }
    
    var lastPathComponent: String
    {
        return (self as NSString).lastPathComponent
    }

    var stringByDeletingPathExtension: String
    {
        return (self as NSString).stringByDeletingPathExtension
    }
    func stringByAppendingPathComponent(str:String) -> String
    {
        return (self as NSString).stringByAppendingPathComponent(str)
    }
    func stringByAppendingPathExtension(str:String) -> String
    {
        return (self as NSString).stringByAppendingPathExtension(str)!
    }
    var stringByDeletingLastPathComponent: String
    {
        return (self as NSString).stringByDeletingLastPathComponent
    }
    var length : Int
    {
        return (self as NSString).length
    }
    /**
    Returns the index of given character
    
    - parameter char: The character
    - returns: The found index (NSNotFound in case the char was not found)
    */
    func indexOfCharacter(char: Character) -> Int
    {
        if let idx = self.characters.indexOf(char)
        {
            return self.startIndex.distanceTo(idx)
        }
        
        return NSNotFound
    }
    
    /**
    Gets a character at given position
    
    - parameter i: The index
    - returns: The character
    */
    subscript (i: Int) -> Character 
    {
        return self[self.startIndex.advancedBy(i)]
    }
    
    /**
    Gets a substring given a range
    
    - parameter r: The range
    - returns: The substring data
    */
    subscript (r: Range<Int>) -> String 
    {
        return substringWithRange(Range(start: startIndex.advancedBy(r.startIndex), end: startIndex.advancedBy(r.endIndex)))
    }
    /// Property used to localize the string
    var localized: String
    {
            let result = NSLocalizedString(self, tableName: nil, bundle: NSBundle.mainBundle(), value: "", comment: "")
        return result
    }
}
