<!--
Bebop simple MD theme
Copyright 2020 Bebop Authors
Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
-->
![48%](../badge.svg)
[![Open in Dash](../img/dash.svg)](dash-feed://https%3A%2F%2Fwww%2Egoogle%2Ecom%2F)


[SpmSwiftModule](../index.md)
 / [Extensions](../extensions.md?swift) / Swift.Array


<details>
<summary>Contents</summary>


[Types](../types.md?swift)

  * [ABaseClass](../types/abaseclass.md?swift)


  * [ADerivedClass](../types/aderivedclass.md?swift)


  * [AnEnum](../types/anenum.md?swift)


  * [FirstProtocol](../types/firstprotocol1.md?swift)


  * [GenericBase](../types/genericbase.md?swift)


  * [Nop](../types/nop.md?swift)


  * [P1](../types.md?swift#p1)


  * [P2](../types.md?swift#p2)


  * [PropertyWrapperClient](../types/propertywrapperclient.md?swift)


  * [S1](../types/s1.md?swift)


  * [S2](../types/s2.md?swift)


  * [SecondProtocol](../types/secondprotocol.md?swift)


  * [SpmSwiftModule](../types/spmswiftmodule.md?swift)

    * [Nested1](../types/spmswiftmodule/nested1.md?swift)

    * [Nested2](../types/spmswiftmodule.md?swift#nested2)


  * [T](../types.md?swift#t2)



[Functions](../functions.md?swift)

  * [deprecatedFunction(callback:)](../functions.md?swift#deprecatedfunctioncallback)


  * [functionA(arg1:_:arg3:)](../functions.md?swift#functionaarg1_arg3)



[Operators](../operators.md?swift)

  * [+(T, T)](../operators.md?swift#t-t)



[Extensions](../extensions.md?swift)

  * Array


  * [Collection](../extensions/collection.md?swift)


  * [Dictionary](../extensions.md?swift#dictionary)


  * [String.Element](../extensions/stringelement.md?swift)


  * [StringProtocol](../extensions/stringprotocol.md?swift)





</details>

# Array



``` swift
extension Array: P1 where Element: Comparable
```










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










[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Protocols.swift#L72-L74)



## Methods









<details>
<summary><code>func arrayFunc()</code></summary>








Undocumented






#### Declaration

``` swift
func arrayFunc()
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Protocols.swift#L73)
</details>





[&laquo; Extensions](../extensions.md?swift) | [Collection &raquo;](../extensions/collection.md?swift)


-----
&copy; 9999. All rights reserved. (Last updated: today).


Generated by [Bebop v1.0](https://github.com/johnfairh/Bebop)
using the md theme, based on technology from
[jazzy ♪♫](https://github.com/realm/jazzy).


