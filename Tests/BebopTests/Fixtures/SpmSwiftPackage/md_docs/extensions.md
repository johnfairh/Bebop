<!--
Bebop simple MD theme
Copyright 2020 Bebop Authors
Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
-->
![48%](badge.svg)
[![Open in Dash](img/dash.svg)](dash-feed://https%3A%2F%2Fwww%2Egoogle%2Ecom%2F)


[SpmSwiftModule](index.md)
 / Extensions


<details>
<summary>Contents</summary>


[Types](types.md?swift)

  * [ABaseClass](types/abaseclass.md?swift)


  * [ADerivedClass](types/aderivedclass.md?swift)


  * [AnEnum](types/anenum.md?swift)


  * [FirstProtocol](types/firstprotocol1.md?swift)


  * [GenericBase](types/genericbase.md?swift)


  * [Nop](types/nop.md?swift)


  * [P1](types.md?swift#p1)


  * [P2](types.md?swift#p2)


  * [PropertyWrapperClient](types/propertywrapperclient.md?swift)


  * [S1](types/s1.md?swift)


  * [S2](types/s2.md?swift)


  * [SecondProtocol](types/secondprotocol.md?swift)


  * [SpmSwiftModule](types/spmswiftmodule.md?swift)

    * [Nested1](types/spmswiftmodule/nested1.md?swift)

    * [Nested2](types/spmswiftmodule.md?swift#nested2)


  * [T](types.md?swift#t2)



[Functions](functions.md?swift)

  * [deprecatedFunction(callback:)](functions.md?swift#deprecatedfunctioncallback)


  * [functionA(arg1:_:arg3:)](functions.md?swift#functionaarg1_arg3)



[Operators](operators.md?swift)

  * [+(T, T)](operators.md?swift#t-t)



Extensions

  * [Array](extensions/array.md?swift)


  * [Collection](extensions/collection.md?swift)


  * [Dictionary](#dictionary)


  * [String.Element](extensions/stringelement.md?swift)


  * [StringProtocol](extensions/stringprotocol.md?swift)





</details>

# Extensions

















<details>
<summary><code>extension Array</code></summary>








An ordered, random-access collection.

Arrays are one of the most commonly used data types in an app. You use arrays to organize your app’s data. Specifically, you use the `Array` type to hold elements of a single type, the array’s `Element` type. An array can store any kind of elements—from integers to strings to classes.

Swift makes it easy to create arrays in your code using an array literal: simply surround a comma-separated list of values with square brackets. Without any other information, Swift creates an array that includes the specified values, automatically inferring the array’s `Element` type. For example:

``` swift
// An array of 'Int' elements
let oddNumbers = [1, 3, 5, 7, 9, 11, 13, 15]

// An array of 'String' elements
let streets = ["Albemarle", "Brandywine", "Chesapeake"]

```

You can create an empty array by specifying the `Element` type of your array in the declaration. For example:

``` swift
// Shortened forms are preferred
var emptyDoubles: [Double] = []

// The full type name is also allowed
var emptyFloats: Array<Float> = Array()

```

If you need an array that is preinitialized with a fixed number of default values, use the `Array(repeating:count:)` initializer.

``` swift
var digitCounts = Array(repeating: 0, count: 10)
print(digitCounts)
// Prints "[0, 0, 0, 0, 0, 0, 0, 0, 0, 0]"

```

# Accessing Array Values

When you need to perform an operation on all of an array’s elements, use a `for`-`in` loop to iterate through the array’s contents.

``` swift
for street in streets {
    print("I don't live on \(street).")
}
// Prints "I don't live on Albemarle."
// Prints "I don't live on Brandywine."
// Prints "I don't live on Chesapeake."

```

Use the `isEmpty` property to check quickly whether an array has any elements, or use the `count` property to find the number of elements in the array.

``` swift
if oddNumbers.isEmpty {
    print("I don't know any odd numbers.")
} else {
    print("I know \(oddNumbers.count) odd numbers.")
}
// Prints "I know 8 odd numbers."

```

Use the `first` and `last` properties for safe access to the value of the array’s first and last elements. If the array is empty, these properties are `nil`.

``` swift
if let firstElement = oddNumbers.first, let lastElement = oddNumbers.last {
    print(firstElement, lastElement, separator: ", ")
}
// Prints "1, 15"

print(emptyDoubles.first, emptyDoubles.last, separator: ", ")
// Prints "nil, nil"

```

You can access individual array elements through a subscript. The first element of a nonempty array is always at index zero. You can subscript an array with any integer from zero up to, but not including, the count of the array. Using a negative number or an index equal to or greater than `count` triggers a runtime error. For example:

``` swift
print(oddNumbers[0], oddNumbers[3], separator: ", ")
// Prints "1, 7"

print(emptyDoubles[0])
// Triggers runtime error: Index out of range

```

# Adding and Removing Elements

Suppose you need to store a list of the names of students that are signed up for a class you’re teaching. During the registration period, you need to add and remove names as students add and drop the class.

``` swift
var students = ["Ben", "Ivy", "Jordell"]

```

To add single elements to the end of an array, use the `append(_:)` method. Add multiple elements at the same time by passing another array or a sequence of any kind to the `append(contentsOf:)` method.

``` swift
students.append("Maxime")
students.append(contentsOf: ["Shakia", "William"])
// ["Ben", "Ivy", "Jordell", "Maxime", "Shakia", "William"]

```

You can add new elements in the middle of an array by using the `insert(_:at:)` method for single elements and by using `insert(contentsOf:at:)` to insert multiple elements from another collection or array literal. The elements at that index and later indices are shifted back to make room.

``` swift
students.insert("Liam", at: 3)
// ["Ben", "Ivy", "Jordell", "Liam", "Maxime", "Shakia", "William"]

```

To remove elements from an array, use the `remove(at:)`, `removeSubrange(_:)`, and `removeLast()` methods.

``` swift
// Ben's family is moving to another state
students.remove(at: 0)
// ["Ivy", "Jordell", "Liam", "Maxime", "Shakia", "William"]

// William is signing up for a different class
students.removeLast()
// ["Ivy", "Jordell", "Liam", "Maxime", "Shakia"]

```

You can replace an existing element with a new value by assigning the new value to the subscript.

``` swift
if let i = students.firstIndex(of: "Maxime") {
    students[i] = "Max"
}
// ["Ivy", "Jordell", "Liam", "Max", "Shakia"]

```

## Growing the Size of an Array

Every array reserves a specific amount of memory to hold its contents. When you add elements to an array and that array begins to exceed its reserved capacity, the array allocates a larger region of memory and copies its elements into the new storage. The new storage is a multiple of the old storage’s size. This exponential growth strategy means that appending an element happens in constant time, averaging the performance of many append operations. Append operations that trigger reallocation have a performance cost, but they occur less and less often as the array grows larger.

If you know approximately how many elements you will need to store, use the `reserveCapacity(_:)` method before appending to the array to avoid intermediate reallocations. Use the `capacity` and `count` properties to determine how many more elements the array can store without allocating larger storage.

For arrays of most `Element` types, this storage is a contiguous block of memory. For arrays with an `Element` type that is a class or `@objc` protocol type, this storage can be a contiguous block of memory or an instance of `NSArray`. Because any arbitrary subclass of `NSArray` can become an `Array`, there are no guarantees about representation or efficiency in this case.

# Modifying Copies of Arrays

Each array has an independent value that includes the values of all of its elements. For simple types such as integers and other structures, this means that when you change a value in one array, the value of that element does not change in any copies of the array. For example:

``` swift
var numbers = [1, 2, 3, 4, 5]
var numbersCopy = numbers
numbers[0] = 100
print(numbers)
// Prints "[100, 2, 3, 4, 5]"
print(numbersCopy)
// Prints "[1, 2, 3, 4, 5]"

```

If the elements in an array are instances of a class, the semantics are the same, though they might appear different at first. In this case, the values stored in the array are references to objects that live outside the array. If you change a reference to an object in one array, only that array has a reference to the new object. However, if two arrays contain references to the same object, you can observe changes to that object’s properties from both arrays. For example:

``` swift
// An integer type with reference semantics
class IntegerReference {
    var value = 10
}
var firstIntegers = [IntegerReference(), IntegerReference()]
var secondIntegers = firstIntegers

// Modifications to an instance are visible from either array
firstIntegers[0].value = 100
print(secondIntegers[0].value)
// Prints "100"

// Replacements, additions, and removals are still visible
// only in the modified array
firstIntegers[0] = IntegerReference()
print(firstIntegers[0].value)
// Prints "10"
print(secondIntegers[0].value)
// Prints "100"

```

Arrays, like all variable-size collections in the standard library, use copy-on-write optimization. Multiple copies of an array share the same storage until you modify one of the copies. When that happens, the array being modified replaces its storage with a uniquely owned copy of itself, which is then modified in place. Optimizations are sometimes applied that can reduce the amount of copying.

This means that if an array is sharing storage with other copies, the first mutating operation on that array incurs the cost of copying the array. An array that is the sole owner of its storage can perform mutating operations in place.

In the example below, a `numbers` array is created along with two copies that share the same storage. When the original `numbers` array is modified, it makes a unique copy of its storage before making the modification. Further modifications to `numbers` are made in place, while the two copies continue to share the original storage.

``` swift
var numbers = [1, 2, 3, 4, 5]
var firstCopy = numbers
var secondCopy = numbers

// The storage for 'numbers' is copied here
numbers[0] = 100
numbers[1] = 200
numbers[2] = 300
// 'numbers' is [100, 200, 300, 4, 5]
// 'firstCopy' and 'secondCopy' are [1, 2, 3, 4, 5]

```

# Bridging Between Array and NSArray

When you need to access APIs that require data in an `NSArray` instance instead of `Array`, use the type-cast operator (`as`) to bridge your instance. For bridging to be possible, the `Element` type of your array must be a class, an `@objc` protocol (a protocol imported from Objective-C or marked with the `@objc` attribute), or a type that bridges to a Foundation type.

The following example shows how you can bridge an `Array` instance to `NSArray` to use the `write(to:atomically:)` method. In this example, the `colors` array can be bridged to `NSArray` because the `colors` array’s `String` elements bridge to `NSString`. The compiler prevents bridging the `moreColors` array, on the other hand, because its `Element` type is `>`, which does *not* bridge to a Foundation type.

``` swift
let colors = ["periwinkle", "rose", "moss"]
let moreColors: [String?] = ["ochre", "pine"]

let url = URL(fileURLWithPath: "names.plist")
(colors as NSArray).write(to: url, atomically: true)
// true

(moreColors as NSArray).write(to: url, atomically: true)
// error: cannot convert value of type '[String?]' to type 'NSArray'

```

Bridging from `Array` to `NSArray` takes O(1) time and O(1) space if the array’s elements are already instances of a class or an `@objc` protocol; otherwise, it takes O(*n*) time and space.

When the destination array’s element type is a class or an `@objc` protocol, bridging from `NSArray` to `Array` first calls the `copy(with:)` (`- copyWithZone:` in Objective-C) method on the array to get an immutable copy and then performs additional Swift bookkeeping work that takes O(1) time. For instances of `NSArray` that are already immutable, `copy(with:)` usually returns the same array in O(1) time; otherwise, the copying performance is unspecified. If `copy(with:)` returns the same array, the instances of `NSArray` and `Array` share storage using the same copy-on-write optimization that is used when two instances of `Array` share storage.

When the destination array’s element type is a nonclass type that bridges to a Foundation type, bridging from `NSArray` to `Array` performs a bridging copy of the elements to contiguous storage in O(*n*) time. For example, bridging from `NSArray` to `>` performs such a copy. No further bridging is required when accessing elements of the `Array` instance.

  - note: The `ContiguousArray` and `ArraySlice` types are not bridged; instances of those types always have a contiguous block of memory as their storage.




#### Declaration

``` swift
extension Array: P1 where Element: Comparable
```









[Show members](extensions/array.md?swift)

[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Protocols.swift#L72-L74)
</details>









<details>
<summary><code>extension Collection</code></summary>








A sequence whose elements can be traversed multiple times, nondestructively, and accessed by an indexed subscript.

Collections are used extensively throughout the standard library. When you use arrays, dictionaries, and other collections, you benefit from the operations that the `Collection` protocol declares and implements. In addition to the operations that collections inherit from the `Sequence` protocol, you gain access to methods that depend on accessing an element at a specific position in a collection.

For example, if you want to print only the first word in a string, you can search for the index of the first space, and then create a substring up to that position.

``` swift
let text = "Buffalo buffalo buffalo buffalo."
if let firstSpace = text.firstIndex(of: " ") {
    print(text[..<firstSpace])
}
// Prints "Buffalo"

```

The `firstSpace` constant is an index into the `text` string—the position of the first space in the string. You can store indices in variables, and pass them to collection algorithms or use them later to access the corresponding element. In the example above, `firstSpace` is used to extract the prefix that contains elements up to that index.

# Accessing Individual Elements

You can access an element of a collection through its subscript by using any valid index except the collection’s `endIndex` property. This property is a “past the end” index that does not correspond with any element of the collection.

Here’s an example of accessing the first character in a string through its subscript:

``` swift
let firstChar = text[text.startIndex]
print(firstChar)
// Prints "B"

```

The `Collection` protocol declares and provides default implementations for many operations that depend on elements being accessible by their subscript. For example, you can also access the first character of `text` using the `first` property, which has the value of the first element of the collection, or `nil` if the collection is empty.

``` swift
print(text.first)
// Prints "Optional("B")"

```

You can pass only valid indices to collection operations. You can find a complete set of a collection’s valid indices by starting with the collection’s `startIndex` property and finding every successor up to, and including, the `endIndex` property. All other values of the `Index` type, such as the `startIndex` property of a different collection, are invalid indices for this collection.

Saved indices may become invalid as a result of mutating operations. For more information about index invalidation in mutable collections, see the reference for the `MutableCollection` and `RangeReplaceableCollection` protocols, as well as for the specific type you’re using.

# Accessing Slices of a Collection

You can access a slice of a collection through its ranged subscript or by calling methods like `prefix(while:)` or `suffix(_:)`. A slice of a collection can contain zero or more of the original collection’s elements and shares the original collection’s semantics.

The following example creates a `firstWord` constant by using the `prefix(while:)` method to get a slice of the `text` string.

``` swift
let firstWord = text.prefix(while: { $0 != " " })
print(firstWord)
// Prints "Buffalo"

```

You can retrieve the same slice using the string’s ranged subscript, which takes a range expression.

``` swift
if let firstSpace = text.firstIndex(of: " ") {
    print(text[..<firstSpace])
    // Prints "Buffalo"
}

```

The retrieved slice of `text` is equivalent in each of these cases.

## Slices Share Indices

A collection and its slices share the same indices. An element of a collection is located under the same index in a slice as in the base collection, as long as neither the collection nor the slice has been mutated since the slice was created.

For example, suppose you have an array holding the number of absences from each class during a session.

``` swift
var absences = [0, 2, 0, 4, 0, 3, 1, 0]

```

You’re tasked with finding the day with the most absences in the second half of the session. To find the index of the day in question, follow these steps:

1.  Create a slice of the `absences` array that holds the second half of the days.
2.  Use the `max(by:)` method to determine the index of the day with the most absences.
3.  Print the result using the index found in step 2 on the original `absences` array.

Here’s an implementation of those steps:

``` swift
let secondHalf = absences.suffix(absences.count / 2)
if let i = secondHalf.indices.max(by: { secondHalf[$0] < secondHalf[$1] }) {
    print("Highest second-half absences: \(absences[i])")
}
// Prints "Highest second-half absences: 3"

```

## Slices Inherit Collection Semantics

A slice inherits the value or reference semantics of its base collection. That is, when working with a slice of a mutable collection that has value semantics, such as an array, mutating the original collection triggers a copy of that collection and does not affect the contents of the slice.

For example, if you update the last element of the `absences` array from `0` to `2`, the `secondHalf` slice is unchanged.

``` swift
absences[7] = 2
print(absences)
// Prints "[0, 2, 0, 4, 0, 3, 1, 2]"
print(secondHalf)
// Prints "[0, 3, 1, 0]"

```

# Traversing a Collection

Although a sequence can be consumed as it is traversed, a collection is guaranteed to be *multipass*: Any element can be repeatedly accessed by saving its index. Moreover, a collection’s indices form a finite range of the positions of the collection’s elements. The fact that all collections are finite guarantees the safety of many sequence operations, such as using the `contains(_:)` method to test whether a collection includes an element.

Iterating over the elements of a collection by their positions yields the same elements in the same order as iterating over that collection using its iterator. This example demonstrates that the `characters` view of a string returns the same characters in the same order whether the view’s indices or the view itself is being iterated.

``` swift
let word = "Swift"
for character in word {
    print(character)
}
// Prints "S"
// Prints "w"
// Prints "i"
// Prints "f"
// Prints "t"

for i in word.indices {
    print(word[i])
}
// Prints "S"
// Prints "w"
// Prints "i"
// Prints "f"
// Prints "t"

```

# Conforming to the Collection Protocol

If you create a custom sequence that can provide repeated access to its elements, make sure that its type conforms to the `Collection` protocol in order to give a more useful and more efficient interface for sequence and collection operations. To add `Collection` conformance to your type, you must declare at least the following requirements:

  - The `startIndex` and `endIndex` properties
  - A subscript that provides at least read-only access to your type’s elements
  - The `index(after:)` method for advancing an index into your collection

# Expected Performance

Types that conform to `Collection` are expected to provide the `startIndex` and `endIndex` properties and subscript access to elements as O(1) operations. Types that are not able to guarantee this performance must document the departure, because many collection operations depend on O(1) subscripting performance for their own performance guarantees.

The performance of some collection operations depends on the type of index that the collection provides. For example, a random-access collection, which can measure the distance between two indices in O(1) time, can calculate its `count` property in O(1) time. Conversely, because a forward or bidirectional collection must traverse the entire collection to count the number of contained elements, accessing its `count` property is an O(*n*) operation.




#### Declaration

``` swift
extension Collection where Element: FirstProtocol

extension Collection where Element == SpmSwiftModule.Nested1
```









[Show members](extensions/collection.md?swift)

[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Extensions.swift#L38-L40)
</details>









<details>
<summary><code>extension Dictionary</code></summary>








A collection whose elements are key-value pairs.

A dictionary is a type of hash table, providing fast access to the entries it contains. Each entry in the table is identified using its key, which is a hashable type such as a string or number. You use that key to retrieve the corresponding value, which can be any object. In other languages, similar data types are known as hashes or associated arrays.

Create a new dictionary by using a dictionary literal. A dictionary literal is a comma-separated list of key-value pairs, in which a colon separates each key from its associated value, surrounded by square brackets. You can assign a dictionary literal to a variable or constant or pass it to a function that expects a dictionary.

Here’s how you would create a dictionary of HTTP response codes and their related messages:

``` swift
var responseMessages = [200: "OK",
                        403: "Access forbidden",
                        404: "File not found",
                        500: "Internal server error"]

```

The `responseMessages` variable is inferred to have type `[Int: String]`. The `Key` type of the dictionary is `Int`, and the `Value` type of the dictionary is `String`.

To create a dictionary with no key-value pairs, use an empty dictionary literal (`[:]`).

``` swift
var emptyDict: [String: String] = [:]

```

Any type that conforms to the `Hashable` protocol can be used as a dictionary’s `Key` type, including all of Swift’s basic types. You can use your own custom types as dictionary keys by making them conform to the `Hashable` protocol.

# Getting and Setting Dictionary Values

The most common way to access values in a dictionary is to use a key as a subscript. Subscripting with a key takes the following form:

``` swift
print(responseMessages[200])
// Prints "Optional("OK")"

```

Subscripting a dictionary with a key returns an optional value, because a dictionary might not hold a value for the key that you use in the subscript.

The next example uses key-based subscripting of the `responseMessages` dictionary with two keys that exist in the dictionary and one that does not.

``` swift
let httpResponseCodes = [200, 403, 301]
for code in httpResponseCodes {
    if let message = responseMessages[code] {
        print("Response \(code): \(message)")
    } else {
        print("Unknown response \(code)")
    }
}
// Prints "Response 200: OK"
// Prints "Response 403: Access forbidden"
// Prints "Unknown response 301"

```

You can also update, modify, or remove keys and values from a dictionary using the key-based subscript. To add a new key-value pair, assign a value to a key that isn’t yet a part of the dictionary.

``` swift
responseMessages[301] = "Moved permanently"
print(responseMessages[301])
// Prints "Optional("Moved permanently")"

```

Update an existing value by assigning a new value to a key that already exists in the dictionary. If you assign `nil` to an existing key, the key and its associated value are removed. The following example updates the value for the `404` code to be simply “Not found” and removes the key-value pair for the `500` code entirely.

``` swift
responseMessages[404] = "Not found"
responseMessages[500] = nil
print(responseMessages)
// Prints "[301: "Moved permanently", 200: "OK", 403: "Access forbidden", 404: "Not found"]"

```

In a mutable `Dictionary` instance, you can modify in place a value that you’ve accessed through a keyed subscript. The code sample below declares a dictionary called `interestingNumbers` with string keys and values that are integer arrays, then sorts each array in-place in descending order.

``` swift
var interestingNumbers = ["primes": [2, 3, 5, 7, 11, 13, 17],
                          "triangular": [1, 3, 6, 10, 15, 21, 28],
                          "hexagonal": [1, 6, 15, 28, 45, 66, 91]]
for key in interestingNumbers.keys {
    interestingNumbers[key]?.sort(by: >)
}

print(interestingNumbers["primes"]!)
// Prints "[17, 13, 11, 7, 5, 3, 2]"

```

# Iterating Over the Contents of a Dictionary

Every dictionary is an unordered collection of key-value pairs. You can iterate over a dictionary using a `for`-`in` loop, decomposing each key-value pair into the elements of a tuple.

``` swift
let imagePaths = ["star": "/glyphs/star.png",
                  "portrait": "/images/content/portrait.jpg",
                  "spacer": "/images/shared/spacer.gif"]

for (name, path) in imagePaths {
    print("The path to '\(name)' is '\(path)'.")
}
// Prints "The path to 'star' is '/glyphs/star.png'."
// Prints "The path to 'portrait' is '/images/content/portrait.jpg'."
// Prints "The path to 'spacer' is '/images/shared/spacer.gif'."

```

The order of key-value pairs in a dictionary is stable between mutations but is otherwise unpredictable. If you need an ordered collection of key-value pairs and don’t need the fast key lookup that `Dictionary` provides, see the `KeyValuePairs` type for an alternative.

You can search a dictionary’s contents for a particular value using the `contains(where:)` or `firstIndex(where:)` methods supplied by default implementation. The following example checks to see if `imagePaths` contains any paths in the `"` directory:

``` swift
let glyphIndex = imagePaths.firstIndex(where: { $0.value.hasPrefix("/glyphs") })
if let index = glyphIndex {
    print("The '\(imagePaths[index].key)' image is a glyph.")
} else {
    print("No glyphs found!")
}
// Prints "The 'star' image is a glyph."

```

Note that in this example, `imagePaths` is subscripted using a dictionary index. Unlike the key-based subscript, the index-based subscript returns the corresponding key-value pair as a non-optional tuple.

``` swift
print(imagePaths[glyphIndex!])
// Prints "(key: "star", value: "/glyphs/star.png")"

```

A dictionary’s indices stay valid across additions to the dictionary as long as the dictionary has enough capacity to store the added values without allocating more buffer. When a dictionary outgrows its buffer, existing indices may be invalidated without any notification.

When you know how many new values you’re adding to a dictionary, use the `init(minimumCapacity:)` initializer to allocate the correct amount of buffer.

# Bridging Between Dictionary and NSDictionary

You can bridge between `Dictionary` and `NSDictionary` using the `as` operator. For bridging to be possible, the `Key` and `Value` types of a dictionary must be classes, `@objc` protocols, or types that bridge to Foundation types.

Bridging from `Dictionary` to `NSDictionary` always takes O(1) time and space. When the dictionary’s `Key` and `Value` types are neither classes nor `@objc` protocols, any required bridging of elements occurs at the first access of each element. For this reason, the first operation that uses the contents of the dictionary may take O(*n*).

Bridging from `NSDictionary` to `Dictionary` first calls the `copy(with:)` method (`- copyWithZone:` in Objective-C) on the dictionary to get an immutable copy and then performs additional Swift bookkeeping work that takes O(1) time. For instances of `NSDictionary` that are already immutable, `copy(with:)` usually returns the same dictionary in O(1) time; otherwise, the copying performance is unspecified. The instances of `NSDictionary` and `Dictionary` share buffer using the same copy-on-write optimization that is used when two instances of `Dictionary` share buffer.




#### Declaration

``` swift
extension Dictionary: P2
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Protocols.swift#L70)
</details>









<details>
<summary><code>extension String.Element</code></summary>








Extension of a nested type from an external module






#### Declaration

``` swift
extension String.Element
```









[Show members](extensions/stringelement.md?swift)

[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Extensions.swift#L56-L61)
</details>









<details>
<summary><code>extension StringProtocol</code></summary>








A type that can represent a string as a collection of characters.

Do not declare new conformances to `StringProtocol`. Only the `String` and `Substring` types in the standard library are valid conforming types.




#### Declaration

``` swift
extension StringProtocol
```









[Show members](extensions/stringprotocol.md?swift)

[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Extensions.swift#L63-L67)
</details>





[&laquo; Operators](operators.md?swift) | [Array &raquo;](extensions/array.md?swift)


-----
&copy; 9999. All rights reserved. (Last updated: today).


Generated by [Bebop v1.0](https://github.com/johnfairh/Bebop)
using the md theme, based on technology from
[jazzy ♪♫](https://github.com/realm/jazzy).


