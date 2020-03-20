// ObjC header to test/demo ObjC->Swift extensions, name-mapping

@import Foundation;

/// Un-renamed class to check normal things still work
///
/// See `-objcNormalMethod`.
@interface NormalClass : NSObject
/// See `JMLKitchen`.
///
/// See `-[JMLKitchen jmlKitchenMethod]`
- (void)objcNormalMethod;
@end

/// Type with different name in Swift
NS_SWIFT_NAME(Kitchen)
@interface JMLKitchen : NSObject
- (void)jmlKitchenMethod NS_SWIFT_NAME(kitchenMethod());
@end

/// Type with a different shape in Swift - parent exists
NS_SWIFT_NAME(Kitchen.Cupboard)
@interface JMLKitchenCupboard : NSObject
#pragma mark - ObjC methods
-(void)jmlKitchenCupboardMethod;
-(void)jmlKitchenCupboardMethod2;
// Repeat the mark, should merge
#pragma mark - ObjC methods
-(void)jmlKitchenCupboardMethod3;
#pragma mark - ObjC methods part 2
-(void)jmlKitchenCupboardMethod4;
@end

/// Type with a different shape in Swift - parent does not exist
NS_SWIFT_NAME(Bathroom.Cupboard)
@interface JMLBathroomCupboard : NSObject
/// See `Cupboard.jmlKitchenCupboardMethod()`
-(void)jmlBathroomCupboardMethod;
@end
