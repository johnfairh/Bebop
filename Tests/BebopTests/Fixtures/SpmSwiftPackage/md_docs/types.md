<!--
Bebop simple MD theme
Copyright 2020 Bebop Authors
Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
-->
![48%](badge.svg)
[![Open in Dash](img/dash.svg)](dash-feed://https%3A%2F%2Fwww%2Egoogle%2Ecom%2F)


[SpmSwiftModule](index.md)
 / Types


<details>
<summary>Contents</summary>


Types

  * [ABaseClass](types/abaseclass.md?swift)


  * [ADerivedClass](types/aderivedclass.md?swift)


  * [AnEnum](types/anenum.md?swift)


  * [FirstProtocol](types/firstprotocol1.md?swift)


  * [GenericBase](types/genericbase.md?swift)


  * [Nop](types/nop.md?swift)


  * [P1](#p1)


  * [P2](#p2)


  * [PropertyWrapperClient](types/propertywrapperclient.md?swift)


  * [S1](types/s1.md?swift)


  * [S2](types/s2.md?swift)


  * [SecondProtocol](types/secondprotocol.md?swift)


  * [SpmSwiftModule](types/spmswiftmodule.md?swift)

    * [Nested1](types/spmswiftmodule/nested1.md?swift)

    * [Nested2](types/spmswiftmodule.md?swift#nested2)


  * [T](#t2)



[Functions](functions.md?swift)

  * [deprecatedFunction(callback:)](functions.md?swift#deprecatedfunctioncallback)


  * [functionA(arg1:_:arg3:)](functions.md?swift#functionaarg1_arg3)



[Operators](operators.md?swift)

  * [+(T, T)](operators.md?swift#t-t)



[Extensions](extensions.md?swift)

  * [Array](extensions/array.md?swift)


  * [Collection](extensions/collection.md?swift)


  * [Dictionary](extensions.md?swift#dictionary)


  * [String.Element](extensions/stringelement.md?swift)


  * [StringProtocol](extensions/stringprotocol.md?swift)





</details>

# Types

















<details>
<summary><code>class ABaseClass</code></summary>








A base class






#### Declaration

``` swift
public class ABaseClass
```









[Show members](types/abaseclass.md?swift)

[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/SpmSwiftModule.swift#L71-L110)
</details>









<details>
<summary><code>class ADerivedClass</code></summary>








A derived class






#### Declaration

``` swift
public class ADerivedClass<T, Q>: ABaseClass where Q: Sequence
```









[Show members](types/aderivedclass.md?swift)

[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/SpmSwiftModule.swift#L121-L135)
</details>









<details>
<summary><code>enum AnEnum</code></summary>








An enum






#### Declaration

``` swift
public enum AnEnum
```









[Show members](types/anenum.md?swift)

[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/SpmSwiftModule.swift#L35-L44)
</details>









<details>
<summary><code>protocol FirstProtocol</code></summary>








A protocol.






#### Declaration

``` swift
public protocol FirstProtocol
```









[Show members](types/firstprotocol1.md?swift)

[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Protocols.swift#L2-L16)
</details>









<details>
<summary><code>class GenericBase</code></summary>








Undocumented






#### Declaration

``` swift
class GenericBase<T>

extension GenericBase: CustomStringConvertible
```









[Show members](types/genericbase.md?swift)

[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Extensions.swift#L1-L10)
</details>









<details>
<summary><code>struct Nop</code></summary>








Undocumented






#### Declaration

``` swift
@propertyWrapper
struct Nop
```









[Show members](types/nop.md?swift)

[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/SpmSwiftModule.swift#L138-L144)
</details>









<details>
<summary><code>protocol P1</code></summary>








Undocumented






#### Declaration

``` swift
protocol P1
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Protocols.swift#L49)
</details>









<details>
<summary><code>protocol P2</code></summary>








Undocumented






#### Declaration

``` swift
protocol P2
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Protocols.swift#L50)
</details>









<details>
<summary><code>struct PropertyWrapperClient</code></summary>








See [`@Nop`](types/nop.md).






#### Declaration

``` swift
struct PropertyWrapperClient
```









[Show members](types/propertywrapperclient.md?swift)

[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/SpmSwiftModule.swift#L147-L150)
</details>









<details>
<summary><code>struct S1</code></summary>








Undocumented






#### Declaration

``` swift
struct S1: P1

extension S1: CustomStringConvertible
```









[Show members](types/s1.md?swift)

[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Protocols.swift#L52)
</details>









<details>
<summary><code>struct S2</code></summary>








Undocumented






#### Declaration

``` swift
struct S2<T>: P1 where T: Equatable

extension S2: Equatable where T: Equatable

extension S2: P2 where T: Comparable
```









[Show members](types/s2.md?swift)

[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Protocols.swift#L58-L60)
</details>









<details>
<summary><code>protocol SecondProtocol</code></summary>








Undocumented






#### Declaration

``` swift
public protocol SecondProtocol: FirstProtocol
```









[Show members](types/secondprotocol.md?swift)

[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/Protocols.swift#L18-L20)
</details>









<details>
<summary><code>struct SpmSwiftModule</code></summary>








Main structure






#### Declaration

``` swift
public struct SpmSwiftModule
```









[Show members](types/spmswiftmodule.md?swift)

[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/SpmSwiftModule.swift#L2-L32)
</details>









<details>
<summary><code>struct T</code></summary>








Undocumented






#### Declaration

``` swift
struct T
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/SpmSwiftModule.swift#L112-L113)
</details>





[&laquo; SpmSwiftModule](index.html) | [ABaseClass &raquo;](types/abaseclass.md?swift)


-----
&copy; 9999. All rights reserved. (Last updated: today).


Generated by [Bebop v1.0](https://github.com/johnfairh/Bebop)
using the md theme, based on technology from
[jazzy ♪♫](https://github.com/realm/jazzy).


