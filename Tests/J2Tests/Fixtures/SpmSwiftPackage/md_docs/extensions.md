<!--
Bebop simple MD theme
Copyright 2020 J2 Authors
Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
-->
![50%](badge.svg)
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


  * [PropertyWrapperClient](types/propertywrapperclient.md?swift)


  * [SecondProtocol](types/secondprotocol.md?swift)


  * [SpmSwiftModule](types/spmswiftmodule.md?swift)

    * [Nested1](types/spmswiftmodule/nested1.md?swift)

    * [Nested2](types/spmswiftmodule.md?swift#nested2)


  * [T](types.md?swift#t1)



[Functions](functions.md?swift)

  * [deprecatedFunction(callback:)](functions.md?swift#deprecatedfunctioncallback)


  * [functionA(arg1:_:arg3:)](functions.md?swift#functionaarg1_arg3)



[Operators](operators.md?swift)

  * [+(T, T)](operators.md?swift#t-t)



Extensions

  * [Collection](extensions/collection.md?swift)


  * [String.Element](extensions/stringelement.md?swift)





</details>

# Extensions

















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
    print(text[..<firstSpace]
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

[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Extensions.swift#L39-L41)
</details>









<details>
<summary><code>extension String.Element</code></summary>








Extension of a nested type from an external module






#### Declaration

``` swift
extension String.Element
```








[Show members](extensions/stringelement.md?swift)

[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Extensions.swift#L57-L62)
</details>





[&laquo; Operators](operators.md?swift) | [Collection &raquo;](extensions/collection.md?swift)


-----
&copy; 9999. All rights reserved. (Last updated: today).


Generated by [j2 vX.Y](https://github.com/johnfairh/j2)
using the md theme, based on technology from
[jazzy ♪♫](https://github.com/realm/jazzy).


