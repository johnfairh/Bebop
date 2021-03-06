<!--
Bebop simple MD theme
Copyright 2020 Bebop Authors
Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
-->
![48%](../badge.svg)
[![Open in Dash](../img/dash.svg)](dash-feed://https%3A%2F%2Fwww%2Egoogle%2Ecom%2F)


[SpmSwiftModule](../index.md)
 / [Types](../types.md?swift) / FirstProtocol


<details>
<summary>Contents</summary>


[Types](../types.md?swift)

  * [ABaseClass](../types/abaseclass.md?swift)


  * [ADerivedClass](../types/aderivedclass.md?swift)


  * [AnEnum](../types/anenum.md?swift)


  * FirstProtocol


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

  * [Array](../extensions/array.md?swift)


  * [Collection](../extensions/collection.md?swift)


  * [Dictionary](../extensions.md?swift#dictionary)


  * [String.Element](../extensions/stringelement.md?swift)


  * [StringProtocol](../extensions/stringprotocol.md?swift)





</details>

# FirstProtocol



``` swift
public protocol FirstProtocol
```










A protocol.












[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Protocols.swift#L2-L16)



## Associated Types









<details>
<summary><code>associatedtype AssocType</code></summary>








Undocumented






#### Declaration

``` swift
associatedtype AssocType
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Protocols.swift#L10)
</details>



## Methods









<details>
<summary><code>func assocFunc() -> AssocType</code></summary>








Undocumented






#### Declaration

``` swift
func assocFunc() -> AssocType
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Protocols.swift#L11)
</details>









<details>
<summary><code>func e()</code></summary>








ℹ️  Note
  - From a protocol extension: not a customization point.

A protocol extension method






#### Declaration

``` swift
func e()
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Protocols.swift#L32)
</details>









<details>
<summary><code>func e<C>(a: C)</code></summary>








ℹ️  Note
  - From a protocol extension: not a customization point.

A generic protocol extension method






#### Declaration

``` swift
func e<C>(a: C) where C: FirstProtocol
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Protocols.swift#L37)
</details>









<details>
<summary><code>func m(arg: Int) -> String</code></summary>








ℹ️  Note
  - Has a default implementation.

  - Has a default implementation for some conforming types.

Brief note about m

What m is all about.

#### Default Implementation
Return a safe default.


There’s more: it’s the empty string.

#### Declaration

``` swift
func m(arg: Int) -> String
```




#### Parameters

`arg`: The argument





#### Return Value
The answer






[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Protocols.swift#L8)
</details>



## Properties









<details>
<summary><code>var getOnly: Int</code></summary>








Undocumented






#### Declaration

``` swift
var getOnly: Int { get }
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Protocols.swift#L13)
</details>









<details>
<summary><code>var setAndGet: Int</code></summary>








Undocumented






#### Declaration

``` swift
var setAndGet: Int { get set }
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Protocols.swift#L15)
</details>



## Available where [`AssocType`](../types/firstprotocol1.md#assoctype): `Hashable`









<details>
<summary><code>func extHashableMethod()</code></summary>








ℹ️  Note
  - From a protocol extension: not a customization point.

Undocumented






#### Declaration

``` swift
func extHashableMethod()
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Extensions.swift#L47)
</details>









<details>
<summary><code>func m(arg: Int) -> String</code></summary>








ℹ️  Note
  - Default implementation only for types that satisfy the constraints.





#### Default Implementation
Special default implementation for m in Hashable case.




#### Declaration

``` swift
func m(arg: Int) -> String
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Extensions.swift#L50-L52)
</details>





[&laquo; AnEnum](../types/anenum.md?swift) | [GenericBase &raquo;](../types/genericbase.md?swift)


-----
&copy; 9999. All rights reserved. (Last updated: today).


Generated by [Bebop v1.0](https://github.com/johnfairh/Bebop)
using the md theme, based on technology from
[jazzy ♪♫](https://github.com/realm/jazzy).


