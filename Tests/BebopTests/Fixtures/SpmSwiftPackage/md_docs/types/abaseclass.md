<!--
Bebop simple MD theme
Copyright 2020 Bebop Authors
Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
-->
![48%](../badge.svg)
[![Open in Dash](../img/dash.svg)](dash-feed://https%3A%2F%2Fwww%2Egoogle%2Ecom%2F)


[SpmSwiftModule](../index.md)
 / [Types](../types.md?swift) / ABaseClass


<details>
<summary>Contents</summary>


[Types](../types.md?swift)

  * ABaseClass


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

  * [Array](../extensions/array.md?swift)


  * [Collection](../extensions/collection.md?swift)


  * [Dictionary](../extensions.md?swift#dictionary)


  * [String.Element](../extensions/stringelement.md?swift)


  * [StringProtocol](../extensions/stringprotocol.md?swift)





</details>

# ABaseClass



``` swift
public class ABaseClass
```










A base class












[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/SpmSwiftModule.swift#L71-L110)



## Initializers









<details>
<summary><code>init()</code></summary>








Undocumented






#### Declaration

``` swift
public init()
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/SpmSwiftModule.swift#L72)
</details>









<details>
<summary><code>init(a: Int)</code></summary>








Undocumented






#### Declaration

``` swift
public convenience init(a: Int)
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/SpmSwiftModule.swift#L74)
</details>



## Deinitializer









<details>
<summary><code>deinit</code></summary>








Undocumented






#### Declaration

``` swift
deinit
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/SpmSwiftModule.swift#L76)
</details>



## Methods









<details>
<summary><code>func method(param: Int) -> String</code></summary>








Base class docs for `method(param:)`






#### Declaration

``` swift
public func method(param: Int) -> String
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/SpmSwiftModule.swift#L78-L80)
</details>



## Operators









<details>
<summary><code>static func +(lhs: ABaseClass, rhs: ABaseClass) -> ABaseClass</code></summary>








An operator\!






#### Declaration

``` swift
public static func + (lhs: ABaseClass, rhs: ABaseClass) -> ABaseClass
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/SpmSwiftModule.swift#L107-L109)
</details>



## Subscripts









<details>
<summary><code>subscript(arg: String) -> Int</code></summary>








Undocumented






#### Declaration

``` swift
public subscript(arg: String) -> Int { get set }
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/SpmSwiftModule.swift#L86-L92)
</details>



## Static Methods









<details>
<summary><code>static func staticMethod() -> Int</code></summary>








Undocumented






#### Declaration

``` swift
public static func staticMethod() -> Int
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/SpmSwiftModule.swift#L82-L84)
</details>



## Static Properties









<details>
<summary><code>static var aStaticVar: Int</code></summary>








Undocumented






#### Declaration

``` swift
static var aStaticVar: Int { get }
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/SpmSwiftModule.swift#L102-L104)
</details>



## Static Subscripts









<details>
<summary><code>static subscript(arg: String) -> Int</code></summary>








Undocumented






#### Declaration

``` swift
public static subscript(arg: String) -> Int { get }
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/SpmSwiftModule.swift#L94-L96)
</details>



## Class Subscripts









<details>
<summary><code>class subscript(arg: Int) -> String</code></summary>








Undocumented






#### Declaration

``` swift
public class subscript(arg: Int) -> String { get }
```











[Show on GitHub](https://www.bbc.co.uk//Sources/SpmSwiftModule/SpmSwiftModule.swift#L98-L100)
</details>





[&laquo; Types](../types.md?swift) | [ADerivedClass &raquo;](../types/aderivedclass.md?swift)


-----
&copy; 9999. All rights reserved. (Last updated: today).


Generated by [Bebop v1.0](https://github.com/johnfairh/Bebop)
using the md theme, based on technology from
[jazzy ♪♫](https://github.com/realm/jazzy).


