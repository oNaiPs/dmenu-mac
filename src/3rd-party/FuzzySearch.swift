/*
The MIT License (MIT) - FuzzySearch.swift

Copyright (c) 2015 Rahul Nadella https://github.com/rahulnadella

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

import Foundation

/*
In computer science, approximate string matching (often colloquially referred
to as fuzzy string searching) is the technique of finding strings that match a
pattern approximately (rather than exactly). The problem of approximate string
matching is typically divided into two sub-problems: finding approximate substring
matches inside a given string and finding dictionarystrings that match the
pattern approximately.

The FuzzySearch provides an implementation to search and match a pattern approximately
will return whether the character set is found or not by a Boolean or Integer value.

:version 1.0
*/
open class FuzzySearch
{
	/*
	The FuzzySearch.search method returns a Boolean of TRUE if the stringToSearch for
	is found in the originalString otherwise FALSE. This search is not case sensitive.
	
	:param originalString
	The original contents that is going to be searched
	:param stringToSearch
	The specific contents to search for
	:return
	A Boolean of TRUE if found otherwise FALSE for not found
	*/
	open class func search<T : Equatable>(originalString: T, stringToSearch: T) -> Bool
	{
		return search(originalString: originalString, stringToSearch: stringToSearch, isCaseSensitive: false)
	}
	
	/*
	The FuzzySearch.search method returns the number of timees found (Integer) of the
	set of characters to be searched within the original character set.
	
	:param originalString
	The original contents that is going to be searched
	:param stringToSearch
	The specific contents to search for
	:return
	A Boolean of TRUE if found otherwise FALSE for not found
	*/
	open class func search<T : Equatable>(originalString: T, stringToSearch: T) -> Int
	{
		return search(originalString: originalString, stringToSearch: stringToSearch, isCaseSensitive: false)
	}
	
	/*
	The FuzzySearch.search method returns a Boolean of TRUE if the stringToSearch for
	is found in the originalString otherwise FALSE. This search does search for case sensitive
	Strings by using a Boolean value to indicate what kind of search to use.
	
	:param originalString
	The original contents that is going to be searched
	:param stringToSearch
	The specific contents to search for
	:param isCaseSensitive
	A Boolean value to indicate whether to use case sensitive or case
	insensitive search parameters
	:return
	A Boolean of TRUE if found otherwise FALSE for not found
	*/
	open class func search<T : Equatable>(originalString: T, stringToSearch: T, isCaseSensitive: Bool) -> Bool
	{
		/* Decipher if the String to be searched for is found */
		let searchCount:Int = search(originalString: originalString, stringToSearch: stringToSearch, isCaseSensitive: isCaseSensitive)
		
		if searchCount > 0
		{
			return true
		}
		else
		{
			return false
		}
	}
	
	/*
	The FuzzySearch.search method returns the number of instances a specific character
	set is found with in a String object
	
	:param originalString
	The original contents that is going to be searched
	:param stringToSearch
	The specific contents to search for
	:param isCaseSensitive
	A Boolean value to indicate whether to use case sensitive or case
	insensitive search parameters
	:return
	An Integer value of the number of instances a character set matches a String
	*/
	open class func search<T : Equatable>(originalString: T, stringToSearch: T, isCaseSensitive: Bool) -> Int
	{
		var tempOriginalString = String()
		var tempStringToSearch = String()
		/*
		Verify that the variables are Strings
		*/
		if originalString is String && stringToSearch is String
		{
			tempOriginalString = originalString as! String
			tempStringToSearch = stringToSearch as! String
		}
		else
		{
			return 0
		}
		/*
		Either String is empty return false
		*/
		if tempOriginalString.count == 0 || tempStringToSearch.count == 0
		{
			return 0
		}
		
		/*
		stringToSearch is greater than the originalString return false
		*/
		if tempOriginalString.count < tempStringToSearch.count
		{
			return 0
		}
		
		/*
		Check isCaseSensitive if true lowercase the contents of both strings
		*/
		if isCaseSensitive
		{
			tempOriginalString = tempOriginalString.lowercased()
			tempStringToSearch = tempStringToSearch.lowercased()
		}
		
		var searchIndex : Int = 0
		var searchCount : Int = 0
		/*
		Search the contents of the originalString to determine if the stringToSearch can be found or not
		*/
		for charOut in tempOriginalString{
			for (indexIn, charIn) in tempStringToSearch.enumerated() {
				if indexIn == searchIndex
				{
					if charOut==charIn
					{
						searchIndex += 1
						if searchIndex == tempStringToSearch.count
						{
							searchCount += 1
							searchIndex = 0
						}
						else
						{
							break
						}
					}
					else
					{
						break
					}
				}
			}
		}
		return searchCount
	}
	
	/*
	The FuzzySearch.search method returns the Array of String(s) a specific character
	approximately matches that String object
	
	:param originalString
	The original contents that is going to be searched
	:param stringToSearch
	The specific contents to search for
	:param isCaseSensitive
	A Boolean value to indicate whether to use case sensitive or case
	insensitive search parameters
	:return
	The Array of String(s) if any are found otherwise an empty Array of String(s)
	*/
	
	public class func search(originalString: String, stringToSearch: String, isCaseSensitive: Bool) -> [String]
	{
		var originalString = originalString, stringToSearch = stringToSearch
		/*
		Either String is empty return false
		*/
		if originalString.count == 0 || stringToSearch.count == 0
		{
			return [String]()
		}
		
		/*
		stringToSearch is greater than the originalString return false
		*/
		if originalString.count < stringToSearch.count
		{
			return [String]()
		}
		
		/*
		Check isCaseSensitive if true lowercase the contents of both strings
		*/
		if isCaseSensitive
		{
			originalString = originalString.lowercased()
			stringToSearch = stringToSearch.lowercased()
		}
		
		var searchIndex : Int = 0
		var approximateMatch:Array = [String]()
		/*
		Search the contents of the originalString to determine if the stringToSearch can be found or not
		*/
		for content in originalString.components(separatedBy: " ")
		{
			for charOut in content
			{
				for (indexIn, charIn) in stringToSearch.enumerated()
				{
					if indexIn == searchIndex
					{
						if charOut==charIn
						{
							searchIndex += 1
							if searchIndex==stringToSearch.count
							{
								approximateMatch.append(content)
								searchIndex = 0
							}
							else
							{
								break
							}
						}
						else
						{
							break
						}
					}
				}
			}
		}
		return approximateMatch
	}
	
	/*
	The score method that provides fast fuzzy string matching and scoring based
	on the technique of finding strings that match a pattern approximately
	(rather than exactly). The problem of approximate string matching is typically
	dived intotwo sub-problems: finding approximate substring matches inside
	a given string and finding dictionary strings that match the pattern approximately.
	
	The design and implementation of this method are based on
	StringScore_Swift by (Yichi Zhang) and StringScore in Javascript (Joshaven Potter)
	
	:param originalString
	The original contents that is going to be searched
	:param stringToMatch
	The specific contents to search for the approximate match
	:param fuzziness
	A Double value to indicate a function of distance between two words,
	which provides a measure of their similarity. The fuzziness value is
	defaulted to 0.
	:return The score value of the approximate match between strings.
	Score of 0 for no match; up to 1 for perfect.
	
	*/
	open class func score(originalString: String, stringToMatch: String, fuzziness: Double? = nil) -> Double
	{
		/*
		Either String objects are empty return score of 0
		*/
		if originalString.isEmpty || stringToMatch.isEmpty
		{
			return 0
		}
		/*
		the stringToMatch is greater than originalString return score of 0
		*/
		if originalString.count < stringToMatch.count
		{
			return 0
		}
		
		/*
		Either String objects are the same return score of 1
		*/
		if originalString == stringToMatch
		{
			return 1
		}
		
		/* Initialization of the local variables */
		var runningScore = 0.0
		var charScore = 0.0
		var finalScore = 0.0
		let lowercaseString = originalString.lowercased()
		let strLength = originalString.count
		let lowercaseStringToMatch = stringToMatch.lowercased()
		let wordLength = stringToMatch.count
		var indexOfString:String.Index!
		var startAt = lowercaseString.startIndex
		var fuzzies = 1.0
		var fuzzyFactor = 0.0
		var fuzzinessIsNil = true
		
		/* Cache fuzzyFactor for speed increase */
		if let fuzziness = fuzziness
		{
			fuzzyFactor = 1 - fuzziness
			fuzzinessIsNil = false
		}
		
		for i in 0..<wordLength
		{
			/*
			Find next first case-insensitive match of word's i-th character.
			The search in "string" begins at "startAt".
			*/
			
			if let range = lowercaseString.range(
				of: String(lowercaseStringToMatch[lowercaseStringToMatch.index(lowercaseStringToMatch.startIndex, offsetBy: i)] as Character),
				options: NSString.CompareOptions.caseInsensitive,
				range: (startAt ..< lowercaseString.endIndex),
				locale: nil
				)
			{
				/* start index of word's i-th character in string. */
				indexOfString = range.lowerBound
				if startAt == indexOfString
				{
					/* Consecutive letter & start-of-string Bonus */
					charScore = 0.7
				}
				else
				{
					charScore = 0.1
					/*
					Acronym Bonus
					Weighing Logic: Typing the first character of an acronym is as if you
					preceded it with two perfect character matches.
					*/
					if originalString[lowercaseString.index(indexOfString, offsetBy: -1)] == " " { charScore += 0.8 }
				}
			}
			else
			{
				/* Character not found. */
				if fuzzinessIsNil
				{
					// Fuzziness is nil. Return 0.
					return 0
				}
				else
				{
					fuzzies += fuzzyFactor
					continue
				}
			}
			
			/* Same case bonus. */
			if (originalString[indexOfString] == stringToMatch[stringToMatch.index(stringToMatch.startIndex, offsetBy: i)])
			{
				charScore += 0.1
			}
			
			/* Update scores and startAt position for next round of indexOf */
			runningScore += charScore
			startAt = lowercaseString.index(indexOfString, offsetBy: 1)
		}
		
		/* Reduce penalty for longer strings. */
		finalScore = 0.5 * (runningScore / Double(strLength) + runningScore / Double(wordLength)) / fuzzies
		
		if (lowercaseString[lowercaseString.startIndex] == lowercaseString[lowercaseString.startIndex]) && (finalScore < 0.85)
		{
			finalScore += 0.15
		}
		
		return finalScore
	}
}
