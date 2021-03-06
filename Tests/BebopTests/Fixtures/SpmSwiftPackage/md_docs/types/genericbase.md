<!--
Bebop simple MD theme
Copyright 2020 Bebop Authors
Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
-->
![48%](../badge.svg)
[![Open in Dash](../img/dash.svg)](dash-feed://https%3A%2F%2Fwww%2Egoogle%2Ecom%2F)


[SpmSwiftModule](../index.md)
 / [Types](../types.md?swift) / GenericBase


<details>
<summary>Contents</summary>


[Types](../types.md?swift)

  * [ABaseClass](../types/abaseclass.md?swift)


  * [ADerivedClass](../types/aderivedclass.md?swift)


  * [AnEnum](../types/anenum.md?swift)


  * [FirstProtocol](../types/firstprotocol1.md?swift)


  * GenericBase


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

  * [Array](../extensions/array.md?swift)


  * [Collection](../extensions/collection.md?swift)


  * [Dictionary](../extensions.md?swift#dictionary)


  * [String.Element](../extensions/stringelement.md?swift)


  * [StringProtocol](../extensions/stringprotocol.md?swift)





</details>

# GenericBase



``` swift
class GenericBase<T>

extension GenericBase: CustomStringConvertible
```










Undocumented












[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Extensions.swift#L1-L10)



## Initializers









<details>
<summary><code>init(type: T)</code></summary>








Undocumented






#### Declaration

``` swift
init(type: T)
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Extensions.swift#L3-L5)
</details>



## Methods









<details>
<summary><code>func mutify() -> T</code></summary>








Undocumented






#### Declaration

``` swift
func mutify() -> T
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Extensions.swift#L7-L9)
</details>



## Properties









<details>
<summary><code>var boxed: T</code></summary>








Undocumented






#### Declaration

``` swift
var boxed: T
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Extensions.swift#L2)
</details>









<details>
<summary><code>var description: String</code></summary>








A textual representation of this instance.

Calling this property directly is discouraged. Instead, convert an instance of any type to a string by using the `String(describing:)` initializer. This initializer works with any type, and uses the custom `description` property for types that conform to `CustomStringConvertible`:

``` swift
struct Point: CustomStringConvertible {
    let x: Int, y: Int

    var description: String {
        return "(\(x), \(y))"
    }
}

let p = Point(x: 21, y: 30)
let s = String(describing: p)
print(s)
// Prints "(21, 30)"

```

The conversion of `p` to a string in the assignment to `s` uses the `Point` type’s `description` property.




#### Declaration

``` swift
var description: String { get }
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Extensions.swift#L33-L35)
</details>



## Available where `T`: `Codable`









<details>
<summary><code>func doCodability()</code></summary>








Undocumented






#### Declaration

``` swift
func doCodability()
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Extensions.swift#L16)
</details>









<details>
<summary><code>var codableCount: Int</code></summary>








Undocumented






#### Declaration

``` swift
var codableCount: Int { get }
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Extensions.swift#L13-L15)
</details>



## Available where `T`: `Equatable`, `T`: [`FirstProtocol`](../types/firstprotocol1.md)









<details>
<summary><code>func doFirstMagic()</code></summary>








Undocumented






#### Declaration

``` swift
func doFirstMagic()
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Extensions.swift#L21)
</details>









<details>
<summary><code>func doMoreMagic()</code></summary>








Undocumented






#### Declaration

``` swift
func doMoreMagic()
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Extensions.swift#L23)
</details>



## Available where `T`: `Hashable`









<details>
<summary><code>func doHashable()</code></summary>








Undocumented






#### Declaration

``` swift
func doHashable()
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Extensions.swift#L28)
</details>





[&laquo; FirstProtocol](../types/firstprotocol1.md?swift) | [Nop &raquo;](../types/nop.md?swift)


-----
&copy; 9999. All rights reserved. (Last updated: today).


Generated by [Bebop v1.0](https://github.com/johnfairh/Bebop)
using the md theme, based on technology from
[jazzy ♪♫](https://github.com/realm/jazzy).


